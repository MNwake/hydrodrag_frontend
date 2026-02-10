/**
 * Matchups and rounds API. Handles round creation, matchup management, and winner recording.
 */

import { apiGet, apiPost, apiPatch, apiFetch, type ApiResponse } from '$lib/api/client';

const base = (eventId: string) => `/admin/events/${eventId}/matchups`;

export interface MatchupBase {
	matchup_id: string;
	racer_a: string; // registration ID
	racer_b: string | null; // registration ID or null for bye
	winner: string | null; // registration ID or null
	bracket: string; // "W" = winner bracket, "L" = loser bracket
	seed_a: number;
	seed_b: number | null; // null for bye
}

export interface RoundBase {
	id: string;
	event_id: string;
	class_key: string;
	round_number: number;
	matchups: MatchupBase[];
	created_at: string;
	updated_at: string;
	is_complete: boolean;
}

/** Backend creates bracket automatically (seeding, winner/loser rounds). */
export interface RoundCreate {
	class_key: string;
}

export interface MatchupUpdate {
	racer_a?: string;
	racer_b?: string | null;
	winner?: string | null;
}

/** GET /admin/events/{event_id}/matchups?class_key={class_key} */
export async function fetchRounds(
	eventId: string,
	classKey?: string
): Promise<ApiResponse<RoundBase[]>> {
	const query = classKey ? `?class_key=${encodeURIComponent(classKey)}` : '';
	return apiGet<RoundBase[]>(`${base(eventId)}${query}`);
}

/** POST /admin/events/{event_id}/matchups/rounds */
export async function createRound(
	eventId: string,
	payload: RoundCreate
): Promise<ApiResponse<RoundBase>> {
	return apiPost<RoundBase>(`${base(eventId)}/rounds`, payload as unknown as Record<string, unknown>);
}

/** PATCH /admin/events/{event_id}/matchups/rounds/{round_id}/matchups/{matchup_id} */
export async function updateMatchup(
	eventId: string,
	roundId: string,
	matchupId: string,
	payload: MatchupUpdate
): Promise<ApiResponse<MatchupBase>> {
	return apiPatch<MatchupBase>(
		`${base(eventId)}/rounds/${roundId}/matchups/${matchupId}`,
		payload as unknown as Record<string, unknown>
	);
}

/** POST /admin/events/{event_id}/matchups/rounds/{round_id}/matchups/{matchup_id}/winner */
export async function recordMatchupWinner(
	eventId: string,
	roundId: string,
	matchupId: string,
	winnerId: string
): Promise<ApiResponse<MatchupBase>> {
	return apiPost<MatchupBase>(
		`${base(eventId)}/rounds/${roundId}/matchups/${matchupId}/winner`,
		{ winner: winnerId } as unknown as Record<string, unknown>
	);
}

/** DELETE /admin/events/{event_id}/matchups/rounds/{round_id}/matchups/{matchup_id}/winner */
export async function undoMatchupWinner(
	eventId: string,
	roundId: string,
	matchupId: string
): Promise<ApiResponse<MatchupBase>> {
	return apiFetch<MatchupBase>(
		`${base(eventId)}/rounds/${roundId}/matchups/${matchupId}/winner`,
		{ method: 'DELETE' }
	);
}

/** DELETE /admin/events/{event_id}/matchups/rounds/{round_id} */
export async function deleteRound(
	eventId: string,
	roundId: string
): Promise<ApiResponse<void>> {
	return apiFetch<void>(
		`${base(eventId)}/rounds/${roundId}`,
		{ method: 'DELETE' }
	);
}

/** POST /admin/events/{event_id}/classes/{class_key}/reset — reset class to pre-event settings (204) */
export async function resetClass(
	eventId: string,
	classKey: string
): Promise<ApiResponse<void>> {
	return apiFetch<void>(
		`/admin/events/${eventId}/classes/${encodeURIComponent(classKey)}/reset`,
		{ method: 'POST' }
	);
}

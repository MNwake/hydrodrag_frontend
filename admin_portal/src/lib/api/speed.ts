/**
 * Speed session API for top_speed events. Matches backend /speed routes.
 */

import { apiGet, apiPost, type ApiResponse } from '$lib/api/client';

const base = () => '/admin/speed';

export interface SpeedSessionRequest {
	event_id: string;
	class_key: string;
}

export interface SpeedUpdateRequest {
	event_id: string;
	class_key: string;
	registration_id: string;
	speed: number;
}

/** Session response from backend (SpeedSessionBase). */
export interface SpeedSessionBase {
	id: string;
	event: string;
	class_key: string;
	started_at: string | null;
	stopped_at: string | null;
	paused_at: string | null;
	duration_seconds: number;
	total_paused_seconds: number;
	/** Server-computed remaining time (Pydantic @computed_field); included on every session response. */
	remaining_seconds: number;
	rankings: SpeedRankingItem[];
}

export interface SpeedRankingItem {
	place: number;
	registration_id: string;
	top_speed: number;
}

export interface SpeedRankingResponse {
	class_key: string;
	rankings: SpeedRankingItem[];
}

export interface SpeedUpdateWithRankingsResponse {
	registration_id: string;
	top_speed: number;
	speed_updated_at: string;
	rankings: SpeedRankingItem[];
}

/** Set session duration in minutes (1–180). Call before starting the session. */
export async function updateSpeedSessionDuration(
	eventId: string,
	classKey: string,
	minutes: number
): Promise<ApiResponse<SpeedSessionBase>> {
	return apiPost<SpeedSessionBase>(`${base()}/duration`, {
		event_id: eventId,
		class_key: classKey,
		minutes
	});
}

/** Start a speed session. Duration is taken from the last set_duration call (or backend default). */
export async function startSpeedSession(
	eventId: string,
	classKey: string
): Promise<ApiResponse<SpeedSessionBase>> {
	return apiPost<SpeedSessionBase>(`${base()}/start`, { event_id: eventId, class_key: classKey });
}

export async function stopSpeedSession(
	eventId: string,
	classKey: string
): Promise<ApiResponse<SpeedSessionBase>> {
	return apiPost<SpeedSessionBase>(`${base()}/stop`, { event_id: eventId, class_key: classKey });
}

export async function getSpeedSessionInfo(
	eventId: string,
	classKey: string
): Promise<ApiResponse<SpeedSessionBase>> {
	const q = `?event_id=${encodeURIComponent(eventId)}`;
	return apiGet<SpeedSessionBase>(`${base()}/session/${encodeURIComponent(classKey)}${q}`);
}

export async function updateSpeed(
	eventId: string,
	classKey: string,
	registrationId: string,
	speed: number
): Promise<ApiResponse<SpeedUpdateWithRankingsResponse>> {
	return apiPost<SpeedUpdateWithRankingsResponse>(`${base()}/update`, {
		event_id: eventId,
		class_key: classKey,
		registration_id: registrationId,
		speed
	});
}

export async function getSpeedRankings(
	eventId: string,
	classKey: string
): Promise<ApiResponse<SpeedRankingResponse>> {
	const q = `?event_id=${encodeURIComponent(eventId)}`;
	return apiGet<SpeedRankingResponse>(`${base()}/rankings/${encodeURIComponent(classKey)}${q}`);
}

export async function resetSpeedSession(
	eventId: string,
	classKey: string
): Promise<ApiResponse<void>> {
	return apiPost<void>(`${base()}/reset`, { event_id: eventId, class_key: classKey });
}

/** Pause session. Returns no body; refetch session info after. */
export async function pauseSpeedSession(
	eventId: string,
	classKey: string
): Promise<ApiResponse<void>> {
	return apiPost<void>(`${base()}/pause`, { event_id: eventId, class_key: classKey });
}

/** Resume session. Returns no body; refetch session info after. */
export async function resumeSpeedSession(
	eventId: string,
	classKey: string
): Promise<ApiResponse<void>> {
	return apiPost<void>(`${base()}/resume`, { event_id: eventId, class_key: classKey });
}

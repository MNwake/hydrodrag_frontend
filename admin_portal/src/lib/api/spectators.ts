/**
 * Spectator passes API.
 * TODO: Backend not built yet. Placeholder types and fetches.
 */

import { apiGet } from '$lib/api/client';

const ensureSlash = (p: string) => (p.startsWith('/') ? p : `/${p}`);

export type SpectatorPassType = 'day' | 'weekend';

/** Placeholder: single spectator pass record (for future list endpoints). */
export interface SpectatorPassRow {
	id: string;
	pass_type: SpectatorPassType;
	event_id?: string | null;
	quantity?: number;
	created_at?: string;
	[key: string]: unknown;
}

export interface SpectatorCounts {
	dayPasses: number;
	weekendPasses: number;
}

/**
 * Fetch spectator pass counts (day + weekend).
 * TODO: Replace with GET /spectators/counts or similar when backend exists.
 */
export async function fetchSpectatorCounts(): Promise<{
	dayPasses: number;
	weekendPasses: number;
	error: string | null;
}> {
	// Placeholder: no backend yet.
	// const res = await apiGet<{ day_pass_count: number; weekend_pass_count: number }>(ensureSlash('/spectators/counts'));
	// if (!res.ok) return { dayPasses: 0, weekendPasses: 0, error: res.error };
	// return { dayPasses: res.data?.day_pass_count ?? 0, weekendPasses: res.data?.weekend_pass_count ?? 0, error: null };
	return { dayPasses: 0, weekendPasses: 0, error: null };
}

/**
 * List day passes.
 * TODO: Replace with GET /spectators/passes?type=day or similar when backend exists.
 */
export async function fetchDayPasses(): Promise<{
	ok: boolean;
	data: SpectatorPassRow[] | null;
	error: string | null;
}> {
	// Placeholder: no backend yet.
	return { ok: true, data: [], error: null };
}

/**
 * List weekend passes.
 * TODO: Replace with GET /spectators/passes?type=weekend or similar when backend exists.
 */
export async function fetchWeekendPasses(): Promise<{
	ok: boolean;
	data: SpectatorPassRow[] | null;
	error: string | null;
}> {
	// Placeholder: no backend yet.
	return { ok: true, data: [], error: null };
}

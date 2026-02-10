/**
 * Web-only API functions for admin resources.
 * All URLs derived from VITE_API_BASE_URL. No shared code with other clients.
 */

import { apiGet } from '$lib/api/client';
import { fetchEvents as fetchEventsApi, type EventListResponse, type EventBase } from '$lib/api/events';
import { fetchEventRegistrations, type EventRegistrationAdmin } from '$lib/api/registrations';

const ensureSlash = (p: string) => (p.startsWith('/') ? p : `/${p}`);

/** @deprecated Use fetchEvents from $lib/api/events */
export async function fetchEvents(page = 1, pageSize = 100) {
	const cappedPageSize = Math.min(pageSize, MAX_PAGE_SIZE);
	return fetchEventsApi(page, cappedPageSize);
}

export type { EventListResponse };

/** GET /racers/all (RacerBase) */
export interface RacerRow {
	id: string;
	email: string;
	first_name?: string | null;
	last_name?: string | null;
	/** Backend computed: "first_name last_name". */
	full_name?: string | null;
	phone?: string | null;
	class_category?: string | null;
	has_valid_waiver?: boolean;
	is_of_age?: boolean;
	membership_number?: string | null;
	waiver_signed_at?: string | null;
	[key: string]: unknown;
}

/** Full racer model (RacerBase) for profile / GET /racers/{id} */
export interface RacerProfile extends RacerRow {
	date_of_birth?: string | null;
	gender?: string | null;
	nationality?: string | null;
	emergency_contact_name?: string | null;
	emergency_contact_phone?: string | null;
	street?: string | null;
	city?: string | null;
	state_province?: string | null;
	country?: string | null;
	zip_postal_code?: string | null;
	bio?: string | null;
	sponsors?: string[] | null;
	organization?: string | null;
	profile_image_path?: string | null;
	banner_image_path?: string | null;
	banner_image_updated_at?: string | null;
	profile_image_updated_at?: string | null;
	waiver_path?: string | null;
	profile_complete?: boolean;
}

export async function fetchRacers() {
	return apiGet<RacerRow[]>(ensureSlash('/admin/racers/all'));
}

/** GET /admin/racers/{racer_id} — single racer profile (RacerBase). */
export async function fetchRacer(id: string) {
	return apiGet<RacerProfile>(ensureSlash(`/admin/racers/${id}`));
}

/**
 * Admin list of all PWCs.
 * TODO: Backend does not expose GET /admin/pwcs or GET /pwcs. Add endpoint
 * that returns all PWCs across racers (id, make, model, engine_class, is_primary, racer_id, etc.).
 */
export interface PwcRow {
	id: string;
	make: string;
	model: string;
	engine_class?: string | null;
	is_primary: boolean;
	racer_id?: string;
	[key: string]: unknown;
}

export async function fetchPwcs(): Promise<{
	ok: boolean;
	status: number;
	data: PwcRow[] | null;
	error: string | null;
}> {
	// TODO: Implement when backend adds GET /admin/pwcs or GET /pwcs (list all).
	// Placeholder: return empty list.
	return { ok: true, status: 200, data: [], error: null };
}

/**
 * Admin list of all registrations.
 * Aggregates registrations from all events by fetching each event's registrations.
 */
export interface RegistrationRow {
	id: string;
	racer_name: string;
	class_name: string;
	status: string;
	amount: string;
	registration_date: string;
	[key: string]: unknown;
}

/** Full registration kept for detail modal. */
export interface RegistrationWithDetail {
	row: RegistrationRow;
	reg: EventRegistrationAdmin;
}

export interface EventRegistrations {
	event_id: string;
	event_name: string;
	event_date: string;
	registrations: RegistrationWithDetail[];
}

const MAX_PAGE_SIZE = 500;

export async function fetchRegistrations(): Promise<{
	ok: boolean;
	status: number;
	data: EventRegistrations[] | null;
	error: string | null;
}> {
	try {
		// Fetch all events with pagination (max 500 per page)
		const allEvents: EventBase[] = [];
		let page = 1;
		let hasMore = true;

		while (hasMore) {
			const eventsRes = await fetchEventsApi(page, MAX_PAGE_SIZE);
			if (!eventsRes.ok) {
				return {
					ok: false,
					status: eventsRes.status,
					data: null,
					error: eventsRes.error ?? 'Failed to fetch events'
				};
			}

			const events = eventsRes.data?.events ?? [];
			allEvents.push(...events);

			// Check if there are more pages
			const total = eventsRes.data?.total ?? 0;
			hasMore = allEvents.length < total;
			page++;
		}

		if (allEvents.length === 0) {
			return { ok: true, status: 200, data: [], error: null };
		}

		// Format event date
		function formatEventDate(event: EventBase): string {
			try {
				const startDate = new Date(event.start_date);
				const endDate = event.end_date ? new Date(event.end_date) : null;
				
				const startFormatted = startDate.toLocaleDateString('en-US', {
					year: 'numeric',
					month: 'short',
					day: 'numeric'
				});
				
				if (endDate && endDate.getTime() !== startDate.getTime()) {
					const endFormatted = endDate.toLocaleDateString('en-US', {
						year: 'numeric',
						month: 'short',
						day: 'numeric'
					});
					return `${startFormatted} - ${endFormatted}`;
				}
				return startFormatted;
			} catch {
				return event.start_date;
			}
		}

		// Fetch registrations for each event and group by event
		const eventRegistrations: EventRegistrations[] = [];

		for (const event of allEvents) {
			const regRes = await fetchEventRegistrations(event.id);
			if (regRes.ok && regRes.data) {
				const registrations: RegistrationWithDetail[] = [];

				for (const reg of regRes.data as EventRegistrationAdmin[]) {
					// Racer name: use hydrated racer object; backend may send racer as id string, so prefer object from racer or racer_model
					let racerName = 'Unknown';
					const racerObj =
						typeof reg.racer === 'object' && reg.racer != null
							? reg.racer
							: reg.racer_model ?? null;
					if (racerObj) {
						const full = (racerObj.full_name ?? '').toString().trim();
						const first = (racerObj.first_name ?? '').toString().trim();
						const last = (racerObj.last_name ?? '').toString().trim();
						const fromParts = [first, last].filter(Boolean).join(' ').trim();
						racerName = full || fromParts || (racerObj.email ? String(racerObj.email) : 'Unknown');
					}

					// Price: use event class price when available; backend sends price in dollars (e.g. 250 = $250)
					const eventObj = reg.event;
					const classPrice =
						eventObj?.classes?.find((c: { key: string }) => c.key === reg.class_key)?.price ??
						reg.price;
					const amount = `$${Number(classPrice).toFixed(2)}`;

					let registrationDate = '—';
					if (reg.created_at) {
						try {
							const date = new Date(reg.created_at);
							registrationDate = date.toLocaleDateString('en-US', {
								year: 'numeric',
								month: 'short',
								day: 'numeric'
							});
						} catch {
							registrationDate = String(reg.created_at);
						}
					}

					registrations.push({
						row: {
							id: reg.id,
							racer_name: racerName,
							class_name: reg.class_name ?? '—',
							status: reg.is_paid ? 'Paid' : 'Unpaid',
							amount,
							registration_date: registrationDate
						},
						reg
					});
				}

				if (registrations.length > 0) {
					eventRegistrations.push({
						event_id: event.id,
						event_name: event.name,
						event_date: formatEventDate(event),
						registrations
					});
				}
			}
		}

		// Sort events by start date (most recent first)
		eventRegistrations.sort((a, b) => {
			const eventA = allEvents.find(e => e.id === a.event_id);
			const eventB = allEvents.find(e => e.id === b.event_id);
			if (!eventA || !eventB) return 0;
			return new Date(eventB.start_date).getTime() - new Date(eventA.start_date).getTime();
		});

		return {
			ok: true,
			status: 200,
			data: eventRegistrations,
			error: null
		};
	} catch (err) {
		return {
			ok: false,
			status: 500,
			data: null,
			error: err instanceof Error ? err.message : 'Unknown error fetching registrations'
		};
	}
}

/** GET /admin/dashboard/counts — events, racers, registrations, revenue breakdown, spectator passes. */
export async function fetchDashboardCounts(): Promise<{
	events: number;
	racers: number;
	registrations: number;
	event_revenue: number;
	spectator_revenue: number;
	membership_revenue: number;
	dayPasses: number;
	weekendPasses: number;
	error: string | null;
}> {
	const res = await apiGet<{
		events: number;
		racers: number;
		registrations: number;
		event_revenue: number;
		spectator_revenue: number;
		membership_revenue: number;
		dayPasses: number;
		weekendPasses: number;
	}>(ensureSlash('/admin/dashboard/counts'));

	if (!res.ok) {
		return {
			events: 0,
			racers: 0,
			registrations: 0,
			event_revenue: 0,
			spectator_revenue: 0,
			membership_revenue: 0,
			dayPasses: 0,
			weekendPasses: 0,
			error: res.error ?? 'Failed to load dashboard counts'
		};
	}

	const d = res.data;
	return {
		events: d?.events ?? 0,
		racers: d?.racers ?? 0,
		registrations: d?.registrations ?? 0,
		event_revenue: d?.event_revenue ?? 0,
		spectator_revenue: d?.spectator_revenue ?? 0,
		membership_revenue: d?.membership_revenue ?? 0,
		dayPasses: d?.dayPasses ?? 0,
		weekendPasses: d?.weekendPasses ?? 0,
		error: null
	};
}

/** GET /admin/dashboard/charts — registrations over time, racers per class. */
export async function fetchDashboardCharts(): Promise<{
	registrations_over_time: { period: string; count: number }[];
	racers_per_class: { class_key: string; class_name: string; count: number }[];
	error: string | null;
}> {
	const res = await apiGet<{
		registrations_over_time: { period: string; count: number }[];
		racers_per_class: { class_key: string; class_name: string; count: number }[];
	}>(ensureSlash('/admin/dashboard/charts'));

	if (!res.ok) {
		return {
			registrations_over_time: [],
			racers_per_class: [],
			error: res.error ?? 'Failed to load dashboard charts'
		};
	}

	const d = res.data;
	return {
		registrations_over_time: d?.registrations_over_time ?? [],
		racers_per_class: d?.racers_per_class ?? [],
		error: null
	};
}

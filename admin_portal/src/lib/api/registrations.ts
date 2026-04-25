/**
 * Event registration API. Matches backend /registrations routes.
 * Admin endpoint returns EventRegistrationAdminBase with hydrated event, racer, payment.
 */

import { apiGet, apiPatch, type ApiResponse } from '$lib/api/client';
import type { EventBase, RacerHydrated } from '$lib/api/events';
import type { PayPalCheckoutRead } from '$lib/api/paypal';

const base = () => '/admin/registrations';

/** Admin-hydrated registration: fully hydrated event, racer, and optional payment. */
export interface EventRegistrationAdmin {
	id: string;

	pwc_identifier: string;
	class_key: string;
	class_name: string;
	price: number;

	losses: number;
	top_speed?: number | null;
	speed_updated_at?: string | null;
	is_paid: boolean;
	created_at: string;

	event: EventBase;
	racer: RacerHydrated;

	payment?: PayPalCheckoutRead | null;
	/** Computed: losses >= 2. */
	is_eliminated?: boolean;

	// Back-compat: older backend response used `racer_model` instead of hydrating `racer`.
	racer_model?: RacerHydrated | null;

	// Computed on the backend (depends on racer details).
	has_valid_waiver?: boolean;
	is_of_age?: boolean;
	has_ihra_membership?: boolean;
}

export interface EventRegistrationAdminUpdate {
	losses?: number;
	is_paid?: boolean;
	top_speed?: number;
	speed_updated_at?: string | null;
	payment_is_captured?: boolean;
	/** Target event (Mongo id). */
	event_id?: string;
	class_key?: string;
	/** Racer-owned PWC document id (stored on registration as `pwc_identifier`). */
	pwc_id?: string;
	/** Legacy or admin text when `pwc_id` is not used (non–ObjectId on file). */
	pwc_identifier?: string;
}

/** GET /admin/registrations/event/{event_id}/registrations — returns admin-hydrated list. */
export async function fetchEventRegistrations(
	eventId: string
): Promise<ApiResponse<EventRegistrationAdmin[]>> {
	return apiGet<EventRegistrationAdmin[]>(`${base()}/event/${eventId}/registrations`);
}

/** GET /admin/registrations/racer/{racer_id} */
export async function fetchRegistrationsByRacer(
	racerId: string
): Promise<ApiResponse<EventRegistrationAdmin[]>> {
	return apiGet<EventRegistrationAdmin[]>(`${base()}/racer/${racerId}`);
}

/** PATCH /admin/registrations/{registration_id} */
export async function updateRegistration(
	registrationId: string,
	payload: EventRegistrationAdminUpdate
): Promise<ApiResponse<EventRegistrationAdmin>> {
	// Only send fields that are present (avoid overwriting with undefined).
	const body: Record<string, unknown> = {};
	for (const [k, v] of Object.entries(payload)) {
		if (v !== undefined) body[k] = v;
	}
	return apiPatch<EventRegistrationAdmin>(`${base()}/${registrationId}`, body);
}

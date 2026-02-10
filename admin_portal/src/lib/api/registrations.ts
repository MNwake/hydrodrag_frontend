/**
 * Event registration API. Matches backend /registrations routes.
 * Admin endpoint returns EventRegistrationAdminBase with hydrated event, racer, payment.
 */

import { apiGet, type ApiResponse } from '$lib/api/client';
import type { EventBase, EventRegistrationBase, RacerHydrated } from '$lib/api/events';
import type { PayPalCheckoutRead } from '$lib/api/paypal';

const base = () => '/admin/registrations';

/** Admin-hydrated registration: full event, racer, and optional payment. */
export interface EventRegistrationAdmin extends EventRegistrationBase {
	event?: EventBase | null;
	racer?: RacerHydrated | null;
	payment?: PayPalCheckoutRead | null;
	is_eliminated?: boolean;
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

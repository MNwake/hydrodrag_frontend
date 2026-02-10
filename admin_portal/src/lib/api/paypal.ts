/**
 * Admin PayPal transactions API. Matches backend PayPalCheckoutRead.
 */

import { apiGet, type ApiResponse } from '$lib/api/client';

/** Minimal event in checkout (EventBase). */
export interface PayPalEventRef {
	id: string;
	name: string;
	[key: string]: unknown;
}

/** Minimal racer in checkout (RacerBase). */
export interface PayPalRacerRef {
	id: string;
	email?: string | null;
	first_name?: string | null;
	last_name?: string | null;
	/** Backend computed: "first_name last_name". */
	full_name?: string | null;
	[key: string]: unknown;
}

export interface PayPalCheckoutRead {
	id: string;
	paypal_order_id: string;
	event: PayPalEventRef;
	racer: PayPalRacerRef;
	class_entries: Record<string, string>;
	spectator_single_day_passes: number;
	spectator_weekend_passes: number;
	purchase_ihra_membership: boolean;
	is_captured: boolean;
	created_at?: string | null;
}

/** GET /admin/paypal/transactions */
export async function fetchPayPalTransactions(
	eventId: string | null = null,
	captured: boolean | null = null
): Promise<ApiResponse<PayPalCheckoutRead[]>> {
	const params = new URLSearchParams();
	if (eventId != null && eventId !== '') params.set('event_id', eventId);
	if (captured !== null) params.set('captured', String(captured));
	const q = params.toString() ? `?${params.toString()}` : '';
	return apiGet<PayPalCheckoutRead[]>(`/admin/paypal/transactions${q}`);
}

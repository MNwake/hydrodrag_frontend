/**
 * Admin PayPal transactions API. Matches backend PayPalCheckoutRead.
 */

import { apiGet, apiPost, type ApiResponse } from '$lib/api/client';

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
	checkout_type?: string | null;
	event?: PayPalEventRef | null;
	racer?: PayPalRacerRef | null;
	purchaser_name?: string | null;
	purchaser_email?: string | null;
	class_entries?: Record<string, string>;
	spectator_single_day_passes: number;
	spectator_weekend_passes: number;
	purchase_ihra_membership: boolean;
	total_amount?: number;
	is_captured: boolean;
	created_at?: string | null;
	captured_at?: string | null;
}

export interface AdminPayPalCaptureRequest {
	paypal_order_id: string;
	send_email?: boolean;
	staff_verified?: boolean;
}

export interface AdminPayPalCaptureResponse {
	checkout_type?: string | null;
	status: string;
	tickets?: { ticket_code: string; ticket_type: string }[];
	registration_ids?: string[];
	email_sent?: boolean;
	email_error?: string | null;
	[key: string]: unknown;
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

/** POST /admin/paypal/checkout/capture — finalize when customer paid but app never confirmed */
export async function capturePayPalCheckout(
	payload: AdminPayPalCaptureRequest
): Promise<ApiResponse<AdminPayPalCaptureResponse>> {
	return apiPost<AdminPayPalCaptureResponse>('/admin/paypal/checkout/capture', payload);
}

export function checkoutTypeLabel(checkoutType: string | null | undefined): string {
	const t = (checkoutType ?? '').trim();
	if (t === 'spectator') return 'Spectator (app)';
	if (t === 'spectator_admin') return 'Spectator (admin)';
	if (t === 'admin_registration') return 'Registration (admin)';
	if (t === 'shirt') return 'Shirt';
	if (!t) return 'Registration (app)';
	return t;
}

/**
 * Event registration API. Matches backend /registrations routes.
 * Admin endpoint returns EventRegistrationAdminBase with hydrated event, racer, payment.
 */

import { apiDelete, apiGet, apiPatch, apiPost, type ApiResponse } from '$lib/api/client';
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

	payment_status?: string;
	payment_status_label?: string;
	amount_collected?: number;
	list_price?: number;
	discount_applied?: number;
	promo_code?: string | null;
	registration_source?: string;
	admin_payment_method?: string | null;
	qr_code?: string | null;
}

export interface AdminCreateRegistrationPayload {
	event_id: string;
	racer_id: string;
	pwc_id: string;
	class_keys: string[];
	payment_method?: 'paypal' | 'cash' | 'check' | 'complimentary';
	mark_paid?: boolean;
	promo_code?: string | null;
	notes?: string | null;
	send_qr_email?: boolean;
}

export interface AdminTransferRegistrationPayload {
	racer_id: string;
	pwc_id: string;
	event_id?: string;
	class_key?: string;
	send_qr_email?: boolean;
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
	/** Admin override: set registration PWC ID directly (any text, e.g. boat number). */
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
/** DELETE /admin/registrations/{registration_id} */
export async function deleteRegistration(
	registrationId: string
): Promise<ApiResponse<void>> {
	return apiDelete(`${base()}/${registrationId}`);
}

/** POST /admin/registrations/{registration_id}/transfer */
export async function transferRegistration(
	registrationId: string,
	payload: AdminTransferRegistrationPayload
): Promise<ApiResponse<EventRegistrationAdmin>> {
	return apiPost<EventRegistrationAdmin>(
		`${base()}/${registrationId}/transfer`,
		payload as unknown as Record<string, unknown>
	);
}

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

export async function createAdminRegistration(
	payload: AdminCreateRegistrationPayload
): Promise<ApiResponse<EventRegistrationAdmin[]>> {
	return apiPost<EventRegistrationAdmin[]>(`${base()}/create`, payload as unknown as Record<string, unknown>);
}

export interface AdminRegistrationPayPalCreate {
	event_id: string;
	racer_id: string;
	pwc_id: string;
	class_keys: string[];
	promo_code?: string | null;
}

export interface AdminRegistrationPayPalResponse {
	paypal_order_id: string;
	approval_url: string;
	amount: number;
	free_checkout?: boolean;
	registration_ids?: string[];
}

export interface AdminRegistrationPayPalPending {
	paypal_order_id: string;
	event_id?: string | null;
	event_name?: string | null;
	racer_id?: string | null;
	racer_name?: string | null;
	class_keys: string[];
	amount: number;
	created_at?: string | null;
}

export interface AdminRegistrationPayPalCaptureResponse {
	status: string;
	paypal_order_id: string;
	registration_ids: string[];
}

/** POST /admin/registrations/paypal/checkout/create */
export async function createAdminRegistrationPayPalCheckout(
	payload: AdminRegistrationPayPalCreate
): Promise<ApiResponse<AdminRegistrationPayPalResponse>> {
	return apiPost<AdminRegistrationPayPalResponse>(
		`${base()}/paypal/checkout/create`,
		payload as unknown as Record<string, unknown>
	);
}

/** GET /admin/registrations/paypal/pending */
export async function fetchPendingAdminRegistrationCheckouts(
	eventId?: string | null
): Promise<ApiResponse<AdminRegistrationPayPalPending[]>> {
	const q = eventId ? `?event_id=${encodeURIComponent(eventId)}` : '';
	return apiGet<AdminRegistrationPayPalPending[]>(`${base()}/paypal/pending${q}`);
}

/** POST /admin/registrations/paypal/checkout/capture */
export async function captureAdminRegistrationPayPalCheckout(paypalOrderId: string) {
	return apiPost<AdminRegistrationPayPalCaptureResponse>(
		`${base()}/paypal/checkout/capture`,
		{ paypal_order_id: paypalOrderId }
	);
}

export async function resendRacerQr(registrationId: string): Promise<ApiResponse<{ ok: boolean }>> {
	return apiPost(`${base()}/${registrationId}/resend-qr`, {});
}

export async function regenerateRacerQr(
	registrationId: string
): Promise<ApiResponse<{ ok: boolean; qr_code: string; email_sent: boolean }>> {
	return apiPost(`${base()}/${registrationId}/regenerate-qr`, {});
}

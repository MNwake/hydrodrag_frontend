/**
 * Spectator tickets API. Matches backend /tickets (SpectatorTicketBase).
 */

import { apiGet, apiPatch, apiPost, type ApiResponse } from '$lib/api/client';

const base = () => '/admin/tickets';

/** Minimal racer when backend returns hydrated ticket (SpectatorTicketAdminBase). */
export interface SpectatorTicketRacerRef {
	full_name?: string | null;
	first_name?: string | null;
	last_name?: string | null;
	[key: string]: unknown;
}

/** Matches backend SpectatorTicketBase (IDs for event, racer, payment). Racer may be hydrated as object. */
export interface SpectatorTicketBase {
	id: string;
	event?: string | null;
	racer?: string | SpectatorTicketRacerRef | null;
	payment?: string | null;
	purchaser_name: string;
	purchaser_phone: string;
	purchaser_email?: string | null;
	ticket_code: string;
	ticket_type: 'single_day' | 'weekend';
	/** spectator (mobile default); vendor/sponsor/vip set in admin only */
	attendee_category?: 'spectator' | 'vendor' | 'sponsor' | 'vip';
	is_used: boolean;
	used_at?: string | null;
	created_at: string;
	[key: string]: unknown;
}

export type AttendeeCategory = 'spectator' | 'vendor' | 'sponsor' | 'vip';

export interface AdminCreateSpectatorTicketPayload {
	ticket_type: 'single_day' | 'weekend';
	quantity: number;
	purchaser_name: string;
	purchaser_phone?: string | null;
	purchaser_email?: string | null;
	send_email: boolean;
	/** Admin-only; mobile purchases are always spectator */
	attendee_category?: AttendeeCategory;
	event_id?: string | null;
}

export interface AdminCreateSpectatorTicketResult {
	tickets: SpectatorTicketBase[];
	email_sent: boolean;
	email_error?: string | null;
}

export interface ResendTicketEmailPayload {
	ticket_code: string;
	to_email?: string | null;
}

export interface ResendTicketEmailResult {
	email_sent: boolean;
	to_email: string;
	email_error?: string | null;
}

/** GET /admin/tickets — list spectator tickets. */
export async function fetchTickets(
	eventId: string | null = null,
	used: boolean | null = null,
	attendeeCategory: AttendeeCategory | null = null
): Promise<ApiResponse<SpectatorTicketBase[]>> {
	const params = new URLSearchParams();
	if (eventId != null && eventId !== '') params.set('event_id', eventId);
	if (used !== null) params.set('used', String(used));
	if (attendeeCategory) params.set('attendee_category', attendeeCategory);
	const q = params.toString() ? `?${params.toString()}` : '';
	return apiGet<SpectatorTicketBase[]>(`${base()}${q}`);
}

/** PATCH /admin/tickets/{id}/category — admin-only category change */
export async function updateTicketCategory(
	ticketId: string,
	attendeeCategory: AttendeeCategory
): Promise<ApiResponse<SpectatorTicketBase>> {
	return apiPatch<SpectatorTicketBase>(`${base()}/${ticketId}/category`, {
		attendee_category: attendeeCategory
	});
}

/** Response from POST /admin/tickets/scan — success with ticket, or error. */
export interface ScanTicketSuccess {
	success: true;
	ticket: SpectatorTicketBase;
}
export interface ScanTicketError {
	success: false;
	error: string;
	used_at?: string | null;
}
export type ScanTicketResponse = ScanTicketSuccess | ScanTicketError;

/** POST /admin/tickets/scan?ticket_code=... — scan a ticket by code (FastAPI reads ticket_code from query). */
export async function scanTicket(ticketCode: string): Promise<ApiResponse<ScanTicketResponse>> {
	const q = `?ticket_code=${encodeURIComponent(ticketCode)}`;
	return apiPost<ScanTicketResponse>(`${base()}/scan${q}`, {});
}

/** POST /admin/tickets/undo-scan?ticket_code=... — undo scan (mark ticket unused). Same response shape as scan. */
export async function undoScanTicket(ticketCode: string): Promise<ApiResponse<ScanTicketResponse>> {
	const q = `?ticket_code=${encodeURIComponent(ticketCode)}`;
	return apiPost<ScanTicketResponse>(`${base()}/undo-scan${q}`, {});
}

/** POST /admin/tickets/create — complimentary spectator ticket (no purchase). */
export async function createComplimentarySpectatorTicket(
	body: AdminCreateSpectatorTicketPayload
): Promise<ApiResponse<AdminCreateSpectatorTicketResult>> {
	return apiPost<AdminCreateSpectatorTicketResult>(`${base()}/create`, {
		ticket_type: body.ticket_type,
		quantity: body.quantity,
		purchaser_name: body.purchaser_name,
		purchaser_phone: body.purchaser_phone?.trim() || null,
		purchaser_email: body.purchaser_email?.trim() || null,
		send_email: body.send_email,
		attendee_category: body.attendee_category ?? 'spectator',
		...(body.event_id ? { event_id: body.event_id } : {})
	});
}

export interface SpectatorPayPalCheckoutCreate {
	purchaser_name: string;
	purchaser_phone?: string | null;
	purchaser_email?: string | null;
	spectator_single_day_passes?: number;
	spectator_weekend_passes?: number;
	event_id?: string | null;
	attendee_category?: AttendeeCategory;
}

export interface SpectatorPayPalCheckoutResponse {
	paypal_order_id: string;
	approval_url: string;
	amount: number;
}

export interface SpectatorPayPalCaptureRequest {
	paypal_order_id: string;
	send_email?: boolean;
	staff_verified?: boolean;
}

export interface SpectatorPayPalCaptureResponse {
	status: string;
	tickets: { ticket_code: string; ticket_type: string }[];
	email_sent?: boolean;
	email_error?: string | null;
}

export interface SpectatorPayPalPending {
	paypal_order_id: string;
	purchaser_name?: string | null;
	purchaser_email?: string | null;
	spectator_single_day_passes: number;
	spectator_weekend_passes: number;
	amount: number;
	created_at?: string | null;
	/** mobile = app checkout; admin = admin portal link */
	source?: 'mobile' | 'admin' | string;
}

export async function createSpectatorPayPalCheckout(
	body: SpectatorPayPalCheckoutCreate
): Promise<ApiResponse<SpectatorPayPalCheckoutResponse>> {
	return apiPost<SpectatorPayPalCheckoutResponse>(
		`${base()}/paypal/checkout/create`,
		body as unknown as Record<string, unknown>
	);
}

export async function captureSpectatorPayPalCheckout(
	body: SpectatorPayPalCaptureRequest
): Promise<ApiResponse<SpectatorPayPalCaptureResponse>> {
	return apiPost<SpectatorPayPalCaptureResponse>(
		`${base()}/paypal/checkout/capture`,
		body as unknown as Record<string, unknown>
	);
}

export async function fetchPendingSpectatorCheckouts(
	eventId: string | null = null
): Promise<ApiResponse<SpectatorPayPalPending[]>> {
	const q = eventId ? `?event_id=${encodeURIComponent(eventId)}` : '';
	return apiGet<SpectatorPayPalPending[]>(`${base()}/paypal/pending${q}`);
}

/** POST /admin/tickets/resend-email — resend QR ticket email to purchaser or to_email override. */
export async function resendTicketEmail(
	body: ResendTicketEmailPayload
): Promise<ApiResponse<ResendTicketEmailResult>> {
	const payload: Record<string, unknown> = { ticket_code: body.ticket_code };
	const to = body.to_email?.trim();
	if (to) payload.to_email = to;
	return apiPost<ResendTicketEmailResult>(`${base()}/resend-email`, payload);
}

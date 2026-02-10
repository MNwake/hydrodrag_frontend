/**
 * Spectator tickets API. Matches backend /tickets (SpectatorTicketBase).
 */

import { apiGet, apiPost, type ApiResponse } from '$lib/api/client';

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
	event: string;
	racer?: string | SpectatorTicketRacerRef | null;
	payment?: string | null;
	purchaser_name: string;
	purchaser_phone: string;
	ticket_code: string;
	ticket_type: 'single_day' | 'weekend';
	is_used: boolean;
	used_at?: string | null;
	created_at: string;
	[key: string]: unknown;
}

/** GET /admin/tickets — list spectator tickets. */
export async function fetchTickets(
	eventId: string | null = null,
	used: boolean | null = null
): Promise<ApiResponse<SpectatorTicketBase[]>> {
	const params = new URLSearchParams();
	if (eventId != null && eventId !== '') params.set('event_id', eventId);
	if (used !== null) params.set('used', String(used));
	const q = params.toString() ? `?${params.toString()}` : '';
	return apiGet<SpectatorTicketBase[]>(`${base()}${q}`);
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

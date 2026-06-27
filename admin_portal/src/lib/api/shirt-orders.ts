import { apiDelete, apiGet, apiPatch, apiPost, getApiBase, getAdminApiKey, type ApiResponse } from '$lib/api/client';

const base = () => '/admin/shirt-orders';

export type ShirtSize = 'S' | 'M' | 'L' | 'XL' | '2XL';

export interface ShirtOrderRead {
	id: string;
	event_id?: string | null;
	event_name?: string | null;
	purchaser_name: string;
	racer_id?: string | null;
	shirt_size: ShirtSize;
	quantity: number;
	unit_price: number;
	notes?: string | null;
	created_by?: string | null;
	created_at?: string | null;
	paypal_order_id?: string | null;
}

export interface ShirtPayPalCheckoutCreate {
	event_id?: string | null;
	purchaser_name: string;
	shirt_size: ShirtSize;
	quantity?: number;
	unit_price: number;
	notes?: string | null;
	racer_id?: string | null;
}

export interface ShirtPayPalCheckoutResponse {
	paypal_order_id: string;
	approval_url: string;
	amount: number;
}

export interface ShirtPayPalCaptureRequest {
	paypal_order_id: string;
}

export interface ShirtPayPalCaptureResponse {
	status: string;
	paypal_order_id: string;
	shirt_order_id?: string | null;
}

export interface ShirtPayPalPending {
	paypal_order_id: string;
	purchaser_name?: string | null;
	shirt_size?: ShirtSize | null;
	quantity?: number | null;
	unit_price?: number | null;
	amount: number;
	created_at?: string | null;
}

export interface ShirtOrderCreate {
	event_id?: string | null;
	purchaser_name: string;
	racer_id?: string | null;
	shirt_size: ShirtSize;
	quantity?: number;
	unit_price?: number;
	notes?: string | null;
	created_by?: string | null;
}

export interface ShirtSummary {
	total_orders: number;
	total_quantity: number;
	total_revenue: number;
	by_size: Record<string, number>;
}

export async function fetchShirtOrders(
	eventId: string | null = null
): Promise<ApiResponse<ShirtOrderRead[]>> {
	const q = eventId ? `?event_id=${encodeURIComponent(eventId)}` : '';
	return apiGet<ShirtOrderRead[]>(`${base()}${q}`);
}

export async function fetchShirtSummary(
	eventId: string | null = null
): Promise<ApiResponse<ShirtSummary>> {
	const q = eventId ? `?event_id=${encodeURIComponent(eventId)}` : '';
	return apiGet<ShirtSummary>(`${base()}/summary${q}`);
}

export async function createShirtOrder(
	body: ShirtOrderCreate
): Promise<ApiResponse<ShirtOrderRead>> {
	return apiPost<ShirtOrderRead>(`${base()}`, body as unknown as Record<string, unknown>);
}

export async function deleteShirtOrder(id: string): Promise<ApiResponse<{ ok: boolean }>> {
	return apiDelete(`${base()}/${id}`);
}

export async function createShirtPayPalCheckout(
	body: ShirtPayPalCheckoutCreate
): Promise<ApiResponse<ShirtPayPalCheckoutResponse>> {
	return apiPost<ShirtPayPalCheckoutResponse>(
		`${base()}/paypal/checkout/create`,
		body as unknown as Record<string, unknown>
	);
}

export async function captureShirtPayPalCheckout(
	body: ShirtPayPalCaptureRequest
): Promise<ApiResponse<ShirtPayPalCaptureResponse>> {
	return apiPost<ShirtPayPalCaptureResponse>(
		`${base()}/paypal/checkout/capture`,
		body as unknown as Record<string, unknown>
	);
}

export async function fetchPendingShirtCheckouts(
	eventId: string | null = null
): Promise<ApiResponse<ShirtPayPalPending[]>> {
	const q = eventId ? `?event_id=${encodeURIComponent(eventId)}` : '';
	return apiGet<ShirtPayPalPending[]>(`${base()}/paypal/pending${q}`);
}

export function shirtOrdersExportUrl(eventId: string | null): string {
	const api = getApiBase();
	const key = getAdminApiKey();
	const q = eventId ? `?event_id=${encodeURIComponent(eventId)}` : '';
	return `${api}${base()}/export.csv${q}${key ? '' : ''}`;
}

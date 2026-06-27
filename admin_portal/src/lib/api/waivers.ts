import { apiFetch, apiGetBlob } from './client';

export interface WaiverListItem {
	id: string;
	event_id: string;
	event_name: string;
	racer_id: string;
	racer_name?: string | null;
	racer_email?: string | null;
	signed_at_utc: string;
	waiver_version: number;
	typed_legal_name: string;
}

export interface WaiverDetail extends WaiverListItem {
	event_start_date: string;
	event_end_date?: string | null;
	venue_name?: string | null;
	venue_address?: string | null;
	waiver_text: string;
	waiver_sha256: string;
	government_id_type: string;
	government_id_front_sha256: string;
	government_id_back_sha256?: string | null;
	selfie_sha256: string;
	signature_sha256: string;
	confirmed_identity: boolean;
	confirmed_read: boolean;
	device_timestamp?: string | null;
	timezone_name?: string | null;
	timezone_offset_minutes?: number | null;
	ip_address?: string | null;
	user_agent?: string | null;
	platform?: string | null;
	operating_system?: string | null;
	app_version?: string | null;
	build_number?: string | null;
	device_model?: string | null;
	locale?: string | null;
	gps_available: boolean;
	gps_latitude?: number | null;
	gps_longitude?: number | null;
	authenticated_email?: string | null;
	authenticated_phone?: string | null;
	has_government_id_back: boolean;
}

export async function fetchWaivers(params?: {
	event_id?: string;
	racer_id?: string;
	limit?: number;
	offset?: number;
}) {
	const q = new URLSearchParams();
	if (params?.event_id) q.set('event_id', params.event_id);
	if (params?.racer_id) q.set('racer_id', params.racer_id);
	if (params?.limit != null) q.set('limit', String(params.limit));
	if (params?.offset != null) q.set('offset', String(params.offset));
	const path = `/admin/waivers${q.toString() ? `?${q}` : ''}`;
	return apiFetch<WaiverListItem[]>(path);
}

export async function fetchWaiver(id: string) {
	return apiFetch<WaiverDetail>(`/admin/waivers/${id}`);
}

export function waiverImageUrl(waiverId: string, kind: 'government-id' | 'selfie' | 'signature', side?: string) {
	const base = import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') ?? '';
	const q = kind === 'government-id' && side ? `?side=${side}` : '';
	return `${base}/admin/waivers/${waiverId}/${kind}${q}`;
}

export async function downloadWaiverPdf(waiverId: string, filename?: string) {
	const res = await apiGetBlob(`/admin/waivers/${waiverId}/pdf`);
	if (!res.ok || !res.data) return res;
	const url = URL.createObjectURL(res.data);
	const a = document.createElement('a');
	a.href = url;
	a.download = filename ?? `waiver_${waiverId}.pdf`;
	a.click();
	URL.revokeObjectURL(url);
	return res;
}

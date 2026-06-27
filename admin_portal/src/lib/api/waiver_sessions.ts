import { apiFetch, apiGetBlob } from './client';

export interface WaiverSessionListItem {
	id: string;
	event_id: string;
	event_name: string;
	racer_id: string;
	status: string;
	expires_at: string;
	created_at: string;
	government_id_type?: string | null;
	government_id_front_uploaded: boolean;
	government_id_back_uploaded: boolean;
	selfie_uploaded: boolean;
}

export interface WaiverSessionDetail extends WaiverSessionListItem {
	updated_at: string;
	has_government_id_front: boolean;
	has_government_id_back: boolean;
	has_selfie: boolean;
}

export async function fetchWaiverSessions(params?: {
	racer_id?: string;
	event_id?: string;
	status?: string;
	limit?: number;
	offset?: number;
}) {
	const q = new URLSearchParams();
	if (params?.racer_id) q.set('racer_id', params.racer_id);
	if (params?.event_id) q.set('event_id', params.event_id);
	if (params?.status) q.set('status', params.status);
	if (params?.limit != null) q.set('limit', String(params.limit));
	if (params?.offset != null) q.set('offset', String(params.offset));
	const path = `/admin/waiver-sessions${q.toString() ? `?${q}` : ''}`;
	return apiFetch<WaiverSessionListItem[]>(path);
}

export async function fetchWaiverSession(id: string) {
	return apiFetch<WaiverSessionDetail>(`/admin/waiver-sessions/${id}`);
}

export function waiverSessionImageUrl(
	sessionId: string,
	kind: 'government-id' | 'selfie',
	side?: string
) {
	const base = import.meta.env.VITE_API_BASE_URL?.replace(/\/$/, '') ?? '';
	const q = kind === 'government-id' && side ? `?side=${side}` : '';
	return `${base}/admin/waiver-sessions/${sessionId}/${kind}${q}`;
}

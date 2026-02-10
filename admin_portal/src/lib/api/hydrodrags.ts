/**
 * HydroDrags company config API. Matches backend HydroDragsConfigUpdate, config response, and sponsor/media CRUD.
 */

import { apiGet, apiPut, apiPost, apiPatch, apiDelete, getAdminApiKey, type ApiResponse } from '$lib/api/client';

const base = () => '/admin/hydrodrags';

export interface Sponsor {
	name: string;
	logo_url?: string | null;
	website_url?: string | null;
	is_active: boolean;
}

export interface SponsorCreate {
	name: string;
	logo_url: string;
	website_url?: string | null;
	is_active?: boolean;
}

export interface SponsorUpdate {
	name?: string | null;
	logo_url?: string | null;
	website_url?: string | null;
	is_active?: boolean | null;
}

export interface SocialLink {
	platform: string;
	url: string;
}

export interface NewsItem {
	title: string;
	description?: string | null;
	media_url?: string | null;
	is_active: boolean;
}

export interface NewsItemCreate {
	title: string;
	description?: string | null;
	media_url?: string | null;
	is_active?: boolean;
}

export interface NewsItemUpdate {
	title?: string | null;
	description?: string | null;
	media_url?: string | null;
	is_active?: boolean | null;
}

export interface SpanishContent {
	about?: string | null;
	tagline?: string | null;
}

export interface AssetUpdateResponse {
	field: string;
	url: string | null;
}

/** Matches backend HydroDragsConfigBase (flat structure). */
export interface HydroDragsConfigResponse {
	headline: string;
	about?: string | null;
	tagline?: string | null;
	es?: SpanishContent | null;
	logo_url?: string | null;
	banner_url?: string | null;

	email?: string | null;
	phone?: string | null;
	support_email?: string | null;
	website_url?: string | null;

	ihra_membership_price: number;
	spectator_single_day_price: number;
	spectator_weekend_price: number;

	sponsors: Sponsor[];
	media_partners: Sponsor[];
	news: NewsItem[];
	social_links: SocialLink[];

	is_active: boolean;
}

/** Main config update: no sponsors or media_partners (use CRUD). Matches backend HydroDragsConfigUpdate. */
export interface HydroDragsConfigUpdate {
	headline?: string | null;
	about?: string | null;
	tagline?: string | null;
	es?: SpanishContent | null;

	email?: string | null;
	phone?: string | null;
	support_email?: string | null;
	website_url?: string | null;

	ihra_membership_price?: number | null;
	spectator_single_day_price?: number | null;
	spectator_weekend_price?: number | null;

	is_active?: boolean | null;
}

/** GET config (GET /admin/hydrodrags/config). Returns full config with es, sponsors, media_partners. */
export async function fetchHydroDragsConfig(): Promise<ApiResponse<HydroDragsConfigResponse>> {
	return apiGet<HydroDragsConfigResponse>(`${base()}/config`);
}

/** PUT update config (admin). Does not include sponsors or media_partners. */
export async function updateHydroDragsConfig(
	payload: HydroDragsConfigUpdate
): Promise<ApiResponse<HydroDragsConfigResponse>> {
	return apiPut<HydroDragsConfigResponse>(base(), payload as unknown as Record<string, unknown>);
}

// ---------- Sponsors CRUD ----------

export async function addSponsor(payload: SponsorCreate): Promise<ApiResponse<Sponsor>> {
	return apiPost<Sponsor>(`${base()}/sponsors`, payload as unknown as Record<string, unknown>);
}

export async function updateSponsor(
	index: number,
	payload: SponsorUpdate
): Promise<ApiResponse<Sponsor>> {
	return apiPatch<Sponsor>(
		`${base()}/sponsors/${index}`,
		payload as unknown as Record<string, unknown>
	);
}

export async function deleteSponsor(index: number): Promise<ApiResponse<void>> {
	return apiDelete(`${base()}/sponsors/${index}`);
}

// ---------- Media partners CRUD ----------

export async function addMediaPartner(payload: SponsorCreate): Promise<ApiResponse<Sponsor>> {
	return apiPost<Sponsor>(`${base()}/media-partners`, payload as unknown as Record<string, unknown>);
}

export async function updateMediaPartner(
	index: number,
	payload: SponsorUpdate
): Promise<ApiResponse<Sponsor>> {
	return apiPatch<Sponsor>(
		`${base()}/media-partners/${index}`,
		payload as unknown as Record<string, unknown>
	);
}

export async function deleteMediaPartner(index: number): Promise<ApiResponse<void>> {
	return apiDelete(`${base()}/media-partners/${index}`);
}

// ---------- Hero news CRUD ----------

export async function addHeroNews(payload: NewsItemCreate): Promise<ApiResponse<NewsItem>> {
	return apiPost<NewsItem>(`${base()}/hero-news`, payload as unknown as Record<string, unknown>);
}

export async function updateHeroNews(
	index: number,
	payload: NewsItemUpdate
): Promise<ApiResponse<NewsItem>> {
	return apiPatch<NewsItem>(
		`${base()}/hero-news/${index}`,
		payload as unknown as Record<string, unknown>
	);
}

export async function deleteHeroNews(index: number): Promise<ApiResponse<void>> {
	return apiDelete(`${base()}/hero-news/${index}`);
}

// ---------- Logo & banner (About) ----------

async function uploadAsset(
	endpoint: string,
	file: File
): Promise<ApiResponse<AssetUpdateResponse>> {
	const apiBase = getApiBase();
	const url = `${apiBase}${base()}${endpoint}`;
	const form = new FormData();
	form.append('file', file);

	const headers: Record<string, string> = {};
	const adminKey = getAdminApiKey();
	if (adminKey) headers['X-Admin-Key'] = adminKey;

	const res = await fetch(url, { method: 'POST', headers, body: form });
	let data: AssetUpdateResponse | null = null;
	let error: string | null = null;
	const text = await res.text();
	if (text) {
		try {
			data = JSON.parse(text) as AssetUpdateResponse;
		} catch {
			error = text || `HTTP ${res.status}`;
		}
	}
	const errDetail =
		!res.ok && data && typeof (data as unknown as { detail?: string }).detail === 'string'
			? (data as unknown as { detail: string }).detail
			: null;
	return {
		ok: res.ok,
		status: res.status,
		data,
		error: error ?? errDetail ?? (res.ok ? null : `HTTP ${res.status}`)
	};
}

export async function uploadLogo(file: File): Promise<ApiResponse<AssetUpdateResponse>> {
	return uploadAsset('/logo', file);
}

export async function deleteLogo(): Promise<ApiResponse<AssetUpdateResponse>> {
	return apiDelete(`${base()}/logo`) as Promise<ApiResponse<AssetUpdateResponse>>;
}

export async function uploadBanner(file: File): Promise<ApiResponse<AssetUpdateResponse>> {
	return uploadAsset('/banner', file);
}

export async function deleteBanner(): Promise<ApiResponse<AssetUpdateResponse>> {
	return apiDelete(`${base()}/banner`) as Promise<ApiResponse<AssetUpdateResponse>>;
}

// ---------- Image uploads ----------

function getApiBase(): string {
	const b = import.meta.env.VITE_API_BASE_URL;
	if (!b || typeof b !== 'string') throw new Error('VITE_API_BASE_URL is not set');
	return b.replace(/\/$/, '');
}

export interface UploadLogoResponse {
	logo_url: string;
}

export async function uploadSponsorImage(file: File): Promise<ApiResponse<UploadLogoResponse>> {
	const apiBase = getApiBase();
	const url = `${apiBase}${base()}/upload/sponsor-image`;
	const form = new FormData();
	form.append('file', file);

	const headers: Record<string, string> = {};
	const adminKey = getAdminApiKey();
	if (adminKey) headers['X-Admin-Key'] = adminKey;

	const res = await fetch(url, { method: 'POST', headers, body: form });
	let data: UploadLogoResponse | null = null;
	let error: string | null = null;
	const text = await res.text();
	if (text) {
		try {
			data = JSON.parse(text) as UploadLogoResponse;
		} catch {
			error = text || `HTTP ${res.status}`;
		}
	}
	const errDetail =
		!res.ok && data && typeof (data as unknown as { detail?: string }).detail === 'string'
			? (data as unknown as { detail: string }).detail
			: null;
	return {
		ok: res.ok,
		status: res.status,
		data,
		error: error ?? errDetail ?? (res.ok ? null : `HTTP ${res.status}`)
	};
}

export async function uploadMediaPartnerImage(file: File): Promise<ApiResponse<UploadLogoResponse>> {
	const apiBase = getApiBase();
	const url = `${apiBase}${base()}/upload/media-partner-image`;
	const form = new FormData();
	form.append('file', file);

	const headers: Record<string, string> = {};
	const adminKey = getAdminApiKey();
	if (adminKey) headers['X-Admin-Key'] = adminKey;

	const res = await fetch(url, { method: 'POST', headers, body: form });
	let data: UploadLogoResponse | null = null;
	let error: string | null = null;
	const text = await res.text();
	if (text) {
		try {
			data = JSON.parse(text) as UploadLogoResponse;
		} catch {
			error = text || `HTTP ${res.status}`;
		}
	}
	const errDetail =
		!res.ok && data && typeof (data as unknown as { detail?: string }).detail === 'string'
			? (data as unknown as { detail: string }).detail
			: null;
	return {
		ok: res.ok,
		status: res.status,
		data,
		error: error ?? errDetail ?? (res.ok ? null : `HTTP ${res.status}`)
	};
}

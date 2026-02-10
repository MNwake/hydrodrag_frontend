/**
 * Event API and web-only types. Matches backend EventBase, EventCreate, EventUpdate.
 * No shared code with Flutter or other clients.
 */

import { apiGet, apiPost, apiPatch, apiDelete, getAdminApiKey, type ApiResponse } from '$lib/api/client';

const base = () => '/admin/events';

export type EventRegistrationStatus = 'open' | 'closed' | 'upcoming' | 'past';

export interface EventScheduleItem {
	id: string;
	day: string;
	start_time?: string | null;
	end_time?: string | null;
	description: string;
}

export interface EventInfo {
	parking?: string | null;
	tickets?: string | null;
	food_and_drink?: string | null;
	seating?: string | null;
	/** Key-value dict: Name (key) → Description (value). */
	additional_info?: Record<string, string>;
}

export interface EventRule {
	category: string;
	description: string;
}

export interface EventClass {
	key: string;
	name: string;
	price: number;
	description?: string | null;
	is_active: boolean;
}

export interface EventLocation {
	name: string;
	address?: string | null;
	city?: string | null;
	state?: string | null;
	zip_code?: string | null;
	country?: string | null;
	latitude?: number | null;
	longitude?: number | null;
	full_address?: string | null;
}

/** Event format: double elimination bracket or top speed. */
export type EventFormat = 'double_elimination' | 'top_speed';

export interface EventBase {
	id: string;
	name: string;
	description?: string | null;
	image_url?: string | null;
	image_updated_at?: string | null;
	start_date: string;
	end_date?: string | null;
	registration_open_date?: string | null;
	registration_close_date?: string | null;
	location?: EventLocation | null;
	schedule: EventScheduleItem[];
	/** Server-computed schedule sorted by day, then start_time. Use this for display. */
	ordered_schedule?: EventScheduleItem[];
	event_info?: EventInfo | null;
	/** double_elimination = bracket; top_speed = no bracket (for now). */
	format?: EventFormat | null;
	classes: EventClass[];
	rules: EventRule[];
	registration_status: EventRegistrationStatus;
	results_url?: string | null;
	results?: Record<string, unknown>;
	is_published: boolean;
	created_at?: string;
	updated_at?: string;
	created_by?: string | null;
}

export interface EventCreate {
	name: string;
	description?: string | null;
	start_date: string;
	end_date?: string | null;
	registration_open_date?: string | null;
	registration_close_date?: string | null;
	location: EventLocation;
	schedule: EventScheduleItem[];
	event_info: EventInfo;
	format?: EventFormat | null;
	registration_status?: EventRegistrationStatus;
	is_published?: boolean;
}

export interface EventUpdate {
	name?: string | null;
	description?: string | null;
	start_date?: string | null;
	end_date?: string | null;
	registration_open_date?: string | null;
	registration_close_date?: string | null;
	location?: EventLocation | null;
	schedule?: EventScheduleItem[] | null;
	event_info?: EventInfo | null;
	format?: EventFormat | null;
	classes?: EventClass[] | null;
	rules?: EventRule[] | null;
	registration_status?: EventRegistrationStatus | null;
	results_url?: string | null;
	results?: Record<string, unknown> | null;
	is_published?: boolean | null;
}

export interface EventListResponse {
	events: EventBase[];
	total: number;
	page: number;
	page_size: number;
}

export interface EventResponse {
	event: EventBase;
}

/** Hydrated racer on EventRegistrationBase (RacerBase; optional, not stored). */
export interface RacerHydrated {
	id: string;
	email: string;
	first_name?: string | null;
	last_name?: string | null;
	/** Backend computed: "first_name last_name". */
	full_name?: string | null;
	date_of_birth?: string | null;
	gender?: string | null;
	nationality?: string | null;
	phone?: string | null;
	emergency_contact_name?: string | null;
	emergency_contact_phone?: string | null;
	street?: string | null;
	city?: string | null;
	state_province?: string | null;
	country?: string | null;
	zip_postal_code?: string | null;
	bio?: string | null;
	sponsors?: string[] | null;
	organization?: string | null;
	membership_number?: string | null;
	class_category?: string | null;
	profile_image_path?: string | null;
	banner_image_path?: string | null;
	waiver_path?: string | null;
	waiver_signed_at?: string | null;
	[key: string]: unknown;
}

/** Optional hydrated PWC on registration (if API includes it). */
export interface PwcHydrated {
	identifier?: string | null;
	make?: string | null;
	model?: string | null;
	[key: string]: unknown;
}

/** Matches backend EventRegistrationBase. */
export interface EventRegistrationBase {
	id: string;
	event: string;
	racer: string;
	pwc_identifier: string;
	class_key: string;
	class_name: string;
	price: number;
	losses: number;
	is_paid: boolean;
	created_at: string;
	/** Hydrated racer (backend sends `racer_model`). */
	racer_model?: RacerHydrated | null;
	/** Computed: losses >= 2. */
	is_eliminated?: boolean;
	has_valid_waiver?: boolean;
	is_of_age?: boolean;
	has_ihra_membership?: boolean;
	/** Top speed (top_speed events). */
	top_speed?: number | null;
	speed_updated_at?: string | null;
	/** Optional fallbacks if API ever sends them. */
	pwc?: PwcHydrated | null;
}

const MAX_PAGE_SIZE = 500;

export async function fetchEvents(
	page = 1,
	pageSize = 100
): Promise<ApiResponse<EventListResponse>> {
	const cappedPageSize = Math.min(pageSize, MAX_PAGE_SIZE);
	const q = `?page=${page}&page_size=${cappedPageSize}`;
	return apiGet<EventListResponse>(`${base()}${q}`);
}

export async function fetchEvent(id: string): Promise<ApiResponse<EventResponse>> {
	return apiGet<EventResponse>(`${base()}/${id}`);
}

export async function createEvent(payload: EventCreate): Promise<ApiResponse<EventBase>> {
	return apiPost<EventBase>(`${base()}`, payload as unknown as Record<string, unknown>);
}

export async function updateEvent(id: string, payload: EventUpdate): Promise<ApiResponse<EventBase>> {
	return apiPatch<EventBase>(`${base()}/${id}`, payload as unknown as Record<string, unknown>);
}

export async function deleteEvent(id: string): Promise<ApiResponse<void>> {
	return apiDelete(`${base()}/${id}`);
}

function getApiBase(): string {
	const b = import.meta.env.VITE_API_BASE_URL;
	if (!b || typeof b !== 'string') throw new Error('VITE_API_BASE_URL is not set');
	return b.replace(/\/$/, '');
}

/** Full URL for event image (backend serves under /assets). */
export function eventImageFullUrl(imageUrl: string | null | undefined): string {
	if (!imageUrl || !imageUrl.trim()) return '';
	const path = imageUrl.startsWith('/') ? imageUrl : `/${imageUrl}`;
	if (path.startsWith('http')) return path;
	return `${getApiBase()}${path}`;
}

/** POST /admin/events/{event_id}/image with multipart form-data. */
export async function uploadEventImage(
	eventId: string,
	file: File
): Promise<ApiResponse<EventBase>> {
	const apiBase = getApiBase();
	const url = `${apiBase}/admin/events/${eventId}/image`;
	const form = new FormData();
	form.append('file', file);

	const headers: Record<string, string> = {};
	const adminKey = getAdminApiKey();
	if (adminKey) headers['X-Admin-Key'] = adminKey;

	const res = await fetch(url, {
		method: 'POST',
		headers,
		body: form
	});

	let data: EventBase | null = null;
	let error: string | null = null;
	const text = await res.text();
	if (text) {
		try {
			data = JSON.parse(text) as EventBase;
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

/** Format ISO datetime for datetime-local input (YYYY-MM-DDTHH:mm) */
export function toDatetimeLocal(iso: string | null | undefined): string {
	if (!iso) return '';
	const d = new Date(iso);
	const y = d.getFullYear();
	const m = String(d.getMonth() + 1).padStart(2, '0');
	const day = String(d.getDate()).padStart(2, '0');
	const h = String(d.getHours()).padStart(2, '0');
	const min = String(d.getMinutes()).padStart(2, '0');
	return `${y}-${m}-${day}T${h}:${min}`;
}

/** Format datetime-local value back to ISO for API */
export function fromDatetimeLocal(v: string): string | null {
	if (!v || !v.trim()) return null;
	const d = new Date(v);
	return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/** Extract HH:mm from ISO datetime for &lt;input type="time"&gt; */
export function isoToTime(iso: string | null | undefined): string {
	if (!iso) return '';
	const d = new Date(iso);
	if (Number.isNaN(d.getTime())) return '';
	return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** Build ISO datetime from date (YYYY-MM-DD or datetime-local) + HH:mm */
export function timeToIso(dateOrDatetime: string, time: string): string | null {
	if (!dateOrDatetime) return null;
	const t = typeof time === 'string' ? time.trim() : '';
	if (!t || !/^\d{1,2}:\d{1,2}$/.test(t)) return null;
	const [h, m] = t.split(':').map(Number);
	if (h > 23 || m > 59) return null;
	const datePart = dateOrDatetime.slice(0, 10);
	const HH = String(h).padStart(2, '0');
	const MM = String(m).padStart(2, '0');
	return `${datePart}T${HH}:${MM}:00.000Z`;
}

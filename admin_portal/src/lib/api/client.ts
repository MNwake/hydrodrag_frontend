/**
 * Web-only API client for the HydroDrags admin portal.
 * Fetch wrapper; no auth (admin uses env-based login, not backend tokens).
 */

const DEBUG_API =
	import.meta.env.VITE_DEBUG_API === 'true' || import.meta.env.DEV;

function getApiBase(): string {
	const base = import.meta.env.VITE_API_BASE_URL;
	if (!base || typeof base !== 'string') {
		throw new Error('VITE_API_BASE_URL is not set');
	}
	return base.replace(/\/$/, '');
}

/** Admin API key sent as X-Admin-Key when VITE_ADMIN_API_KEY is set. */
export function getAdminApiKey(): string {
	const k = import.meta.env.VITE_ADMIN_API_KEY;
	return (k != null && typeof k === 'string' && k.trim()) ? k.trim() : '';
}

function debugLog(
	dir: '→' | '←',
	opts: { method: string; url: string; body?: string; status?: number; ok?: boolean; data?: unknown; error?: string | null }
) {
	if (!DEBUG_API) return;
	const pre = `[API] ${dir}`;
	if (dir === '→') {
		const parts = [`${opts.method} ${opts.url}`];
		if (opts.body) parts.push(`body: ${opts.body.length > 500 ? opts.body.slice(0, 500) + '…' : opts.body}`);
		console.log(pre, ...parts);
	} else {
		const parts = [`${opts.status} ${opts.ok ? 'OK' : 'ERR'} ${opts.url}`];
		if (opts.error) parts.push(`error: ${opts.error}`);
		if (opts.data != null && !opts.error) {
			const raw = JSON.stringify(opts.data);
			parts.push(`data: ${raw.length > 400 ? raw.slice(0, 400) + '…' : raw}`);
		}
		console.log(pre, ...parts);
	}
}

type RequestInitWithBody = Omit<RequestInit, 'body'> & {
	body?: Record<string, unknown> | string;
};

export interface ApiResponse<T = unknown> {
	ok: boolean;
	status: number;
	data: T | null;
	error: string | null;
}

export async function apiFetch<T = unknown>(
	path: string,
	init: RequestInitWithBody = {}
): Promise<ApiResponse<T>> {
	const base = getApiBase();
	const url = path.startsWith('http') ? path : `${base}${path.startsWith('/') ? '' : '/'}${path}`;
	const method = (init.method ?? 'GET').toUpperCase();

	const headers = new Headers(init.headers);
	const adminKey = getAdminApiKey();
	if (adminKey) headers.set('X-Admin-Key', adminKey);
	if (!headers.has('Content-Type') && init.body && typeof init.body === 'object' && !(init.body instanceof FormData)) {
		headers.set('Content-Type', 'application/json');
	}

	let body: BodyInit | undefined;
	let bodyStr: string | undefined;
	if (init.body !== undefined) {
		bodyStr = typeof init.body === 'string' ? init.body : JSON.stringify(init.body);
		body = bodyStr;
	}

	debugLog('→', { method, url, body: bodyStr });

	const timeoutMs = 25000;
	const controller = new AbortController();
	const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
	let res: Response;
	try {
		res = await fetch(url, { ...init, headers, body, signal: controller.signal });
	} catch (e) {
		clearTimeout(timeoutId);
		const msg = e instanceof Error ? e.message : String(e);
		debugLog('←', { method, url: url, status: 0, ok: false, error: msg });
		return {
			ok: false,
			status: 0,
			data: null,
			error: msg === 'The operation was aborted.' ? 'Request timed out.' : msg
		};
	}
	clearTimeout(timeoutId);

	let data: T | null = null;
	let error: string | null = null;
	const text = await res.text();
	if (text) {
		try {
			data = JSON.parse(text) as T;
		} catch {
			error = text || `HTTP ${res.status}`;
		}
	}

	const errDetail =
		!res.ok && data && typeof (data as unknown as { detail?: string }).detail === 'string'
			? (data as unknown as { detail: string }).detail
			: null;
	const finalError = error ?? errDetail ?? (res.ok ? null : `HTTP ${res.status}`);

	debugLog('←', {
		method,
		url: res.url,
		status: res.status,
		ok: res.ok,
		data: data ?? (text || null),
		error: finalError
	});

	return {
		ok: res.ok,
		status: res.status,
		data,
		error: finalError
	};
}

export async function apiGet<T = unknown>(path: string): Promise<ApiResponse<T>> {
	return apiFetch<T>(path, { method: 'GET' });
}

export async function apiPost<T = unknown>(path: string, body: Record<string, unknown>): Promise<ApiResponse<T>> {
	return apiFetch<T>(path, { method: 'POST', body });
}

export async function apiPatch<T = unknown>(path: string, body: Record<string, unknown>): Promise<ApiResponse<T>> {
	return apiFetch<T>(path, { method: 'PATCH', body });
}

export async function apiPut<T = unknown>(path: string, body: Record<string, unknown>): Promise<ApiResponse<T>> {
	return apiFetch<T>(path, { method: 'PUT', body });
}

export async function apiDelete(path: string): Promise<ApiResponse<void>> {
	return apiFetch<void>(path, { method: 'DELETE' });
}

/**
 * Env-based portal login (admin + optional staff). Session in localStorage; not backend auth.
 * Legacy key hydrodrags_admin_logged_in = '1' is treated as admin.
 */

const LEGACY_LOGGED_KEY = 'hydrodrags_admin_logged_in';
const SESSION_KEY = 'hydrodrags_portal_session';

export type PortalRole = 'admin' | 'staff';

export type PortalSession = {
	role: PortalRole;
	username: string;
};

function isBrowser(): boolean {
	return typeof window !== 'undefined';
}

function envAdminUsername(): string {
	return String(import.meta.env.VITE_ADMIN_USERNAME ?? '').trim() || 'admin';
}

function envAdminPassword(): string {
	return String(import.meta.env.VITE_ADMIN_PASSWORD ?? '').trim();
}

function envStaffUsername(): string {
	return String(import.meta.env.VITE_STAFF_USERNAME ?? '').trim();
}

function envStaffPassword(): string {
	return String(import.meta.env.VITE_STAFF_PASSWORD ?? '').trim();
}

/** Staff login is enabled only when both username and password are set in env (at Vite build / dev time). */
export function isStaffLoginConfigured(): boolean {
	return Boolean(envStaffUsername() && envStaffPassword());
}

/** When true, failed logins log diagnostics to the console (no password values). */
function portalLoginDebug(): boolean {
	return Boolean(
		import.meta.env.DEV ||
			String(import.meta.env.VITE_DEBUG_LOGIN ?? '')
				.toLowerCase()
				.trim() === 'true'
	);
}

/**
 * Attempt login. Returns role on success, null on failure.
 * Admin is checked first if credentials match both (admin wins).
 */
export function tryPortalLogin(username: string, password: string): PortalRole | null {
	const u = username.trim();
	const p = password.trim();
	if (u === envAdminUsername() && p === envAdminPassword()) {
		return 'admin';
	}
	if (isStaffLoginConfigured() && u === envStaffUsername() && p === envStaffPassword()) {
		return 'staff';
	}
	if (portalLoginDebug()) {
		const passAdmin = envAdminPassword();
		const passStaff = envStaffPassword();
		console.debug('[hydrodrags portal login] rejected', {
			viteMode: import.meta.env.MODE,
			attemptedUsername: u,
			usernameHadLeadingOrTrailingSpace: username !== username.trim(),
			passwordLengthAfterTrim: p.length,
			passwordLengthBeforeTrim: password.length,
			admin: {
				expectedUsername: envAdminUsername(),
				usernameMatch: u === envAdminUsername(),
				expectedPasswordLength: passAdmin.length,
				passwordMatch: p === passAdmin,
			},
			staff: {
				configured: isStaffLoginConfigured(),
				expectedUsername: envStaffUsername(),
				usernameMatch: u === envStaffUsername(),
				expectedPasswordLength: passStaff.length,
				passwordMatch: p === passStaff,
			},
		});
	}
	return null;
}

function readSession(): PortalSession | null {
	if (!isBrowser()) return null;
	const legacy = localStorage.getItem(LEGACY_LOGGED_KEY);
	if (legacy === '1') {
		return { role: 'admin', username: envAdminUsername() };
	}
	const raw = localStorage.getItem(SESSION_KEY);
	if (!raw) return null;
	try {
		const o = JSON.parse(raw) as Partial<PortalSession>;
		if (o.role === 'admin' || o.role === 'staff') {
			return { role: o.role, username: typeof o.username === 'string' ? o.username : uForRole(o.role) };
		}
	} catch {
		/* ignore */
	}
	return null;
}

function uForRole(role: PortalRole): string {
	return role === 'staff' ? envStaffUsername() || 'staff' : envAdminUsername();
}

export function getPortalRole(): PortalRole | null {
	return readSession()?.role ?? null;
}

export function getPortalUsername(): string {
	return readSession()?.username ?? envAdminUsername();
}

export function isPortalLoggedIn(): boolean {
	return getPortalRole() !== null;
}

export function isStaffPortal(): boolean {
	return getPortalRole() === 'staff';
}

export function isAdminPortal(): boolean {
	return getPortalRole() === 'admin';
}

export function setPortalSession(role: PortalRole, username: string): void {
	if (!isBrowser()) return;
	localStorage.removeItem(LEGACY_LOGGED_KEY);
	localStorage.setItem(SESSION_KEY, JSON.stringify({ role, username } satisfies PortalSession));
}

/** @deprecated use setPortalSession */
export function setAdminLoggedIn(): void {
	setPortalSession('admin', envAdminUsername());
}

export function clearPortalSession(): void {
	if (!isBrowser()) return;
	localStorage.removeItem(SESSION_KEY);
	localStorage.removeItem(LEGACY_LOGGED_KEY);
}

/** @deprecated use clearPortalSession */
export function clearAdminLoggedIn(): void {
	clearPortalSession();
}

/** @deprecated use isPortalLoggedIn */
export function isAdminLoggedIn(): boolean {
	return isPortalLoggedIn();
}

/** @deprecated use getPortalUsername */
export function getAdminUsername(): string {
	return getPortalUsername();
}

/** @deprecated use tryPortalLogin */
export function checkCredentials(username: string, password: string): boolean {
	return tryPortalLogin(username, password) !== null;
}

/** Staff may only use these URL paths (pathname must match). */
export function staffAllowedPath(pathname: string): boolean {
	if (pathname === '/events' || pathname === '/racers') return true;
	if (pathname.startsWith('/racers/')) return true;
	if (pathname.startsWith('/events/')) {
		if (pathname === '/events/new' || pathname.startsWith('/events/new/')) return false;
		return true;
	}
	return false;
}

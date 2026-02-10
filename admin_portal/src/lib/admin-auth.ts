/**
 * Env-based admin login. Single account from VITE_ADMIN_USERNAME / VITE_ADMIN_PASSWORD.
 * Session stored in localStorage; no backend auth.
 */

const STORAGE_KEY = 'hydrodrags_admin_logged_in';

function isBrowser(): boolean {
	return typeof window !== 'undefined';
}

function envUsername(): string {
	return (import.meta.env.VITE_ADMIN_USERNAME as string) || 'admin';
}

function envPassword(): string {
	return (import.meta.env.VITE_ADMIN_PASSWORD as string) || '';
}

export function getAdminUsername(): string {
	return envUsername();
}

export function isAdminLoggedIn(): boolean {
	if (!isBrowser()) return false;
	return localStorage.getItem(STORAGE_KEY) === '1';
}

export function setAdminLoggedIn(): void {
	if (!isBrowser()) return;
	localStorage.setItem(STORAGE_KEY, '1');
}

export function clearAdminLoggedIn(): void {
	if (!isBrowser()) return;
	localStorage.removeItem(STORAGE_KEY);
}

export function checkCredentials(username: string, password: string): boolean {
	return username === envUsername() && password === envPassword();
}

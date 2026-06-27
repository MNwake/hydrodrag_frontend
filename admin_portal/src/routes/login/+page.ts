import { redirect } from '@sveltejs/kit';
import { isPortalLoggedIn } from '$lib/admin-auth';

export const ssr = false;

export function load() {
	if (isPortalLoggedIn()) {
		throw redirect(302, '/dashboard');
	}
	return {};
}

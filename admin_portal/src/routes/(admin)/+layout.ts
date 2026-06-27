import { redirect } from '@sveltejs/kit';
import { isPortalLoggedIn, isStaffPortal, staffAllowedPath } from '$lib/admin-auth';

export const ssr = false;

export function load({ url }) {
	if (!isPortalLoggedIn()) {
		throw redirect(302, '/login');
	}
	if (isStaffPortal() && !staffAllowedPath(url.pathname)) {
		throw redirect(302, '/events');
	}
	return {};
}

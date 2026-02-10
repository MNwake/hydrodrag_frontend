import { redirect } from '@sveltejs/kit';
import { isAdminLoggedIn } from '$lib/admin-auth';

export const ssr = false;

export function load() {
	if (!isAdminLoggedIn()) {
		throw redirect(302, '/login');
	}
	return {};
}

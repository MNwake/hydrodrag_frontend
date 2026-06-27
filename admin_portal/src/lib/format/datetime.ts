const HAS_TZ_SUFFIX = /(?:Z|[+-]\d{2}:\d{2})$/i;
const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

/** PayPal checkout approval window — orders expire if not approved within ~3 hours. */
export const PAYPAL_PENDING_MAX_MS = 3 * 60 * 60 * 1000;

/** Parse API ISO timestamps; naive strings from the backend are treated as UTC. */
export function parseApiDateTime(iso: string | null | undefined): Date | null {
	if (iso == null) return null;
	const trimmed = iso.trim();
	if (!trimmed) return null;
	if (DATE_ONLY.test(trimmed)) {
		const d = new Date(`${trimmed}T00:00:00`);
		return Number.isNaN(d.getTime()) ? null : d;
	}
	const normalized = HAS_TZ_SUFFIX.test(trimmed) ? trimmed : `${trimmed}Z`;
	const d = new Date(normalized);
	return Number.isNaN(d.getTime()) ? null : d;
}

export function isRecentPayPalPending(iso: string | null | undefined): boolean {
	const d = parseApiDateTime(iso);
	if (!d) return false;
	return Date.now() - d.getTime() <= PAYPAL_PENDING_MAX_MS;
}

export function formatDateTimeLocal(iso: string | null | undefined): string {
	const d = parseApiDateTime(iso);
	if (!d) return '—';
	return d.toLocaleString('en-US', {
		month: 'short',
		day: 'numeric',
		year: 'numeric',
		hour: 'numeric',
		minute: '2-digit'
	});
}

export function formatDateLocal(iso: string | null | undefined): string {
	const d = parseApiDateTime(iso);
	if (!d) return '—';
	return d.toLocaleDateString('en-US', {
		month: 'short',
		day: 'numeric',
		year: 'numeric'
	});
}

/** Best timestamp for when PayPal payment actually completed. */
export function paymentCompletedAt(input: {
	captured_at?: string | null;
	registration_created_at?: string | null;
	checkout_created_at?: string | null;
}): string | null | undefined {
	return input.captured_at ?? input.registration_created_at ?? input.checkout_created_at;
}

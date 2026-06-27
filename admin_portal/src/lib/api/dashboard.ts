/**
 * Admin dashboard summary API — GET /admin/dashboard/summary
 */

import { apiGet, type ApiResponse } from '$lib/api/client';

export type DashboardScopePreset =
	| 'auto'
	| 'current_event'
	| 'upcoming_events'
	| 'last_30_days'
	| 'season'
	| 'all';

export interface DashboardEventRef {
	id: string;
	name: string;
	start_date?: string | null;
	end_date?: string | null;
	event_status?: string | null;
}

export interface DashboardScopeMeta {
	preset: string;
	label: string;
	event_id?: string | null;
	event_name?: string | null;
	date_from?: string | null;
	date_to?: string | null;
}

export interface ClassCountItem {
	class_key: string;
	class_name: string;
	count: number;
}

export interface PeriodCountItem {
	period: string;
	count: number;
}

export interface ClassFillItem {
	class_key: string;
	class_name: string;
	entries: number;
}

export interface EventRegistrationCountItem {
	event_id: string;
	event_name: string;
	count: number;
}

export interface CategoryCountItem {
	category: string;
	count: number;
}

export interface DashboardAttendeeCounts {
	unique_racers: number;
	racer_registration_entries: number;
	spectators: number;
	vendors: number;
	sponsors: number;
	vip: number;
	total_attendees: number;
}

export interface DashboardRegistrations {
	unique_racers: number;
	total_entries: number;
	classes_with_registrations: number;
	by_class: ClassCountItem[];
	over_time: PeriodCountItem[];
	class_fill: ClassFillItem[];
	per_event: EventRegistrationCountItem[];
	racer_vs_attendee: CategoryCountItem[];
}

export interface RevenueBySourceItem {
	source: 'event' | 'spectator' | 'membership' | 'day_pass' | 'weekend_pass';
	amount: number;
}

export interface DashboardRevenue {
	gross: number;
	net: number;
	refunds: number;
	/** Deprecated: always 0; uncaptured PayPal attempts are not pending revenue. */
	pending: number;
	discounts_given: number;
	event: number;
	spectator: number;
	membership: number;
	day_pass_revenue: number;
	weekend_pass_revenue: number;
	by_source: RevenueBySourceItem[];
	avg_revenue_per_racer?: number | null;
	pricing_config_warning?: string | null;
}

export interface DashboardSpectators {
	day_passes_issued: number;
	weekend_passes_issued: number;
	day_passes_paid: number;
	weekend_passes_paid: number;
}

export interface DashboardShirts {
	total_orders: number;
	total_quantity: number;
	by_size: Record<string, number>;
}

export interface PaymentStatusItem {
	status: string;
	count: number;
}

export interface DashboardPayments {
	captured_count: number;
	/** Deprecated: always 0; use Payments page for checkout detail. */
	pending_count: number;
	status_breakdown: PaymentStatusItem[];
}

export interface DashboardEventOverview {
	total_events: number;
	upcoming_events: number;
	current_event?: DashboardEventRef | null;
	next_event?: DashboardEventRef | null;
	days_until_next_event?: number | null;
}

export interface DashboardRecentRegistration {
	id: string;
	created_at?: string | null;
	racer_name: string;
	class_name: string;
	event_name: string;
	is_paid: boolean;
	payment_status: string;
	payment_status_label: string;
	amount_collected: number;
}

export interface DashboardRecentPayment {
	id: string;
	paypal_order_id: string;
	created_at?: string | null;
	captured_at?: string | null;
	total_amount: number;
	is_captured: boolean;
	event_name?: string | null;
	racer_name?: string | null;
	purchaser_name?: string | null;
}

export interface DashboardSummary {
	generated_at: string;
	scope: DashboardScopeMeta;
	event_overview: DashboardEventOverview;
	attendees: DashboardAttendeeCounts;
	registrations: DashboardRegistrations;
	revenue: DashboardRevenue;
	spectators: DashboardSpectators;
	shirts: DashboardShirts;
	payments: DashboardPayments;
	recent_registrations: DashboardRecentRegistration[];
	recent_payments: DashboardRecentPayment[];
}

export async function fetchDashboardSummary(
	eventId: string | null = null,
	scope: DashboardScopePreset = 'upcoming_events'
): Promise<ApiResponse<DashboardSummary>> {
	const params = new URLSearchParams();
	if (eventId) params.set('event_id', eventId);
	if (scope) params.set('scope', scope);
	const q = params.toString() ? `?${params.toString()}` : '';
	return apiGet<DashboardSummary>(`/admin/dashboard/summary${q}`);
}

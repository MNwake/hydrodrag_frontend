<script lang="ts">
	import { onMount, tick } from 'svelte';
	import {
		fetchDashboardSummary,
		type DashboardSummary,
		type DashboardScopePreset
	} from '$lib/api/dashboard';
	import { fetchEvents } from '$lib/api/events';
	import DataTable from '$lib/components/DataTable.svelte';
	import Chart from 'chart.js/auto';
	import { formatDateTimeLocal } from '$lib/format/datetime';

	let loading = true;
	let error: string | null = null;
	let summary: DashboardSummary | null = null;
	let events: { id: string; name: string }[] = [];
	let filterEventId = '';
	let filterScope: DashboardScopePreset = 'upcoming_events';

	let countdown = { days: 0, hours: 0, minutes: 0, seconds: 0 };
	let countdownOver = false;
	let intervalId: ReturnType<typeof setInterval> | null = null;

	let lineChartCanvas: HTMLCanvasElement;
	let barChartCanvas: HTMLCanvasElement;
	let revenueChartCanvas: HTMLCanvasElement;
	let paymentChartCanvas: HTMLCanvasElement;
	let rvChartCanvas: HTMLCanvasElement;
	let perEventChartCanvas: HTMLCanvasElement;
	let lineChartInstance: Chart | null = null;
	let barChartInstance: Chart | null = null;
	let revenueChartInstance: Chart | null = null;
	let paymentChartInstance: Chart | null = null;
	let rvChartInstance: Chart | null = null;
	let perEventChartInstance: Chart | null = null;

	const scopeOptions: { value: DashboardScopePreset; label: string }[] = [
		{ value: 'upcoming_events', label: 'Upcoming events' },
		{ value: 'all', label: 'All time (all events)' },
		{ value: 'current_event', label: 'Current event only' },
		{ value: 'last_30_days', label: 'Last 30 days' },
		{ value: 'season', label: 'This season' }
	];

	function formatCurrency(n: number): string {
		return n.toLocaleString('en-US', {
			style: 'currency',
			currency: 'USD',
			minimumFractionDigits: 0,
			maximumFractionDigits: 0
		});
	}

	function formatPeriod(period: string): string {
		const [y, m] = period.split('-');
		const monthNames = [
			'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
			'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
		];
		const mi = parseInt(m, 10) - 1;
		return mi >= 0 && mi < 12 ? `${monthNames[mi]} ${y}` : period;
	}

	const revenueSourceColors: Record<string, string> = {
		event: 'rgba(22, 163, 74, 0.85)',
		spectator: 'rgba(14, 165, 233, 0.85)',
		membership: 'rgba(124, 58, 237, 0.85)',
		day_pass: 'rgba(234, 88, 12, 0.85)',
		weekend_pass: 'rgba(236, 72, 153, 0.85)'
	};
	const chartPaletteFallback = [
		'rgba(22, 163, 74, 0.85)',
		'rgba(14, 165, 233, 0.85)',
		'rgba(124, 58, 237, 0.85)',
		'rgba(234, 88, 12, 0.85)',
		'rgba(236, 72, 153, 0.85)',
		'rgba(202, 138, 4, 0.85)',
		'rgba(20, 184, 166, 0.85)',
		'rgba(239, 68, 68, 0.85)'
	];

	function formatPaymentStatus(status: string): string {
		const labels: Record<string, string> = {
			captured: 'Captured',
			incomplete: 'Incomplete checkouts',
			abandoned: 'Abandoned'
		};
		return labels[status] ?? status;
	}

	function formatDateTime(iso: string | null | undefined): string {
		return formatDateTimeLocal(iso);
	}

	function destroyCharts() {
		lineChartInstance?.destroy();
		barChartInstance?.destroy();
		revenueChartInstance?.destroy();
		paymentChartInstance?.destroy();
		rvChartInstance?.destroy();
		perEventChartInstance?.destroy();
		lineChartInstance = null;
		barChartInstance = null;
		revenueChartInstance = null;
		paymentChartInstance = null;
		rvChartInstance = null;
		perEventChartInstance = null;
	}

	function updateCountdown() {
		const next = summary?.event_overview?.next_event;
		if (!next?.start_date) {
			countdownOver = true;
			return;
		}
		const end = new Date(next.start_date).getTime();
		const now = Date.now();
		let diff = Math.floor((end - now) / 1000);
		if (diff <= 0) {
			countdownOver = true;
			countdown = { days: 0, hours: 0, minutes: 0, seconds: 0 };
			return;
		}
		countdownOver = false;
		const days = Math.floor(diff / 86400);
		diff %= 86400;
		const hours = Math.floor(diff / 3600);
		diff %= 3600;
		const minutes = Math.floor(diff / 60);
		const seconds = diff % 60;
		countdown = { days, hours, minutes, seconds };
	}

	async function buildCharts() {
		destroyCharts();
		await tick();
		if (!summary) return;

		const reg = summary.registrations;
		if (lineChartCanvas && reg.over_time.length > 0) {
			lineChartInstance = new Chart(lineChartCanvas, {
				type: 'line',
				data: {
					labels: reg.over_time.map((d) => formatPeriod(d.period)),
					datasets: [
						{
							label: 'Registration entries',
							data: reg.over_time.map((d) => d.count),
							borderColor: 'rgb(14, 165, 233)',
							backgroundColor: 'rgba(14, 165, 233, 0.1)',
							fill: true,
							tension: 0.2
						}
					]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false,
					plugins: { legend: { display: false } },
					scales: {
						y: { beginAtZero: true, ticks: { stepSize: 1 } },
						x: { grid: { display: false } }
					}
				}
			});
		}

		if (barChartCanvas && reg.by_class.length > 0) {
			barChartInstance = new Chart(barChartCanvas, {
				type: 'bar',
				data: {
					labels: reg.by_class.map((d) => d.class_name),
					datasets: [
						{
							label: 'Entries',
							data: reg.by_class.map((d) => d.count),
							backgroundColor: 'rgba(14, 165, 233, 0.7)',
							borderColor: 'rgb(14, 165, 233)',
							borderWidth: 1
						}
					]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false,
					plugins: { legend: { display: false } },
					scales: {
						y: { beginAtZero: true, ticks: { stepSize: 1 } },
						x: { grid: { display: false } }
					}
				}
			});
		}

		const rev = summary.revenue.by_source.filter((x) => x.amount > 0);
		if (revenueChartCanvas && rev.length > 0) {
			revenueChartInstance = new Chart(revenueChartCanvas, {
				type: 'doughnut',
				data: {
					labels: rev.map((x) => {
						const labels: Record<string, string> = {
							event: 'Event registrations',
							spectator: 'Spectator (combined)',
							membership: 'IHRA membership',
							day_pass: 'Day pass revenue',
							weekend_pass: 'Weekend pass revenue'
						};
						return labels[x.source] ?? x.source;
					}),
					datasets: [
						{
							data: rev.map((x) => x.amount),
							backgroundColor: rev.map(
								(x, i) =>
									revenueSourceColors[x.source] ??
									chartPaletteFallback[i % chartPaletteFallback.length]
							)
						}
					]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false
				}
			});
		}

		const pay = summary.payments.status_breakdown.filter((x) => x.count > 0);
		if (paymentChartCanvas && pay.length > 0) {
			paymentChartInstance = new Chart(paymentChartCanvas, {
				type: 'bar',
				data: {
					labels: pay.map((x) => formatPaymentStatus(x.status)),
					datasets: [
						{
							label: 'Checkouts',
							data: pay.map((x) => x.count),
							backgroundColor: 'rgba(100, 116, 139, 0.7)'
						}
					]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false,
					plugins: { legend: { display: false } },
					scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } }
				}
			});
		}

		const rv = summary.registrations.racer_vs_attendee.filter((x) => x.count > 0);
		if (rvChartCanvas && rv.length > 0) {
			rvChartInstance = new Chart(rvChartCanvas, {
				type: 'bar',
				data: {
					labels: rv.map((x) => x.category),
					datasets: [
						{
							label: 'Count',
							data: rv.map((x) => x.count),
							backgroundColor: 'rgba(14, 165, 233, 0.7)'
						}
					]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false,
					plugins: { legend: { display: false } },
					scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } }
				}
			});
		}

		const pe = summary.registrations.per_event;
		if (perEventChartCanvas && pe.length > 0) {
			perEventChartInstance = new Chart(perEventChartCanvas, {
				type: 'bar',
				data: {
					labels: pe.map((x) => x.event_name),
					datasets: [
						{
							label: 'Registration entries',
							data: pe.map((x) => x.count),
							backgroundColor: 'rgba(22, 163, 74, 0.7)'
						}
					]
				},
				options: {
					responsive: true,
					maintainAspectRatio: false,
					plugins: { legend: { display: false } },
					scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } }
				}
			});
		}
	}

	async function load() {
		loading = true;
		error = null;
		destroyCharts();
		const eventId = filterEventId || null;
		const res = await fetchDashboardSummary(eventId, filterScope);
		loading = false;
		if (!res.ok || !res.data) {
			error = res.error ?? 'Failed to load dashboard';
			summary = null;
			return;
		}
		summary = res.data;
		updateCountdown();
		await buildCharts();
	}

	async function loadEvents() {
		const res = await fetchEvents(1, 200);
		if (res.ok && res.data?.events) {
			events = res.data.events.map((e) => ({ id: e.id, name: e.name }));
		}
	}

	function onFilterChange() {
		load();
	}

	$: recentRegRows =
		summary?.recent_registrations.map((r) => ({
			created_at: formatDateTime(r.created_at),
			racer_name: r.racer_name,
			class_name: r.class_name,
			event_name: r.event_name,
			status: r.payment_status_label ?? (r.is_paid ? 'Paid' : 'Pending'),
			amount_collected: r.amount_collected > 0 ? formatCurrency(r.amount_collected) : '—'
		})) ?? [];

	$: recentPayRows =
		summary?.recent_payments.map((p) => ({
			date: formatDateTime(p.captured_at ?? p.created_at),
			amount: formatCurrency(p.total_amount),
			status: p.is_captured ? 'Captured' : 'Pending',
			event_name: p.event_name ?? '—',
			party: p.racer_name ?? p.purchaser_name ?? '—',
			order: p.paypal_order_id
		})) ?? [];

	$: classFillRows =
		summary?.registrations.class_fill.map((c) => ({
			class_name: c.class_name,
			entries: c.entries
		})) ?? [];

	onMount(async () => {
		await loadEvents();
		await load();
		intervalId = setInterval(() => {
			if (countdownOver) return;
			updateCountdown();
		}, 1000);
		return () => {
			if (intervalId) clearInterval(intervalId);
			destroyCharts();
		};
	});
</script>

<div class="page-header dashboard-header">
	<div>
		<h1 class="page-title">Dashboard</h1>
		<p class="page-subtitle">Operations overview for events, registrations, and revenue</p>
	</div>
	<div class="dashboard-toolbar">
		<div class="filter-group">
			<label for="dash-event">Event</label>
			<select id="dash-event" bind:value={filterEventId} onchange={onFilterChange} disabled={loading}>
				<option value="">All events</option>
				{#each events as ev}
					<option value={ev.id}>{ev.name}</option>
				{/each}
			</select>
		</div>
		<div class="filter-group">
			<label for="dash-scope">Date range</label>
			<select id="dash-scope" bind:value={filterScope} onchange={onFilterChange} disabled={loading}>
				{#each scopeOptions as opt}
					<option value={opt.value}>{opt.label}</option>
				{/each}
			</select>
		</div>
		<button type="button" class="btn btn-secondary" onclick={load} disabled={loading}>
			{loading ? 'Loading…' : 'Refresh'}
		</button>
	</div>
</div>

{#if summary && !loading}
	<p class="scope-banner">
		<strong>Summarizing:</strong> {summary.scope.label}
		<span class="scope-meta"> · Last updated {formatDateTime(summary.generated_at)}</span>
	</p>
{/if}

{#if loading && !summary}
	<div class="loading-placeholder">Loading dashboard…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if summary}
	{#if summary.event_overview.next_event?.start_date && !countdownOver}
		<div class="countdown-card">
			<div class="countdown-title">Days until next event</div>
			<a href="/events/{summary.event_overview.next_event.id}" class="countdown-event-name">
				{summary.event_overview.next_event.name}
			</a>
			<div class="countdown-units" role="timer" aria-live="polite">
				<span class="countdown-unit"><span class="countdown-num">{countdown.days}</span> days</span>
				<span class="countdown-unit"><span class="countdown-num">{countdown.hours}</span> hours</span>
				<span class="countdown-unit"><span class="countdown-num">{countdown.minutes}</span> min</span>
				<span class="countdown-unit"><span class="countdown-num">{countdown.seconds}</span> sec</span>
			</div>
		</div>
	{/if}

	<section class="dash-section">
		<h2 class="dash-section-title">Attendees (separated)</h2>
		<p class="section-hint">
			Racers, spectators, vendors, sponsors, and VIP are counted separately.
			Total attendees: {summary.attendees.total_attendees} (explicit sum).
		</p>
		<div class="stats-grid">
			<div class="stat-card">
				<div class="value">{summary.attendees.unique_racers}</div>
				<div class="label">Unique racers</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.attendees.racer_registration_entries}</div>
				<div class="label">Racer registration entries</div>
			</div>
			<div class="stat-card stat-card--spectator-revenue">
				<div class="value">{summary.attendees.spectators}</div>
				<div class="label">Spectator passes</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.attendees.vendors}</div>
				<div class="label">Vendor passes</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.attendees.sponsors}</div>
				<div class="label">Sponsor passes</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.attendees.vip}</div>
				<div class="label">VIP passes</div>
			</div>
		</div>
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Registrations</h2>
		{#if summary.registrations.per_event.length > 1}
			<p class="section-hint">
				Totals below are across all events in scope ({summary.registrations.total_entries} entries,
				{summary.registrations.per_event.length} events). Per-event breakdown is in Charts.
			</p>
		{/if}
		<div class="stats-grid">
			<div class="stat-card">
				<div class="value">{summary.registrations.unique_racers}</div>
				<div class="label">Unique registered racers</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.registrations.total_entries}</div>
				<div class="label">Total registration entries</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.registrations.classes_with_registrations}</div>
				<div class="label">Classes with registrations</div>
			</div>
		</div>
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Revenue</h2>
		<p class="section-hint">
			Revenue from captured PayPal checkouts. Refunds shown when tracking is available.
			{#if summary.revenue.pricing_config_warning}
				<br /><strong>{summary.revenue.pricing_config_warning}</strong>
			{/if}
		</p>
		<div class="stats-grid">
			<div class="stat-card stat-card--event-revenue">
				<div class="value">{formatCurrency(summary.revenue.gross)}</div>
				<div class="label">Revenue</div>
			</div>
			<div class="stat-card">
				<div class="value">{formatCurrency(summary.revenue.refunds)}</div>
				<div class="label">Refunds</div>
			</div>
			<div class="stat-card">
				<div class="value">{formatCurrency(summary.revenue.discounts_given)}</div>
				<div class="label">Discounts given</div>
			</div>
			<div class="stat-card stat-card--event-revenue">
				<div class="value">{formatCurrency(summary.revenue.event)}</div>
				<div class="label">Event registration revenue</div>
			</div>
			<div class="stat-card stat-card--spectator-revenue">
				<div class="value">{formatCurrency(summary.revenue.spectator)}</div>
				<div class="label">Spectator pass revenue (total)</div>
			</div>
			<div class="stat-card stat-card--spectator-revenue">
				<div class="value">{formatCurrency(summary.revenue.day_pass_revenue)}</div>
				<div class="label">Day pass revenue</div>
			</div>
			<div class="stat-card stat-card--spectator-revenue">
				<div class="value">{formatCurrency(summary.revenue.weekend_pass_revenue)}</div>
				<div class="label">Weekend pass revenue</div>
			</div>
			<div class="stat-card stat-card--membership-revenue">
				<div class="value">{formatCurrency(summary.revenue.membership)}</div>
				<div class="label">Membership fee revenue</div>
			</div>
			<div class="stat-card">
				<div class="value">
					{summary.revenue.avg_revenue_per_racer != null
						? formatCurrency(summary.revenue.avg_revenue_per_racer)
						: '—'}
				</div>
				<div class="label">Avg revenue per racer</div>
			</div>
		</div>
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Spectators / passes</h2>
		<div class="stats-grid">
			<div class="stat-card stat-card--spectator-revenue">
				<div class="value">{summary.spectators.day_passes_issued}</div>
				<div class="label">Day passes issued</div>
				<div class="stat-sublabel">{summary.spectators.day_passes_paid} paid</div>
			</div>
			<div class="stat-card stat-card--spectator-revenue">
				<div class="value">{summary.spectators.weekend_passes_issued}</div>
				<div class="label">Weekend passes issued</div>
				<div class="stat-sublabel">{summary.spectators.weekend_passes_paid} paid</div>
			</div>
		</div>
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Shirt sales (internal tracker)</h2>
		<div class="stats-grid stats-grid--compact">
			<div class="stat-card">
				<div class="value">{summary.shirts.total_orders}</div>
				<div class="label">Shirt orders</div>
			</div>
			<div class="stat-card">
				<div class="value">{summary.shirts.total_quantity}</div>
				<div class="label">Shirts sold (qty)</div>
			</div>
			<a href="/shirts" class="stat-card stat-card--link">
				<div class="value">→</div>
				<div class="label">Manage shirt sales</div>
			</a>
		</div>
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Payments</h2>
		<div class="stats-grid stats-grid--compact">
			<div class="stat-card">
				<div class="value">{summary.payments.captured_count}</div>
				<div class="label">Captured checkouts</div>
			</div>
			<a href="/payments" class="stat-card stat-card--link">
				<div class="value">→</div>
				<div class="label">View all payments</div>
			</a>
		</div>
	</section>

	<section class="dash-section charts-section">
		<h2 class="dash-section-title">Charts</h2>
		<div class="charts-grid">
			<div class="chart-card">
				<h3 class="chart-card-title">Registrations over time</h3>
				<div class="chart-container">
					{#if summary.registrations.over_time.length > 0}
						<canvas bind:this={lineChartCanvas} aria-label="Registrations over time"></canvas>
					{:else}
						<p class="chart-empty">No registrations in this scope.</p>
					{/if}
				</div>
			</div>
			<div class="chart-card">
				<h3 class="chart-card-title">Registrations by class</h3>
				<div class="chart-container">
					{#if summary.registrations.by_class.length > 0}
						<canvas bind:this={barChartCanvas} aria-label="Registrations by class"></canvas>
					{:else}
						<p class="chart-empty">No class registrations in this scope.</p>
					{/if}
				</div>
			</div>
			<div class="chart-card">
				<h3 class="chart-card-title">Revenue by source</h3>
				<div class="chart-container">
					{#if summary.revenue.by_source.some((x) => x.amount > 0)}
						<canvas bind:this={revenueChartCanvas} aria-label="Revenue by source"></canvas>
					{:else}
						<p class="chart-empty">No captured revenue in this scope.</p>
					{/if}
				</div>
			</div>
			<div class="chart-card">
				<h3 class="chart-card-title">Racer vs attendee passes</h3>
				<div class="chart-container">
					{#if summary.registrations.racer_vs_attendee.some((x) => x.count > 0)}
						<canvas bind:this={rvChartCanvas} aria-label="Racer vs attendee"></canvas>
					{:else}
						<p class="chart-empty">No attendee data in this scope.</p>
					{/if}
				</div>
			</div>
			<div class="chart-card">
				<h3 class="chart-card-title">Registrations per event</h3>
				<div class="chart-container">
					{#if summary.registrations.per_event.length > 0}
						<canvas bind:this={perEventChartCanvas} aria-label="Registrations per event"></canvas>
					{:else}
						<p class="chart-empty">No per-event registrations in this scope.</p>
					{/if}
				</div>
			</div>
			<div class="chart-card">
				<h3 class="chart-card-title">Payment status</h3>
				<div class="chart-container">
					{#if summary.payments.status_breakdown.some((x) => x.count > 0)}
						<canvas bind:this={paymentChartCanvas} aria-label="Payment status"></canvas>
					{:else}
						<p class="chart-empty">No checkout activity in this scope.</p>
					{/if}
				</div>
			</div>
		</div>
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Class registration counts</h2>
		{#if classFillRows.length > 0}
			<DataTable
				columns={[
					{ key: 'class_name', label: 'Class' },
					{ key: 'entries', label: 'Entries', class: 'num' }
				]}
				rows={classFillRows}
				emptyMessage="No classes"
			/>
		{:else}
			<p class="chart-empty">No class data in this scope.</p>
		{/if}
	</section>

	<section class="dash-section">
		<h2 class="dash-section-title">Recent activity</h2>
		<div class="recent-grid">
			<div>
				<h3 class="recent-title">Recent registrations</h3>
				{#if recentRegRows.length > 0}
					<DataTable
						columns={[
							{ key: 'created_at', label: 'Date' },
							{ key: 'racer_name', label: 'Racer' },
							{ key: 'class_name', label: 'Class' },
							{ key: 'event_name', label: 'Event' },
							{ key: 'status', label: 'Payment status' },
							{ key: 'amount_collected', label: 'Collected', class: 'num' }
						]}
						rows={recentRegRows}
						emptyMessage="No recent registrations"
					/>
				{:else}
					<p class="chart-empty">No recent registrations.</p>
				{/if}
			</div>
			<div>
				<h3 class="recent-title">Recent payments</h3>
				{#if recentPayRows.length > 0}
					<DataTable
						columns={[
							{ key: 'date', label: 'Date' },
							{ key: 'amount', label: 'Amount' },
							{ key: 'status', label: 'Status' },
							{ key: 'party', label: 'Racer / purchaser' },
							{ key: 'event_name', label: 'Event' }
						]}
						rows={recentPayRows}
						emptyMessage="No recent payments"
					/>
				{:else}
					<p class="chart-empty">No recent payments.</p>
				{/if}
			</div>
		</div>
	</section>
{:else if !loading}
	<div class="chart-empty">No dashboard data available.</div>
{/if}

<style>
	.dashboard-header {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		align-items: flex-start;
		gap: 1rem;
	}
	.dashboard-toolbar {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: 0.75rem;
	}
	.filter-group {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}
	.filter-group label {
		font-size: 0.8rem;
		color: var(--text-muted);
	}
	.filter-group select {
		min-width: 12rem;
		padding: 0.4rem 0.5rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg-card);
	}
	.scope-banner {
		margin: 0 0 1.25rem;
		padding: 0.75rem 1rem;
		background: var(--bg-muted, #f1f5f9);
		border-radius: var(--radius);
		font-size: 0.9rem;
	}
	.scope-meta {
		color: var(--text-muted);
	}
	.dash-section {
		margin-bottom: 2rem;
	}
	.dash-section-title {
		font-size: 1.15rem;
		font-weight: 700;
		margin: 0 0 1rem;
		color: var(--text);
	}
	.section-hint {
		font-size: 0.85rem;
		color: var(--text-muted);
		margin: -0.5rem 0 1rem;
	}
	.stat-sublabel {
		font-size: 0.8rem;
		color: var(--text-muted);
		margin-top: 0.15rem;
	}
	.countdown-card {
		background: linear-gradient(135deg, var(--primary) 0%, var(--primary-hover) 100%);
		color: #fff;
		border-radius: var(--radius);
		box-shadow: var(--shadow);
		padding: 1.25rem 1.5rem;
		margin-bottom: 1.5rem;
	}
	.countdown-title {
		font-size: 0.9rem;
		font-weight: 600;
		opacity: 0.95;
		margin-bottom: 0.35rem;
	}
	.countdown-event-name {
		font-size: 1.25rem;
		font-weight: 700;
		color: #fff;
		text-decoration: none;
		display: inline-block;
		margin-bottom: 1rem;
	}
	.countdown-event-name:hover {
		text-decoration: underline;
	}
	.countdown-units {
		display: flex;
		flex-wrap: wrap;
		gap: 1.25rem;
	}
	.countdown-unit {
		font-size: 0.95rem;
	}
	.countdown-num {
		display: inline-block;
		min-width: 1.8ch;
		font-weight: 700;
		font-size: 1.1em;
	}
	a.stat-card {
		text-decoration: none;
		color: inherit;
		transition: box-shadow 0.15s, border-color 0.15s;
	}
	a.stat-card:hover {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.12);
		border-color: var(--primary);
	}
	.stat-card--event-revenue {
		border-left: 3px solid #16a34a;
	}
	.stat-card--spectator-revenue {
		border-left: 3px solid #0ea5e9;
	}
	.stat-card--membership-revenue {
		border-left: 3px solid #7c3aed;
	}
	.charts-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: 1.5rem;
	}
	.chart-card {
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		box-shadow: var(--shadow);
		padding: 1.25rem;
	}
	.chart-card-title {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 1rem 0;
	}
	.chart-container {
		position: relative;
		height: 240px;
	}
	.chart-container canvas {
		display: block;
		width: 100% !important;
		height: 100% !important;
	}
	.chart-empty {
		margin: 0;
		padding: 2rem;
		text-align: center;
		color: var(--text-muted);
		font-size: 0.9rem;
	}
	.recent-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
		gap: 1.5rem;
	}
	.recent-title {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 0.75rem;
	}
</style>

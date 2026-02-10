<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { fetchDashboardCounts, fetchDashboardCharts } from '$lib/api/resources';
	import { fetchEvents } from '$lib/api/events';
	import type { EventBase } from '$lib/api/events';
	import Chart from 'chart.js/auto';

	let loading = true;
	let error: string | null = null;
	let counts = {
		events: 0,
		racers: 0,
		registrations: 0,
		event_revenue: 0,
		spectator_revenue: 0,
		membership_revenue: 0,
		dayPasses: 0,
		weekendPasses: 0
	};
	let chartsData = {
		registrations_over_time: [] as { period: string; count: number }[],
		racers_per_class: [] as { class_key: string; class_name: string; count: number }[]
	};
	let nextEvent: EventBase | null = null;
	let countdown = { days: 0, hours: 0, minutes: 0, seconds: 0 };
	let countdownOver = false;

	let lineChartCanvas: HTMLCanvasElement;
	let barChartCanvas: HTMLCanvasElement;
	let lineChartInstance: Chart | null = null;
	let barChartInstance: Chart | null = null;

	function findNextEvent(events: EventBase[]): EventBase | null {
		const now = Date.now();
		const future = events
			.filter((e) => e.start_date && new Date(e.start_date).getTime() > now)
			.sort((a, b) => new Date(a.start_date).getTime() - new Date(b.start_date).getTime());
		return future[0] ?? null;
	}

	function updateCountdown() {
		if (!nextEvent?.start_date) return;
		const end = new Date(nextEvent.start_date).getTime();
		const now = Date.now();
		let diff = Math.floor((end - now) / 1000);
		if (diff <= 0) {
			countdownOver = true;
			countdown = { days: 0, hours: 0, minutes: 0, seconds: 0 };
			return;
		}
		const days = Math.floor(diff / 86400);
		diff %= 86400;
		const hours = Math.floor(diff / 3600);
		diff %= 3600;
		const minutes = Math.floor(diff / 60);
		const seconds = diff % 60;
		countdown = { days, hours, minutes, seconds };
	}

	function formatPeriod(period: string): string {
		// period is "YYYY-MM"
		const [y, m] = period.split('-');
		const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
		const mi = parseInt(m, 10) - 1;
		return mi >= 0 && mi < 12 ? `${monthNames[mi]} ${y}` : period;
	}

	let intervalId: ReturnType<typeof setInterval> | null = null;

	onMount(() => {
		(async () => {
			loading = true;
			error = null;
			const [result, chartsRes, eventsRes] = await Promise.all([
				fetchDashboardCounts(),
				fetchDashboardCharts(),
				fetchEvents(1, 100)
			]);
			loading = false;
			counts = {
				events: result.events,
				racers: result.racers,
				registrations: result.registrations,
				event_revenue: result.event_revenue,
				spectator_revenue: result.spectator_revenue,
				membership_revenue: result.membership_revenue,
				dayPasses: result.dayPasses,
				weekendPasses: result.weekendPasses
			};
			chartsData = {
				registrations_over_time: chartsRes.registrations_over_time,
				racers_per_class: chartsRes.racers_per_class
			};
			error = result.error ?? chartsRes.error ?? null;

			if (eventsRes.ok && eventsRes.data?.events) {
				nextEvent = findNextEvent(eventsRes.data.events);
				updateCountdown();
			}

			intervalId = setInterval(() => {
				if (countdownOver) {
					if (intervalId) clearInterval(intervalId);
					intervalId = null;
					return;
				}
				updateCountdown();
			}, 1000);

			// Build charts after data and DOM are ready
			await tick();
			if (lineChartCanvas && chartsData.registrations_over_time.length > 0) {
				lineChartInstance = new Chart(lineChartCanvas, {
					type: 'line',
					data: {
						labels: chartsData.registrations_over_time.map((d) => formatPeriod(d.period)),
						datasets: [
							{
								label: 'Registrations',
								data: chartsData.registrations_over_time.map((d) => d.count),
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
						plugins: {
							legend: { display: false },
							tooltip: { mode: 'index', intersect: false }
						},
						scales: {
							y: { beginAtZero: true, ticks: { stepSize: 1 } },
							x: { grid: { display: false } }
						}
					}
				});
			}
			if (barChartCanvas && chartsData.racers_per_class.length > 0) {
				barChartInstance = new Chart(barChartCanvas, {
					type: 'bar',
					data: {
						labels: chartsData.racers_per_class.map((d) => d.class_name),
						datasets: [
							{
								label: 'Registrations',
								data: chartsData.racers_per_class.map((d) => d.count),
								backgroundColor: 'rgba(14, 165, 233, 0.7)',
								borderColor: 'rgb(14, 165, 233)',
								borderWidth: 1
							}
						]
					},
					options: {
						responsive: true,
						maintainAspectRatio: false,
						plugins: {
							legend: { display: false },
							tooltip: { mode: 'index', intersect: false }
						},
						scales: {
							y: { beginAtZero: true, ticks: { stepSize: 1 } },
							x: { grid: { display: false } }
						}
					}
				});
			}
		})();

		return () => {
			if (intervalId) clearInterval(intervalId);
			lineChartInstance?.destroy();
			barChartInstance?.destroy();
		};
	});
</script>

<div class="page-header">
	<h1 class="page-title">Dashboard</h1>
	<p class="page-subtitle">Overview of events, racers, registrations, and revenue</p>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else}
	{#if nextEvent && nextEvent.start_date && !countdownOver}
		<div class="countdown-card">
			<div class="countdown-title">Countdown to next event</div>
			<a href="/events/{nextEvent.id}" class="countdown-event-name">{nextEvent.name}</a>
			<div class="countdown-units" role="timer" aria-live="polite">
				<span class="countdown-unit"><span class="countdown-num">{countdown.days}</span> days</span>
				<span class="countdown-unit"><span class="countdown-num">{countdown.hours}</span> hours</span>
				<span class="countdown-unit"><span class="countdown-num">{countdown.minutes}</span> minutes</span>
				<span class="countdown-unit"><span class="countdown-num">{countdown.seconds}</span> seconds</span>
			</div>
		</div>
	{/if}

	<div class="stats-grid">
		<div class="stat-card">
			<div class="value">{counts.events}</div>
			<div class="label">Events</div>
		</div>
		<div class="stat-card">
			<div class="value">{counts.racers}</div>
			<div class="label">Racers</div>
		</div>
		<div class="stat-card">
			<div class="value">{counts.registrations}</div>
			<div class="label">Registrations</div>
		</div>
		<div class="stat-card stat-card--event-revenue">
			<div class="value">{counts.event_revenue.toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0, maximumFractionDigits: 0 })}</div>
			<div class="label">Event revenue</div>
		</div>
		<div class="stat-card stat-card--spectator-revenue">
			<div class="value">{counts.spectator_revenue.toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0, maximumFractionDigits: 0 })}</div>
			<div class="label">Spectator revenue</div>
		</div>
		<div class="stat-card stat-card--membership-revenue">
			<div class="value">{counts.membership_revenue.toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0, maximumFractionDigits: 0 })}</div>
			<div class="label">Membership fee revenue</div>
		</div>
		<div class="stat-card">
			<div class="value">{counts.dayPasses}</div>
			<div class="label">Day passes</div>
		</div>
		<div class="stat-card">
			<div class="value">{counts.weekendPasses}</div>
			<div class="label">Weekend passes</div>
		</div>
		<a href="/payments" class="stat-card stat-card--link">
			<div class="value">PayPal</div>
			<div class="label">View payments</div>
		</a>
	</div>

	<section class="charts-section">
		<h2 class="charts-title">Charts</h2>
		<div class="charts-grid">
			<div class="chart-card">
				<h3 class="chart-card-title">Registrations over time</h3>
				<div class="chart-container">
					{#if chartsData.registrations_over_time.length > 0}
						<canvas bind:this={lineChartCanvas} aria-label="Registrations over time line chart"></canvas>
					{:else}
						<p class="chart-empty">No registration data yet.</p>
					{/if}
				</div>
			</div>
			<div class="chart-card">
				<h3 class="chart-card-title">Registrations per class</h3>
				<div class="chart-container">
					{#if chartsData.racers_per_class.length > 0}
						<canvas bind:this={barChartCanvas} aria-label="Registrations per class bar chart"></canvas>
					{:else}
						<p class="chart-empty">No class data yet.</p>
					{/if}
				</div>
			</div>
		</div>
	</section>
{/if}

<style>
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
		box-shadow: 0 2px 8px rgba(0,0,0,0.12);
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
	.charts-section {
		margin-top: 2.5rem;
	}
	.charts-title {
		font-size: 1.25rem;
		font-weight: 700;
		margin-bottom: 1.25rem;
		color: var(--text);
	}
	.charts-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
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
		color: var(--text);
	}
	.chart-container {
		position: relative;
		height: 260px;
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
</style>

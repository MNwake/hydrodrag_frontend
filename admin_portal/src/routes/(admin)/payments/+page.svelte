<script lang="ts">
	import { onMount } from 'svelte';
	import { fetchPayPalTransactions, type PayPalCheckoutRead } from '$lib/api/paypal';
	import { fetchEvents } from '$lib/api/events';

	let loading = true;
	let error: string | null = null;
	let transactions: PayPalCheckoutRead[] = [];
	let events: { id: string; name: string }[] = [];
	let filterEventId = '';
	let filterCaptured: '' | 'true' | 'false' = '';

	async function loadEvents() {
		const res = await fetchEvents(1, 200);
		if (res.ok && res.data?.events) {
			events = res.data.events.map((e) => ({ id: e.id, name: e.name }));
		}
	}

	async function load() {
		loading = true;
		error = null;
		try {
			const eventId = filterEventId && filterEventId !== '' ? filterEventId : null;
			const captured =
				filterCaptured === '' ? null : filterCaptured === 'true';
			const res = await fetchPayPalTransactions(eventId, captured);
			if (!res.ok) {
				error = res.error ?? 'Failed to load transactions';
				transactions = [];
				return;
			}
			transactions = res.data ?? [];
		} catch (e) {
			error =
				e instanceof Error
					? e.message
					: 'Request failed (network or CORS). Check API URL and server CORS for your origin.';
			transactions = [];
		} finally {
			loading = false;
		}
	}

	function racerDisplay(t: PayPalCheckoutRead): string {
		const r = t.racer;
		const full = (r?.full_name ?? '').toString().trim();
		return full || (r?.email ?? t.id);
	}

	function formatDate(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' });
	}

	function classEntriesSummary(t: PayPalCheckoutRead): string {
		const entries = t.class_entries ?? {};
		const keys = Object.keys(entries);
		if (keys.length === 0) return '—';
		if (keys.length <= 2) return keys.join(', ');
		return `${keys.length} classes`;
	}

	onMount(async () => {
		await loadEvents();
		await load();
	});
</script>

<div class="page-header" style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
	<div>
		<h1 class="page-title">Payments</h1>
		<p class="page-subtitle">PayPal checkout transactions</p>
	</div>
</div>

<div class="filters-row">
	<label for="filter-event">Event</label>
	<select id="filter-event" bind:value={filterEventId} onchange={load}>
		<option value="">All events</option>
		{#each events as ev}
			<option value={ev.id}>{ev.name}</option>
		{/each}
	</select>
	<label for="filter-captured">Status</label>
	<select id="filter-captured" bind:value={filterCaptured} onchange={load}>
		<option value="">All</option>
		<option value="true">Captured</option>
		<option value="false">Pending</option>
	</select>
	<button type="button" class="btn btn-secondary btn-sm" onclick={load} disabled={loading}>
		Refresh
	</button>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if transactions.length === 0}
	<div class="data-table-wrap">
		<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
			No transactions found.
		</div>
	</div>
{:else}
	<div class="data-table-wrap">
		<table class="data-table">
			<thead>
				<tr>
					<th>Date</th>
					<th>Order ID</th>
					<th>Event</th>
					<th>Racer</th>
					<th>Classes</th>
					<th class="num">Day</th>
					<th class="num">Weekend</th>
					<th class="center">IHRA</th>
					<th class="center">Captured</th>
				</tr>
			</thead>
			<tbody>
				{#each transactions as t}
					<tr>
						<td data-label="Date">{formatDate(t.created_at)}</td>
						<td data-label="Order ID"><code class="code-cell">{t.paypal_order_id}</code></td>
						<td data-label="Event">{t.event?.name ?? '—'}</td>
						<td data-label="Racer">{racerDisplay(t)}</td>
						<td data-label="Classes">{classEntriesSummary(t)}</td>
						<td class="num" data-label="Day">{t.spectator_single_day_passes ?? 0}</td>
						<td class="num" data-label="Weekend">{t.spectator_weekend_passes ?? 0}</td>
						<td class="center" data-label="IHRA">{t.purchase_ihra_membership ? 'Yes' : '—'}</td>
						<td class="center" data-label="Captured">{t.is_captured ? 'Yes' : 'Pending'}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

<style>
	.filters-row {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 0.75rem 1.5rem;
		margin-bottom: 1.25rem;
	}
	.filters-row label {
		font-size: 0.9rem;
		font-weight: 500;
		color: var(--text);
	}
	.filters-row select {
		padding: 0.4rem 0.6rem;
		font-size: 0.9rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg-card);
		min-width: 180px;
	}
	.code-cell {
		font-size: 0.85em;
		background: var(--bg-muted);
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
		word-break: break-all;
	}
</style>

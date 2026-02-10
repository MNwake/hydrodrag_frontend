<script lang="ts">
	import { onMount } from 'svelte';
	import DataTable from '$lib/components/DataTable.svelte';
	import Modal from '$lib/components/Modal.svelte';
	import {
		fetchRegistrations,
		type EventRegistrations,
		type RegistrationRow,
		type RegistrationWithDetail
	} from '$lib/api/resources';
	import type { EventRegistrationAdmin } from '$lib/api/registrations';

	type SortKey = 'racer_name' | 'class_name' | 'status' | 'amount' | 'registration_date';
	type SortDir = 'asc' | 'desc';

	let loading = true;
	let error: string | null = null;
	let eventRegistrations: EventRegistrations[] = [];
	let sortKey: SortKey = 'racer_name';
	let sortDir: SortDir = 'asc';
	let expandedEvents: Record<string, boolean> = {};
	let selectedReg: EventRegistrationAdmin | null = null;
	let showDetailModal = false;

	const columns: { key: SortKey; label: string; class?: 'num' | 'center'; sortable?: boolean }[] = [
		{ key: 'racer_name', label: 'Racer', sortable: true },
		{ key: 'class_name', label: 'Class', sortable: true },
		{ key: 'status', label: 'Status', sortable: true },
		{ key: 'amount', label: 'Amount', class: 'num', sortable: true },
		{ key: 'registration_date', label: 'Registration Date', sortable: true }
	];

	onMount(async () => {
		loading = true;
		error = null;
		const res = await fetchRegistrations();
		loading = false;
		if (!res.ok) {
			error = res.error ?? `HTTP ${res.status}`;
			return;
		}
		eventRegistrations = (res.data ?? []) as EventRegistrations[];
		expandedEvents = {};
	});

	function toggleEvent(eventId: string) {
		expandedEvents = { ...expandedEvents, [eventId]: !(expandedEvents[eventId] ?? false) };
	}

	function sortValue(row: Record<string, unknown>, key: SortKey): string | number {
		const v = row[key];
		if (key === 'amount') {
			const numStr = String(v).replace(/[^0-9.]/g, '');
			return parseFloat(numStr) || 0;
		}
		return String(v ?? '');
	}

	function toggleSort(key: SortKey) {
		if (sortKey === key) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortKey = key;
			sortDir = 'asc';
		}
	}

	function registrationRows(items: RegistrationWithDetail[]): Record<string, unknown>[] {
		return items.map(({ row, reg }) => ({
			id: row.id,
			racer_name: row.racer_name ?? '—',
			class_name: row.class_name ?? '—',
			status: row.status ?? '—',
			amount: row.amount ?? '—',
			registration_date: row.registration_date ?? '—',
			_reg: reg
		}));
	}

	function findRegById(registrationId: string): EventRegistrationAdmin | null {
		for (const er of eventRegistrations) {
			const found = er.registrations.find((r) => r.reg.id === registrationId);
			if (found) return found.reg;
		}
		return null;
	}

	function handleRowClick(row: Record<string, unknown>) {
		const id = row.id as string | undefined;
		const reg = (row._reg as EventRegistrationAdmin | undefined) ?? (id ? findRegById(id) : null);
		if (reg) {
			selectedReg = reg;
			showDetailModal = true;
		}
	}

	function racerDisplay(reg: EventRegistrationAdmin): string {
		const r = reg.racer ?? reg.racer_model;
		if (!r) return '—';
		const full = (r.full_name ?? '').toString().trim();
		const first = (r.first_name ?? '').toString().trim();
		const last = (r.last_name ?? '').toString().trim();
		const fromParts = [first, last].filter(Boolean).join(' ').trim();
		return full || fromParts || (r.email ?? '—');
	}

	function formatDate(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' });
	}

	/** Backend sends price in dollars (e.g. 250 = $250). */
	function formatPrice(dollars: number): string {
		return `$${Number(dollars).toFixed(2)}`;
	}

	$: sortedRows = (items: RegistrationWithDetail[]) => {
		const withReg = registrationRows(items);
		return [...withReg].sort((a, b) => {
			const va = sortValue(a, sortKey);
			const vb = sortValue(b, sortKey);
			let c = 0;
			if (typeof va === 'number' && typeof vb === 'number') {
				c = va - vb;
			} else {
				c = String(va).localeCompare(String(vb), undefined, { sensitivity: 'base' });
			}
			return sortDir === 'asc' ? c : -c;
		});
	};
</script>

<div class="page-header">
	<h1 class="page-title">Registrations</h1>
	<p class="page-subtitle">All event registrations grouped by event. Click a row to view details.</p>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if eventRegistrations.length === 0}
	<div class="data-table-wrap">
		<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
			No registrations found.
		</div>
	</div>
{:else}
	{#each eventRegistrations as { event_id, event_name, event_date, registrations }}
		{@const isExpanded = expandedEvents[event_id] ?? false}
		<section class="event-registrations-section">
			<button
				type="button"
				class="event-header"
				onclick={() => toggleEvent(event_id)}
			>
				<div class="event-header-content">
					<span class="event-chevron" class:expanded={isExpanded}>▼</span>
					<div class="event-header-text">
						<h2 class="event-name">{event_name}</h2>
						<p class="event-date">{event_date}</p>
					</div>
				</div>
			</button>
			{#if isExpanded}
				<div class="event-table-container">
					<DataTable
						{columns}
						rows={sortedRows(registrations)}
						emptyMessage="No registrations for this event."
						sortKey={sortKey}
						sortDir={sortDir}
						onSort={(key) => toggleSort(key as SortKey)}
						onRowClick={handleRowClick}
					/>
				</div>
			{/if}
		</section>
	{/each}
{/if}

<Modal bind:open={showDetailModal} title="Registration details">
	{#if selectedReg}
		<div class="detail-sections">
			<section class="detail-section">
				<h3 class="detail-heading">Racer</h3>
				<dl class="detail-dl">
					<dt>Name</dt>
					<dd>{racerDisplay(selectedReg)}</dd>
					{#if selectedReg.racer?.email ?? selectedReg.racer_model?.email}
						<dt>Email</dt>
						<dd>{(selectedReg.racer ?? selectedReg.racer_model)?.email ?? '—'}</dd>
					{/if}
					{#if selectedReg.racer?.phone ?? selectedReg.racer_model?.phone}
						<dt>Phone</dt>
						<dd>{(selectedReg.racer ?? selectedReg.racer_model)?.phone ?? '—'}</dd>
					{/if}
				</dl>
			</section>
			<section class="detail-section">
				<h3 class="detail-heading">Event & class</h3>
				<dl class="detail-dl">
					<dt>Event</dt>
					<dd>{selectedReg.event?.name ?? '—'}</dd>
					<dt>Class</dt>
					<dd>{selectedReg.class_name ?? selectedReg.class_key ?? '—'}</dd>
					<dt>PWC</dt>
					<dd>{selectedReg.pwc_identifier ?? '—'}</dd>
					<dt>Price</dt>
					<dd>
						{selectedReg.event?.classes
							? formatPrice(
									selectedReg.event.classes.find((c: { key: string }) => c.key === selectedReg?.class_key)
										?.price ?? selectedReg.price
								)
							: formatPrice(selectedReg.price)}
					</dd>
					<dt>Losses</dt>
					<dd>{selectedReg.losses ?? 0}</dd>
					<dt>Eliminated</dt>
					<dd>{selectedReg.is_eliminated ? 'Yes' : 'No'}</dd>
					<dt>Paid</dt>
					<dd>{selectedReg.is_paid ? 'Yes' : 'No'}</dd>
					<dt>Created</dt>
					<dd>{formatDate(selectedReg.created_at)}</dd>
				</dl>
			</section>
			{#if selectedReg.payment}
				<section class="detail-section">
					<h3 class="detail-heading">Payment (PayPal)</h3>
					<dl class="detail-dl">
						<dt>Order ID</dt>
						<dd><code>{selectedReg.payment.paypal_order_id}</code></dd>
						<dt>Captured</dt>
						<dd>{selectedReg.payment.is_captured ? 'Yes' : 'Pending'}</dd>
						{#if selectedReg.payment.spectator_single_day_passes > 0 || selectedReg.payment.spectator_weekend_passes > 0}
							<dt>Spectator passes</dt>
							<dd>Day: {selectedReg.payment.spectator_single_day_passes}, Weekend: {selectedReg.payment.spectator_weekend_passes}</dd>
						{/if}
						{#if selectedReg.payment.purchase_ihra_membership}
							<dt>IHRA membership</dt>
							<dd>Yes</dd>
						{/if}
						{#if selectedReg.payment.created_at}
							<dt>Payment date</dt>
							<dd>{formatDate(selectedReg.payment.created_at)}</dd>
						{/if}
					</dl>
				</section>
			{:else}
				<section class="detail-section">
					<h3 class="detail-heading">Payment</h3>
					<p class="detail-muted">No payment linked.</p>
				</section>
			{/if}
		</div>
	{/if}
	<svelte:fragment slot="footer">
		<button type="button" class="btn btn-primary" onclick={() => (showDetailModal = false)}>Close</button>
	</svelte:fragment>
</Modal>

<style>
	.event-registrations-section {
		margin-bottom: 2.5rem;
	}
	.event-table-container {
		margin-top: 1rem;
	}
	.event-header {
		width: 100%;
		padding: 1rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		cursor: pointer;
		transition: all 0.15s;
		margin-bottom: 0;
		text-align: left;
	}
	.event-header:hover {
		background: var(--bg-muted);
		border-color: var(--primary);
	}
	.event-header-content {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}
	.event-chevron {
		font-size: 0.75rem;
		color: var(--text-muted);
		transition: transform 0.2s;
		transform: rotate(-90deg);
		flex-shrink: 0;
	}
	.event-chevron.expanded {
		transform: rotate(0deg);
	}
	.event-header-text {
		flex: 1;
	}
	.event-name {
		font-size: 1.2rem;
		font-weight: 600;
		margin: 0 0 0.25rem 0;
		color: var(--text);
	}
	.event-date {
		font-size: 0.95rem;
		color: var(--text-muted);
		margin: 0;
	}
	.detail-sections {
		display: flex;
		flex-direction: column;
		gap: 1.25rem;
	}
	.detail-section {
		padding: 0;
	}
	.detail-heading {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 0.5rem 0;
		color: var(--text);
		border-bottom: 1px solid var(--border);
		padding-bottom: 0.35rem;
	}
	.detail-dl {
		display: grid;
		grid-template-columns: auto 1fr;
		gap: 0.25rem 1.5rem;
		margin: 0;
		font-size: 0.95rem;
	}
	.detail-dl dt {
		color: var(--text-muted);
		font-weight: 500;
	}
	.detail-dl dd {
		margin: 0;
	}
	.detail-dl code {
		font-size: 0.9em;
		background: var(--bg-muted);
		padding: 0.15rem 0.4rem;
		border-radius: 4px;
	}
	.detail-muted {
		margin: 0;
		color: var(--text-muted);
		font-size: 0.95rem;
	}
</style>

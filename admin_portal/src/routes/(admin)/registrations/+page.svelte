<script lang="ts">
	import { onMount } from 'svelte';
	import DataTable from '$lib/components/DataTable.svelte';
	import Modal from '$lib/components/Modal.svelte';
	import {
		fetchRegistrations,
		fetchRacerPwcs,
		type EventRegistrations,
		type RegistrationRow,
		type RacerPwcRow,
		type RegistrationWithDetail
	} from '$lib/api/resources';
	import { fetchAllEventsForAdmin, type EventBase, type EventClass } from '$lib/api/events';
	import {
		updateRegistration,
		type EventRegistrationAdmin,
		type EventRegistrationAdminUpdate
	} from '$lib/api/registrations';
	import { toast } from '$lib/stores/toast';

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

	// Admin edit state
	let editing = false;
	let editSaving = false;
	let editIsPaid = false;

	let allEditEvents: EventBase[] = [];
	let racerPwcs: RacerPwcRow[] = [];
	let editEventId = '';
	let editClassKey = '';
	let editPwcId = '';
	let editFormLoading = false;

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
			void loadRacerPwcsForDisplay(reg.racer.id);
		}
	}

	async function loadRacerPwcsForDisplay(racerId: string) {
		const res = await fetchRacerPwcs(racerId);
		racerPwcs = res.ok && res.data ? res.data : [];
	}

	/** Pick a valid class_key for the given event (keeps current key when still valid). */
	function syncClassKeyForEvent(eventId: string) {
		const ev = allEditEvents.find((e) => e.id === eventId);
		const classes = (ev?.classes ?? []).filter((c) => c.is_active);
		if (classes.length && !classes.some((c) => c.key === editClassKey)) {
			editClassKey = classes[0].key;
		}
	}

	function onEditEventSelectChange(e: Event) {
		const v = (e.currentTarget as HTMLSelectElement).value;
		editEventId = v;
		syncClassKeyForEvent(v);
	}

	async function beginEdit() {
		if (!selectedReg) return;
		editing = true;
		editFormLoading = true;
		editIsPaid = selectedReg.is_paid ?? false;
		editEventId = selectedReg.event.id;
		editClassKey = selectedReg.class_key;
		editPwcId = selectedReg.pwc_identifier ?? '';

		try {
			const evRes = await fetchAllEventsForAdmin();
			if (evRes.ok && evRes.data) {
				allEditEvents = [...evRes.data].sort(
					(a, b) =>
						new Date(b.start_date).getTime() - new Date(a.start_date).getTime()
				);
			} else {
				allEditEvents = [];
				if (evRes.error) toast(evRes.error, 'error');
			}

			const pwcRes = await fetchRacerPwcs(selectedReg.racer.id);
			if (pwcRes.ok && pwcRes.data) {
				racerPwcs = pwcRes.data;
			} else {
				racerPwcs = [];
				if (pwcRes.error) toast(pwcRes.error, 'error');
			}

			if (!allEditEvents.some((e) => e.id === editEventId)) {
				toast('Current event not in admin list — pick another event.', 'error');
			}

			syncClassKeyForEvent(editEventId);

			const opts = pwcSelectOptions(racerPwcs, editPwcId);
			if (opts.length && !opts.some((o) => o.value === editPwcId)) {
				editPwcId = opts[0].value;
			}

			if (opts.length === 0) {
				toast('This racer has no PWCs on file — add one or save a PWC label after edit.', 'error');
			}
		} finally {
			editFormLoading = false;
		}
	}

	function cancelEdit() {
		editing = false;
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

	function formatShortDate(iso: string | undefined): string {
		if (!iso) return '';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '' : d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
	}

	function looksLikeMongoId(s: string): boolean {
		return /^[a-f\d]{24}$/i.test((s ?? '').trim());
	}

	type PwcOpt = { value: string; label: string };

	function pwcSelectOptions(pwcs: RacerPwcRow[], currentValue: string): PwcOpt[] {
		const out: PwcOpt[] = pwcs.map((p) => ({
			value: p.id,
			label: `${p.make} ${p.model}${p.is_primary ? ' (primary)' : ''}`
		}));
		const s = (currentValue ?? '').trim();
		if (s && !out.some((o) => o.value === s)) {
			out.unshift({ value: s, label: `${s} (on file)` });
		}
		return out;
	}

	function pwcLabel(pwcId: string | null | undefined): string {
		if (!pwcId) return '—';
		const id = pwcId.trim();
		const byId = racerPwcs.find((x) => x.id === id);
		if (byId) return `${byId.make} ${byId.model}${byId.is_primary ? ' (primary)' : ''}`;
		const byCompose = racerPwcs.find(
			(x) => `${x.make} ${x.model}`.trim().toLowerCase() === id.toLowerCase()
		);
		if (byCompose)
			return `${byCompose.make} ${byCompose.model}${byCompose.is_primary ? ' (primary)' : ''}`;
		return pwcId;
	}

	function activeClassesForEditEvent(): EventClass[] {
		return (allEditEvents.find((e) => e.id === editEventId)?.classes ?? []).filter((c) => c.is_active);
	}

	function priceForEditClass(): string {
		const cls = activeClassesForEditEvent().find((c) => c.key === editClassKey);
		if (cls) return formatPrice(cls.price);
		if (selectedReg) return formatPrice(selectedReg.price);
		return '—';
	}

	async function saveEdit() {
		if (!selectedReg) return;
		if (!editEventId || !editClassKey) {
			toast('Select an event and class.', 'error');
			return;
		}
		const pwcSel = (editPwcId ?? '').trim();
		if (!pwcSel) {
			toast('Select or keep a PWC for this racer.', 'error');
			return;
		}
		editSaving = true;

		const payload: EventRegistrationAdminUpdate = {
			is_paid: editIsPaid,
			event_id: editEventId,
			class_key: editClassKey
		};
		if (looksLikeMongoId(pwcSel)) {
			payload.pwc_id = pwcSel;
		} else {
			payload.pwc_identifier = pwcSel;
		}

		const res = await updateRegistration(selectedReg.id, payload);
		editSaving = false;

		if (!res.ok || !res.data) {
			toast(res.error ?? 'Failed to update registration', 'error');
			return;
		}

		toast('Registration updated', 'success');
		editing = false;
		selectedReg = res.data;

		// Refresh table so losses/paid status is consistent everywhere.
		const refreshed = await fetchRegistrations();
		if (refreshed.ok && refreshed.data) {
			eventRegistrations = refreshed.data as EventRegistrations[];
			selectedReg = findRegById(res.data.id) ?? res.data;
			if (selectedReg) void loadRacerPwcsForDisplay(selectedReg.racer.id);
		}
	}

	$: if (!showDetailModal) {
		editing = false;
		editSaving = false;
		editFormLoading = false;
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
					<dt>Email</dt>
					<dd>{selectedReg.racer?.email ?? selectedReg.racer_model?.email ?? '—'}</dd>
					<dt>Phone</dt>
					<dd>{selectedReg.racer?.phone ?? selectedReg.racer_model?.phone ?? '—'}</dd>
				</dl>
			</section>
			<section class="detail-section">
				<h3 class="detail-heading">Event &amp; class</h3>
				{#if editing && editFormLoading}
					<p class="detail-muted">Loading events and watercraft…</p>
				{:else}
					<dl class="detail-dl">
						<dt>Event</dt>
						<dd>
							{#if editing}
								<select
									class="admin-edit-select"
									value={editEventId}
									onchange={onEditEventSelectChange}
									disabled={editSaving}
								>
									{#each allEditEvents as ev}
										<option value={ev.id}>
											{ev.name}{formatShortDate(ev.start_date)
												? ` (${formatShortDate(ev.start_date)})`
												: ''}
										</option>
									{/each}
								</select>
							{:else}
								{selectedReg.event?.name ?? '—'}
							{/if}
						</dd>
						<dt>Class</dt>
						<dd>
							{#if editing}
								{#key editEventId}
									<select class="admin-edit-select" bind:value={editClassKey} disabled={editSaving}>
										{#each activeClassesForEditEvent() as cls (cls.key)}
											<option value={cls.key}>{cls.name} — {formatPrice(cls.price)}</option>
										{/each}
									</select>
								{/key}
							{:else}
								{selectedReg.class_name ?? selectedReg.class_key ?? '—'}
							{/if}
						</dd>
						<dt>PWC</dt>
						<dd>
							{#if editing}
								<select class="admin-edit-select" bind:value={editPwcId} disabled={editSaving}>
									{#each pwcSelectOptions(racerPwcs, editPwcId) as opt}
										<option value={opt.value}>{opt.label}</option>
									{/each}
								</select>
							{:else}
								{pwcLabel(selectedReg.pwc_identifier)}
							{/if}
						</dd>
						<dt>Price</dt>
						<dd>
							{#if editing}
								{priceForEditClass()}
							{:else}
								{selectedReg.event?.classes
									? formatPrice(
											selectedReg.event.classes.find(
												(c: { key: string }) => c.key === selectedReg?.class_key
											)?.price ?? selectedReg.price
										)
									: formatPrice(selectedReg.price)}
							{/if}
						</dd>
						<dt>Losses</dt>
						<dd>{selectedReg.losses ?? 0}</dd>
						<dt>Eliminated</dt>
						<dd>{selectedReg.is_eliminated ? 'Yes' : 'No'}</dd>
						<dt>Paid</dt>
						<dd>
							{#if editing}
								<label class="paid-edit-label">
									<input type="checkbox" bind:checked={editIsPaid} disabled={editSaving} />
									<span class="paid-edit-hint">
										Updating paid here also updates the linked PayPal checkout when one exists.
									</span>
								</label>
							{:else}
								{selectedReg.is_paid ? 'Yes' : 'No'}
							{/if}
						</dd>
						<dt>Created</dt>
						<dd>{formatDate(selectedReg.created_at)}</dd>
					</dl>
				{/if}
			</section>
			{#if selectedReg.payment}
				<section class="detail-section">
					<h3 class="detail-heading">Payment (PayPal)</h3>
					<dl class="detail-dl">
						<dt>Order ID</dt>
						<dd><code>{selectedReg.payment.paypal_order_id}</code></dd>
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
		{#if editing}
			<button type="button" class="btn btn-secondary" disabled={editSaving || editFormLoading} onclick={cancelEdit}>Cancel</button>
			<button type="button" class="btn btn-primary" disabled={editSaving || editFormLoading} onclick={saveEdit}>
				{editSaving ? 'Saving…' : 'Save changes'}
			</button>
		{:else}
			<button type="button" class="btn btn-secondary" onclick={beginEdit}>Edit</button>
			<button type="button" class="btn btn-primary" disabled={editSaving} onclick={() => (showDetailModal = false)}>
				Close
			</button>
		{/if}
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

	.admin-edit-select {
		width: 100%;
		max-width: 22rem;
	}

	.paid-edit-label {
		display: flex;
		align-items: flex-start;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: 400;
	}

	.paid-edit-hint {
		display: block;
		color: var(--text-muted);
		font-size: 0.85rem;
		line-height: 1.35;
		max-width: 20rem;
	}
</style>

<script lang="ts">
	import { onMount } from 'svelte';
	import {
		capturePayPalCheckout,
		checkoutTypeLabel,
		fetchPayPalTransactions,
		type AdminPayPalCaptureResponse,
		type PayPalCheckoutRead
	} from '$lib/api/paypal';
	import { fetchEvents } from '$lib/api/events';
	import { toast } from '$lib/stores/toast';
	import { formatDateTimeLocal, isRecentPayPalPending } from '$lib/format/datetime';

	let loading = true;
	let error: string | null = null;
	let transactions: PayPalCheckoutRead[] = [];
	let events: { id: string; name: string }[] = [];
	let filterEventId = '';
	let filterCaptured: '' | 'true' | 'false' = '';
	let captureSubmitting: string | null = null;
	let approveSendEmail = true;
	let approveStaffVerified = false;

	$: pendingTransactions = transactions.filter(
		(t) => !t.is_captured && isRecentPayPalPending(t.created_at)
	);

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
			let rows = res.data ?? [];
			if (filterCaptured === 'false') {
				rows = rows.filter(
					(t) => !t.is_captured && isRecentPayPalPending(t.created_at)
				);
			}
			transactions = rows;
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
		if (t.purchaser_name) return t.purchaser_name;
		const r = t.racer;
		const full = (r?.full_name ?? '').toString().trim();
		return full || (r?.email ?? '—');
	}

	function customerEmail(t: PayPalCheckoutRead): string {
		return (t.purchaser_email ?? t.racer?.email ?? '').toString().trim();
	}

	function formatDate(iso: string | null | undefined): string {
		return formatDateTimeLocal(iso);
	}

	function formatMoney(amount: number | undefined): string {
		return `$${Number(amount ?? 0).toFixed(2)}`;
	}

	function classEntriesSummary(t: PayPalCheckoutRead): string {
		const entries = t.class_entries ?? {};
		const keys = Object.keys(entries);
		if (keys.length === 0) return '—';
		if (keys.length <= 2) return keys.join(', ');
		return `${keys.length} classes`;
	}

	function spectatorPassSummary(t: PayPalCheckoutRead): string {
		const parts: string[] = [];
		if ((t.spectator_single_day_passes ?? 0) > 0) {
			parts.push(`${t.spectator_single_day_passes} day`);
		}
		if ((t.spectator_weekend_passes ?? 0) > 0) {
			parts.push(`${t.spectator_weekend_passes} weekend`);
		}
		return parts.length ? parts.join(', ') : '—';
	}

	function wantsEmailOnApprove(t: PayPalCheckoutRead): boolean {
		if (!approveSendEmail) return false;
		const ct = (t.checkout_type ?? '').toLowerCase();
		if (ct.includes('spectator') || ct === 'admin_registration') {
			return Boolean(customerEmail(t));
		}
		return Boolean(customerEmail(t));
	}

	function captureResultMessage(data: AdminPayPalCaptureResponse): string {
		if (data.tickets?.length) {
			const codes = data.tickets.map((tk) => tk.ticket_code).join(', ');
			return `Approved. ${data.tickets.length} ticket(s): ${codes}.`;
		}
		const regIds = data.registration_ids as string[] | undefined;
		if (regIds?.length) {
			return `Approved. ${regIds.length} registration(s) finalized.`;
		}
		if (data.registrations_written != null) {
			return `Approved. ${data.registrations_written} registration(s) finalized.`;
		}
		if (data.shirt_order_id) {
			return 'Approved. Shirt order recorded.';
		}
		return `Approved (${data.status ?? 'captured'}).`;
	}

	function approveConfirmMessage(t: PayPalCheckoutRead): string {
		const who = racerDisplay(t);
		const amount = formatMoney(t.total_amount);
		const type = checkoutTypeLabel(t.checkout_type);
		const passes = spectatorPassSummary(t);
		const classes = classEntriesSummary(t);

		let detail = `${type} — ${amount}`;
		if (passes !== '—') detail += ` — ${passes}`;
		else if (classes !== '—') detail += ` — ${classes}`;

		return (
			(approveStaffVerified
				? `Issue tickets/registrations without PayPal capture?\n\nUse only when staff verified payment on the device but PayPal cannot capture order ${t.paypal_order_id}.`
				: `Payment verified on the customer's device?\n\nApprove PayPal order ${t.paypal_order_id} for ${who}.\n${detail}\n\nThis captures payment and issues tickets/registrations in HydroDrags.`) +
			(wantsEmailOnApprove(t) ? '\n\nA confirmation email will be sent.' : '')
		);
	}

	async function approveTransaction(t: PayPalCheckoutRead) {
		if (t.is_captured) return;
		if (!confirm(approveConfirmMessage(t))) return;

		captureSubmitting = t.paypal_order_id;
		const res = await capturePayPalCheckout({
			paypal_order_id: t.paypal_order_id,
			send_email: wantsEmailOnApprove(t),
			staff_verified: approveStaffVerified
		});
		captureSubmitting = null;

		if (!res.ok || !res.data) {
			const errText = res.error ?? 'Approval failed';
			if (
				!approveStaffVerified &&
				/not found|staff-verified|cannot be captured/i.test(errText) &&
				confirm(
					`${errText}\n\nTry staff-verified finalize? This issues tickets/registrations without calling PayPal.`
				)
			) {
				approveStaffVerified = true;
				return approveTransaction(t);
			}
			alert(errText);
			toast(errText, 'error');
			return;
		}

		let msg = captureResultMessage(res.data);
		if (wantsEmailOnApprove(t)) {
			if (res.data.email_sent) msg += ' Email sent.';
			else if (res.data.email_error) msg += ` Email not sent: ${res.data.email_error}`;
		}
		toast(msg, 'success');
		await load();
	}

	onMount(async () => {
		await loadEvents();
		await load();
	});
</script>

<div class="page-header page-header-row">
	<div>
		<h1 class="page-title">Payments</h1>
		<p class="page-subtitle">
			All PayPal checkouts. Approve when the customer paid on their device but did not finish in the
			app.
		</p>
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
		<option value="false">Pending approval (last 3 hours)</option>
	</select>
	<button type="button" class="btn btn-secondary btn-sm" onclick={load} disabled={loading}>
		Refresh
	</button>
</div>

{#if !loading && !error && pendingTransactions.length > 0}
	<section class="pending-approval-section">
		<h2 class="pending-approval-title">
			Awaiting approval
			<span class="pending-count">{pendingTransactions.length}</span>
		</h2>
		<p class="pending-approval-hint">
			Staff verified payment on the customer’s phone — approve here to capture PayPal and create
			tickets or registrations. Only checkouts from the last 3 hours are shown (PayPal approval
			window).
		</p>
		<label class="pending-email-option">
			<input
				type="checkbox"
				bind:checked={approveSendEmail}
				disabled={captureSubmitting !== null}
			/>
			Send confirmation / QR email when an address is on file
		</label>
		<label class="pending-email-option">
			<input
				type="checkbox"
				bind:checked={approveStaffVerified}
				disabled={captureSubmitting !== null}
			/>
			Payment verified on device — finalize without PayPal capture (use if Approve fails)
		</label>
		<div class="data-table-wrap">
			<table class="data-table pending-approval-table">
				<thead>
					<tr>
						<th>Date</th>
						<th>Type</th>
						<th>Customer</th>
						<th>Details</th>
						<th class="num">Amount</th>
						<th>Order ID</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					{#each pendingTransactions as t (t.paypal_order_id)}
						<tr class="row-pending">
							<td data-label="Date">{formatDate(t.created_at)}</td>
							<td data-label="Type">{checkoutTypeLabel(t.checkout_type)}</td>
							<td data-label="Customer">
								{racerDisplay(t)}
								{#if customerEmail(t)}
									<div class="customer-email">{customerEmail(t)}</div>
								{/if}
							</td>
							<td data-label="Details">
								{#if spectatorPassSummary(t) !== '—'}
									{spectatorPassSummary(t)}
								{:else if classEntriesSummary(t) !== '—'}
									{classEntriesSummary(t)}
								{:else}
									{t.event?.name ?? '—'}
								{/if}
							</td>
							<td class="num" data-label="Amount">{formatMoney(t.total_amount)}</td>
							<td data-label="Order ID">
								<code class="code-cell">{t.paypal_order_id}</code>
							</td>
							<td class="actions-cell">
								<button
									type="button"
									class="btn btn-primary btn-sm"
									disabled={captureSubmitting === t.paypal_order_id}
									onclick={() => void approveTransaction(t)}
								>
									{captureSubmitting === t.paypal_order_id
										? 'Approving…'
										: 'Approve'}
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	</section>
{/if}

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if transactions.length === 0}
	<div class="data-table-wrap">
		<div class="empty-state">No transactions found.</div>
	</div>
{:else}
	<h2 class="all-transactions-title">All transactions</h2>
	<div class="data-table-wrap">
		<table class="data-table">
			<thead>
				<tr>
					<th>Date</th>
					<th>Order ID</th>
					<th>Type</th>
					<th>Customer</th>
					<th>Event</th>
					<th>Classes</th>
					<th class="num">Day</th>
					<th class="num">Weekend</th>
					<th class="num">Amount</th>
					<th class="center">Status</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each transactions as t (t.paypal_order_id)}
					<tr class:row-pending={!t.is_captured}>
						<td data-label="Date">{formatDate(t.created_at)}</td>
						<td data-label="Order ID"><code class="code-cell">{t.paypal_order_id}</code></td>
						<td data-label="Type">{checkoutTypeLabel(t.checkout_type)}</td>
						<td data-label="Customer">
							{racerDisplay(t)}
							{#if customerEmail(t)}
								<div class="customer-email">{customerEmail(t)}</div>
							{/if}
						</td>
						<td data-label="Event">{t.event?.name ?? '—'}</td>
						<td data-label="Classes">{classEntriesSummary(t)}</td>
						<td class="num" data-label="Day">{t.spectator_single_day_passes ?? 0}</td>
						<td class="num" data-label="Weekend">{t.spectator_weekend_passes ?? 0}</td>
						<td class="num" data-label="Amount">{formatMoney(t.total_amount)}</td>
						<td class="center" data-label="Status">
							{#if t.is_captured}
								Captured
							{:else}
								<span class="status-pending">Pending</span>
							{/if}
						</td>
						<td class="center actions-cell">
							{#if !t.is_captured}
								<button
									type="button"
									class="btn btn-primary btn-sm"
									disabled={captureSubmitting === t.paypal_order_id}
									onclick={() => void approveTransaction(t)}
								>
									{captureSubmitting === t.paypal_order_id ? 'Approving…' : 'Approve'}
								</button>
							{:else}
								—
							{/if}
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

<style>
	.page-header-row {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		flex-wrap: wrap;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

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

	.pending-approval-section {
		margin-bottom: 2rem;
		padding: 1rem 1.25rem;
		background: var(--bg-card);
		border: 1px solid rgba(14, 165, 233, 0.35);
		border-radius: var(--radius);
	}
	.pending-approval-title {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 1.1rem;
		font-weight: 600;
		margin: 0 0 0.35rem 0;
	}
	.pending-count {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 1.5rem;
		padding: 0.1rem 0.45rem;
		font-size: 0.85rem;
		font-weight: 600;
		border-radius: 999px;
		background: rgba(14, 165, 233, 0.15);
		color: #0369a1;
	}
	.pending-approval-hint {
		margin: 0 0 0.75rem 0;
		font-size: 0.95rem;
		color: var(--text-muted);
		line-height: 1.45;
	}
	.pending-email-option {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
		font-size: 0.9rem;
		cursor: pointer;
	}
	.pending-approval-table {
		margin-top: 0.25rem;
	}

	.all-transactions-title {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 0.75rem 0;
		color: var(--text-muted);
	}

	.empty-state {
		padding: 2rem;
		text-align: center;
		color: var(--text-muted);
	}

	.code-cell {
		font-size: 0.85em;
		background: var(--bg-muted);
		padding: 0.2rem 0.4rem;
		border-radius: 4px;
		word-break: break-all;
	}
	.customer-email {
		font-size: 0.8rem;
		color: var(--text-muted);
		margin-top: 0.15rem;
	}
	.actions-cell {
		white-space: nowrap;
	}
	.row-pending {
		background: color-mix(in srgb, rgba(14, 165, 233, 0.08) 100%, transparent);
	}
	.status-pending {
		font-weight: 600;
		color: #0369a1;
	}
</style>

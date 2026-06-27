<script lang="ts">
	import { onMount } from 'svelte';
	import { fetchEvents } from '$lib/api/events';
	import {
		captureShirtPayPalCheckout,
		createShirtOrder,
		createShirtPayPalCheckout,
		deleteShirtOrder,
		fetchPendingShirtCheckouts,
		fetchShirtOrders,
		fetchShirtSummary,
		type ShirtOrderCreate,
		type ShirtOrderRead,
		type ShirtPayPalPending,
		type ShirtSize
	} from '$lib/api/shirt-orders';
	import { getApiBase, getAdminApiKey } from '$lib/api/client';
	import { formatDateLocal, formatDateTimeLocal } from '$lib/format/datetime';

	let loading = true;
	let orders: ShirtOrderRead[] = [];
	let pending: ShirtPayPalPending[] = [];
	let summary: { total_orders: number; total_quantity: number; by_size: Record<string, number> } | null =
		null;
	let events: { id: string; name: string }[] = [];
	let filterEventId = '';

	let purchaserName = '';
	let shirtSize: ShirtSize = 'M';
	let quantity = 1;
	let unitPrice = 0;
	let notes = '';
	let submitting = false;
	let message: { ok: boolean; text: string } | null = null;

	let paypalApprovalUrl: string | null = null;
	let paypalOrderId: string | null = null;
	let paypalAmount: number | null = null;
	let paypalSubmitting = false;
	let captureSubmitting: string | null = null;

	const sizes: ShirtSize[] = ['S', 'M', 'L', 'XL', '2XL'];

	async function load() {
		loading = true;
		const [ordersRes, summaryRes, pendingRes] = await Promise.all([
			fetchShirtOrders(filterEventId || null),
			fetchShirtSummary(filterEventId || null),
			fetchPendingShirtCheckouts(filterEventId || null)
		]);
		orders = ordersRes.ok && ordersRes.data ? ordersRes.data : [];
		summary = summaryRes.ok && summaryRes.data ? summaryRes.data : null;
		pending = pendingRes.ok && pendingRes.data ? pendingRes.data : [];
		loading = false;
	}

	onMount(async () => {
		const evRes = await fetchEvents(1, 200);
		if (evRes.ok && evRes.data?.events) {
			events = evRes.data.events.map((e) => ({ id: e.id, name: e.name }));
		}
		await load();
	});

	function salePayload() {
		return {
			...(filterEventId ? { event_id: filterEventId } : {}),
			purchaser_name: purchaserName.trim(),
			shirt_size: shirtSize,
			quantity: Math.max(1, Math.floor(quantity) || 1),
			notes: notes.trim() || null
		};
	}

	async function handleAdd(e: Event) {
		e.preventDefault();
		if (!purchaserName.trim()) {
			message = { ok: false, text: 'Enter purchaser name.' };
			return;
		}
		submitting = true;
		message = null;
		const body: ShirtOrderCreate = {
			...salePayload(),
			unit_price: Number(unitPrice) || 0
		};
		const res = await createShirtOrder(body);
		submitting = false;
		if (!res.ok) {
			message = { ok: false, text: res.error ?? 'Failed to add shirt order' };
			return;
		}
		message = { ok: true, text: 'Shirt sale recorded.' };
		purchaserName = '';
		notes = '';
		await load();
	}

	async function handlePayPalCheckout(e: Event) {
		e.preventDefault();
		if (!purchaserName.trim()) {
			message = { ok: false, text: 'Enter purchaser name.' };
			return;
		}
		const price = Number(unitPrice);
		if (!price || price <= 0) {
			message = { ok: false, text: 'Enter a unit price greater than zero.' };
			return;
		}
		paypalSubmitting = true;
		message = null;
		paypalApprovalUrl = null;
		paypalOrderId = null;
		paypalAmount = null;
		const res = await createShirtPayPalCheckout({
			...salePayload(),
			unit_price: price
		});
		paypalSubmitting = false;
		if (!res.ok || !res.data) {
			message = { ok: false, text: res.error ?? 'Failed to create PayPal checkout' };
			return;
		}
		paypalApprovalUrl = res.data.approval_url;
		paypalOrderId = res.data.paypal_order_id;
		paypalAmount = res.data.amount;
		message = {
			ok: true,
			text: 'Payment link ready. Open PayPal for the customer, then capture after they pay.'
		};
		await load();
	}

	function openPayPal() {
		if (paypalApprovalUrl) {
			window.open(paypalApprovalUrl, '_blank', 'noopener,noreferrer');
		}
	}

	async function capturePending(orderId: string) {
		captureSubmitting = orderId;
		message = null;
		const res = await captureShirtPayPalCheckout({ paypal_order_id: orderId });
		captureSubmitting = null;
		if (!res.ok) {
			message = { ok: false, text: res.error ?? 'Capture failed' };
			return;
		}
		if (paypalOrderId === orderId) {
			paypalApprovalUrl = null;
			paypalOrderId = null;
			paypalAmount = null;
		}
		message = { ok: true, text: 'Payment captured and shirt sale recorded.' };
		await load();
	}

	function exportCsv() {
		const base = getApiBase();
		const key = getAdminApiKey();
		const q = filterEventId ? `?event_id=${encodeURIComponent(filterEventId)}` : '';
		const url = `${base}/admin/shirt-orders/export.csv${q}`;
		fetch(url, { headers: key ? { 'X-Admin-Key': key } : {} })
			.then((r) => r.blob())
			.then((blob) => {
				const a = document.createElement('a');
				a.href = URL.createObjectURL(blob);
				a.download = 'shirt_orders.csv';
				a.click();
			});
	}

	async function removeOrder(id: string) {
		if (!confirm('Delete this shirt order?')) return;
		await deleteShirtOrder(id);
		await load();
	}
</script>

<div class="page-header">
	<h1 class="page-title">Shirt sales</h1>
	<p class="page-subtitle">
		Record manual/POS sales or create a PayPal link for the customer to pay on-site.
	</p>
</div>

<div class="filters-row">
	<label for="shirt-event">Filter by event (optional)</label>
	<select id="shirt-event" bind:value={filterEventId} onchange={load}>
		<option value="">All events</option>
		{#each events as ev}
			<option value={ev.id}>{ev.name}</option>
		{/each}
	</select>
	<button type="button" class="btn btn-secondary" onclick={exportCsv}>
		Export CSV
	</button>
</div>

{#if summary}
	<div class="stats-grid">
		{#each sizes as size}
			<div class="stat-card">
				<div class="value">{summary.by_size[size] ?? 0}</div>
				<div class="label">Size {size}</div>
			</div>
		{/each}
		<div class="stat-card">
			<div class="value">{summary.total_quantity}</div>
			<div class="label">Total shirts (qty)</div>
		</div>
	</div>
{/if}

<section class="form-card" style="margin-top: 1.5rem;">
	<h2 class="form-section-title">Sell with PayPal</h2>
	<p class="section-hint">
		Fill in the sale details, create a payment link, and open it for the customer. After they
		complete PayPal checkout, capture the payment to record the sale.
	</p>
	{#if message}
		<p class={message.ok ? 'success-msg' : 'error-msg'}>{message.text}</p>
	{/if}
	<form class="create-form-grid" onsubmit={handlePayPalCheckout}>
		<label>
			Purchaser name
			<input type="text" bind:value={purchaserName} required />
		</label>
		<label>
			Size
			<select bind:value={shirtSize}>
				{#each sizes as s}
					<option value={s}>{s}</option>
				{/each}
			</select>
		</label>
		<label>
			Quantity
			<input type="number" min="1" bind:value={quantity} />
		</label>
		<label>
			Unit price ($)
			<input type="number" min="0.01" step="0.01" bind:value={unitPrice} required />
		</label>
		<label class="span2">
			Notes
			<input type="text" bind:value={notes} />
		</label>
		<div class="paypal-actions">
			<button type="submit" class="btn btn-primary" disabled={paypalSubmitting}>
				{paypalSubmitting ? 'Creating…' : 'Create PayPal link'}
			</button>
			{#if paypalApprovalUrl}
				<button type="button" class="btn btn-secondary" onclick={openPayPal}>
					Open PayPal for customer
				</button>
				{#if paypalOrderId}
					<button
						type="button"
						class="btn btn-secondary"
						disabled={captureSubmitting === paypalOrderId}
						onclick={() => capturePending(paypalOrderId!)}
					>
						{captureSubmitting === paypalOrderId ? 'Capturing…' : 'Capture payment'}
					</button>
				{/if}
			{/if}
		</div>
	</form>
	{#if paypalApprovalUrl && paypalAmount != null}
		<p class="paypal-meta">
			Amount: <strong>${paypalAmount.toFixed(2)}</strong>
			{#if paypalOrderId}
				· Order: <code>{paypalOrderId}</code>
			{/if}
		</p>
	{/if}
</section>

{#if pending.length > 0}
	<section class="form-card" style="margin-top: 1rem;">
		<h2 class="form-section-title">Awaiting capture</h2>
		<table class="data-table">
			<thead>
				<tr>
					<th>Created</th>
					<th>Purchaser</th>
					<th>Size</th>
					<th>Qty</th>
					<th>Amount</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each pending as p}
					<tr>
						<td>{p.created_at ? formatDateTimeLocal(p.created_at) : '—'}</td>
						<td>{p.purchaser_name ?? '—'}</td>
						<td>{p.shirt_size ?? '—'}</td>
						<td>{p.quantity ?? '—'}</td>
						<td>${p.amount.toFixed(2)}</td>
						<td>
							<button
								type="button"
								class="btn btn-primary btn-sm"
								disabled={captureSubmitting === p.paypal_order_id}
								onclick={() => capturePending(p.paypal_order_id)}
							>
								{captureSubmitting === p.paypal_order_id ? '…' : 'Capture'}
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</section>
{/if}

<section class="form-card" style="margin-top: 1.5rem;">
	<h2 class="form-section-title">Record manual sale</h2>
	<p class="section-hint">Cash, card terminal, or other POS — no PayPal link.</p>
	<form class="create-form-grid" onsubmit={handleAdd}>
		<label>
			Purchaser name
			<input type="text" bind:value={purchaserName} required />
		</label>
		<label>
			Size
			<select bind:value={shirtSize}>
				{#each sizes as s}
					<option value={s}>{s}</option>
				{/each}
			</select>
		</label>
		<label>
			Quantity
			<input type="number" min="1" bind:value={quantity} />
		</label>
		<label>
			Unit price ($)
			<input type="number" min="0" step="0.01" bind:value={unitPrice} />
		</label>
		<label class="span2">
			Notes
			<input type="text" bind:value={notes} />
		</label>
		<button type="submit" class="btn btn-secondary" disabled={submitting}>
			{submitting ? 'Saving…' : 'Add manual sale'}
		</button>
	</form>
</section>

{#if loading}
	<p>Loading…</p>
{:else if orders.length === 0}
	<p class="chart-empty">No shirt orders yet.</p>
{:else}
	<table class="data-table" style="margin-top: 1.5rem;">
		<thead>
			<tr>
				<th>Date</th>
				<th>Purchaser</th>
				{#if !filterEventId}
					<th>Event</th>
				{/if}
				<th>Size</th>
				<th>Qty</th>
				<th>Unit $</th>
				<th>Payment</th>
				<th></th>
			</tr>
		</thead>
		<tbody>
			{#each orders as o}
				<tr>
					<td>{o.created_at ? formatDateLocal(o.created_at) : '—'}</td>
					<td>{o.purchaser_name}</td>
					{#if !filterEventId}
						<td>{o.event_name ?? '—'}</td>
					{/if}
					<td>{o.shirt_size}</td>
					<td>{o.quantity}</td>
					<td>${o.unit_price.toFixed(2)}</td>
					<td>{o.paypal_order_id ? 'PayPal' : 'Manual'}</td>
					<td>
						<button type="button" class="btn btn-secondary btn-sm" onclick={() => removeOrder(o.id)}>
							Delete
						</button>
					</td>
				</tr>
			{/each}
		</tbody>
	</table>
{/if}

<style>
	.create-form-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
		gap: 1rem;
		align-items: end;
	}
	.create-form-grid label {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		font-size: 0.85rem;
	}
	.span2 {
		grid-column: span 2;
	}
	.paypal-actions {
		grid-column: 1 / -1;
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		align-items: center;
	}
	.section-hint {
		margin: 0 0 1rem;
		color: #64748b;
		font-size: 0.9rem;
	}
	.paypal-meta {
		margin: 0.75rem 0 0;
		font-size: 0.9rem;
		color: #475569;
	}
	.paypal-meta code {
		font-size: 0.8rem;
	}
	.success-msg {
		color: #16a34a;
	}
	.error-msg {
		color: #dc2626;
	}
</style>

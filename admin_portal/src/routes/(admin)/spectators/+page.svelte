<script lang="ts">
	import { onMount, tick } from 'svelte';
	import {
		fetchTickets,
		scanTicket,
		undoScanTicket,
		type SpectatorTicketBase,
		type ScanTicketResponse
	} from '$lib/api/tickets';
	import { fetchEvents } from '$lib/api/events';

	let loading = true;
	let error: string | null = null;
	let tickets: SpectatorTicketBase[] = [];
	let events: { id: string; name: string }[] = [];
	let filterEventId = '';
	let filterUsed: '' | 'true' | 'false' = '';
	let searchQuery = '';

	let undoingCode: string | null = null;
	let scanCode = '';
	let scanLoading = false;
	let scanResult: {
		ok: boolean;
		ticket?: SpectatorTicketBase;
		error?: string;
		used_at?: string | null;
		source?: 'scan' | 'undo';
	} | null = null;
	let scanInput: HTMLInputElement | undefined;

	/* Camera scan */
	let cameraScanOpen = false;
	let cameraError: string | null = null;
	let qrScanner: import('qr-scanner').default | null = null;
	let videoEl: HTMLVideoElement | undefined;

	$: dayPassesSold = tickets.filter((t) => t.ticket_type === 'single_day').length;
	$: weekendPassesSold = tickets.filter((t) => t.ticket_type === 'weekend').length;

	async function loadEvents() {
		const res = await fetchEvents(1, 200);
		if (res.ok && res.data?.events) {
			events = res.data.events.map((e) => ({ id: e.id, name: e.name }));
		}
	}

	async function load() {
		loading = true;
		error = null;
		const eventId = filterEventId && filterEventId !== '' ? filterEventId : null;
		const used = filterUsed === '' ? null : filterUsed === 'true';
		const res = await fetchTickets(eventId, used);
		loading = false;
		if (!res.ok) {
			error = res.error ?? 'Failed to load tickets';
			tickets = [];
			return;
		}
		tickets = res.data ?? [];
	}

	function extractTicketCode(qrContent: string): string {
		const s = qrContent.trim();
		if (s.startsWith('http://') || s.startsWith('https://')) {
			try {
				const url = new URL(s);
				const codeParam = url.searchParams.get('code') ?? url.searchParams.get('ticket_code');
				if (codeParam) return codeParam.trim();
				const segs = url.pathname.split('/').filter(Boolean);
				if (segs.length > 0) return segs[segs.length - 1];
			} catch {
				/* fall through */
			}
		}
		return s;
	}

	async function handleScan(codeOverride?: string) {
		const code = (codeOverride ?? scanCode).trim();
		if (!code) return;
		scanLoading = true;
		scanResult = null;
		try {
			const res = await scanTicket(code);
			const data = res.data as ScanTicketResponse | null | undefined;
			if (res.ok && data && data.success === true) {
				scanResult = { ok: true, ticket: data.ticket, source: 'scan' };
				scanCode = '';
				load();
				closeCameraScan();
			} else if (res.ok && data && data.success === false) {
				scanResult = { ok: false, error: data.error, used_at: data.used_at ?? undefined };
				qrScanner?.start();
			} else {
				scanResult = { ok: false, error: res.error ?? 'Scan failed' };
				qrScanner?.start();
			}
		} catch (e) {
			scanResult = {
				ok: false,
				error:
					e instanceof Error
						? e.message
						: 'Request failed (network or CORS). Check API URL and server CORS for your origin.'
			};
			qrScanner?.start();
		} finally {
			scanLoading = false;
		}
	}

	async function openCameraScan() {
		cameraError = null;
		cameraScanOpen = true;
		scanResult = null;
		await tick();
		if (!videoEl || !cameraScanOpen) return;
		try {
			const QrScanner = (await import('qr-scanner')).default;
			const hasCam = await QrScanner.hasCamera();
			if (!hasCam) {
				cameraError = 'No camera found on this device.';
				return;
			}
			qrScanner = new QrScanner(
				videoEl,
				(result) => {
					if (scanLoading) return;
					const code = extractTicketCode(result.data);
					if (!code) return;
					qrScanner?.pause();
					handleScan(code);
				},
				{
					returnDetailedScanResult: true,
					preferredCamera: 'environment',
					highlightScanRegion: true
				}
			);
			await qrScanner.start();
		} catch (e) {
			cameraError =
				e instanceof Error ? e.message : 'Failed to start camera. Ensure you have granted permission.';
		}
	}

	function closeCameraScan() {
		cameraScanOpen = false;
		cameraError = null;
		if (qrScanner) {
			qrScanner.stop();
			qrScanner.destroy();
			qrScanner = null;
		}
	}

	function handleCameraKeydown(e: KeyboardEvent) {
		if (cameraScanOpen && e.key === 'Escape') closeCameraScan();
	}

	function formatDate(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' });
	}

	function ticketTypeLabel(t: SpectatorTicketBase): string {
		return t.ticket_type === 'weekend' ? 'Weekend' : 'Single day';
	}

	function purchaserDisplay(t: SpectatorTicketBase): string {
		const r = t.racer;
		if (r && typeof r === 'object') {
			const full = (r.full_name ?? '').toString().trim();
			const first = (r.first_name ?? '').toString().trim();
			const last = (r.last_name ?? '').toString().trim();
			const fromParts = [first, last].filter(Boolean).join(' ').trim();
			if (full || fromParts) return full || fromParts;
		}
		return t.purchaser_name ?? '—';
	}

	function onTicketClick(t: SpectatorTicketBase) {
		scanCode = t.ticket_code;
		scanResult = null;
		setTimeout(() => scanInput?.focus(), 0);
	}

	async function handleUndo(t: SpectatorTicketBase, e: Event) {
		e.preventDefault();
		e.stopPropagation();
		if (!confirm('Are you sure you want to undo this scan? The ticket will be marked as unused.')) {
			return;
		}
		const code = t.ticket_code;
		undoingCode = code;
		scanResult = null;
		try {
			const res = await undoScanTicket(code);
			const data = res.data as ScanTicketResponse | null | undefined;
			if (res.ok && data && data.success === true) {
				scanResult = { ok: true, ticket: data.ticket, source: 'undo' };
				load();
			} else if (res.ok && data && data.success === false) {
				scanResult = { ok: false, error: data.error };
			} else {
				scanResult = { ok: false, error: res.error ?? 'Undo failed' };
			}
		} catch (err) {
			scanResult = {
				ok: false,
				error: err instanceof Error ? err.message : 'Request failed.'
			};
		} finally {
			undoingCode = null;
		}
	}

	function matchesSearch(t: SpectatorTicketBase, q: string): boolean {
		const s = q.trim().toLowerCase();
		if (!s) return true;
		const name = purchaserDisplay(t).toLowerCase();
		const phone = (t.purchaser_phone ?? '').replace(/\D/g, '');
		const phoneQuery = s.replace(/\D/g, '');
		const code = (t.ticket_code ?? '').toLowerCase();
		return name.includes(s) || code.includes(s) || (phoneQuery.length > 0 && phone.includes(phoneQuery));
	}

	$: filteredTickets = searchQuery.trim() === '' ? tickets : tickets.filter((t) => matchesSearch(t, searchQuery));

	onMount(async () => {
		await loadEvents();
		await load();
	});
</script>

<div class="page-header">
	<h1 class="page-title">Spectators & tickets</h1>
	<p class="page-subtitle">Pass sales and scan spectator tickets.</p>
</div>

<div class="stats-grid spectators-stats">
	<div class="stat-card">
		<div class="value">{dayPassesSold}</div>
		<div class="label">Day passes sold</div>
	</div>
	<div class="stat-card">
		<div class="value">{weekendPassesSold}</div>
		<div class="label">Weekend passes sold</div>
	</div>
</div>

<div class="scan-section">
	<h2 class="section-title">Scan ticket</h2>
	<div class="scan-row">
		<input
			type="text"
			class="scan-input"
			placeholder="Enter ticket code"
			bind:value={scanCode}
			bind:this={scanInput}
			onkeydown={(e) => e.key === 'Enter' && handleScan()}
		/>
		<button
			type="button"
			class="btn btn-primary"
			onclick={() => handleScan()}
			disabled={scanLoading || !scanCode.trim()}
		>
			{scanLoading ? 'Scanning…' : 'Scan'}
		</button>
		<button
			type="button"
			class="btn btn-secondary"
			onclick={openCameraScan}
			disabled={scanLoading}
			title="Open camera to scan QR code"
		>
			📷 Scan with camera
		</button>
	</div>
	{#if scanResult}
		{#if scanResult.ok && scanResult.ticket}
			{@const ticket = scanResult.ticket}
			<div class="scan-result scan-result-success">
				<div class="scan-result-title">
					{scanResult.source === 'undo' ? 'Scan undone' : 'Ticket scanned successfully'}
				</div>
				<dl class="scan-result-dl">
					<dt>Purchaser</dt>
					<dd>{purchaserDisplay(ticket)}</dd>
					<dt>Type</dt>
					<dd>{ticketTypeLabel(ticket)}</dd>
					<dt>Event</dt>
					<dd>{events.find((e) => e.id === ticket.event)?.name ?? ticket.event}</dd>
					<dt>Code</dt>
					<dd><code class="code-cell">{ticket.ticket_code}</code></dd>
				</dl>
			</div>
		{:else}
			{@const sr = scanResult}
			<div class="scan-result scan-result-error">
				{sr.error ?? 'Scan failed'}
				{#if sr.used_at != null}
					<div class="scan-result-used-at">Used at: {formatDate(sr.used_at)}</div>
				{/if}
			</div>
		{/if}
	{/if}
</div>

<svelte:window onkeydown={handleCameraKeydown} />

{#if cameraScanOpen}
	<div class="camera-scan-overlay" role="dialog" aria-modal="true" aria-labelledby="camera-scan-title">
		<div class="camera-scan-modal">
			<div class="camera-scan-header">
				<h2 id="camera-scan-title" class="camera-scan-title">Scan ticket QR code</h2>
				<button
					type="button"
					class="camera-scan-close"
					aria-label="Close camera"
					onclick={closeCameraScan}
				>
					✕
				</button>
			</div>
			<div class="camera-scan-body">
				{#if cameraError}
					<div class="camera-error">
						{cameraError}
					</div>
					<p class="camera-error-hint">Make sure you have granted camera permission and that the page is served over HTTPS (or localhost).</p>
				{:else}
					<div class="camera-video-wrap">
						<video bind:this={videoEl} muted playsinline class="camera-video"></video>
					</div>
					<p class="camera-hint">Point your camera at the ticket QR code</p>
				{/if}
			</div>
		</div>
	</div>
{/if}

<div class="filters-row">
	<label for="search-tickets">Search</label>
	<input
		id="search-tickets"
		type="search"
		class="search-input"
		placeholder="Phone, name, or code…"
		bind:value={searchQuery}
	/>
	<label for="filter-event">Event</label>
	<select id="filter-event" bind:value={filterEventId} onchange={load}>
		<option value="">All events</option>
		{#each events as ev}
			<option value={ev.id}>{ev.name}</option>
		{/each}
	</select>
	<label for="filter-used">Status</label>
	<select id="filter-used" bind:value={filterUsed} onchange={load}>
		<option value="">All</option>
		<option value="false">Unused</option>
		<option value="true">Used</option>
	</select>
	<button type="button" class="btn btn-secondary btn-sm" onclick={load} disabled={loading}>
		Refresh
	</button>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if tickets.length === 0}
	<div class="data-table-wrap">
		<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
			No tickets found.
		</div>
	</div>
{:else if filteredTickets.length === 0}
	<div class="data-table-wrap">
		<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
			No tickets match "{searchQuery.trim()}".
		</div>
	</div>
{:else}
	<div class="data-table-wrap">
		<table class="data-table">
			<thead>
				<tr>
					<th>Code</th>
					<th>Type</th>
					<th>Purchaser</th>
					<th>Phone</th>
					<th>Event</th>
					<th class="center">Used</th>
					<th>Used at</th>
					<th>Created</th>
					<th class="actions-col">Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each filteredTickets as t}
					<tr
						role="button"
						tabindex="0"
						class="ticket-row-clickable"
						onclick={() => onTicketClick(t)}
						onkeydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), onTicketClick(t))}
					>
						<td data-label="Code"><code class="code-cell">{t.ticket_code}</code></td>
						<td data-label="Type">{ticketTypeLabel(t)}</td>
						<td data-label="Purchaser">{purchaserDisplay(t)}</td>
						<td data-label="Phone">{t.purchaser_phone ?? '—'}</td>
						<td data-label="Event">{events.find((e) => e.id === t.event)?.name ?? t.event}</td>
						<td class="center" data-label="Used">{t.is_used ? 'Yes' : 'No'}</td>
						<td data-label="Used at">{formatDate(t.used_at)}</td>
						<td data-label="Created">{formatDate(t.created_at)}</td>
						<td class="actions-col" data-label="Actions" onclick={(e) => e.stopPropagation()}>
							{#if t.is_used}
								<button
									type="button"
									class="btn btn-secondary btn-sm"
									disabled={undoingCode === t.ticket_code}
									onclick={(e) => handleUndo(t, e)}
								>
									{undoingCode === t.ticket_code ? 'Undoing…' : 'Undo'}
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
	.spectators-stats {
		margin-bottom: 1.5rem;
	}
	.scan-section {
		margin-bottom: 1.5rem;
		padding: 1rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.section-title {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 0.75rem 0;
		color: var(--text);
	}
	.scan-row {
		display: flex;
		gap: 0.75rem;
		align-items: center;
		flex-wrap: wrap;
	}
	.scan-input {
		min-width: 220px;
		padding: 0.5rem 0.75rem;
		font-size: 1rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg);
		color: var(--text);
	}
	.scan-result {
		margin-top: 0.75rem;
		padding: 0.75rem 1rem;
		border-radius: var(--radius);
		font-size: 0.95rem;
	}
	.scan-result-success {
		background: var(--bg-muted);
		color: var(--text);
		border: 1px solid var(--border);
	}
	.scan-result-title {
		font-weight: 600;
		margin-bottom: 0.5rem;
		color: var(--primary);
	}
	.scan-result-dl {
		display: grid;
		grid-template-columns: auto 1fr;
		gap: 0.25rem 1rem;
		margin: 0;
		font-size: 0.9rem;
	}
	.scan-result-dl dt {
		color: var(--text-muted);
		font-weight: 500;
	}
	.scan-result-dl dd {
		margin: 0;
	}
	.scan-result-error {
		background: rgba(200, 60, 60, 0.15);
		color: var(--text);
		border: 1px solid rgba(200, 60, 60, 0.3);
	}
	.scan-result-used-at {
		margin-top: 0.35rem;
		font-size: 0.9em;
		opacity: 0.95;
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
	.search-input {
		min-width: 200px;
		padding: 0.4rem 0.6rem;
		font-size: 0.9rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg-card);
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
	.ticket-row-clickable {
		cursor: pointer;
		transition: background 0.15s;
	}
	.ticket-row-clickable:hover {
		background: var(--bg-muted);
	}
	.ticket-row-clickable:focus {
		outline: none;
		box-shadow: inset 0 0 0 2px var(--primary);
	}
	.actions-col {
		white-space: nowrap;
	}
	.actions-col button {
		margin: 0;
	}

	.camera-scan-overlay {
		position: fixed;
		inset: 0;
		z-index: 10000;
		background: rgba(0, 0, 0, 0.85);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	.camera-scan-modal {
		background: var(--bg-card);
		border-radius: var(--radius);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
		max-width: 100%;
		width: 100%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}
	.camera-scan-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
		border-bottom: 1px solid var(--border);
	}
	.camera-scan-title {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 600;
		color: var(--text);
	}
	.camera-scan-close {
		width: 2.5rem;
		height: 2.5rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		font-size: 1.25rem;
		cursor: pointer;
		color: var(--text-muted);
		transition: background 0.15s, color 0.15s;
	}
	.camera-scan-close:hover {
		background: var(--bg-muted);
		color: var(--text);
	}
	.camera-scan-body {
		padding: 1.25rem;
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		min-height: 200px;
	}
	.camera-video-wrap {
		position: relative;
		width: 100%;
		max-width: 400px;
		aspect-ratio: 1;
		background: #000;
		border-radius: var(--radius);
		overflow: hidden;
	}
	.camera-video {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.camera-hint {
		margin: 1rem 0 0;
		font-size: 0.95rem;
		color: var(--text-muted);
	}
	.camera-error {
		padding: 1.5rem;
		background: rgba(200, 60, 60, 0.1);
		border: 1px solid rgba(200, 60, 60, 0.3);
		border-radius: var(--radius);
		color: var(--error);
		font-weight: 500;
		text-align: center;
	}
	.camera-error-hint {
		margin: 1rem 0 0;
		font-size: 0.9rem;
		color: var(--text-muted);
		text-align: center;
		max-width: 320px;
	}
</style>

<script lang="ts">
	import { onMount, tick } from 'svelte';
	import {
		captureSpectatorPayPalCheckout,
		createComplimentarySpectatorTicket,
		createSpectatorPayPalCheckout,
		fetchPendingSpectatorCheckouts,
		fetchTickets,
		resendTicketEmail,
		scanTicket,
		undoScanTicket,
		type AttendeeCategory,
		type ScanTicketResponse,
		type SpectatorPayPalPending,
		type SpectatorTicketBase
	} from '$lib/api/tickets';
	import { fetchEvents } from '$lib/api/events';
	import { fetchHydroDragsConfig } from '$lib/api/hydrodrags';
	import { toast } from '$lib/stores/toast';
	import { formatDateTimeLocal, isRecentPayPalPending } from '$lib/format/datetime';

	let loading = true;
	let error: string | null = null;
	let tickets: SpectatorTicketBase[] = [];
	let events: { id: string; name: string }[] = [];
	let filterEventId = '';
	let filterAttendeeCategory: '' | 'spectator' | 'vendor' | 'sponsor' | 'vip' = '';
	let filterUsed: '' | 'true' | 'false' = 'false';
	let searchQuery = '';

	let undoingCode: string | null = null;
	let resendingCode: string | null = null;
	let resendNotice: { ok: boolean; text: string } | null = null;
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

	/* Create ticket modal */
	type CreateMode = 'complimentary' | 'paypal';
	let createMode: CreateMode = 'complimentary';
	let createTicketType: 'single_day' | 'weekend' = 'single_day';
	let createAttendeeCategory: AttendeeCategory = 'spectator';
	let createQuantity = 1;
	let createDayPasses = 0;
	let createWeekendPasses = 0;
	let createPurchaserName = '';
	let createPurchaserPhone = '';
	let createPurchaserEmail = '';
	let createSendEmail = true;
	let createSubmitting = false;
	let createMessage: { ok: boolean; text: string } | null = null;
	let createModalOpen = false;
	let createFlash: { ok: boolean; text: string } | null = null;
	let dayPassPrice = 0;
	let weekendPassPrice = 0;
	let paypalApprovalUrl: string | null = null;
	let paypalOrderId: string | null = null;
	let paypalAmount: number | null = null;
	let paypalPending: SpectatorPayPalPending[] = [];
	let captureSubmitting: string | null = null;
	/** Email QR tickets when capturing from the main pending list (office verification flow). */
	let pendingCaptureSendEmail = true;
	let staffVerifiedFinalize = false;

	/* Camera scan */
	let cameraScanOpen = false;
	let cameraError: string | null = null;
	let qrScanner: import('qr-scanner').default | null = null;
	let videoEl: HTMLVideoElement | undefined;

	$: dayPassesSold = tickets.filter(
		(t) => t.ticket_type === 'single_day' && (t.attendee_category ?? 'spectator') === 'spectator'
	).length;
	$: weekendPassesSold = tickets.filter(
		(t) => t.ticket_type === 'weekend' && (t.attendee_category ?? 'spectator') === 'spectator'
	).length;

	async function loadEvents() {
		const res = await fetchEvents(1, 200);
		if (res.ok && res.data?.events) {
			events = res.data.events.map((e) => ({ id: e.id, name: e.name }));
		}
	}

	async function handleCreateTicket(e: Event) {
		e.preventDefault();
		createMessage = null;
		if (!createPurchaserName.trim()) {
			createMessage = { ok: false, text: 'Enter purchaser name.' };
			return;
		}
		if (createSendEmail && !createPurchaserEmail.trim()) {
			createMessage = { ok: false, text: 'Enter an email address to send the ticket, or turn off “Email ticket to customer”.' };
			return;
		}
		const qty = Math.min(50, Math.max(1, Math.floor(Number(createQuantity)) || 1));
		createSubmitting = true;
		try {
			const res = await createComplimentarySpectatorTicket({
				ticket_type: createTicketType,
				quantity: qty,
				purchaser_name: createPurchaserName.trim(),
				purchaser_phone: createPurchaserPhone.trim() || null,
				purchaser_email: createPurchaserEmail.trim() || null,
				send_email: createSendEmail,
				attendee_category: createAttendeeCategory,
				...(filterEventId ? { event_id: filterEventId } : {})
			});
			if (res.ok && res.data) {
				const codes = res.data.tickets.map((t) => t.ticket_code);
				const n = codes.length;
				const codesSummary =
					n <= 6
						? codes.join(', ')
						: `${codes.slice(0, 4).join(', ')} and ${n - 4} more`;
				const parts = [
					`${n} ticket${n === 1 ? '' : 's'} created (codes: ${codesSummary}).`,
					res.data.email_sent
						? 'Confirmation email sent with all QR attachments.'
						: createSendEmail && res.data.email_error
							? `Email could not be sent: ${res.data.email_error}`
							: createSendEmail
								? 'Email was not sent.'
								: ''
				].filter(Boolean);
				createFlash = { ok: true, text: parts.join(' ') };
				createPurchaserName = '';
				createPurchaserPhone = '';
				createPurchaserEmail = '';
				createQuantity = 1;
				closeCreateModal();
				load();
			} else {
				createMessage = { ok: false, text: res.error ?? 'Failed to create ticket.' };
			}
		} catch (err) {
			createMessage = {
				ok: false,
				text: err instanceof Error ? err.message : 'Request failed.'
			};
		} finally {
			createSubmitting = false;
		}
	}

	function resetPaypalSession() {
		paypalApprovalUrl = null;
		paypalOrderId = null;
		paypalAmount = null;
	}

	function setCreateMode(mode: CreateMode) {
		createMode = mode;
		createMessage = null;
		resetPaypalSession();
	}

	async function openCreateModal() {
		createModalOpen = true;
		createMessage = null;
		createFlash = null;
		resetPaypalSession();
		await loadPendingPaypal();
	}

	function closeCreateModal() {
		createModalOpen = false;
		createMessage = null;
		resetPaypalSession();
	}

	function handleGlobalKeydown(e: KeyboardEvent) {
		if (e.key !== 'Escape') return;
		if (cameraScanOpen) closeCameraScan();
		else if (createModalOpen) closeCreateModal();
	}

	async function loadPendingPaypal() {
		// Always load all pending spectator checkouts (not scoped to ticket list event filter).
		const res = await fetchPendingSpectatorCheckouts(null);
		paypalPending = (res.ok && res.data ? res.data : []).filter((p) =>
			isRecentPayPalPending(p.created_at)
		);
	}

	async function load() {
		loading = true;
		error = null;
		const eventId = filterEventId && filterEventId !== '' ? filterEventId : null;
		const used = filterUsed === '' ? null : filterUsed === 'true';
		const cat = filterAttendeeCategory || null;
		const [ticketsRes] = await Promise.all([
			fetchTickets(eventId, used, cat),
			loadPendingPaypal()
		]);
		loading = false;
		if (!ticketsRes.ok) {
			error = ticketsRes.error ?? 'Failed to load tickets';
			tickets = [];
			return;
		}
		tickets = ticketsRes.data ?? [];
	}

	$: paypalLineTotal =
		createDayPasses * dayPassPrice + createWeekendPasses * weekendPassPrice;

	async function handlePayPalCheckout(e: Event) {
		e.preventDefault();
		createMessage = null;
		if (!createPurchaserName.trim()) {
			createMessage = { ok: false, text: 'Enter purchaser name.' };
			return;
		}
		const day = Math.max(0, Math.floor(Number(createDayPasses)) || 0);
		const weekend = Math.max(0, Math.floor(Number(createWeekendPasses)) || 0);
		if (day + weekend < 1) {
			createMessage = { ok: false, text: 'Select at least one pass.' };
			return;
		}
		if (createSendEmail && !createPurchaserEmail.trim()) {
			createMessage = {
				ok: false,
				text: 'Enter an email to send tickets after capture, or turn off email.'
			};
			return;
		}
		createSubmitting = true;
		resetPaypalSession();
		try {
			const res = await createSpectatorPayPalCheckout({
				purchaser_name: createPurchaserName.trim(),
				purchaser_phone: createPurchaserPhone.trim() || null,
				purchaser_email: createPurchaserEmail.trim() || null,
				spectator_single_day_passes: day,
				spectator_weekend_passes: weekend,
				attendee_category: createAttendeeCategory,
				...(filterEventId ? { event_id: filterEventId } : {})
			});
			if (!res.ok || !res.data) {
				createMessage = { ok: false, text: res.error ?? 'Failed to create PayPal checkout' };
				return;
			}
			paypalApprovalUrl = res.data.approval_url;
			paypalOrderId = res.data.paypal_order_id;
			paypalAmount = res.data.amount;
			createMessage = {
				ok: true,
				text: 'Payment link ready. Open PayPal for the customer, then capture after they pay.'
			};
			await loadPendingPaypal();
		} catch (err) {
			createMessage = {
				ok: false,
				text: err instanceof Error ? err.message : 'Request failed.'
			};
		} finally {
			createSubmitting = false;
		}
	}

	function openPayPal() {
		if (paypalApprovalUrl) {
			window.open(paypalApprovalUrl, '_blank', 'noopener,noreferrer');
		}
	}

	function formatMoney(amount: number): string {
		return `$${Number(amount ?? 0).toFixed(2)}`;
	}

	function pendingPassSummary(p: SpectatorPayPalPending): string {
		const parts: string[] = [];
		if (p.spectator_single_day_passes > 0) {
			parts.push(`${p.spectator_single_day_passes} day`);
		}
		if (p.spectator_weekend_passes > 0) {
			parts.push(`${p.spectator_weekend_passes} weekend`);
		}
		return parts.length ? parts.join(', ') : '—';
	}

	async function capturePending(
		orderId: string,
		opts?: { inModal?: boolean; staffVerified?: boolean }
	) {
		const row = paypalPending.find((p) => p.paypal_order_id === orderId);
		const sendEmail = opts?.inModal ? createSendEmail : pendingCaptureSendEmail;
		const staffVerified = opts?.staffVerified ?? staffVerifiedFinalize;
		const who = row?.purchaser_name?.trim() || 'Purchaser';
		const amount = row ? formatMoney(row.amount) : '';
		const passes = row ? pendingPassSummary(row) : '';

		const confirmed = confirm(
			(staffVerified
				? `Issue tickets without PayPal capture?\n\nUse this only when staff verified payment on the customer's device but PayPal cannot capture order ${orderId}.`
				: `Payment verified on the customer's device?\n\nApprove and capture PayPal order ${orderId}`) +
				(amount ? ` for ${who} (${amount})` : ` for ${who}`) +
				(passes && passes !== '—' ? ` — ${passes}` : '') +
				'.\n\nThis issues ticket QR code(s) in the system.' +
				(sendEmail ? '\n\nAn email with QR codes will be sent to the purchaser.' : '')
		);
		if (!confirmed) return;

		captureSubmitting = orderId;
		if (opts?.inModal) createMessage = null;
		try {
			const res = await captureSpectatorPayPalCheckout({
				paypal_order_id: orderId,
				send_email: sendEmail,
				staff_verified: staffVerified
			});
			if (!res.ok || !res.data) {
				const errText = res.error ?? 'Capture failed';
				if (
					!staffVerified &&
					/not found|staff-verified|cannot be captured/i.test(errText) &&
					confirm(
						`${errText}\n\nTry staff-verified finalize? This issues tickets without calling PayPal (use when payment was confirmed on the customer's device).`
					)
				) {
					return capturePending(orderId, { ...opts, staffVerified: true });
				}
				if (opts?.inModal) {
					createMessage = { ok: false, text: errText };
				} else {
					alert(errText);
					toast(errText, 'error');
				}
				return;
			}
			const codes = res.data.tickets.map((t) => t.ticket_code).join(', ');
			let text = `Payment captured. ${res.data.tickets.length} ticket(s): ${codes}.`;
			if (sendEmail) {
				text += res.data.email_sent
					? ' Email sent with QR codes.'
					: res.data.email_error
						? ` Email not sent: ${res.data.email_error}`
						: ' Email not sent.';
			}
			if (opts?.inModal) {
				createMessage = { ok: true, text };
			} else {
				toast(text, 'success');
			}
			if (paypalOrderId === orderId) {
				resetPaypalSession();
			}
			await loadPendingPaypal();
			await load();
		} catch (err) {
			const errText = err instanceof Error ? err.message : 'Capture failed.';
			if (opts?.inModal) {
				createMessage = { ok: false, text: errText };
			} else {
				toast(errText, 'error');
			}
		} finally {
			captureSubmitting = null;
		}
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

	function formatDate(iso: string | null | undefined): string {
		return formatDateTimeLocal(iso);
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

	async function handleResend(t: SpectatorTicketBase, e: Event) {
		e.preventDefault();
		e.stopPropagation();
		resendNotice = null;
		const code = t.ticket_code;
		resendingCode = code;
		try {
			let res = await resendTicketEmail({ ticket_code: code });
			if (
				!res.ok &&
				res.status === 400 &&
				(res.error ?? '').toLowerCase().includes('no email on file')
			) {
				const prompted = window.prompt(
					'No email on file for this ticket. Send QR ticket to:',
					t.purchaser_email?.trim() ?? ''
				);
				const addr = prompted?.trim();
				if (addr) {
					res = await resendTicketEmail({ ticket_code: code, to_email: addr });
				} else {
					resendNotice = { ok: false, text: 'Resend cancelled (no address entered).' };
					return;
				}
			}
			if (!res.ok || !res.data) {
				resendNotice = { ok: false, text: res.error ?? 'Resend failed.' };
				return;
			}
			if (res.data.email_sent) {
				resendNotice = {
					ok: true,
					text: `Email sent to ${res.data.to_email}.`
				};
			} else {
				resendNotice = {
					ok: false,
					text: res.data.email_error
						? `Email not sent: ${res.data.email_error}`
						: 'Email not sent.'
				};
			}
		} catch (err) {
			resendNotice = {
				ok: false,
				text: err instanceof Error ? err.message : 'Request failed.'
			};
		} finally {
			resendingCode = null;
		}
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
		const mail = (t.purchaser_email ?? '').toLowerCase();
		return (
			name.includes(s) ||
			code.includes(s) ||
			mail.includes(s) ||
			(phoneQuery.length > 0 && phone.includes(phoneQuery))
		);
	}

	$: filteredTickets = searchQuery.trim() === '' ? tickets : tickets.filter((t) => matchesSearch(t, searchQuery));

	onMount(async () => {
		const cfgRes = await fetchHydroDragsConfig();
		if (cfgRes.ok && cfgRes.data) {
			dayPassPrice = cfgRes.data.spectator_single_day_price ?? 0;
			weekendPassPrice = cfgRes.data.spectator_weekend_price ?? 0;
		}
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

{#if paypalPending.length > 0}
	<section class="pending-paypal-section">
		<h2 class="pending-paypal-title">Spectator tickets awaiting approval</h2>
		<p class="pending-paypal-hint">
			Customer paid in PayPal on their phone but did not finish in the app. After staff verifies
			payment on the device, click <strong>Approve &amp; issue tickets</strong> to capture and create
			QR passes. Only checkouts from the last 3 hours are shown (PayPal approval window).
		</p>
		<label class="pending-email-option">
			<input type="checkbox" bind:checked={pendingCaptureSendEmail} disabled={captureSubmitting !== null} />
			Email QR tickets to purchaser after approval
		</label>
		<label class="pending-email-option">
			<input type="checkbox" bind:checked={staffVerifiedFinalize} disabled={captureSubmitting !== null} />
			Payment verified on device — issue tickets without PayPal capture (use if Approve fails with order not found)
		</label>
		<table class="data-table pending-paypal-table">
			<thead>
				<tr>
					<th>Created</th>
					<th>Source</th>
					<th>Purchaser</th>
					<th>Passes</th>
					<th>Amount</th>
					<th>PayPal order</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each paypalPending as p (p.paypal_order_id)}
					<tr>
						<td>{p.created_at ? formatDate(p.created_at) : '—'}</td>
						<td>{p.source === 'mobile' ? 'App' : 'Admin'}</td>
						<td>
							{p.purchaser_name ?? '—'}
							{#if p.purchaser_email}
								<div class="pending-email">{p.purchaser_email}</div>
							{/if}
						</td>
						<td>{pendingPassSummary(p)}</td>
						<td>{formatMoney(p.amount)}</td>
						<td><code class="code-cell">{p.paypal_order_id}</code></td>
						<td class="pending-actions">
							<button
								type="button"
								class="btn btn-primary btn-sm"
								disabled={captureSubmitting === p.paypal_order_id}
								onclick={() => void capturePending(p.paypal_order_id)}
							>
								{captureSubmitting === p.paypal_order_id
									? 'Approving…'
									: 'Approve & issue tickets'}
							</button>
							<button
								type="button"
								class="btn btn-secondary btn-sm"
								disabled={captureSubmitting === p.paypal_order_id}
								onclick={() =>
									void capturePending(p.paypal_order_id, { staffVerified: true })}
								title="Payment confirmed on customer's device; skip PayPal capture"
							>
								Staff verified
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</section>
{/if}

<div class="scan-section">
	<div class="scan-section-header">
		<h2 class="section-title scan-section-title">Scan ticket</h2>
		<button type="button" class="btn btn-primary" onclick={openCreateModal}>
			Create ticket
			{#if paypalPending.length > 0}
				<span class="pending-badge">{paypalPending.length} pending</span>
			{/if}
		</button>
	</div>
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

{#if createFlash}
	<div
		class="create-flash"
		class:create-flash--ok={createFlash.ok}
		class:create-flash--err={!createFlash.ok}
	>
		{createFlash.text}
		<button type="button" class="create-flash-dismiss" onclick={() => (createFlash = null)} aria-label="Dismiss">
			✕
		</button>
	</div>
{/if}

<svelte:window onkeydown={handleGlobalKeydown} />

{#if createModalOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div
		class="create-ticket-overlay"
		role="presentation"
		onclick={closeCreateModal}
	>
		<div
			class="create-ticket-modal"
			role="dialog"
			aria-modal="true"
			aria-labelledby="create-ticket-title"
			tabindex="-1"
			onclick={(e) => e.stopPropagation()}
		>
			<div class="create-ticket-header">
				<h2 id="create-ticket-title" class="create-ticket-title">Create ticket</h2>
				<button
					type="button"
					class="create-ticket-close"
					aria-label="Close"
					onclick={closeCreateModal}
				>
					✕
				</button>
			</div>
			<div class="create-ticket-body">
				<div class="create-mode-tabs" role="tablist" aria-label="Ticket sale type">
					<button
						type="button"
						role="tab"
						aria-selected={createMode === 'complimentary'}
						class="create-mode-tab"
						class:create-mode-tab--active={createMode === 'complimentary'}
						onclick={() => setCreateMode('complimentary')}
					>
						Complimentary
					</button>
					<button
						type="button"
						role="tab"
						aria-selected={createMode === 'paypal'}
						class="create-mode-tab"
						class:create-mode-tab--active={createMode === 'paypal'}
						onclick={() => setCreateMode('paypal')}
					>
						PayPal
					</button>
				</div>

				{#if createMode === 'complimentary'}
					<p class="section-hint">
						Issue complimentary passes (no purchase). Mobile purchases are always spectator;
						set vendor, sponsor, or VIP here when needed.
					</p>
					<form class="create-form" onsubmit={handleCreateTicket}>
						<div class="create-form-grid">
							<label class="create-field">
								<span class="create-label">Attendee category</span>
								<select bind:value={createAttendeeCategory} class="create-input">
									<option value="spectator">Spectator</option>
									<option value="vendor">Vendor</option>
									<option value="sponsor">Sponsor</option>
									<option value="vip">VIP</option>
								</select>
							</label>
							<label class="create-field">
								<span class="create-label">Pass type</span>
								<select bind:value={createTicketType} class="create-input">
									<option value="single_day">Single day</option>
									<option value="weekend">Weekend</option>
								</select>
							</label>
							<label class="create-field">
								<span class="create-label">Quantity</span>
								<input
									type="number"
									class="create-input"
									min="1"
									max="50"
									step="1"
									bind:value={createQuantity}
								/>
							</label>
							<label class="create-field create-field-span2">
								<span class="create-label">Purchaser name</span>
								<input
									type="text"
									class="create-input"
									autocomplete="name"
									placeholder="Full name"
									bind:value={createPurchaserName}
								/>
							</label>
							<label class="create-field">
								<span class="create-label">Phone <span class="optional">(optional)</span></span>
								<input
									type="tel"
									class="create-input"
									autocomplete="tel"
									placeholder="—"
									bind:value={createPurchaserPhone}
								/>
							</label>
							<label class="create-field">
								<span class="create-label">Email</span>
								<input
									type="email"
									class="create-input"
									autocomplete="email"
									placeholder="customer@example.com"
									bind:value={createPurchaserEmail}
								/>
							</label>
							<label class="create-checkbox create-field-span2">
								<input type="checkbox" bind:checked={createSendEmail} />
								<span>Email confirmations to this address (all tickets in one email)</span>
							</label>
						</div>
						<div class="create-actions">
							<button type="button" class="btn btn-secondary" onclick={closeCreateModal} disabled={createSubmitting}>
								Cancel
							</button>
							<button type="submit" class="btn btn-primary" disabled={createSubmitting}>
								{createSubmitting ? 'Creating…' : 'Create ticket(s)'}
							</button>
						</div>
					</form>
				{:else}
					<p class="section-hint">
						Day ${dayPassPrice.toFixed(2)}, weekend ${weekendPassPrice.toFixed(2)}. Create a PayPal
						link for the customer, then capture after they pay.
						{#if filterEventId}
							Event filter applies to this sale.
						{/if}
					</p>
					<form class="create-form" onsubmit={handlePayPalCheckout}>
						<div class="create-form-grid">
							<label class="create-field">
								<span class="create-label">Day passes</span>
								<input
									type="number"
									class="create-input"
									min="0"
									max="50"
									bind:value={createDayPasses}
								/>
							</label>
							<label class="create-field">
								<span class="create-label">Weekend passes</span>
								<input
									type="number"
									class="create-input"
									min="0"
									max="50"
									bind:value={createWeekendPasses}
								/>
							</label>
							<label class="create-field">
								<span class="create-label">Attendee category</span>
								<select bind:value={createAttendeeCategory} class="create-input">
									<option value="spectator">Spectator</option>
									<option value="vendor">Vendor</option>
									<option value="sponsor">Sponsor</option>
									<option value="vip">VIP</option>
								</select>
							</label>
							<label class="create-field create-field-span2">
								<span class="create-label">Purchaser name</span>
								<input
									type="text"
									class="create-input"
									autocomplete="name"
									placeholder="Full name"
									bind:value={createPurchaserName}
								/>
							</label>
							<label class="create-field">
								<span class="create-label">Phone <span class="optional">(optional)</span></span>
								<input
									type="tel"
									class="create-input"
									autocomplete="tel"
									placeholder="—"
									bind:value={createPurchaserPhone}
								/>
							</label>
							<label class="create-field">
								<span class="create-label">Email</span>
								<input
									type="email"
									class="create-input"
									autocomplete="email"
									placeholder="customer@example.com"
									bind:value={createPurchaserEmail}
								/>
							</label>
							<label class="create-checkbox create-field-span2">
								<input type="checkbox" bind:checked={createSendEmail} />
								<span>Email QR tickets after capture</span>
							</label>
						</div>
						<p class="paypal-total">
							Estimated total: <strong>${paypalLineTotal.toFixed(2)}</strong>
						</p>
						{#if paypalApprovalUrl && paypalAmount != null}
							<p class="paypal-meta">
								Charge: <strong>${paypalAmount.toFixed(2)}</strong>
								{#if paypalOrderId}
									· <code>{paypalOrderId}</code>
								{/if}
							</p>
						{/if}
						<div class="create-actions create-actions--wrap">
							<button type="button" class="btn btn-secondary" onclick={closeCreateModal} disabled={createSubmitting}>
								Cancel
							</button>
							<button type="submit" class="btn btn-primary" disabled={createSubmitting}>
								{createSubmitting ? 'Creating…' : 'Create PayPal link'}
							</button>
							{#if paypalApprovalUrl}
								<button type="button" class="btn btn-secondary" onclick={openPayPal}>
									Open PayPal
								</button>
								{#if paypalOrderId}
									<button
										type="button"
										class="btn btn-secondary"
										disabled={captureSubmitting === paypalOrderId}
										onclick={() => void capturePending(paypalOrderId!, { inModal: true })}
									>
										{captureSubmitting === paypalOrderId ? 'Capturing…' : 'Capture'}
									</button>
								{/if}
							{/if}
						</div>
					</form>
				{/if}

				{#if createMessage}
					<div
						class="create-feedback"
						class:create-feedback-error={!createMessage.ok}
						class:create-feedback-success={createMessage.ok}
					>
						{createMessage.text}
					</div>
				{/if}

				{#if paypalPending.length > 0}
					<h3 class="subsection-title">Awaiting capture</h3>
					<div class="modal-pending-wrap">
						<table class="data-table modal-pending-table">
							<thead>
								<tr>
									<th>Source</th>
									<th>Purchaser</th>
									<th>Day</th>
									<th>Wknd</th>
									<th>$</th>
									<th></th>
								</tr>
							</thead>
							<tbody>
								{#each paypalPending as p}
									<tr>
										<td>{p.source === 'mobile' ? 'App' : 'Admin'}</td>
										<td>
											{p.purchaser_name ?? '—'}
											{#if p.purchaser_email}
												<div class="pending-email">{p.purchaser_email}</div>
											{/if}
										</td>
										<td>{p.spectator_single_day_passes}</td>
										<td>{p.spectator_weekend_passes}</td>
										<td>{p.amount.toFixed(0)}</td>
										<td>
											<button
												type="button"
												class="btn btn-primary btn-sm"
												disabled={captureSubmitting === p.paypal_order_id}
												onclick={() => void capturePending(p.paypal_order_id, { inModal: true })}
											>
												{captureSubmitting === p.paypal_order_id ? '…' : 'Capture'}
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}

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
		placeholder="Phone, name, email, or code…"
		bind:value={searchQuery}
	/>
	<label for="filter-event">Event</label>
	<select id="filter-event" bind:value={filterEventId} onchange={load}>
		<option value="">All events</option>
		{#each events as ev}
			<option value={ev.id}>{ev.name}</option>
		{/each}
	</select>
	<label for="filter-category">Category</label>
	<select id="filter-category" bind:value={filterAttendeeCategory} onchange={load}>
		<option value="">All categories</option>
		<option value="spectator">Spectators</option>
		<option value="vendor">Vendors</option>
		<option value="sponsor">Sponsors</option>
		<option value="vip">VIP</option>
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

{#if resendNotice}
	<div
		class="resend-notice"
		class:resend-notice--ok={resendNotice.ok}
		class:resend-notice--err={!resendNotice.ok}
	>
		{resendNotice.text}
	</div>
{/if}

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
					<th>Email</th>
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
						<td data-label="Phone">{t.purchaser_phone?.trim() ? t.purchaser_phone : '—'}</td>
						<td data-label="Email">{t.purchaser_email?.trim() ? t.purchaser_email : '—'}</td>
						<td data-label="Event">{events.find((e) => e.id === t.event)?.name ?? t.event ?? '—'}</td>
						<td class="center" data-label="Used">{t.is_used ? 'Yes' : 'No'}</td>
						<td data-label="Used at">{formatDate(t.used_at)}</td>
						<td data-label="Created">{formatDate(t.created_at)}</td>
						<td class="actions-col" data-label="Actions" onclick={(e) => e.stopPropagation()}>
							<div class="action-btns">
								<button
									type="button"
									class="btn btn-secondary btn-sm"
									disabled={resendingCode === t.ticket_code}
									onclick={(e) => handleResend(t, e)}
									title="Resend ticket"
								>
									{resendingCode === t.ticket_code ? 'Sending…' : 'Resend ticket'}
								</button>
								{#if t.is_used}
									<button
										type="button"
										class="btn btn-secondary btn-sm"
										disabled={undoingCode === t.ticket_code}
										onclick={(e) => handleUndo(t, e)}
									>
										{undoingCode === t.ticket_code ? 'Undoing…' : 'Undo scan'}
									</button>
								{/if}
							</div>
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
	.pending-paypal-section {
		margin-bottom: 2rem;
		padding: 1rem 1.25rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.pending-paypal-title {
		font-size: 1.1rem;
		font-weight: 600;
		margin: 0 0 0.35rem 0;
	}
	.pending-paypal-hint {
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
	.pending-paypal-table {
		margin-top: 0.25rem;
	}
	.pending-paypal-table .code-cell {
		font-size: 0.8rem;
		word-break: break-all;
	}
	.pending-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		white-space: nowrap;
	}
	.pending-badge {
		margin-left: 0.35rem;
		font-size: 0.75rem;
		font-weight: 600;
		opacity: 0.9;
	}
	.create-mode-tabs {
		display: flex;
		gap: 0.35rem;
		margin-bottom: 1rem;
		padding: 0.2rem;
		background: var(--bg-muted);
		border-radius: var(--radius);
	}
	.create-mode-tab {
		flex: 1;
		padding: 0.5rem 0.75rem;
		border: none;
		border-radius: calc(var(--radius) - 2px);
		background: transparent;
		color: var(--text-muted);
		font-size: 0.9rem;
		font-weight: 500;
		cursor: pointer;
	}
	.create-mode-tab--active {
		background: var(--bg-card);
		color: var(--text);
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
	}
	.subsection-title {
		font-size: 0.95rem;
		font-weight: 600;
		margin: 1.25rem 0 0.5rem;
	}
	.paypal-total {
		margin: 0.5rem 0 0;
		font-size: 0.9rem;
		color: var(--text-muted);
	}
	.paypal-meta {
		margin: 0.35rem 0 0;
		font-size: 0.85rem;
		color: var(--text-muted);
	}
	.paypal-meta code {
		font-size: 0.75rem;
		word-break: break-all;
	}
	.create-actions--wrap {
		flex-wrap: wrap;
	}
	.modal-pending-wrap {
		overflow-x: auto;
		margin-top: 0.25rem;
	}
	.modal-pending-table {
		font-size: 0.85rem;
	}
	.pending-email {
		font-size: 0.8rem;
		color: var(--text-muted);
		margin-top: 0.15rem;
	}
	.modal-pending-table th,
	.modal-pending-table td {
		padding: 0.35rem 0.5rem;
	}
	.create-flash {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 0.75rem;
		margin-bottom: 1rem;
		padding: 0.65rem 0.85rem;
		border-radius: var(--radius);
		font-size: 0.9rem;
		line-height: 1.4;
	}
	.create-flash--ok {
		background: rgba(40, 140, 80, 0.12);
		border: 1px solid rgba(40, 140, 80, 0.35);
		color: var(--text);
	}
	.create-flash--err {
		background: rgba(200, 60, 60, 0.12);
		border: 1px solid rgba(200, 60, 60, 0.3);
		color: var(--text);
	}
	.create-flash-dismiss {
		flex-shrink: 0;
		width: 1.75rem;
		height: 1.75rem;
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		cursor: pointer;
		color: var(--text-muted);
		font-size: 1rem;
		line-height: 1;
	}
	.create-flash-dismiss:hover {
		background: var(--bg-muted);
		color: var(--text);
	}
	.create-ticket-overlay {
		position: fixed;
		inset: 0;
		z-index: 10000;
		background: rgba(0, 0, 0, 0.85);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	.create-ticket-modal {
		background: var(--bg-card);
		border-radius: var(--radius);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
		width: 100%;
		max-width: 560px;
		max-height: min(90vh, 720px);
		overflow: hidden;
		display: flex;
		flex-direction: column;
		border: 1px solid var(--border);
	}
	.create-ticket-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
		border-bottom: 1px solid var(--border);
		flex-shrink: 0;
	}
	.create-ticket-title {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 600;
		color: var(--text);
	}
	.create-ticket-close {
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
	.create-ticket-close:hover {
		background: var(--bg-muted);
		color: var(--text);
	}
	.create-ticket-body {
		padding: 1rem 1.25rem 1.25rem;
		overflow-y: auto;
	}
	.section-hint {
		margin: 0 0 1rem 0;
		font-size: 0.9rem;
		color: var(--text-muted);
		line-height: 1.45;
	}
	.create-form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem 1rem;
		margin-bottom: 0.75rem;
	}
	@media (max-width: 640px) {
		.create-form-grid {
			grid-template-columns: 1fr;
		}
	}
	.create-field {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
		min-width: 0;
	}
	.create-field-span2 {
		grid-column: 1 / -1;
	}
	.create-label {
		font-size: 0.85rem;
		font-weight: 500;
		color: var(--text);
	}
	.create-label .optional {
		font-weight: 400;
		color: var(--text-muted);
	}
	.create-input {
		padding: 0.5rem 0.75rem;
		font-size: 1rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg);
		color: var(--text);
	}
	.create-checkbox {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.9rem;
		color: var(--text);
		cursor: pointer;
	}
	.create-checkbox input {
		width: 1rem;
		height: 1rem;
		accent-color: var(--primary);
	}
	.create-actions {
		margin-top: 0.25rem;
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		align-items: center;
	}
	.create-feedback {
		margin-top: 0.75rem;
		padding: 0.6rem 0.75rem;
		border-radius: var(--radius);
		font-size: 0.9rem;
	}
	.create-feedback-success {
		background: rgba(40, 140, 80, 0.12);
		border: 1px solid rgba(40, 140, 80, 0.35);
		color: var(--text);
	}
	.create-feedback-error {
		background: rgba(200, 60, 60, 0.12);
		border: 1px solid rgba(200, 60, 60, 0.3);
		color: var(--text);
	}
	.scan-section {
		margin-bottom: 1.5rem;
		padding: 1rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.scan-section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
		flex-wrap: wrap;
		margin-bottom: 0.75rem;
	}
	.scan-section-title {
		margin: 0;
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
	.resend-notice {
		margin-bottom: 1rem;
		padding: 0.65rem 0.85rem;
		border-radius: var(--radius);
		font-size: 0.9rem;
	}
	.resend-notice--ok {
		background: rgba(40, 140, 80, 0.12);
		border: 1px solid rgba(40, 140, 80, 0.35);
		color: var(--text);
	}
	.resend-notice--err {
		background: rgba(200, 60, 60, 0.12);
		border: 1px solid rgba(200, 60, 60, 0.3);
		color: var(--text);
	}
	.actions-col {
		white-space: nowrap;
	}
	.action-btns {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		align-items: center;
		justify-content: flex-end;
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

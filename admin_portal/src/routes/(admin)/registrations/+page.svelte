<script lang="ts">
	import { onMount } from 'svelte';
	import DataTable from '$lib/components/DataTable.svelte';
	import Modal from '$lib/components/Modal.svelte';
	import {
		fetchRegistrations,
		fetchRacer,
		fetchRacers,
		type EventRegistrations,
		type RegistrationRow,
		type RacerRow,
		type RegistrationWithDetail
	} from '$lib/api/resources';
	import { fetchAllEventsForAdmin, type EventBase, type EventClass } from '$lib/api/events';
	import {
		captureAdminRegistrationPayPalCheckout,
		createAdminRegistration,
		createAdminRegistrationPayPalCheckout,
		deleteRegistration,
		fetchPendingAdminRegistrationCheckouts,
		transferRegistration,
		updateRegistration,
		type AdminRegistrationPayPalPending,
		type AdminTransferRegistrationPayload,
		type EventRegistrationAdmin,
		type EventRegistrationAdminUpdate
	} from '$lib/api/registrations';
	import { toast } from '$lib/stores/toast';
	import { formatDateLocal, formatDateTimeLocal, paymentCompletedAt } from '$lib/format/datetime';

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
	/** Watercraft labels from racer.pwc_id on the racer profile. */
	let racerProfilePwcs: string[] = [];
	let editEventId = '';
	let editClassKey = '';
	/** Selected value from racer.pwc_id. */
	let editPwcSelect = '';
	let editFormLoading = false;
	let showDeleteRegModal = false;
	let deleteRegSaving = false;

	// Transfer registration modal
	let showTransferModal = false;
	let transferSaving = false;
	let transferFormLoading = false;
	let transferRacerSearch = '';
	let transferRacerId = '';
	let transferEventId = '';
	let transferClassKey = '';
	let transferPwcId = '';
	let transferSendQrEmail = true;
	let transferProfilePwcs: string[] = [];
	let transferAllRacers: RacerRow[] = [];
	let transferAllEvents: EventBase[] = [];

	// Create registration modal
	let showCreateModal = false;
	let createSaving = false;
	let createFormLoading = false;
	let allEvents: EventBase[] = [];
	let allRacers: RacerRow[] = [];
	let createRacerSearch = '';
	let createEventId = '';
	let createRacerId = '';
	let createPwcId = '';
	let createClassKeys: string[] = [];
	type CreatePaymentMode = 'manual' | 'paypal_link';
	let createPaymentMode: CreatePaymentMode = 'manual';
	let createPaymentMethod: 'complimentary' | 'cash' | 'check' = 'complimentary';
	let createMarkPaid = true;
	let createPromoCode = '';
	let createNotes = '';
	let createSendQrEmail = true;
	let createProfilePwcs: string[] = [];

	let paypalApprovalUrl: string | null = null;
	let paypalOrderId: string | null = null;
	let paypalAmount: number | null = null;
	let paypalSubmitting = false;
	let captureSubmitting: string | null = null;
	let pendingPaypal: AdminRegistrationPayPalPending[] = [];

	const columns: { key: SortKey; label: string; class?: 'num' | 'center'; sortable?: boolean }[] = [
		{ key: 'racer_name', label: 'Racer', sortable: true },
		{ key: 'class_name', label: 'Class', sortable: true },
		{ key: 'status', label: 'Status', sortable: true },
		{ key: 'amount', label: 'Amount', class: 'num', sortable: true },
		{ key: 'registration_date', label: 'Registration Date', sortable: true }
	];

	async function loadPendingPaypal() {
		const res = await fetchPendingAdminRegistrationCheckouts();
		pendingPaypal = res.ok && res.data ? res.data : [];
	}

	onMount(async () => {
		loading = true;
		error = null;
		const [res] = await Promise.all([fetchRegistrations(), loadPendingPaypal()]);
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

	function racerLabel(r: RacerRow): string {
		const full = (r.full_name ?? '').toString().trim();
		const first = (r.first_name ?? '').toString().trim();
		const last = (r.last_name ?? '').toString().trim();
		const fromParts = [first, last].filter(Boolean).join(' ').trim();
		const name = full || fromParts || r.email;
		return r.email && name !== r.email ? `${name} (${r.email})` : (r.email ?? name);
	}

	function resetCreateForm() {
		createRacerSearch = '';
		createEventId = '';
		createRacerId = '';
		createPwcId = '';
		createClassKeys = [];
		createPaymentMode = 'manual';
		createPaymentMethod = 'complimentary';
		createMarkPaid = true;
		createPromoCode = '';
		createNotes = '';
		createSendQrEmail = true;
		createProfilePwcs = [];
		paypalApprovalUrl = null;
		paypalOrderId = null;
		paypalAmount = null;
	}

	function createFormReady(): boolean {
		return Boolean(createEventId && createRacerId && createPwcId && createClassKeys.length > 0);
	}

	function estimatedClassTotal(): number {
		return activeClassesForCreateEvent()
			.filter((c) => createClassKeys.includes(c.key))
			.reduce((sum, c) => sum + Number(c.price || 0), 0);
	}

	function openPayPalForCustomer() {
		if (paypalApprovalUrl) {
			window.open(paypalApprovalUrl, '_blank', 'noopener,noreferrer');
		}
	}

	async function submitCreatePayPalLink() {
		if (!createFormReady()) {
			toast('Complete event, racer, watercraft, and class selection.', 'error');
			return;
		}

		paypalSubmitting = true;
		paypalApprovalUrl = null;
		paypalOrderId = null;
		paypalAmount = null;

		const res = await createAdminRegistrationPayPalCheckout({
			event_id: createEventId,
			racer_id: createRacerId,
			pwc_id: createPwcId,
			class_keys: createClassKeys,
			promo_code: createPromoCode.trim() || null
		});
		paypalSubmitting = false;

		if (!res.ok || !res.data) {
			toast(res.error ?? 'Failed to create PayPal checkout', 'error');
			return;
		}

		if (res.data.free_checkout) {
			toast('Registration completed (no payment required).', 'success');
			closeCreateModal();
			expandedEvents = { ...expandedEvents, [createEventId]: true };
			loading = true;
			const refreshed = await fetchRegistrations();
			loading = false;
			if (refreshed.ok && refreshed.data) {
				eventRegistrations = refreshed.data as EventRegistrations[];
			}
			await loadPendingPaypal();
			return;
		}

		paypalApprovalUrl = res.data.approval_url;
		paypalOrderId = res.data.paypal_order_id;
		paypalAmount = res.data.amount;
		toast('PayPal link ready. Open for the customer, then capture after they pay.', 'success');
		await loadPendingPaypal();
	}

	async function capturePayPalRegistration(orderId: string) {
		captureSubmitting = orderId;
		const res = await captureAdminRegistrationPayPalCheckout(orderId);
		captureSubmitting = null;

		if (!res.ok) {
			toast(res.error ?? 'Capture failed', 'error');
			return;
		}

		if (paypalOrderId === orderId) {
			paypalApprovalUrl = null;
			paypalOrderId = null;
			paypalAmount = null;
		}

		toast('Payment captured and registration recorded.', 'success');
		closeCreateModal();
		loading = true;
		const refreshed = await fetchRegistrations();
		loading = false;
		if (refreshed.ok && refreshed.data) {
			eventRegistrations = refreshed.data as EventRegistrations[];
		}
		await loadPendingPaypal();
	}

	async function openCreateModal() {
		showCreateModal = true;
		createFormLoading = true;
		resetCreateForm();
		const [evRes, racerRes] = await Promise.all([fetchAllEventsForAdmin(), fetchRacers()]);
		createFormLoading = false;
		if (evRes.ok && evRes.data) {
			allEvents = [...evRes.data].sort(
				(a, b) => new Date(b.start_date).getTime() - new Date(a.start_date).getTime()
			);
			if (allEvents.length) createEventId = allEvents[0].id;
		} else {
			allEvents = [];
			if (evRes.error) toast(evRes.error, 'error');
		}
		if (racerRes.ok && racerRes.data) {
			allRacers = racerRes.data;
		} else {
			allRacers = [];
			if (racerRes.error) toast(racerRes.error, 'error');
		}
	}

	function closeCreateModal() {
		showCreateModal = false;
		resetCreateForm();
	}

	function activeClassesForCreateEvent(): EventClass[] {
		return (allEvents.find((e) => e.id === createEventId)?.classes ?? []).filter((c) => c.is_active);
	}

	function toggleCreateClass(key: string) {
		if (createClassKeys.includes(key)) {
			createClassKeys = createClassKeys.filter((k) => k !== key);
		} else {
			createClassKeys = [...createClassKeys, key];
		}
	}

	function profilePwcIdsFromRacer(
		racer: { pwc_id?: string[] | null } | null | undefined
	): string[] {
		const raw = racer?.pwc_id;
		if (!Array.isArray(raw)) return [];
		return raw.map((s) => String(s).trim()).filter(Boolean);
	}

	async function loadProfilePwcsForRacer(
		racerId: string,
		racer?: { pwc_id?: string[] | null } | null
	): Promise<string[]> {
		let ids = profilePwcIdsFromRacer(racer);
		if (!ids.length) {
			const res = await fetchRacer(racerId);
			if (res.ok && res.data) {
				ids = profilePwcIdsFromRacer(res.data);
			}
		}
		return ids;
	}

	async function onCreateRacerChange() {
		createPwcId = '';
		createProfilePwcs = [];
		if (!createRacerId) return;
		const fromList = allRacers.find((r) => r.id === createRacerId);
		createProfilePwcs = await loadProfilePwcsForRacer(createRacerId, fromList);
		if (createProfilePwcs.length) {
			createPwcId = createProfilePwcs[0];
		}
	}

	async function submitCreateRegistration() {
		if (createPaymentMode === 'paypal_link') {
			await submitCreatePayPalLink();
			return;
		}

		if (!createEventId) {
			toast('Select an event.', 'error');
			return;
		}
		if (!createRacerId) {
			toast('Select a racer.', 'error');
			return;
		}
		if (!createPwcId) {
			toast('Select a watercraft from this racer\'s account.', 'error');
			return;
		}
		if (createClassKeys.length === 0) {
			toast('Select at least one class.', 'error');
			return;
		}

		createSaving = true;
		const res = await createAdminRegistration({
			event_id: createEventId,
			racer_id: createRacerId,
			pwc_id: createPwcId,
			class_keys: createClassKeys,
			payment_method: createPaymentMethod,
			mark_paid: createMarkPaid,
			promo_code: createPromoCode.trim() || null,
			notes: createNotes.trim() || null,
			send_qr_email: createSendQrEmail
		});
		createSaving = false;

		if (!res.ok || !res.data?.length) {
			toast(res.error ?? 'Failed to create registration', 'error');
			return;
		}

		const count = res.data.length;
		toast(
			count === 1 ? 'Registration created' : `${count} registrations created`,
			'success'
		);
		closeCreateModal();
		expandedEvents = { ...expandedEvents, [createEventId]: true };

		loading = true;
		const refreshed = await fetchRegistrations();
		loading = false;
		if (refreshed.ok && refreshed.data) {
			eventRegistrations = refreshed.data as EventRegistrations[];
		}
		await loadPendingPaypal();
	}

	$: filteredCreateRacers = (() => {
		const q = createRacerSearch.trim().toLowerCase();
		if (!q) return allRacers;
		return allRacers.filter((r) => {
			const label = racerLabel(r).toLowerCase();
			const phone = (r.phone ?? '').toString().toLowerCase();
			return label.includes(q) || phone.includes(q);
		});
	})();

	$: if (createEventId) {
		const valid = new Set(activeClassesForCreateEvent().map((c) => c.key));
		if (createClassKeys.some((k) => !valid.has(k))) {
			createClassKeys = createClassKeys.filter((k) => valid.has(k));
		}
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
			void loadRacerPwcContext(reg.racer.id, reg.racer);
		}
	}

	async function loadRacerPwcContext(
		racerId: string,
		racer?: EventRegistrationAdmin['racer'] | null
	) {
		racerProfilePwcs = await loadProfilePwcsForRacer(racerId, racer);
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

			await loadRacerPwcContext(selectedReg.racer.id, selectedReg.racer);

			if (!allEditEvents.some((e) => e.id === editEventId)) {
				toast('Current event not in admin list — pick another event.', 'error');
			}

			syncClassKeyForEvent(editEventId);
			initPwcEditSelection(selectedReg.pwc_identifier ?? '');
		} finally {
			editFormLoading = false;
		}
	}

	function initPwcEditSelection(current: string) {
		const cur = current.trim();
		if (cur && racerProfilePwcs.includes(cur)) {
			editPwcSelect = cur;
		} else if (racerProfilePwcs.length > 0) {
			editPwcSelect = racerProfilePwcs[0];
		} else {
			editPwcSelect = '';
		}
	}

	function cancelEdit() {
		editing = false;
	}

	function resetTransferForm() {
		transferRacerSearch = '';
		transferRacerId = '';
		transferEventId = '';
		transferClassKey = '';
		transferPwcId = '';
		transferSendQrEmail = true;
		transferProfilePwcs = [];
	}

	function activeClassesForTransferEvent(): EventClass[] {
		return (transferAllEvents.find((e) => e.id === transferEventId)?.classes ?? []).filter(
			(c) => c.is_active
		);
	}

	function syncTransferClassKeyForEvent(eventId: string) {
		const classes = (transferAllEvents.find((e) => e.id === eventId)?.classes ?? []).filter(
			(c) => c.is_active
		);
		if (classes.length && !classes.some((c) => c.key === transferClassKey)) {
			transferClassKey = classes[0].key;
		}
	}

	function onTransferEventSelectChange(e: Event) {
		const v = (e.currentTarget as HTMLSelectElement).value;
		transferEventId = v;
		syncTransferClassKeyForEvent(v);
	}

	async function onTransferRacerChange() {
		transferPwcId = '';
		transferProfilePwcs = [];
		if (!transferRacerId) return;
		const fromList = transferAllRacers.find((r) => r.id === transferRacerId);
		transferProfilePwcs = await loadProfilePwcsForRacer(transferRacerId, fromList);
		if (transferProfilePwcs.length) {
			const preferred = selectedReg?.pwc_identifier?.trim();
			transferPwcId =
				preferred && transferProfilePwcs.includes(preferred)
					? preferred
					: transferProfilePwcs[0];
		}
	}

	function selectTransferRacer(racerId: string) {
		if (!racerId || transferRacerId === racerId) return;
		transferRacerId = racerId;
		void onTransferRacerChange();
	}

	function onTransferRacerSearchKeydown(e: KeyboardEvent) {
		if (e.key !== 'Enter') return;
		e.preventDefault();
		const first = filteredTransferRacers[0];
		if (first) selectTransferRacer(first.id);
	}

	$: if (!transferFormLoading && !transferSaving && transferRacerSearch.trim()) {
		if (filteredTransferRacers.length === 1) {
			selectTransferRacer(filteredTransferRacers[0].id);
		}
	}

	function transferRacerLabel(): string {
		const r = transferAllRacers.find((x) => x.id === transferRacerId);
		return r ? racerLabel(r) : transferRacerId;
	}

	async function openTransferModal() {
		if (!selectedReg) return;
		showTransferModal = true;
		transferFormLoading = true;
		resetTransferForm();
		transferEventId = selectedReg.event.id;
		transferClassKey = selectedReg.class_key;

		const [evRes, racerRes] = await Promise.all([fetchAllEventsForAdmin(), fetchRacers()]);
		transferFormLoading = false;

		if (evRes.ok && evRes.data) {
			transferAllEvents = [...evRes.data].sort(
				(a, b) => new Date(b.start_date).getTime() - new Date(a.start_date).getTime()
			);
		} else {
			transferAllEvents = [];
			if (evRes.error) toast(evRes.error, 'error');
		}
		if (racerRes.ok && racerRes.data) {
			transferAllRacers = racerRes.data;
		} else {
			transferAllRacers = [];
			if (racerRes.error) toast(racerRes.error, 'error');
		}

		syncTransferClassKeyForEvent(transferEventId);
	}

	function closeTransferModal() {
		showTransferModal = false;
		resetTransferForm();
	}

	function currentRegistrantRacerId(): string {
		if (!selectedReg) return '';
		return String(selectedReg.racer?.id ?? selectedReg.racer_model?.id ?? '').trim();
	}

	$: transferCanSubmit = Boolean(
		!transferFormLoading &&
			!transferSaving &&
			transferRacerId &&
			transferEventId &&
			transferClassKey &&
			String(transferPwcId ?? '').trim()
	);

	async function submitTransfer() {
		if (!selectedReg) return;
		if (!transferRacerId) {
			toast('Select the racer receiving this registration.', 'error');
			return;
		}
		if (transferRacerId === currentRegistrantRacerId()) {
			toast('Choose a different racer than the current registrant.', 'error');
			return;
		}
		if (!transferPwcId) {
			toast('Select a watercraft from the new racer\'s account.', 'error');
			return;
		}
		if (!transferEventId || !transferClassKey) {
			toast('Select an event and class.', 'error');
			return;
		}

		transferSaving = true;
		const payload: AdminTransferRegistrationPayload = {
			racer_id: transferRacerId,
			pwc_id: transferPwcId,
			event_id: transferEventId,
			class_key: transferClassKey,
			send_qr_email: transferSendQrEmail
		};
		const res = await transferRegistration(selectedReg.id, payload);
		transferSaving = false;

		if (!res.ok || !res.data) {
			toast(res.error ?? 'Failed to transfer registration', 'error');
			return;
		}

		toast('Registration transferred', 'success');
		closeTransferModal();
		editing = false;
		selectedReg = res.data;

		const refreshed = await fetchRegistrations();
		if (refreshed.ok && refreshed.data) {
			eventRegistrations = refreshed.data as EventRegistrations[];
			selectedReg = findRegById(res.data.id) ?? res.data;
			if (selectedReg) void loadRacerPwcContext(selectedReg.racer.id, selectedReg.racer);
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
		return formatDateTimeLocal(iso);
	}

	/** Backend sends price in dollars (e.g. 250 = $250). */
	function formatPrice(dollars: number): string {
		return `$${Number(dollars).toFixed(2)}`;
	}

	function formatShortDate(iso: string | undefined): string {
		if (!iso) return '';
		return formatDateLocal(iso, { month: 'short', day: 'numeric', year: 'numeric' });
	}

	function pwcLabel(pwcId: string | null | undefined): string {
		if (!pwcId) return '—';
		return pwcId.trim() || '—';
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
		const pwcIdentifier = editPwcSelect.trim();
		if (!pwcIdentifier || !racerProfilePwcs.includes(pwcIdentifier)) {
			toast('Select a watercraft from this racer\'s account.', 'error');
			return;
		}
		editSaving = true;

		const payload: EventRegistrationAdminUpdate = {
			is_paid: editIsPaid,
			event_id: editEventId,
			class_key: editClassKey,
			pwc_identifier: pwcIdentifier
		};

		const res = await updateRegistration(selectedReg.id, payload);

		if (!res.ok || !res.data) {
			editSaving = false;
			toast(res.error ?? 'Failed to update registration', 'error');
			return;
		}

		editSaving = false;
		toast('Registration updated', 'success');
		editing = false;
		selectedReg = res.data;

		// Refresh table so losses/paid status is consistent everywhere.
		const refreshed = await fetchRegistrations();
		if (refreshed.ok && refreshed.data) {
			eventRegistrations = refreshed.data as EventRegistrations[];
			selectedReg = findRegById(res.data.id) ?? res.data;
			if (selectedReg) void loadRacerPwcContext(selectedReg.racer.id, selectedReg.racer);
		}
	}

	$: filteredTransferRacers = (() => {
		const q = transferRacerSearch.trim().toLowerCase();
		const currentId = selectedReg?.racer?.id;
		let list = transferAllRacers;
		if (currentId) {
			list = list.filter((r) => r.id !== currentId);
		}
		if (!q) return list;
		return list.filter((r) => {
			const label = racerLabel(r).toLowerCase();
			const phone = (r.phone ?? '').toString().toLowerCase();
			return label.includes(q) || phone.includes(q);
		});
	})();

	$: if (!showDetailModal) {
		editing = false;
		editSaving = false;
		editFormLoading = false;
		showDeleteRegModal = false;
		deleteRegSaving = false;
		showTransferModal = false;
		transferSaving = false;
		transferFormLoading = false;
	}

	function registrationDeleteLabel(reg: EventRegistrationAdmin): string {
		const name = racerDisplay(reg);
		const cls = reg.class_name ?? reg.class_key ?? 'class';
		const ev = reg.event?.name ?? 'event';
		return `${name} — ${cls} (${ev})`;
	}

	async function confirmDeleteRegistration() {
		if (!selectedReg) return;
		deleteRegSaving = true;
		const regId = selectedReg.id;
		const eventId = selectedReg.event?.id;
		const res = await deleteRegistration(regId);
		deleteRegSaving = false;

		if (!res.ok) {
			toast(res.error ?? 'Failed to delete registration', 'error');
			return;
		}

		toast('Registration deleted', 'success');
		showDeleteRegModal = false;
		showDetailModal = false;
		editing = false;
		selectedReg = null;

		loading = true;
		const refreshed = await fetchRegistrations();
		loading = false;
		if (refreshed.ok && refreshed.data) {
			eventRegistrations = refreshed.data as EventRegistrations[];
			if (eventId) {
				expandedEvents = { ...expandedEvents, [eventId]: true };
			}
		}
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
	<div class="page-header-row">
		<div>
			<h1 class="page-title">Registrations</h1>
			<p class="page-subtitle">All event registrations grouped by event. Click a row to view details.</p>
		</div>
		<button
			type="button"
			class="btn btn-primary"
			disabled={loading}
			onclick={openCreateModal}
		>
			+ Add registration
		</button>
	</div>
</div>

{#if pendingPaypal.length > 0}
	<section class="pending-paypal-section">
		<h2 class="pending-paypal-title">Registrations awaiting PayPal capture</h2>
		<p class="detail-muted">
			Customer approved payment on PayPal — capture here to finalize registration.
		</p>
		<table class="data-table pending-paypal-table">
			<thead>
				<tr>
					<th>Created</th>
					<th>Event</th>
					<th>Racer</th>
					<th>Classes</th>
					<th>Amount</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each pendingPaypal as p (p.paypal_order_id)}
					<tr>
						<td>{p.created_at ? formatDate(p.created_at) : '—'}</td>
						<td>{p.event_name ?? '—'}</td>
						<td>{p.racer_name ?? '—'}</td>
						<td>{p.class_keys?.length ? p.class_keys.join(', ') : '—'}</td>
						<td>{formatPrice(p.amount)}</td>
						<td>
							<button
								type="button"
								class="btn btn-primary btn-sm"
								disabled={captureSubmitting === p.paypal_order_id}
								onclick={() => void capturePayPalRegistration(p.paypal_order_id)}
							>
								{captureSubmitting === p.paypal_order_id ? 'Capturing…' : 'Capture'}
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</section>
{/if}

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

<Modal bind:open={showCreateModal} title="Add registration">
	{#if createFormLoading}
		<p class="detail-muted">Loading events and racers…</p>
	{:else}
		<form class="create-reg-form" onsubmit={(e) => { e.preventDefault(); void submitCreateRegistration(); }}>
			<div class="form-field">
				<label for="create-event">Event</label>
				<select
					id="create-event"
					class="admin-edit-select"
					bind:value={createEventId}
					disabled={createSaving}
				>
					{#each allEvents as ev}
						<option value={ev.id}>
							{ev.name}{formatShortDate(ev.start_date) ? ` (${formatShortDate(ev.start_date)})` : ''}
						</option>
					{/each}
				</select>
			</div>

			<div class="form-field">
				<label for="create-racer-search">Racer</label>
				<input
					id="create-racer-search"
					class="admin-edit-input"
					type="search"
					placeholder="Search by name, email, or phone…"
					bind:value={createRacerSearch}
					disabled={createSaving}
					autocomplete="off"
				/>
				<select
					id="create-racer"
					class="admin-edit-select"
					bind:value={createRacerId}
					onchange={() => void onCreateRacerChange()}
					disabled={createSaving || filteredCreateRacers.length === 0}
				>
					<option value="">— Select racer —</option>
					{#each filteredCreateRacers as r (r.id)}
						<option value={r.id}>{racerLabel(r)}</option>
					{/each}
				</select>
			</div>

			{#if createRacerId}
				<div class="form-field">
					<label for="create-pwc">Watercraft (PWC)</label>
					{#if createProfilePwcs.length > 0}
						<select
							id="create-pwc"
							class="admin-edit-select"
							bind:value={createPwcId}
							disabled={createSaving}
						>
							{#each createProfilePwcs as label (label)}
								<option value={label}>{label}</option>
							{/each}
						</select>
					{:else}
						<p class="detail-muted">
							This racer has no watercraft on their account. They must add watercraft in the app before you can register them.
						</p>
					{/if}
				</div>

				<div class="form-field">
					<span class="form-label">Classes</span>
					{#if activeClassesForCreateEvent().length === 0}
						<p class="detail-muted">No active classes for this event.</p>
					{:else}
						<ul class="class-checklist">
							{#each activeClassesForCreateEvent() as cls (cls.key)}
								<li>
									<label class="class-check-label">
										<input
											type="checkbox"
											checked={createClassKeys.includes(cls.key)}
											disabled={createSaving}
											onchange={() => toggleCreateClass(cls.key)}
										/>
										<span>{cls.name} — {formatPrice(cls.price)}</span>
									</label>
								</li>
							{/each}
						</ul>
					{/if}
				</div>
			{/if}

			<div class="form-field">
				<span class="form-label">Payment</span>
				<div class="payment-mode-tabs">
					<label class="payment-mode-tab">
						<input
							type="radio"
							name="create-payment-mode"
							value="manual"
							bind:group={createPaymentMode}
							disabled={createSaving || paypalSubmitting}
						/>
						<span>Record manual payment</span>
					</label>
					<label class="payment-mode-tab">
						<input
							type="radio"
							name="create-payment-mode"
							value="paypal_link"
							bind:group={createPaymentMode}
							disabled={createSaving || paypalSubmitting}
						/>
						<span>Collect with PayPal</span>
					</label>
				</div>
			</div>

			{#if createPaymentMode === 'manual'}
				<p class="detail-muted">
					Cash, check, card terminal, or complimentary — registration is saved immediately.
				</p>
				<div class="form-field form-row-2">
					<div>
						<label for="create-payment">How paid</label>
						<select
							id="create-payment"
							class="admin-edit-select"
							bind:value={createPaymentMethod}
							disabled={createSaving}
						>
							<option value="complimentary">Complimentary</option>
							<option value="cash">Cash</option>
							<option value="check">Check</option>
						</select>
					</div>
					<div class="form-field-checkbox">
						<label class="paid-edit-label">
							<input type="checkbox" bind:checked={createMarkPaid} disabled={createSaving} />
							Mark as paid
						</label>
					</div>
				</div>

				<div class="form-field">
					<label for="create-notes">Notes (optional)</label>
					<input
						id="create-notes"
						class="admin-edit-input"
						type="text"
						bind:value={createNotes}
						disabled={createSaving}
						autocomplete="off"
					/>
				</div>

				<div class="form-field">
					<label class="paid-edit-label">
						<input type="checkbox" bind:checked={createSendQrEmail} disabled={createSaving} />
						Send QR code email to racer
					</label>
				</div>
			{:else}
				<p class="detail-muted">
					Create a PayPal link for the customer (e.g. on-site). Open it on their device, then capture
					after they approve payment. Estimated total: <strong>{formatPrice(estimatedClassTotal())}</strong>
					(promo applied when the link is created).
				</p>

				<div class="form-field">
					<label for="create-promo">Promo code (optional)</label>
					<input
						id="create-promo"
						class="admin-edit-input"
						type="text"
						bind:value={createPromoCode}
						disabled={createSaving || paypalSubmitting}
						autocomplete="off"
					/>
				</div>

				<div class="paypal-actions">
					<button
						type="button"
						class="btn btn-primary"
						disabled={paypalSubmitting || !createFormReady()}
						onclick={() => void submitCreatePayPalLink()}
					>
						{paypalSubmitting ? 'Creating…' : 'Create PayPal link'}
					</button>
					{#if paypalApprovalUrl}
						<button
							type="button"
							class="btn btn-secondary"
							disabled={createSaving}
							onclick={openPayPalForCustomer}
						>
							Open PayPal for customer
						</button>
						{#if paypalOrderId}
							<button
								type="button"
								class="btn btn-secondary"
								disabled={captureSubmitting === paypalOrderId}
								onclick={() => void capturePayPalRegistration(paypalOrderId!)}
							>
								{captureSubmitting === paypalOrderId ? 'Capturing…' : 'Capture payment'}
							</button>
						{/if}
					{/if}
				</div>
				{#if paypalApprovalUrl && paypalAmount != null}
					<p class="paypal-meta">
						Amount: <strong>{formatPrice(paypalAmount)}</strong>
						{#if paypalOrderId}
							· Order: <code>{paypalOrderId}</code>
						{/if}
					</p>
				{/if}
			{/if}
		</form>
	{/if}
	<svelte:fragment slot="footer">
		<button type="button" class="btn btn-secondary" disabled={createSaving} onclick={closeCreateModal}>
			Cancel
		</button>
		{#if createPaymentMode === 'manual'}
			<button
				type="button"
				class="btn btn-primary"
				disabled={createSaving || createFormLoading || !createFormReady()}
				onclick={() => void submitCreateRegistration()}
			>
				{createSaving ? 'Creating…' : 'Create registration'}
			</button>
		{/if}
	</svelte:fragment>
</Modal>

<Modal bind:open={showDetailModal} title="Registration details">
	{#if selectedReg}
		<div class="detail-sections">
			<section class="detail-section">
				<div class="detail-section-header">
					<h3 class="detail-heading">Racer</h3>
					{#if editing && !editFormLoading}
						<button
							type="button"
							class="btn btn-secondary btn-sm"
							disabled={editSaving || transferSaving}
							onclick={() => void openTransferModal()}
						>
							Transfer registration
						</button>
					{/if}
				</div>
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
								{#if racerProfilePwcs.length > 0}
									<select
										id="edit-pwc-select"
										class="admin-edit-select"
										bind:value={editPwcSelect}
										disabled={editSaving}
									>
										{#each racerProfilePwcs as label (label)}
											<option value={label}>{label}</option>
										{/each}
									</select>
								{:else}
									<p class="detail-muted">
										This racer has no watercraft on their account.
									</p>
								{/if}
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
				{@const paidAt = paymentCompletedAt({
					captured_at: selectedReg.payment.captured_at,
					registration_created_at: selectedReg.created_at,
					checkout_created_at: selectedReg.payment.created_at
				})}
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
						{#if paidAt}
							<dt>Payment date</dt>
							<dd>{formatDate(paidAt)}</dd>
						{/if}
						{#if selectedReg.payment.created_at && paidAt !== selectedReg.payment.created_at}
							<dt>Checkout started</dt>
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
		{#if selectedReg}
			<button
				type="button"
				class="btn btn-danger btn-sm reg-detail-delete"
				disabled={editSaving || editFormLoading || deleteRegSaving}
				onclick={() => (showDeleteRegModal = true)}
			>
				Delete registration
			</button>
		{/if}
		{#if editing}
			<button type="button" class="btn btn-secondary" disabled={editSaving || editFormLoading} onclick={cancelEdit}>Cancel</button>
			<button type="button" class="btn btn-primary" disabled={editSaving || editFormLoading} onclick={() => void saveEdit()}>
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

<Modal bind:open={showTransferModal} title="Transfer registration">
	{#if selectedReg}
		<p class="detail-muted transfer-intro">
			Move this registration from <strong>{racerDisplay(selectedReg)}</strong> to another racer.
			Payment and paid status stay on this registration record.
		</p>
	{/if}
	{#if transferFormLoading}
		<p class="detail-muted">Loading events and racers…</p>
	{:else}
		<form
			class="create-reg-form"
			onsubmit={(e) => {
				e.preventDefault();
				void submitTransfer();
			}}
		>
			<div class="form-field">
				<label for="transfer-racer-search">New racer</label>
				<input
					id="transfer-racer-search"
					class="admin-edit-input"
					type="search"
					placeholder="Search by name, email, or phone…"
					bind:value={transferRacerSearch}
					disabled={transferSaving}
					autocomplete="off"
					onkeydown={onTransferRacerSearchKeydown}
				/>
				{#if transferRacerId}
					<p class="transfer-selected-racer">
						Selected: <strong>{transferRacerLabel()}</strong>
						<button
							type="button"
							class="btn-link"
							disabled={transferSaving}
							onclick={() => {
								transferRacerId = '';
								transferPwcId = '';
								transferProfilePwcs = [];
							}}
						>
							Change
						</button>
					</p>
				{:else if filteredTransferRacers.length === 0}
					<p class="detail-muted">No matching racers. Clear the search or try another name.</p>
				{:else}
					<p class="detail-muted">Pick a racer below or press Enter to select the first match.</p>
				{/if}
				<select
					id="transfer-racer"
					class="admin-edit-select"
					bind:value={transferRacerId}
					onchange={() => void onTransferRacerChange()}
					disabled={transferSaving || filteredTransferRacers.length === 0}
				>
					<option value="">— Select racer —</option>
					{#each filteredTransferRacers as r (r.id)}
						<option value={r.id}>{racerLabel(r)}</option>
					{/each}
				</select>
			</div>

			<div class="form-field">
				<label for="transfer-event">Event</label>
				<select
					id="transfer-event"
					class="admin-edit-select"
					value={transferEventId}
					onchange={onTransferEventSelectChange}
					disabled={transferSaving}
				>
					{#each transferAllEvents as ev}
						<option value={ev.id}>
							{ev.name}{formatShortDate(ev.start_date)
								? ` (${formatShortDate(ev.start_date)})`
								: ''}
						</option>
					{/each}
				</select>
			</div>

			<div class="form-field">
				<label for="transfer-class">Class</label>
				{#key transferEventId}
					<select
						id="transfer-class"
						class="admin-edit-select"
						bind:value={transferClassKey}
						disabled={transferSaving}
					>
						{#each activeClassesForTransferEvent() as cls (cls.key)}
							<option value={cls.key}>{cls.name} — {formatPrice(cls.price)}</option>
						{/each}
					</select>
				{/key}
			</div>

			{#if transferRacerId}
				<div class="form-field">
					<label for="transfer-pwc">Watercraft (PWC)</label>
					{#if transferProfilePwcs.length > 0}
						<select
							id="transfer-pwc"
							class="admin-edit-select"
							bind:value={transferPwcId}
							disabled={transferSaving}
						>
							{#each transferProfilePwcs as label (label)}
								<option value={label}>{label}</option>
							{/each}
						</select>
					{:else}
						<p class="detail-muted">This racer has no watercraft on their account.</p>
					{/if}
				</div>
			{/if}

			<div class="form-field form-field-checkbox">
				<label class="paid-edit-label">
					<input type="checkbox" bind:checked={transferSendQrEmail} disabled={transferSaving} />
					Send QR code email to the new racer
				</label>
			</div>
		</form>
	{/if}
	<svelte:fragment slot="footer">
		<button
			type="button"
			class="btn btn-secondary"
			disabled={transferSaving}
			onclick={closeTransferModal}
		>
			Cancel
		</button>
		<button
			type="button"
			class="btn btn-primary"
			disabled={!transferCanSubmit || transferSaving}
			onclick={() => void submitTransfer()}
		>
			{transferSaving ? 'Transferring…' : 'Transfer registration'}
		</button>
	</svelte:fragment>
</Modal>

<Modal bind:open={showDeleteRegModal} title="Delete registration">
	{#if selectedReg}
		<p>
			Delete <strong>{registrationDeleteLabel(selectedReg)}</strong>?
			This cannot be undone.
		</p>
		<p class="detail-muted">
			The racer will be removed from this event and class. Any bracket matchups that include them will be updated.
		</p>
	{/if}
	<svelte:fragment slot="footer">
		<button
			type="button"
			class="btn btn-secondary"
			disabled={deleteRegSaving}
			onclick={() => (showDeleteRegModal = false)}
		>
			Cancel
		</button>
		<button
			type="button"
			class="btn btn-danger"
			disabled={deleteRegSaving || !selectedReg}
			onclick={() => void confirmDeleteRegistration()}
		>
			{deleteRegSaving ? 'Deleting…' : 'Delete registration'}
		</button>
	</svelte:fragment>
</Modal>

<style>
	.page-header-row {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		flex-wrap: wrap;
		gap: 1rem;
	}

	.create-reg-form {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.form-field {
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.form-field label,
	.form-label {
		font-size: 0.9rem;
		font-weight: 500;
		color: var(--text-muted);
	}

	.form-row-2 {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		align-items: end;
	}

	@media (max-width: 520px) {
		.form-row-2 {
			grid-template-columns: 1fr;
		}
	}

	.form-field-checkbox {
		padding-bottom: 0.35rem;
	}

	.class-checklist {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
	}

	.class-check-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: 400;
	}

	.btn-sm {
		padding: 0.35rem 0.75rem;
		font-size: 0.875rem;
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

	.pending-paypal-table {
		margin-top: 0.75rem;
	}

	.payment-mode-tabs {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.payment-mode-tab {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		cursor: pointer;
		font-weight: 400;
	}

	.paypal-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		align-items: center;
	}

	.paypal-meta {
		margin: 0.5rem 0 0;
		font-size: 0.9rem;
		color: var(--text-muted);
	}

	.paypal-meta code {
		font-size: 0.85em;
		background: var(--bg-muted);
		padding: 0.1rem 0.35rem;
		border-radius: 4px;
	}

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
	.detail-section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 0.75rem;
		flex-wrap: wrap;
		margin-bottom: 0.5rem;
		padding-bottom: 0.35rem;
		border-bottom: 1px solid var(--border);
	}
	.detail-section-header .detail-heading {
		margin: 0;
		border-bottom: none;
		padding-bottom: 0;
	}
	.transfer-intro {
		margin: 0 0 1rem 0;
		line-height: 1.45;
	}
	.transfer-selected-racer {
		margin: 0.35rem 0 0.5rem;
		font-size: 0.95rem;
	}
	.btn-link {
		margin-left: 0.5rem;
		padding: 0;
		border: none;
		background: none;
		color: var(--accent, #2563eb);
		cursor: pointer;
		font: inherit;
		text-decoration: underline;
	}
	.btn-link:disabled {
		opacity: 0.5;
		cursor: not-allowed;
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
	.detail-timezone-hint {
		margin: 0 0 0.75rem 0;
		line-height: 1.45;
	}

	.admin-edit-select,
	.admin-edit-input {
		width: 100%;
		max-width: 22rem;
	}

	.admin-edit-input {
		padding: 0.4rem 0.55rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg);
		color: var(--text);
		font-size: 0.95rem;
	}

	/* Registration details modal: Delete on the left, other actions on the right */
	:global(.modal-footer:has(.reg-detail-delete)) {
		flex-wrap: wrap;
		align-items: center;
		gap: 0.5rem;
	}

	.reg-detail-delete {
		margin-right: auto;
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

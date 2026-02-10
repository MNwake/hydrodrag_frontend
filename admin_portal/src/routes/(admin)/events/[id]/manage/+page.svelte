<script lang="ts">
	import { page } from '$app/stores';
	import { onMount, onDestroy, tick } from 'svelte';
	import { fetchEvent, type EventBase, type EventRegistrationBase } from '$lib/api/events';
	import { fetchEventRegistrations } from '$lib/api/registrations';
	import {
		fetchRounds,
		createRound,
		updateMatchup,
		recordMatchupWinner as apiRecordMatchupWinner,
		undoMatchupWinner as apiUndoMatchupWinner,
		deleteRound,
		resetClass,
		type RoundBase
	} from '$lib/api/matchups';
	import {
		startSpeedSession,
		updateSpeedSessionDuration,
		stopSpeedSession,
		getSpeedSessionInfo,
		updateSpeed,
		getSpeedRankings,
		resetSpeedSession,
		pauseSpeedSession,
		resumeSpeedSession,
		type SpeedSessionBase,
		type SpeedRankingItem
	} from '$lib/api/speed';
	import DataTable from '$lib/components/DataTable.svelte';
	import { toast } from '$lib/stores/toast';

	let loading = true;
	let error: string | null = null;
	let event: EventBase | null = null;
	let registrations: EventRegistrationBase[] = [];

	// Tab state per class: 'details' | 'matchups' | 'speed'
	let activeTab: Record<string, 'details' | 'matchups' | 'speed'> = {};

	// Sorting state per class
	type SortKey = 'seed' | 'racer_name' | 'pwc_identifier' | 'losses' | 'status' | 'payment' | 'ihra_membership' | 'valid_waiver' | 'is_of_age';
	type SortDir = 'asc' | 'desc';
	let sortKeyByClass: Record<string, SortKey> = {};
	let sortDirByClass: Record<string, SortDir> = {};
	let recordingWinnerMatchupId: string | null = null;

	// Admin notes and flags per matchup (UI only; API to be added later)
	let matchupNotes: Record<string, string> = {};
	let matchupProtest: Record<string, boolean> = {};
	let matchupUnderReview: Record<string, boolean> = {};

	// Matchup types
	type Matchup = {
		matchup_id: string; // backend matchup_id
		racerA: EventRegistrationBase;
		racerB: EventRegistrationBase | null; // null if bye
		winner: string | null; // registration id
		bracket: string; // "W" = winner bracket, "L" = loser bracket
		seed_a: number;
		seed_b: number | null; // null for bye
		roundId?: string; // backend round ID
	};

	type Round = {
		id?: string; // backend round ID
		number: number;
		matchups: Matchup[];
	};

	// Rounds per class: { classKey: Round[] }
	let roundsByClass: Record<string, Round[]> = {};
	// Current round being viewed per class
	let currentRoundByClass: Record<string, number> = {};
	// Dragging state
	let draggedRacer: { classKey: string; round: number; matchupId: string; racerId: string } | null = null;

	// Top speed (top_speed events): session info and rankings per class
	let speedSessionByClass: Record<string, SpeedSessionBase | null> = {};
	let speedRankingsByClass: Record<string, SpeedRankingItem[]> = {};
	let speedSessionLoading: Record<string, boolean> = {};
	let speedUpdatingRegId: string | null = null;
	/** Duration in minutes before starting (per class). Default 10. */
	let speedDurationMinutesByClass: Record<string, number> = {};
	/** Debounce timeouts for duration API calls per class. */
	let speedDurationDebounce: Record<string, ReturnType<typeof setTimeout>> = {};
	/** Ticks every second for timer display when a speed session is active. */
	let speedTimerTick = 0;
	let speedTimerInterval: ReturnType<typeof setInterval> | null = null;
	/** Display remaining seconds per class; synced from server on each response, then counted down client-side. */
	let displayRemainingByClass: Record<string, number> = {};

	const columns: { key: SortKey; label: string; class?: 'num' | 'center' | 'seed'; sortable?: boolean }[] = [
		{ key: 'seed', label: 'Seed', class: 'seed', sortable: true },
		{ key: 'racer_name', label: 'Racer', sortable: true },
		{ key: 'pwc_identifier', label: 'PWC', sortable: true },
		{ key: 'losses', label: 'Losses', class: 'num', sortable: true },
		{ key: 'status', label: 'Status', sortable: true },
		{ key: 'payment', label: 'Payment', sortable: true },
		{ key: 'ihra_membership', label: 'IHRA Membership', class: 'center', sortable: true },
		{ key: 'valid_waiver', label: 'Valid Waiver', class: 'center', sortable: true },
		{ key: 'is_of_age', label: 'Is of Age', class: 'center', sortable: true }
	];

	/** Map backend RoundBase to local Round format */
	function mapBackendRoundToLocal(roundBase: RoundBase, registrationsMap: Map<string, EventRegistrationBase>): Round | null {
		const matchups: Matchup[] = [];
		for (const m of roundBase.matchups) {
			const racerA = registrationsMap.get(m.racer_a);
			if (!racerA) {
				console.warn(`Registration ${m.racer_a} not found, skipping matchup ${m.matchup_id}`);
				continue;
			}
			const racerB = m.racer_b ? registrationsMap.get(m.racer_b) : null;
			matchups.push({
				matchup_id: m.matchup_id,
				racerA,
				racerB: racerB || null,
				winner: m.winner,
				bracket: m.bracket ?? 'W',
				seed_a: m.seed_a ?? 0,
				seed_b: m.seed_b ?? null,
				roundId: roundBase.id
			});
		}
		// Only return round if it has at least one valid matchup
		if (matchups.length === 0) {
			return null;
		}
		return {
			id: roundBase.id,
			number: roundBase.round_number,
			matchups
		};
	}

	async function load() {
		const id = $page.params.id;
		if (!id) return;
		loading = true;
		error = null;
		event = null;
		registrations = [];

		const [eventRes, regsRes] = await Promise.all([
			fetchEvent(id),
			fetchEventRegistrations(id)
		]);
		loading = false;

		if (!eventRes.ok) {
			error = eventRes.error ?? 'Event not found';
			return;
		}
		event = eventRes.data?.event ?? null;

		if (!regsRes.ok) {
			error = regsRes.error ?? 'Failed to load registrations';
			return;
		}
		registrations = Array.isArray(regsRes.data) ? regsRes.data : [];

		// Load rounds from backend
		await loadRounds(id);

		// If this is a top_speed event and any class has the speed tab active, fetch fresh session so timer is correct (e.g. after navigating back)
		if (event?.format === 'top_speed') {
			refetchActiveSpeedTabs();
		}
	}

	/** Reload registrations only (ensures Racer Details tab stays in sync with matchups). */
	async function reloadRegistrations(eventId: string) {
		const regsRes = await fetchEventRegistrations(eventId);
		if (regsRes.ok && Array.isArray(regsRes.data)) {
			// Assign new array so Svelte reactivity reliably updates byClass / sortedRowsByClass
			registrations = [...regsRes.data];
		}
	}

	/** Load rounds from backend for all classes */
	async function loadRounds(eventId: string) {
		try {
			// Create a map of registrations by ID for quick lookup
			const registrationsMap = new Map<string, EventRegistrationBase>();
			for (const reg of registrations) {
				registrationsMap.set(reg.id, reg);
			}

			// Fetch all rounds (no class_key filter to get all)
			const roundsRes = await fetchRounds(eventId);
			if (!roundsRes.ok) {
				console.error('Failed to load rounds:', roundsRes.error);
				return;
			}

			const backendRounds = roundsRes.data || [];
			const newRoundsByClass: Record<string, Round[]> = {};

			// Group rounds by class_key
			for (const roundBase of backendRounds) {
				const classKey = roundBase.class_key;
				if (!newRoundsByClass[classKey]) {
					newRoundsByClass[classKey] = [];
				}
				try {
					const localRound = mapBackendRoundToLocal(roundBase, registrationsMap);
					if (localRound) {
						newRoundsByClass[classKey].push(localRound);
					}
				} catch (err) {
					console.error('Error mapping round:', err);
				}
			}

			// Sort rounds by round_number within each class
			for (const classKey in newRoundsByClass) {
				newRoundsByClass[classKey].sort((a, b) => a.number - b.number);
			}

			roundsByClass = newRoundsByClass;

			// Preserve current round selection for each class, or set to latest if not set
			const newCurrentRoundByClass: Record<string, number> = {};
			for (const classKey in newRoundsByClass) {
				const rounds = newRoundsByClass[classKey];
				if (rounds.length > 0) {
					// Preserve existing selection if it still exists, otherwise use latest
					const existingRound = currentRoundByClass[classKey];
					const roundExists = rounds.some((r) => r.number === existingRound);
					newCurrentRoundByClass[classKey] = roundExists
						? existingRound
						: rounds[rounds.length - 1].number;
				}
			}
			currentRoundByClass = newCurrentRoundByClass;
		} catch (err) {
			console.error('Error loading rounds:', err);
		}
	}

	function racerDisplay(r: EventRegistrationBase): string {
		const model = r.racer_model;
		if (!model) return String(r.racer ?? '—');
		const full = (model.full_name ?? '').toString().trim();
		return full || String(model.email ?? '') || String(r.racer ?? '—');
	}


	/** Group registrations by class_key. Order: event classes first, then "Other". */
	$: byClass = (() => {
		const map = new Map<string, EventRegistrationBase[]>();
		for (const r of registrations) {
			const k = r.class_key || 'other';
			if (!map.has(k)) map.set(k, []);
			map.get(k)!.push(r);
		}
		const order: { key: string; label: string }[] = [];
		const seen = new Set<string>();
		if (event?.classes?.length) {
			for (const c of event.classes) {
				order.push({ key: c.key, label: c.name });
				seen.add(c.key);
			}
		}
		for (const k of map.keys()) {
			if (seen.has(k)) continue;
			const first = map.get(k)?.[0];
			order.push({ key: k, label: first?.class_name ?? k });
		}
		return order.map(({ key, label }) => ({ classKey: key, classLabel: label, regs: map.get(key) ?? [] }));
	})();

	/** Seed for a registration from round 1 of this class (if any). */
	function getSeedForRegistration(classKey: string, registrationId: string): number | null {
		const rounds = roundsByClass[classKey] ?? [];
		const round1 = rounds.find((r) => r.number === 1);
		if (!round1?.matchups) return null;
		for (const m of round1.matchups) {
			if (m.racerA.id === registrationId) return m.seed_a;
			if (m.racerB?.id === registrationId) return m.seed_b ?? null;
		}
		return null;
	}

	/** Convert registrations to table rows for a class */
	function registrationRows(regs: EventRegistrationBase[], classKey: string): Record<string, unknown>[] {
		return regs.map((r) => {
			const isEliminated = (r.losses ?? 0) >= 2;
			const status = isEliminated ? 'Eliminated' : 'Active';
			const payment = r.is_paid ? 'Paid' : 'Unpaid';
			const ihraMembership = r.has_ihra_membership ? 'Yes' : 'No';
			const validWaiver = r.has_valid_waiver ? 'Yes' : 'No';
			const isOfAge = r.is_of_age ? 'Yes' : 'No';
			const seed = getSeedForRegistration(classKey, r.id);

			return {
				seed: seed != null ? seed : '—',
				racer_name: racerDisplay(r),
				pwc_identifier: r.pwc_identifier || '—',
				losses: r.losses ?? 0,
				status,
				payment,
				ihra_membership: ihraMembership,
				valid_waiver: validWaiver,
				is_of_age: isOfAge
			};
		});
	}

	/** Get sort value for a row and key */
	function sortValue(row: Record<string, unknown>, key: SortKey): string | number | boolean {
		const value = row[key];
		if (key === 'seed' || key === 'losses') {
			return typeof value === 'number' ? value : 9999; // '—' / missing sorts last
		}
		if (key === 'ihra_membership' || key === 'valid_waiver' || key === 'is_of_age') {
			// Sort Yes/No as boolean (Yes = true, No = false)
			return String(value).toLowerCase() === 'yes';
		}
		return String(value ?? '').toLowerCase();
	}

	/** Toggle sort for a class */
	function toggleSort(classKey: string, key: SortKey) {
		const currentKey = sortKeyByClass[classKey];
		const currentDir = sortDirByClass[classKey];
		
		if (currentKey === key) {
			sortDirByClass = { ...sortDirByClass, [classKey]: currentDir === 'asc' ? 'desc' : 'asc' };
		} else {
			sortKeyByClass = { ...sortKeyByClass, [classKey]: key };
			sortDirByClass = { ...sortDirByClass, [classKey]: 'asc' };
		}
	}

	/** Get sorted rows for a class */
	function getSortedRows(classKey: string, regs: EventRegistrationBase[]): Record<string, unknown>[] {
		const rows = registrationRows(regs, classKey);
		const sortKey = sortKeyByClass[classKey] || 'racer_name';
		const sortDir = sortDirByClass[classKey] || 'asc';

		return [...rows].sort((a, b) => {
			const va = sortValue(a, sortKey);
			const vb = sortValue(b, sortKey);
			let c = 0;
			if (typeof va === 'string' && typeof vb === 'string') {
				c = va.localeCompare(vb, undefined, { sensitivity: 'base' });
			} else if (typeof va === 'number' && typeof vb === 'number') {
				c = va - vb;
			} else if (va < vb) {
				c = -1;
			} else if (va > vb) {
				c = 1;
			}
			return sortDir === 'asc' ? c : -c;
		});
	}

	// Reactive map of sorted rows per class - depends on byClass, roundsByClass, sortKeyByClass, sortDirByClass
	$: sortedRowsByClass = (() => {
		const sortKeys = sortKeyByClass;
		const sortDirs = sortDirByClass;
		const rounds = roundsByClass; // dependency so seed column updates when rounds change
		const result: Record<string, Record<string, unknown>[]> = {};
		for (const { classKey, regs } of byClass) {
			// Use the referenced values to ensure reactivity
			const sortKey = sortKeys[classKey] || 'racer_name';
			const sortDir = sortDirs[classKey] || 'asc';
			const rows = registrationRows(regs, classKey);
			result[classKey] = [...rows].sort((a, b) => {
				const va = sortValue(a, sortKey);
				const vb = sortValue(b, sortKey);
				let c = 0;
				if (typeof va === 'boolean' && typeof vb === 'boolean') {
					c = va === vb ? 0 : va ? 1 : -1;
				} else if (typeof va === 'string' && typeof vb === 'string') {
					c = va.localeCompare(vb, undefined, { sensitivity: 'base' });
				} else if (typeof va === 'number' && typeof vb === 'number') {
					c = va - vb;
				} else if (va < vb) {
					c = -1;
				} else if (va > vb) {
					c = 1;
				}
				return sortDir === 'asc' ? c : -c;
			});
		}
		return result;
	})();

	/** Create a new round for a class. Backend builds bracket (initial or next round). */
	async function generateMatchups(classKey: string) {
		const id = $page.params.id;
		if (!id) return;

		const res = await createRound(id, { class_key: classKey });
		if (!res.ok) {
			toast(res.error ?? 'Failed to create round', 'error');
			return;
		}

		await loadRounds(id);
		const newRoundNum = res.data?.round_number;
		toast(newRoundNum != null ? `Round ${newRoundNum} created` : 'New round created', 'success');
	}

	/** Reset class to pre-event settings (clears rounds/matchups for this class). */
	async function resetClassHandler(classKey: string) {
		const id = $page.params.id;
		if (!id) return;
		if (!confirm(`Reset ${classKey} to pre-event settings? This will remove all rounds and matchups for this class.`)) {
			return;
		}

		const res = await resetClass(id, classKey);
		if (!res.ok) {
			toast(res.error ?? 'Failed to reset class', 'error');
			return;
		}

		// Reload registrations so Racer Details shows updated losses (reset to 0)
		await reloadRegistrations(id);
		await loadRounds(id);
		// Clear current round view for this class
		const next = { ...currentRoundByClass };
		delete next[classKey];
		currentRoundByClass = next;
		toast('Class reset to pre-event settings', 'success');
	}


	/** Set current round for a class */
	function setCurrentRound(classKey: string, roundNum: number) {
		currentRoundByClass = { ...currentRoundByClass, [classKey]: roundNum };
	}

	/** Delete a round */
	async function deleteRoundHandler(classKey: string, roundId: string, roundNum: number) {
		const id = $page.params.id;
		if (!id) return;

		if (!confirm(`Are you sure you want to delete Round ${roundNum}? This action cannot be undone.`)) {
			return;
		}

		const res = await deleteRound(id, roundId);
		if (!res.ok) {
			toast(res.error ?? 'Failed to delete round', 'error');
			return;
		}

		// Reload rounds after deletion
		await loadRounds(id);
		
		// If we deleted the current round, switch to the latest round
		const rounds = roundsByClass[classKey] || [];
		if (rounds.length > 0) {
			const latestRound = rounds[rounds.length - 1];
			currentRoundByClass = { ...currentRoundByClass, [classKey]: latestRound.number };
		} else {
			// No rounds left, clear the current round
			const newCurrent = { ...currentRoundByClass };
			delete newCurrent[classKey];
			currentRoundByClass = newCurrent;
		}

		toast(`Round ${roundNum} deleted`, 'success');
	}

	/** Record winner for a matchup */
	async function recordMatchupWinner(classKey: string, roundNum: number, matchupId: string, winnerId: string) {
		const id = $page.params.id;
		if (!id) return;

		const rounds = roundsByClass[classKey] || [];
		const round = rounds.find((r) => r.number === roundNum);
		if (!round || !round.id) return;

		const matchup = round.matchups.find((m) => m.matchup_id === matchupId);
		if (!matchup) return;

		const scrollY = window.scrollY;
		recordingWinnerMatchupId = matchupId;
		try {
			const winnerRes = await apiRecordMatchupWinner(id, round.id, matchupId, winnerId);
			if (!winnerRes.ok) {
				toast(winnerRes.error ?? 'Failed to record matchup winner', 'error');
				return;
			}
			// Loss is handled server-side when recording the matchup winner
			await reloadRegistrations(id);
			await loadRounds(id);
			await tick();
			window.scrollTo(0, scrollY);
			toast('Matchup result recorded', 'success');
		} finally {
			recordingWinnerMatchupId = null;
		}
	}

	/** Undo winner selection for a matchup */
	async function undoMatchupWinner(classKey: string, roundNum: number, matchupId: string) {
		const id = $page.params.id;
		if (!id) return;

		const rounds = roundsByClass[classKey] || [];
		const round = rounds.find((r) => r.number === roundNum);
		if (!round || !round.id) return;

		const matchup = round.matchups.find((m) => m.matchup_id === matchupId);
		if (!matchup || !matchup.winner) return;

		// Save scroll position before any updates
		const scrollY = window.scrollY;

		// Undo winner on backend
		const res = await apiUndoMatchupWinner(id, round.id, matchupId);
		if (!res.ok) {
			toast(res.error ?? 'Failed to undo matchup winner', 'error');
			return;
		}

		// Reload registrations first, then rounds (so rounds can use fresh registration data)
		await reloadRegistrations(id);
		await loadRounds(id);
		await tick();
		window.scrollTo(0, scrollY);
		toast('Winner selection undone. Note: The loss recorded on the backend may need manual correction.', 'default');
	}

	/** Swap racers between matchups (drag and drop) */
	async function swapRacers(
		classKey: string,
		roundNum: number,
		sourceMatchupId: string,
		sourceRacerId: string,
		targetMatchupId: string,
		targetRacerId: string
	) {
		const id = $page.params.id;
		if (!id) return;

		const rounds = roundsByClass[classKey] || [];
		const round = rounds.find((r) => r.number === roundNum);
		if (!round || !round.id) return;

		const sourceMatchup = round.matchups.find((m) => m.matchup_id === sourceMatchupId);
		const targetMatchup = round.matchups.find((m) => m.matchup_id === targetMatchupId);
		if (!sourceMatchup || !targetMatchup) return;

		// Find the racers
		const sourceRacer = sourceMatchup.racerA.id === sourceRacerId
			? sourceMatchup.racerA
			: sourceMatchup.racerB?.id === sourceRacerId
			? sourceMatchup.racerB
			: null;
		const targetRacer = targetMatchup.racerA.id === targetRacerId
			? targetMatchup.racerA
			: targetMatchup.racerB?.id === targetRacerId
			? targetMatchup.racerB
			: null;

		if (!sourceRacer || !targetRacer) return;

		// Determine which position each racer is in
		const sourceIsA = sourceMatchup.racerA.id === sourceRacerId;
		const targetIsA = targetMatchup.racerA.id === targetRacerId;

		// Update both matchups on backend
		const sourceUpdate: { racer_a?: string; racer_b?: string | null } = {};
		const targetUpdate: { racer_a?: string; racer_b?: string | null } = {};

		if (sourceIsA) {
			sourceUpdate.racer_a = targetRacer.id;
		} else {
			sourceUpdate.racer_b = targetRacer.id;
		}

		if (targetIsA) {
			targetUpdate.racer_a = sourceRacer.id;
		} else {
			targetUpdate.racer_b = sourceRacer.id;
		}

		// Update both matchups
		const [sourceRes, targetRes] = await Promise.all([
			updateMatchup(id, round.id, sourceMatchupId, sourceUpdate),
			updateMatchup(id, round.id, targetMatchupId, targetUpdate)
		]);

		if (!sourceRes.ok || !targetRes.ok) {
			toast(sourceRes.error ?? targetRes.error ?? 'Failed to swap racers', 'error');
			return;
		}

		// Reload rounds to sync state
		await loadRounds(id);
		toast('Racers swapped', 'success');
	}

	/** Set tab for a class. When switching to speed tab we always fetch fresh session from server. */
	function setTab(classKey: string, tab: 'details' | 'matchups' | 'speed') {
		activeTab = { ...activeTab, [classKey]: tab };
		if (tab === 'speed' && event?.id) {
			loadSpeedSessionForClass(classKey);
			loadSpeedRankingsForClass(classKey);
		}
	}

	/** Refetch speed session for any class that currently has the speed tab active (e.g. after navigating back to this page). */
	function refetchActiveSpeedTabs() {
		if (!event?.id || event?.format !== 'top_speed') return;
		for (const { classKey } of byClass) {
			if ((activeTab[classKey] || 'details') === 'speed') {
				loadSpeedSessionForClass(classKey);
				loadSpeedRankingsForClass(classKey);
			}
		}
	}

	/** Load speed session info for a class (top_speed events). */
	async function loadSpeedSessionForClass(classKey: string) {
		if (!event?.id) return;
		speedSessionLoading = { ...speedSessionLoading, [classKey]: true };
		const res = await getSpeedSessionInfo(event.id, classKey);
		speedSessionLoading = { ...speedSessionLoading, [classKey]: false };
		if (res.ok && res.data) {
			speedSessionByClass = { ...speedSessionByClass, [classKey]: res.data };
			syncDisplayRemaining(classKey, res.data);
			if (!res.data.stopped_at && !speedTimerInterval) {
				speedTimerInterval = setInterval(tickSpeedDisplayRemaining, 1000);
			}
		} else {
			speedSessionByClass = { ...speedSessionByClass, [classKey]: null };
			const next = { ...displayRemainingByClass };
			delete next[classKey];
			displayRemainingByClass = next;
		}
	}

	/** Load speed rankings for a class. */
	async function loadSpeedRankingsForClass(classKey: string) {
		if (!event?.id) return;
		const res = await getSpeedRankings(event.id, classKey);
		if (res.ok && res.data) {
			speedRankingsByClass = { ...speedRankingsByClass, [classKey]: res.data.rankings };
		}
	}

	/** Called when user changes session length (debounced). Updates backend. */
	function onSpeedDurationChange(classKey: string, minutes: number) {
		if (!event?.id) return;
		const prev = speedDurationDebounce[classKey];
		if (prev) clearTimeout(prev);
		speedDurationDebounce[classKey] = setTimeout(async () => {
			const next = { ...speedDurationDebounce };
			delete next[classKey];
			speedDurationDebounce = next;
			const res = await updateSpeedSessionDuration(event!.id, classKey, minutes);
			if (!res.ok) {
				toast(res.error ?? 'Failed to update session duration', 'error');
			}
		}, 400);
	}

	async function startSpeedHandler(classKey: string) {
		if (!event?.id) return;
		const minutes = Math.max(1, Math.min(180, Math.round(speedDurationMinutesByClass[classKey] ?? 10)));
		const durationRes = await updateSpeedSessionDuration(event.id, classKey, minutes);
		if (!durationRes.ok) {
			toast(durationRes.error ?? 'Failed to set session duration', 'error');
			return;
		}
		const res = await startSpeedSession(event.id, classKey);
		if (res.ok && res.data) {
			speedSessionByClass = { ...speedSessionByClass, [classKey]: res.data };
			syncDisplayRemaining(classKey, res.data);
			if (!speedTimerInterval) {
				speedTimerInterval = setInterval(tickSpeedDisplayRemaining, 1000);
			}
			toast('Session started', 'success');
		} else {
			toast(res.error ?? 'Failed to start session', 'error');
		}
	}

	async function stopSpeedHandler(classKey: string) {
		if (!event?.id) return;
		const res = await stopSpeedSession(event.id, classKey);
		if (res.ok && res.data) {
			speedSessionByClass = { ...speedSessionByClass, [classKey]: res.data };
			syncDisplayRemaining(classKey, res.data);
			toast('Speed session stopped', 'success');
		} else {
			toast(res.error ?? 'Failed to stop session', 'error');
		}
	}

	async function pauseSpeedHandler(classKey: string) {
		if (!event?.id) return;
		const res = await pauseSpeedSession(event.id, classKey);
		if (res.ok) {
			await loadSpeedSessionForClass(classKey);
			toast('Speed session paused', 'success');
		} else {
			toast(res.error ?? 'Failed to pause', 'error');
		}
	}

	async function resumeSpeedHandler(classKey: string) {
		if (!event?.id) return;
		const res = await resumeSpeedSession(event.id, classKey);
		if (res.ok) {
			await loadSpeedSessionForClass(classKey);
			toast('Speed session resumed', 'success');
		} else {
			toast(res.error ?? 'Failed to resume', 'error');
		}
	}

	async function resetSpeedHandler(classKey: string) {
		if (!event?.id) return;
		if (!confirm('Reset this class\'s speed session? This will clear all recorded speeds.')) return;
		const res = await resetSpeedSession(event.id, classKey);
		if (res.ok) {
			speedSessionByClass = { ...speedSessionByClass, [classKey]: null };
			speedRankingsByClass = { ...speedRankingsByClass, [classKey]: [] };
			const next = { ...displayRemainingByClass };
			delete next[classKey];
			displayRemainingByClass = next;
			registrations = registrations.map((r) =>
				r.class_key === classKey ? { ...r, top_speed: null, speed_updated_at: null } : r
			);
			toast('Speed session reset', 'success');
		} else {
			toast(res.error ?? 'Failed to reset', 'error');
		}
	}

	/** Client-side remaining seconds (fallback when server doesn't send remaining_seconds). Matches backend formula. */
	function computedRemainingFallback(session: SpeedSessionBase): number {
		if (!session.started_at) return session.duration_seconds;
		if (session.stopped_at) return 0;
		const now = Date.now() / 1000;
		const startSec = new Date(session.started_at).getTime() / 1000;
		let elapsed = now - startSec;
		elapsed -= session.total_paused_seconds ?? 0;
		if (session.paused_at) {
			const pausedSec = new Date(session.paused_at).getTime() / 1000;
			elapsed -= now - pausedSec;
		}
		const raw = Math.floor(session.duration_seconds - elapsed);
		// Clamp to [0, duration] to avoid timezone/clock skew showing huge numbers
		return Math.max(0, Math.min(session.duration_seconds, raw));
	}

	/** Sync display remaining from server (remaining_seconds is server-computed). Fallback to client compute only if missing. */
	function syncDisplayRemaining(classKey: string, session: SpeedSessionBase) {
		const raw =
			session.remaining_seconds != null && Number.isFinite(Number(session.remaining_seconds))
				? Number(session.remaining_seconds)
				: computedRemainingFallback(session);
		const serverRemaining = Math.max(0, Math.min(session.duration_seconds, raw));
		const currentDisplay = displayRemainingByClass[classKey];
		// If server returns full duration (e.g. after resume before backend updates total_paused_seconds) but we have a lower value (paused time), keep it so resume continues from paused time
		const serverSaysFull = serverRemaining >= session.duration_seconds - 2;
		const weHavePausedValue = currentDisplay != null && currentDisplay < session.duration_seconds - 2;
		const remaining = weHavePausedValue && serverSaysFull ? currentDisplay : serverRemaining;
		displayRemainingByClass = { ...displayRemainingByClass, [classKey]: remaining };
	}

	/** Called every second: decrement display remaining for active running (not paused) sessions. */
	function tickSpeedDisplayRemaining() {
		const next = { ...displayRemainingByClass };
		let hasActive = false;
		for (const ck of Object.keys(speedSessionByClass)) {
			const session = speedSessionByClass[ck];
			if (!session || session.stopped_at || session.paused_at) continue;
			hasActive = true;
			const current = Number(next[ck] ?? session.remaining_seconds ?? session.duration_seconds);
			next[ck] = Math.max(0, Math.min(session.duration_seconds, current - 1));
		}
		if (hasActive) {
			displayRemainingByClass = next;
			speedTimerTick += 1;
		}
	}

	/** Value to show in timer UI: synced from server remaining_seconds, then counted down client-side. Never exceed session duration. */
	function getDisplayRemaining(classKey: string, session: SpeedSessionBase | null): number {
		if (!session) return 0;
		if (session.stopped_at) return 0;
		const synced = displayRemainingByClass[classKey];
		const serverRemaining =
			session.remaining_seconds != null && Number.isFinite(Number(session.remaining_seconds))
				? Number(session.remaining_seconds)
				: null;
		const raw = synced != null ? Number(synced) : (serverRemaining ?? computedRemainingFallback(session));
		return Math.max(0, Math.min(session.duration_seconds, raw));
	}

	/** Session is active (can record speeds) when started and not stopped. */
	function isSpeedSessionActive(session: SpeedSessionBase | null): boolean {
		return !!session && !session.stopped_at;
	}

	/** True when session is running but currently paused. */
	function isSpeedSessionPaused(session: SpeedSessionBase | null): boolean {
		return !!session && !session.stopped_at && !!session.paused_at;
	}

	function formatSpeedTimer(remainingSeconds: number): string {
		const n = Number(remainingSeconds);
		if (!Number.isFinite(n) || n < 0) return '0:00';
		const m = Math.floor(n / 60);
		const s = Math.floor(n % 60);
		return `${m}:${String(s).padStart(2, '0')}`;
	}

	onDestroy(() => {
		if (speedTimerInterval) {
			clearInterval(speedTimerInterval);
			speedTimerInterval = null;
		}
		Object.values(speedDurationDebounce).forEach((t) => clearTimeout(t));
	});

	/** Submit speed for a racer (on blur or Enter). Updates local state and rankings from response. */
	async function submitSpeed(classKey: string, regId: string, speedStr: string) {
		if (!event?.id) return;
		const speed = parseFloat(speedStr.trim());
		if (!Number.isFinite(speed) || speed <= 0) return;
		speedUpdatingRegId = regId;
		const res = await updateSpeed(event.id, classKey, regId, speed);
		speedUpdatingRegId = null;
		if (res.ok && res.data) {
			const data = res.data;
			registrations = registrations.map((r) =>
				r.id === regId ? { ...r, top_speed: data.top_speed, speed_updated_at: data.speed_updated_at } : r
			);
			speedRankingsByClass = { ...speedRankingsByClass, [classKey]: data.rankings };
			toast('Speed updated', 'success');
		} else {
			toast(res.error ?? 'Failed to update speed', 'error');
		}
	}

	function formatSpeedSessionTime(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' });
	}

	function getRacerNameForRegId(regId: string): string {
		const r = registrations.find((rr) => rr.id === regId);
		return r ? racerDisplay(r) : regId;
	}

	// Reactive state - force updates by creating new object references
	$: tabs = activeTab;
	$: rounds = roundsByClass;
	$: currentRounds = currentRoundByClass;


	$: id = $page.params.id;

	// When event id changes (navigate to different event or back), clear speed session state and reload so we don't show stale timer/session
	let previousEventId: string | undefined = undefined;
	$: if (id && id !== previousEventId) {
		previousEventId = id;
		speedSessionByClass = {};
		displayRemainingByClass = {};
		speedRankingsByClass = {};
		load();
	}

	onMount(() => {
		// Initial load is handled by reactive block when id is set
	});
</script>

<div class="page-header" style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
	<div>
		<h1 class="page-title">Manage event</h1>
		<p class="page-subtitle">
			{#if event}
				{event.name}
			{:else}
				Event registrations
			{/if}
		</p>
	</div>
	<div style="display: flex; gap: 0.5rem;">
		<a href="/events" class="btn btn-secondary">← Back to events</a>
		{#if event}
			<a href="/events/{event.id}" class="btn btn-primary">Edit event</a>
		{/if}
	</div>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">
		{error}
		<br />
		<a href="/events">← Back to events</a>
	</div>
{:else if !event}
	<div class="error-placeholder">Event not found. <a href="/events">← Back to events</a></div>
{:else}
	{#if byClass.length === 0}
		<div class="data-table-wrap">
			<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
				No registrations yet for this event.
			</div>
		</div>
	{:else}
		{#each byClass as { classKey, classLabel, regs }}
			<section class="manage-class-section">
				<h2 class="manage-class-title">{classLabel}</h2>
				
				<div class="class-tabs">
					<button
						type="button"
						class="class-tab"
						class:active={(tabs[classKey] || 'details') === 'details'}
						onclick={() => setTab(classKey, 'details')}
					>
						Racer Details
					</button>
					{#if event?.format === 'top_speed'}
						<button
							type="button"
							class="class-tab"
							class:active={(tabs[classKey] || 'details') === 'speed'}
							onclick={() => setTab(classKey, 'speed')}
						>
							Top speed
						</button>
					{:else}
						<button
							type="button"
							class="class-tab"
							class:active={(tabs[classKey] || 'details') === 'matchups'}
							onclick={() => setTab(classKey, 'matchups')}
						>
							Matchups
						</button>
					{/if}
				</div>

				{#if (tabs[classKey] || 'details') === 'details'}
					<DataTable
						columns={columns}
						rows={sortedRowsByClass[classKey] || []}
						emptyMessage="No registrations in this class."
						sortKey={sortKeyByClass[classKey] ?? 'racer_name'}
						sortDir={sortDirByClass[classKey] ?? 'asc'}
						onSort={(key) => toggleSort(classKey, key as SortKey)}
					/>
				{:else if (tabs[classKey] || 'details') === 'speed' && event?.format === 'top_speed'}
					{@const session = speedSessionByClass[classKey]}
					{@const sessionActive = isSpeedSessionActive(session)}
					<div class="speed-view">
						<div class="speed-session-bar">
							{#if session}
								<div class="speed-session-info">
									<span>Started: {formatSpeedSessionTime(session.started_at)}</span>
									<span>Duration: {formatSpeedTimer(session.duration_seconds)}</span>
									{#if session.stopped_at}
										<span class="speed-stopped">Session ended</span>
									{:else if isSpeedSessionPaused(session)}
										<span class="speed-paused">Paused</span>
										{@const remaining = getDisplayRemaining(classKey, session) + 0 * speedTimerTick}
										<span class="speed-timer" class:ended={remaining <= 0}>
											{remaining <= 0 ? '0:00' : formatSpeedTimer(remaining)}
										</span>
									{:else}
										{@const remaining = getDisplayRemaining(classKey, session) + 0 * speedTimerTick}
										<span class="speed-timer" class:ended={remaining <= 0}>
											{remaining <= 0 ? '0:00' : formatSpeedTimer(remaining)}
										</span>
									{/if}
								</div>
								<div class="speed-session-actions">
									{#if session.stopped_at}
										<button type="button" class="btn btn-secondary btn-sm" disabled>Session ended</button>
									{:else}
										<button type="button" class="btn btn-secondary btn-sm" onclick={() => stopSpeedHandler(classKey)}>Stop</button>
										{#if isSpeedSessionPaused(session)}
											<button type="button" class="btn btn-secondary btn-sm" onclick={() => resumeSpeedHandler(classKey)}>Resume</button>
										{:else}
											<button type="button" class="btn btn-secondary btn-sm" onclick={() => pauseSpeedHandler(classKey)}>Pause</button>
										{/if}
									{/if}
									<button type="button" class="btn btn-secondary btn-sm" onclick={() => resetSpeedHandler(classKey)}>Reset</button>
								</div>
							{:else}
								<div class="speed-session-info speed-session-pre">
									<label class="speed-duration-label">
										Session length (minutes):
										<input
											type="number"
											min="1"
											max="180"
											class="speed-duration-input"
											value={speedDurationMinutesByClass[classKey] ?? 10}
											oninput={(e) => {
												const v = parseInt(e.currentTarget.value, 10);
												if (Number.isFinite(v) && v >= 1 && v <= 180) {
													speedDurationMinutesByClass = { ...speedDurationMinutesByClass, [classKey]: v };
													onSpeedDurationChange(classKey, v);
												}
											}}
										/>
									</label>
								</div>
								<div class="speed-session-actions">
									<button
										type="button"
										class="btn btn-primary btn-sm"
										disabled={speedSessionLoading[classKey]}
										onclick={() => startSpeedHandler(classKey)}
									>
										{speedSessionLoading[classKey] ? 'Starting…' : 'Start Session'}
									</button>
								</div>
							{/if}
						</div>
						<div class="speed-content">
							<div class="speed-racers">
								<h3 class="speed-subtitle">Enter speed (mph)</h3>
								<p class="speed-hint">
									{sessionActive ? 'Submit by blurring the field or pressing Enter.' : 'Start the session to record speeds.'}
								</p>
								<table class="data-table speed-table">
									<thead>
										<tr>
											<th>Racer</th>
											<th>PWC</th>
											<th class="num">Top speed</th>
										</tr>
									</thead>
									<tbody>
										{#each regs as reg}
											<tr class:disabled={!sessionActive}>
												<td>{racerDisplay(reg)}</td>
												<td>{reg.pwc_identifier || '—'}</td>
												<td class="num">
													<input
														type="number"
														step="0.01"
														min="0"
														class="speed-input"
														placeholder="—"
														value={reg.top_speed ?? ''}
														onblur={(e) => sessionActive && submitSpeed(classKey, reg.id, e.currentTarget.value)}
														onkeydown={(e) => sessionActive && e.key === 'Enter' && (e.preventDefault(), submitSpeed(classKey, reg.id, (e.currentTarget as HTMLInputElement).value))}
														disabled={!sessionActive || speedUpdatingRegId === reg.id}
													/>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
							<div class="speed-rankings">
								<h3 class="speed-subtitle">Rankings</h3>
								{#if (speedRankingsByClass[classKey] || []).length === 0}
									<p class="speed-no-rankings">No speeds recorded yet.</p>
								{:else}
									<ol class="speed-rankings-list">
										{#each speedRankingsByClass[classKey] || [] as item}
											<li class="speed-ranking-item">
												<span class="speed-place">#{item.place}</span>
												<span class="speed-racer-name">{getRacerNameForRegId(item.registration_id)}</span>
												<span class="speed-value">{item.top_speed} mph</span>
											</li>
										{/each}
									</ol>
								{/if}
							</div>
						</div>
					</div>
				{:else}
					<div class="matchups-view">
						{#if (rounds[classKey] || []).length > 0}
							{@const classRounds = rounds[classKey] || []}
							{@const currentRoundNum = currentRounds[classKey] || (classRounds.length > 0 ? classRounds[classRounds.length - 1].number : 0)}
							{@const currentRound = classRounds.find((r: Round) => r.number === currentRoundNum) || null}
							<div class="round-tabs-container">
								<div class="round-tabs">
									{#each classRounds as round (round.number)}
										<button
											type="button"
											class="round-tab"
											class:active={currentRound?.number === round.number}
											onclick={() => setCurrentRound(classKey, round.number)}
										>
											Round {round.number}
										</button>
										<button
											type="button"
											class="round-tab-delete"
											onclick={(e) => {
												e.stopPropagation();
												if (round.id) {
													deleteRoundHandler(classKey, round.id, round.number);
												}
											}}
											title="Delete Round {round.number}"
										>
											×
										</button>
									{/each}
								</div>
								<button
									type="button"
									class="btn btn-primary btn-sm"
									onclick={() => (roundsByClass[classKey]?.length ? resetClassHandler(classKey) : generateMatchups(classKey))}
								>
									{roundsByClass[classKey]?.length ? 'Reset Class' : 'Generate New Round'}
								</button>
							</div>

							{#if currentRound}

								<div class="matchups-list">
									{#each currentRound.matchups as matchup}
										<div class="matchup-card">
											<div class="matchup-bracket-label" class:winner-bracket={matchup.bracket === 'W'} class:loser-bracket={matchup.bracket === 'L'}>
												{matchup.bracket === 'W' ? 'Winner Bracket' : 'Loser Bracket'}
											</div>
											<div class="matchup-racers">
											<div
												class="matchup-racer"
												class:winner={matchup.winner === matchup.racerA.id}
												class:eliminated={(matchup.racerA.losses ?? 0) >= 2}
												draggable={!matchup.winner}
												role="button"
												tabindex={matchup.winner ? undefined : 0}
												ondragstart={(e) => {
														if (!matchup.winner) {
															draggedRacer = {
																classKey,
																round: currentRound.number,
																matchupId: matchup.matchup_id,
																racerId: matchup.racerA.id
															};
															e.dataTransfer!.effectAllowed = 'move';
														}
													}}
													ondragover={(e) => {
														if (draggedRacer && !matchup.winner) {
															e.preventDefault();
															e.dataTransfer!.dropEffect = 'move';
														}
													}}
													ondrop={(e) => {
														e.preventDefault();
														if (draggedRacer && draggedRacer.classKey === classKey && draggedRacer.round === currentRound.number) {
															swapRacers(
																classKey,
																currentRound.number,
																draggedRacer.matchupId,
																draggedRacer.racerId,
																matchup.matchup_id,
																matchup.racerA.id
															);
															draggedRacer = null;
														}
													}}
												>
													<div class="racer-name">{racerDisplay(matchup.racerA)}</div>
													<div class="racer-details">Seed {matchup.seed_a} · Losses: {matchup.racerA.losses ?? 0}</div>
												</div>
												<div class="matchup-vs">VS</div>
												{#if matchup.racerB}
												<div
													class="matchup-racer"
													class:winner={matchup.winner === matchup.racerB.id}
													class:eliminated={(matchup.racerB.losses ?? 0) >= 2}
													draggable={!matchup.winner}
													role="button"
													tabindex={matchup.winner ? undefined : 0}
													ondragstart={(e) => {
															if (!matchup.winner) {
																draggedRacer = {
																	classKey,
																	round: currentRound.number,
																	matchupId: matchup.matchup_id,
																	racerId: matchup.racerB!.id
																};
																e.dataTransfer!.effectAllowed = 'move';
															}
														}}
														ondragover={(e) => {
															if (draggedRacer && !matchup.winner) {
																e.preventDefault();
																e.dataTransfer!.dropEffect = 'move';
															}
														}}
														ondrop={(e) => {
															e.preventDefault();
															if (draggedRacer && draggedRacer.classKey === classKey && draggedRacer.round === currentRound.number) {
																swapRacers(
																	classKey,
																	currentRound.number,
																	draggedRacer.matchupId,
																	draggedRacer.racerId,
																	matchup.matchup_id,
																	matchup.racerB!.id
																);
																draggedRacer = null;
															}
														}}
													>
														<div class="racer-name">{racerDisplay(matchup.racerB)}</div>
														<div class="racer-details">Seed {matchup.seed_b ?? '—'} · Losses: {matchup.racerB.losses ?? 0}</div>
													</div>
												{:else}
													<div class="matchup-racer matchup-bye">Bye</div>
												{/if}
											</div>
											{#if !matchup.winner}
												<div class="matchup-actions-buttons">
												<button
													type="button"
													class="btn btn-primary btn-sm"
													onclick={() => recordMatchupWinner(classKey, currentRound.number, matchup.matchup_id, matchup.racerA.id)}
													disabled={recordingWinnerMatchupId === matchup.matchup_id}
												>
													{racerDisplay(matchup.racerA)} Wins
												</button>
												{#if matchup.racerB}
													<button
														type="button"
														class="btn btn-primary btn-sm"
														onclick={() => recordMatchupWinner(classKey, currentRound.number, matchup.matchup_id, matchup.racerB!.id)}
														disabled={recordingWinnerMatchupId === matchup.matchup_id}
													>
														{racerDisplay(matchup.racerB)} Wins
													</button>
												{/if}
												</div>
											{:else}
												<div class="matchup-winner">
													<div class="matchup-winner-info">
														✓ Winner: <strong>{racerDisplay(matchup.racerA.id === matchup.winner ? matchup.racerA : matchup.racerB!)}</strong>
													</div>
													<button
														type="button"
														class="btn btn-secondary btn-sm"
														onclick={() => undoMatchupWinner(classKey, currentRound.number, matchup.matchup_id)}
													>
														Undo
													</button>
												</div>
												<div class="matchup-admin-section">
													<label class="matchup-admin-label" for="notes-{matchup.matchup_id}">Notes</label>
													<textarea
														id="notes-{matchup.matchup_id}"
														class="matchup-notes-input"
														placeholder="Add notes…"
														value={matchupNotes[matchup.matchup_id] ?? ''}
														oninput={(e) => {
															matchupNotes = { ...matchupNotes, [matchup.matchup_id]: e.currentTarget.value };
														}}
													></textarea>
													<div class="matchup-flags">
														<label class="matchup-flag">
															<input
																type="checkbox"
																checked={matchupProtest[matchup.matchup_id] ?? false}
																onchange={(e) => {
																	matchupProtest = { ...matchupProtest, [matchup.matchup_id]: e.currentTarget.checked };
																}}
															/>
															<span class="matchup-flag-label">Flag for protest</span>
														</label>
														<label class="matchup-flag">
															<input
																type="checkbox"
																checked={matchupUnderReview[matchup.matchup_id] ?? false}
																onchange={(e) => {
																	matchupUnderReview = { ...matchupUnderReview, [matchup.matchup_id]: e.currentTarget.checked };
																}}
															/>
															<span class="matchup-flag-label">Under review</span>
														</label>
													</div>
												</div>
											{/if}
										</div>
									{/each}
								</div>
							{/if}
						{:else}
							<div class="matchup-empty">
								<p>No rounds generated yet. Click "Generate New Round" to create matchups.</p>
								<button
									type="button"
									class="btn btn-primary"
									onclick={() => generateMatchups(classKey)}
								>
									Generate New Round
								</button>
							</div>
						{/if}
					</div>
				{/if}
			</section>
		{/each}
	{/if}
{/if}

<style>
	.manage-class-section {
		margin-bottom: 2rem;
	}
	.manage-class-title {
		font-size: 1.1rem;
		font-weight: 600;
		margin: 0 0 0.75rem 0;
		color: var(--text);
	}
	.class-tabs {
		display: flex;
		gap: 0.5rem;
		border-bottom: 2px solid var(--border);
		margin-bottom: 1rem;
	}
	.class-tab {
		padding: 0.5rem 1rem;
		font-size: 0.9rem;
		font-weight: 500;
		color: var(--text-muted);
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		margin-bottom: -2px;
		cursor: pointer;
		transition: color 0.15s, border-color 0.15s;
	}
	.class-tab:hover {
		color: var(--text);
	}
	.class-tab.active {
		color: var(--primary);
		border-bottom-color: var(--primary);
	}
	.matchups-view {
		margin-top: 1rem;
	}
	.round-tabs-container {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
	}
	.round-tabs {
		display: flex;
		gap: 0.25rem;
		flex: 1;
		flex-wrap: wrap;
	}
	.round-tab {
		padding: 0.4rem 0.75rem;
		font-size: 0.85rem;
		font-weight: 500;
		color: var(--text-muted);
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		cursor: pointer;
		transition: all 0.15s;
		position: relative;
	}
	.round-tab:hover {
		color: var(--text);
		border-color: var(--primary);
	}
	.round-tab.active {
		color: var(--primary);
		border-color: var(--primary);
		background: rgba(14, 165, 233, 0.1);
	}
	.round-tab-delete {
		padding: 0.25rem 0.5rem;
		font-size: 1.2rem;
		line-height: 1;
		color: var(--text-muted);
		background: transparent;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		cursor: pointer;
		transition: all 0.15s;
		margin-left: -0.25rem;
		margin-right: 0.5rem;
	}
	.round-tab-delete:hover {
		color: #ef4444;
		border-color: #ef4444;
		background: rgba(239, 68, 68, 0.1);
	}
	.matchup-empty {
		padding: 2rem;
		text-align: center;
		color: var(--text-muted);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
	}
	.matchups-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.matchup-card {
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 1.5rem;
	}
	.matchup-bracket-label {
		font-size: 0.75rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		margin-bottom: 0.75rem;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		display: inline-block;
	}
	.matchup-bracket-label.winner-bracket {
		background: #dcfce7;
		color: #166534;
	}
	.matchup-bracket-label.loser-bracket {
		background: #fef3c7;
		color: #92400e;
	}
	.matchup-racers {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 1rem;
		flex-wrap: wrap;
	}
	.matchup-racer {
		flex: 1;
		min-width: 150px;
		padding: 0.75rem;
		border: 2px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg);
		transition: all 0.15s;
		cursor: move;
	}
	.matchup-racer:hover {
		border-color: var(--primary);
		background: var(--bg-muted);
	}
	.matchup-racer.winner {
		border-color: var(--primary);
		background: rgba(14, 165, 233, 0.1);
	}
	.matchup-racer.eliminated {
		border-color: #ef4444;
		border-width: 3px;
	}
	.matchup-racer[draggable="false"] {
		cursor: default;
	}
	.matchup-bye {
		flex: 1;
		min-width: 150px;
		padding: 0.75rem;
		text-align: center;
		color: var(--text-muted);
		font-style: italic;
		border: 2px dashed var(--border);
		border-radius: var(--radius);
	}
	.racer-name {
		font-weight: 600;
		font-size: 0.95rem;
		margin-bottom: 0.25rem;
		color: var(--text);
	}
	.racer-details {
		font-size: 0.8rem;
		color: var(--text-muted);
	}
	.matchup-vs {
		font-weight: 600;
		color: var(--text-muted);
		font-size: 0.9rem;
	}
	.matchup-actions-buttons {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}
	.matchup-winner {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 0.75rem;
		background: var(--bg-muted);
		border-radius: var(--radius);
		color: var(--text);
		font-size: 0.9rem;
	}
	.matchup-winner-info {
		flex: 1;
		text-align: center;
	}
	.matchup-admin-section {
		margin-top: 1rem;
		padding-top: 1rem;
		border-top: 1px solid var(--border);
	}
	.matchup-admin-label {
		display: block;
		font-size: 0.8rem;
		font-weight: 600;
		color: var(--text-muted);
		margin-bottom: 0.35rem;
	}
	.matchup-notes-input {
		width: 100%;
		min-height: 60px;
		padding: 0.5rem 0.6rem;
		font: inherit;
		font-size: 0.85rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg-card);
		color: var(--text);
		resize: vertical;
		margin-bottom: 0.75rem;
	}
	.matchup-notes-input::placeholder {
		color: var(--text-muted);
	}
	.matchup-notes-input:focus {
		outline: none;
		border-color: var(--primary);
		box-shadow: 0 0 0 2px rgba(14, 165, 233, 0.2);
	}
	.matchup-flags {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
	}
	.matchup-flag {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		cursor: pointer;
		font-size: 0.85rem;
		color: var(--text);
	}
	.matchup-flag input {
		accent-color: var(--primary);
	}
	.matchup-flag-label {
		user-select: none;
	}

	/* Top speed view */
	.speed-view {
		margin-top: 1rem;
	}
	.speed-session-bar {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		padding: 1rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		margin-bottom: 1.25rem;
	}
	.speed-session-info {
		display: flex;
		flex-wrap: wrap;
		gap: 1rem;
		font-size: 0.95rem;
		color: var(--text);
	}
	.speed-session-info .speed-stopped {
		color: var(--text-muted);
		font-weight: 500;
	}
	.speed-session-info .speed-paused {
		color: var(--warning, #b8860b);
		font-weight: 500;
	}
	.speed-timer {
		font-variant-numeric: tabular-nums;
		font-weight: 600;
		color: var(--primary);
	}
	.speed-timer.ended {
		color: var(--text-muted);
	}
	.speed-session-pre {
		align-items: center;
	}
	.speed-duration-label {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.95rem;
		color: var(--text);
	}
	.speed-duration-input {
		width: 4rem;
		padding: 0.35rem 0.5rem;
		font-size: 0.95rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg);
		color: var(--text);
		text-align: right;
	}
	.speed-session-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
	}
	.speed-content {
		display: grid;
		grid-template-columns: 1fr auto;
		gap: 2rem;
		align-items: start;
	}
	@media (max-width: 768px) {
		.speed-content {
			grid-template-columns: 1fr;
		}
	}
	.speed-subtitle {
		font-size: 1rem;
		font-weight: 600;
		margin: 0 0 0.5rem 0;
		color: var(--text);
	}
	.speed-hint {
		font-size: 0.85rem;
		color: var(--text-muted);
		margin: 0 0 0.75rem 0;
	}
	.speed-table {
		width: 100%;
	}
	.speed-input {
		width: 6rem;
		padding: 0.4rem 0.5rem;
		font-size: 0.95rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg);
		color: var(--text);
		text-align: right;
	}
	.speed-input:focus {
		outline: none;
		border-color: var(--primary);
	}
	.speed-input:disabled {
		opacity: 0.7;
		cursor: not-allowed;
		background: var(--bg-card);
	}
	.speed-table tbody tr.disabled {
		opacity: 0.75;
	}
	.speed-rankings {
		min-width: 220px;
		padding: 1rem;
		background: var(--bg-card);
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.speed-no-rankings {
		font-size: 0.9rem;
		color: var(--text-muted);
		margin: 0;
	}
	.speed-rankings-list {
		margin: 0;
		padding-left: 1.25rem;
		list-style: decimal;
	}
	.speed-ranking-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.35rem 0;
		font-size: 0.95rem;
	}
	.speed-place {
		font-weight: 600;
		color: var(--text-muted);
		min-width: 2rem;
	}
	.speed-racer-name {
		flex: 1;
	}
	.speed-value {
		font-weight: 600;
		color: var(--primary);
	}
</style>

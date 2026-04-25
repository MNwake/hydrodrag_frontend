<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import Modal from '$lib/components/Modal.svelte';
	import { toast } from '$lib/stores/toast';
	import { createRacer, fetchRacers, type RacerCreatePayload, type RacerRow } from '$lib/api/resources';

	type SortKey = 'name' | 'phone' | 'membership_number' | 'waiver_signed_at' | 'is_of_age' | 'has_ihra_membership';
	type SortDir = 'asc' | 'desc';

	const columns: { key: SortKey; label: string }[] = [
		{ key: 'name', label: 'Name' },
		{ key: 'phone', label: 'Phone' },
		{ key: 'membership_number', label: 'Membership number' },
		{ key: 'waiver_signed_at', label: 'Waiver signed at' },
		{ key: 'is_of_age', label: 'Is of age' },
		{ key: 'has_ihra_membership', label: 'Has IHRA membership' }
	];

	let loading = true;
	let error: string | null = null;
	let racers: RacerRow[] = [];
	let searchQuery = '';
	let sortKey: SortKey = 'name';
	let sortDir: SortDir = 'asc';

	let showCreateModal = false;
	let creatingRacer = false;

	let createForm = {
		email: '',
		first_name: '',
		last_name: '',
		date_of_birth: '',
		gender: '',
		nationality: '',
		phone: '',
		emergency_contact_name: '',
		emergency_contact_phone: '',
		street: '',
		city: '',
		state_province: '',
		country: '',
		zip_postal_code: '',
		membership_number: '',
		bio: ''
	};

	function toOptionalString(v: string) {
		const t = v.trim();
		return t ? t : undefined;
	}

	function buildCreatePayload(): RacerCreatePayload {
		const payload: RacerCreatePayload = {
			email: createForm.email.trim(),
			first_name: toOptionalString(createForm.first_name),
			last_name: toOptionalString(createForm.last_name),
			date_of_birth: createForm.date_of_birth.trim() ? createForm.date_of_birth.trim() : undefined,
			gender: toOptionalString(createForm.gender),
			nationality: toOptionalString(createForm.nationality),
			phone: toOptionalString(createForm.phone),
			emergency_contact_name: toOptionalString(createForm.emergency_contact_name),
			emergency_contact_phone: toOptionalString(createForm.emergency_contact_phone),
			street: toOptionalString(createForm.street),
			city: toOptionalString(createForm.city),
			state_province: toOptionalString(createForm.state_province),
			country: toOptionalString(createForm.country),
			zip_postal_code: toOptionalString(createForm.zip_postal_code),
			membership_number: toOptionalString(createForm.membership_number),
			bio: toOptionalString(createForm.bio)
		};
		return payload;
	}

	async function handleCreateRacer() {
		if (creatingRacer) return;

		const email = createForm.email.trim();
		const firstName = createForm.first_name.trim();
		const lastName = createForm.last_name.trim();

		if (!email) {
			toast('Email is required', 'error');
			return;
		}
		if (!firstName || !lastName) {
			toast('First and last name are required', 'error');
			return;
		}

		creatingRacer = true;
		const payload = buildCreatePayload();
		const res = await createRacer(payload);
		creatingRacer = false;

		if (res.ok && res.data) {
			toast('Racer created', 'success');
			showCreateModal = false;
			const newId = res.data.id;
			// Reset form so the next create starts clean.
			createForm = {
				email: '',
				first_name: '',
				last_name: '',
				date_of_birth: '',
				gender: '',
				nationality: '',
				phone: '',
				emergency_contact_name: '',
				emergency_contact_phone: '',
				street: '',
				city: '',
				state_province: '',
				country: '',
				zip_postal_code: '',
				membership_number: '',
				bio: ''
			};
			await goto(`/racers/${newId}`);
			return;
		}

		toast(res.error ?? 'Failed to create racer', 'error');
	}

	function fullName(r: RacerRow): string {
		const full = (r.full_name ?? '').toString().trim();
		return full || '—';
	}

	function formatWaiverSignedAt(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString();
	}

	function matchesSearch(r: RacerRow, q: string): boolean {
		const trimmed = q.trim();
		if (!trimmed) return true;
		const s = trimmed.toLowerCase();
		const name = fullName(r).toLowerCase();
		const email = (r.email ?? '').toLowerCase();
		const phone = (r.phone ?? '').replace(/\D/g, '');
		const phoneQuery = s.replace(/\D/g, '');
		return (
			name.includes(s) ||
			email.includes(s) ||
			(phoneQuery.length > 0 && phone.includes(phoneQuery))
		);
	}

	function sortValue(r: RacerRow, key: SortKey): string | number {
		switch (key) {
			case 'name':
				return fullName(r);
			case 'phone':
				return r.phone ?? '';
			case 'membership_number':
				return r.membership_number ?? '';
			case 'waiver_signed_at':
				return r.waiver_signed_at ?? '';
			case 'is_of_age':
				return r.is_of_age === true ? 'Yes' : 'No';
			case 'has_ihra_membership':
				return r.membership_number != null && String(r.membership_number).trim() !== '' ? 'Yes' : 'No';
			default:
				return '';
		}
	}

	function applySearchAndSort(
		list: RacerRow[],
		query: string,
		key: SortKey,
		dir: SortDir
	): RacerRow[] {
		let out = list.filter((r) => matchesSearch(r, query));
		out = [...out].sort((a, b) => {
			const va = sortValue(a, key);
			const vb = sortValue(b, key);
			const c =
				key === 'name'
					? String(va).localeCompare(String(vb), undefined, { sensitivity: 'base' })
					: (va < vb ? -1 : va > vb ? 1 : 0);
			return dir === 'asc' ? c : -c;
		});
		return out;
	}

	$: filtered = applySearchAndSort(racers, searchQuery, sortKey, sortDir);

	function goToProfile(id: string) {
		goto(`/racers/${id}`);
	}

	function toggleSort(key: SortKey) {
		if (sortKey === key) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortKey = key;
			sortDir = 'asc';
		}
	}

	onMount(async () => {
		loading = true;
		error = null;
		const res = await fetchRacers();
		loading = false;
		if (!res.ok) {
			error = res.error ?? `HTTP ${res.status}`;
			return;
		}
		racers = (res.data ?? []) as RacerRow[];
	});
</script>

<div class="page-header">
	<div style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
		<div>
			<h1 class="page-title">Racers</h1>
			<p class="page-subtitle">All registered racers</p>
		</div>
		<button
			type="button"
			class="btn btn-primary"
			on:click={() => (showCreateModal = true)}
			disabled={creatingRacer || loading}
		>
			{creatingRacer ? 'Creating…' : '+ Create racer'}
		</button>
	</div>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else}
	<div class="racers-toolbar">
		<div class="racers-search">
			<label for="racers-search-input">Search</label>
			<input
				id="racers-search-input"
				type="text"
				placeholder="Name, phone, or email…"
				bind:value={searchQuery}
				autocomplete="off"
			/>
		</div>
	</div>

	<p class="racers-count">
		{filtered.length} racer{filtered.length === 1 ? '' : 's'}
		{#if filtered.length !== racers.length}
			(of {racers.length})
		{/if}
	</p>

	<div class="data-table-wrap">
		<table class="data-table">
			<thead>
				<tr>
					{#each columns as col}
						<th>
							<button
								type="button"
								class="th-sort"
								class:active={sortKey === col.key}
								on:click={() => toggleSort(col.key)}
							>
								{col.label}
								{#if sortKey === col.key}
									<span class="th-sort-icon" aria-hidden="true">{sortDir === 'asc' ? '↑' : '↓'}</span>
								{/if}
							</button>
						</th>
					{/each}
				</tr>
			</thead>
			<tbody>
				{#if filtered.length === 0}
					<tr class="data-table-empty-row">
						<td colspan={columns.length} class="racers-empty center">
							{searchQuery.trim() ? 'No racers match your search.' : 'No racers.'}
						</td>
					</tr>
				{:else}
					{#each filtered as r}
						<tr
							class="racers-row-link"
							role="button"
							tabindex="0"
							on:click={() => goToProfile(r.id)}
							on:keydown={(e) => (e.key === 'Enter' || e.key === ' ') && (e.preventDefault(), goToProfile(r.id))}
						>
							<td data-label="Name">{fullName(r)}</td>
							<td data-label="Phone">{r.phone ?? '—'}</td>
							<td data-label="Membership #">{r.membership_number ?? '—'}</td>
							<td data-label="Waiver">{formatWaiverSignedAt(r.waiver_signed_at)}</td>
							<td data-label="Of age">{r.is_of_age === true ? 'Yes' : 'No'}</td>
							<td data-label="Member">{r.membership_number != null && String(r.membership_number).trim() !== '' ? 'Yes' : 'No'}</td>
						</tr>
					{/each}
				{/if}
			</tbody>
		</table>
	</div>
{/if}

<Modal bind:open={showCreateModal} title="Create racer">
	<form id="create-racer-form" on:submit|preventDefault={handleCreateRacer}>
		<div class="form-card" style="margin-bottom: 0;">
			<div class="form-section">
				<h2 class="form-section-title">Identity</h2>
				<div class="form-grid">
					<div class="form-group" style="grid-column: span 2;">
						<label for="create-racer-email">Email <span class="label-required" aria-hidden="true">*</span></label>
						<input
							id="create-racer-email"
							type="email"
							bind:value={createForm.email}
							autocomplete="off"
							spellcheck="false"
						/>
					</div>
					<div class="form-group">
						<label for="create-racer-first-name">First name <span class="label-required" aria-hidden="true">*</span></label>
						<input id="create-racer-first-name" type="text" bind:value={createForm.first_name} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-last-name">Last name <span class="label-required" aria-hidden="true">*</span></label>
						<input id="create-racer-last-name" type="text" bind:value={createForm.last_name} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-dob">Date of birth</label>
						<input id="create-racer-dob" type="date" bind:value={createForm.date_of_birth} />
					</div>
					<div class="form-group">
						<label for="create-racer-phone">Phone</label>
						<input id="create-racer-phone" type="text" bind:value={createForm.phone} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-gender">Gender</label>
						<input id="create-racer-gender" type="text" bind:value={createForm.gender} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-nationality">Nationality</label>
						<input
							id="create-racer-nationality"
							type="text"
							bind:value={createForm.nationality}
							autocomplete="off"
						/>
					</div>
					<div class="form-group">
						<label for="create-racer-membership-number">Membership number</label>
						<input
							id="create-racer-membership-number"
							type="text"
							bind:value={createForm.membership_number}
							autocomplete="off"
						/>
					</div>
				</div>
			</div>

			<div class="form-section">
				<h2 class="form-section-title">Emergency contact</h2>
				<div class="form-grid">
					<div class="form-group">
						<label for="create-racer-emergency-contact-name">Name</label>
						<input
							id="create-racer-emergency-contact-name"
							type="text"
							bind:value={createForm.emergency_contact_name}
							autocomplete="off"
						/>
					</div>
					<div class="form-group">
						<label for="create-racer-emergency-contact-phone">Phone</label>
						<input
							id="create-racer-emergency-contact-phone"
							type="text"
							bind:value={createForm.emergency_contact_phone}
							autocomplete="off"
						/>
					</div>
				</div>
			</div>

			<div class="form-section">
				<h2 class="form-section-title">Address</h2>
				<div class="form-grid">
					<div class="form-group" style="grid-column: span 2;">
						<label for="create-racer-street">Street</label>
						<input id="create-racer-street" type="text" bind:value={createForm.street} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-city">City</label>
						<input id="create-racer-city" type="text" bind:value={createForm.city} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-state-province">State / Province</label>
						<input
							id="create-racer-state-province"
							type="text"
							bind:value={createForm.state_province}
							autocomplete="off"
						/>
					</div>
					<div class="form-group">
						<label for="create-racer-country">Country</label>
						<input id="create-racer-country" type="text" bind:value={createForm.country} autocomplete="off" />
					</div>
					<div class="form-group">
						<label for="create-racer-zip-postal-code">ZIP / Postal</label>
						<input
							id="create-racer-zip-postal-code"
							type="text"
							bind:value={createForm.zip_postal_code}
							autocomplete="off"
						/>
					</div>
				</div>
			</div>

			<div class="form-section">
				<h2 class="form-section-title">Notes</h2>
				<div class="form-grid">
					<div class="form-group" style="grid-column: span 2;">
						<label for="create-racer-bio">Bio</label>
						<textarea
							id="create-racer-bio"
							bind:value={createForm.bio}
							placeholder="Optional notes about the racer"
						></textarea>
					</div>
				</div>
			</div>

			<div class="form-actions">
				<button type="button" class="btn btn-secondary" on:click={() => (showCreateModal = false)} disabled={creatingRacer}>
					Cancel
				</button>
				<button type="submit" class="btn btn-primary" disabled={creatingRacer}>
					{creatingRacer ? 'Creating…' : 'Create'}
				</button>
			</div>
		</div>
	</form>
</Modal>

<style>
	.label-required {
		color: var(--error);
		font-weight: 600;
	}

	.racers-toolbar {
		margin-bottom: 1rem;
	}
	.racers-search {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		max-width: 320px;
	}
	.racers-search label {
		font-size: 0.85rem;
		font-weight: 500;
		color: var(--text-muted);
	}
	.racers-search input {
		padding: 0.5rem 0.75rem;
		font-size: 0.95rem;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg-card);
		color: var(--text);
	}
	.racers-search input::placeholder {
		color: var(--text-muted);
	}
	.racers-search input:focus {
		outline: none;
		border-color: var(--primary);
		box-shadow: 0 0 0 2px rgba(14, 165, 233, 0.2);
	}
	.racers-count {
		font-size: 0.9rem;
		color: var(--text-muted);
		margin: 0 0 1rem;
	}
	.th-sort {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		padding: 0.35rem 0.5rem;
		margin: -0.35rem -0.5rem;
		font: inherit;
		font-weight: 600;
		color: var(--text);
		background: transparent;
		border: none;
		border-radius: var(--radius);
		cursor: pointer;
		text-align: left;
		transition: background 0.15s;
	}
	.th-sort:hover {
		background: var(--bg-muted);
	}
	.th-sort:focus {
		outline: none;
		box-shadow: 0 0 0 2px var(--primary);
	}
	.th-sort.active {
		color: var(--primary);
	}
	.th-sort-icon {
		font-size: 0.85em;
		opacity: 0.9;
	}
	.racers-row-link {
		cursor: pointer;
		transition: background 0.15s;
	}
	.racers-row-link:hover {
		background: var(--bg-muted);
	}
	.racers-row-link:focus {
		outline: none;
		background: var(--bg-muted);
		box-shadow: inset 0 0 0 2px var(--primary);
	}
	.racers-empty {
		text-align: center;
		color: var(--text-muted);
		padding: 2rem !important;
	}
</style>

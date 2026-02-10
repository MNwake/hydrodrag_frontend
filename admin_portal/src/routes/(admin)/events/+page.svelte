<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import {
		fetchEvents,
		createEvent,
		type EventBase
	} from '$lib/api/events';
	import { toast } from '$lib/stores/toast';

	type SortKey = 'name' | 'start_date' | 'registration_status' | 'is_published';
	type SortDir = 'asc' | 'desc';

	let loading = true;
	let error: string | null = null;
	let events: EventBase[] = [];
	let sortKey: SortKey = 'start_date';
	let sortDir: SortDir = 'desc';
	let creatingEvent = false;

	const columns: { key: SortKey; label: string; sortable?: boolean }[] = [
		{ key: 'name', label: 'Name', sortable: true },
		{ key: 'start_date', label: 'Start date', sortable: true },
		{ key: 'registration_status', label: 'Status', sortable: true },
		{ key: 'is_published', label: 'Published', sortable: true }
	];

	async function load() {
		loading = true;
		error = null;
		const res = await fetchEvents(1, 100);
		loading = false;
		if (!res.ok) {
			error = res.error ?? `HTTP ${res.status}`;
			return;
		}
		events = res.data?.events ?? [];
	}

	function goToManage(id: string, e?: MouseEvent | KeyboardEvent) {
		// Don't navigate if clicking on a button or link
		if (e) {
			const target = e.target as HTMLElement;
			if (target.closest('button, a')) {
				return;
			}
		}
		goto(`/events/${id}/manage`);
	}

	function formatDate(iso: string) {
		return iso ? iso.slice(0, 10) : '—';
	}

	async function handleAddEvent() {
		if (creatingEvent) return;
		creatingEvent = true;
		
		// Create empty event with minimal payload - backend will provide defaults
		const emptyPayload = {
			name: 'New Event',
			description: null,
			start_date: new Date().toISOString().split('T')[0],
			end_date: null,
			registration_open_date: null,
			registration_close_date: null,
			location: {
				name: '',
				address: null,
				city: null,
				state: null,
				zip_code: null,
				country: null,
				latitude: null,
				longitude: null,
				full_address: null
			},
			schedule: [],
			event_info: {
				parking: null,
				tickets: null,
				food_and_drink: null,
				seating: null,
				additional_info: {}
			}
		};
		
		const res = await createEvent(emptyPayload);
		creatingEvent = false;
		
		if (res.ok && res.data) {
			toast('Event created', 'success');
			await goto(`/events/${res.data.id}`);
		} else {
			toast(res.error ?? 'Failed to create event', 'error');
		}
	}

	function sortValue(evt: EventBase, key: SortKey): string | number | boolean {
		switch (key) {
			case 'name':
				return evt.name.toLowerCase();
			case 'start_date':
				return evt.start_date;
			case 'registration_status':
				return evt.registration_status;
			case 'is_published':
				return evt.is_published;
			default:
				return '';
		}
	}

	function toggleSort(key: SortKey) {
		if (sortKey === key) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortKey = key;
			sortDir = 'asc';
		}
	}

	$: sortedEvents = [...events].sort((a, b) => {
		const va = sortValue(a, sortKey);
		const vb = sortValue(b, sortKey);
		let c = 0;
		if (typeof va === 'string' && typeof vb === 'string') {
			c = va.localeCompare(vb, undefined, { sensitivity: 'base' });
		} else if (va < vb) {
			c = -1;
		} else if (va > vb) {
			c = 1;
		}
		return sortDir === 'asc' ? c : -c;
	});

	$: tableRows = sortedEvents.map((evt) => ({
		name: evt.name,
		start_date: formatDate(evt.start_date),
		registration_status: evt.registration_status,
		is_published: evt.is_published ? 'Yes' : 'No',
		_event: evt
	}));

	onMount(load);
</script>

<div class="page-header" style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
	<div>
		<h1 class="page-title">Events</h1>
		<p class="page-subtitle">Add, edit, and delete events. Manage schedules and rules.</p>
	</div>
	<button
		type="button"
		class="btn btn-primary"
		onclick={handleAddEvent}
		disabled={creatingEvent}
	>
		{creatingEvent ? 'Creating…' : '+ Add event'}
	</button>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if events.length === 0}
	<div class="data-table-wrap">
		<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
			No events yet. <a href="/events/new">Create one</a>.
		</div>
	</div>
{:else}
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
								onclick={() => toggleSort(col.key)}
							>
								{col.label}
								{#if sortKey === col.key}
									<span class="th-sort-icon" aria-hidden="true">{sortDir === 'asc' ? '↑' : '↓'}</span>
								{/if}
							</button>
						</th>
					{/each}
					<th style="width: 1%; white-space: nowrap;">Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each tableRows as row}
					{@const evt = row._event}
					<tr
						class="events-row-link"
						role="button"
						tabindex="0"
						onclick={(e) => goToManage(evt.id, e)}
						onkeydown={(e) => {
							if (e.key === 'Enter' || e.key === ' ') {
								e.preventDefault();
								goToManage(evt.id);
							}
						}}
					>
						<td data-label="Name">{row.name}</td>
						<td data-label="Start date">{row.start_date}</td>
						<td data-label="Status">{row.registration_status}</td>
						<td data-label="Published">{row.is_published}</td>
						<td data-label="Actions">
							<a
								href="/events/{evt.id}"
								class="btn btn-secondary btn-sm"
								onclick={(e) => e.stopPropagation()}
							>
								Edit
							</a>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

<style>
	.events-row-link {
		cursor: pointer;
		transition: background 0.15s;
	}
	.events-row-link:hover {
		background: var(--bg-muted);
	}
	.events-row-link:focus {
		outline: none;
		background: var(--bg-muted);
		box-shadow: inset 0 0 0 2px var(--primary);
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
		width: 100%;
		justify-content: flex-start;
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
</style>

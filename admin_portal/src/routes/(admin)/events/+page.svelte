<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import {
		fetchEvents,
		createEvent,
		duplicateEvent,
		markEventComplete,
		type EventBase,
		type EventStatus
	} from '$lib/api/events';
	import { toast } from '$lib/stores/toast';
	import { isStaffPortal } from '$lib/admin-auth';

	type SortKey = 'name' | 'start_date' | 'event_status' | 'is_published';
	type SortDir = 'asc' | 'desc';

	let loading = true;
	let error: string | null = null;
	let events: EventBase[] = [];
	let sortKey: SortKey = 'start_date';
	let sortDir: SortDir = 'desc';
	let creatingEvent = false;
	let showCompleted = false;

	const staffPortal = isStaffPortal();

	const columns: { key: SortKey; label: string; sortable?: boolean }[] = [
		{ key: 'name', label: 'Name', sortable: true },
		{ key: 'start_date', label: 'Start date', sortable: true },
		{ key: 'event_status', label: 'Status', sortable: true },
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

	function statusLabel(status: EventStatus): string {
		if (status === 'completed') return 'Completed';
		if (status === 'posted') return 'Posted';
		return 'Draft';
	}

	async function handleAddEvent() {
		if (creatingEvent || staffPortal) return;
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
			case 'event_status':
				return evt.event_status;
			case 'is_published':
				return evt.is_published;
			default:
				return '';
		}
	}

	async function handleMarkComplete(evt: EventBase) {
		const res = await markEventComplete(evt.id);
		if (res.ok) {
			toast('Event marked complete', 'success');
			await load();
		} else {
			toast(res.error ?? 'Failed to mark event complete', 'error');
		}
	}

	async function handleDuplicate(evt: EventBase) {
		const now = new Date();
		const start = new Date(evt.start_date || now.toISOString());
		start.setDate(start.getDate() + 7);
		const end = evt.end_date ? new Date(evt.end_date) : null;
		if (end) {
			const durationMs = end.getTime() - new Date(evt.start_date).getTime();
			end.setTime(start.getTime() + durationMs);
		}
		const res = await duplicateEvent(evt.id, {
			name: `${evt.name} Copy`,
			start_date: start.toISOString(),
			end_date: end ? end.toISOString() : null
		});
		if (res.ok && res.data) {
			toast('Event duplicated as draft', 'success');
			await goto(`/events/${res.data.id}`);
		} else {
			toast(res.error ?? 'Failed to duplicate event', 'error');
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

	$: visibleEvents = events.filter(
		(evt) => showCompleted || evt.event_status !== 'completed'
	);

	$: sortedEvents = [...visibleEvents].sort((a, b) => {
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
		event_status: evt.event_status,
		is_published: evt.is_published ? 'Yes' : 'No',
		_event: evt
	}));

	onMount(load);
</script>

<div class="page-header" style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
	<div>
		<h1 class="page-title">Events</h1>
		<p class="page-subtitle">
			{staffPortal
				? 'View events. Open an event for registrations and brackets (view-only).'
				: 'Add, edit, and delete events. Manage schedules and rules.'}
		</p>
	</div>
	{#if !staffPortal}
		<button
			type="button"
			class="btn btn-primary"
			onclick={handleAddEvent}
			disabled={creatingEvent}
		>
			{creatingEvent ? 'Creating…' : '+ Add event'}
		</button>
	{/if}
</div>

<div class="events-toolbar">
	<label class="events-filter-checkbox">
		<input type="checkbox" bind:checked={showCompleted} />
		Show completed events
	</label>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else if visibleEvents.length === 0}
	<div class="data-table-wrap">
		<div style="padding: 2rem; text-align: center; color: var(--text-muted);">
			{#if events.length === 0}
				No events yet.{#if !staffPortal} <a href="/events/new">Create one</a>.{/if}
			{:else}
				No active events.{#if !showCompleted} Check "Show completed events" to view past events.{/if}
			{/if}
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
						<td data-label="Status">
							<span class="status-pill status-{row.event_status}">{statusLabel(row.event_status as EventStatus)}</span>
						</td>
						<td data-label="Published">{row.is_published}</td>
						<td data-label="Actions">
							<div class="event-actions" role="group" aria-label="Event actions">
								{#if !staffPortal}
									<button
										type="button"
										class="btn-icon"
										title="Duplicate event"
										aria-label="Duplicate event"
										onclick={(e) => {
											e.stopPropagation();
											void handleDuplicate(evt);
										}}
									>
										<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
											<rect x="9" y="9" width="13" height="13" rx="2" />
											<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
										</svg>
									</button>
									{#if evt.event_status !== 'completed'}
										<button
											type="button"
											class="btn-icon btn-icon-success"
											title="Mark complete"
											aria-label="Mark complete"
											onclick={(e) => {
												e.stopPropagation();
												void handleMarkComplete(evt);
											}}
										>
											<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
												<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
												<polyline points="22 4 12 14.01 9 11.01" />
											</svg>
										</button>
									{/if}
								{/if}
								<a
									href="/events/{evt.id}"
									class="btn-icon"
									title={staffPortal ? 'View event' : 'Edit event'}
									aria-label={staffPortal ? 'View event' : 'Edit event'}
									onclick={(e) => e.stopPropagation()}
								>
									{#if staffPortal}
										<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
											<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
											<circle cx="12" cy="12" r="3" />
										</svg>
									{:else}
										<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
											<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
											<path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
										</svg>
									{/if}
								</a>
							</div>
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
	.status-pill {
		display: inline-block;
		padding: 0.125rem 0.5rem;
		border-radius: 999px;
		font-size: 0.8rem;
		font-weight: 600;
	}
	.status-draft {
		background: #f3f4f6;
		color: #374151;
	}
	.status-posted {
		background: #dcfce7;
		color: #166534;
	}
	.status-completed {
		background: #dbeafe;
		color: #1e40af;
	}
	.events-toolbar {
		margin-bottom: 1rem;
		display: flex;
		gap: 0.75rem;
		align-items: center;
	}
	.events-filter-checkbox {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.9rem;
		color: var(--text-muted);
		cursor: pointer;
		user-select: none;
	}
	.events-filter-checkbox input {
		cursor: pointer;
	}
	.event-actions {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		flex-wrap: nowrap;
	}
	.btn-icon {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 2rem;
		height: 2rem;
		padding: 0;
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--bg-card);
		color: var(--text-muted);
		cursor: pointer;
		transition: background 0.15s, color 0.15s, border-color 0.15s;
		text-decoration: none;
		flex-shrink: 0;
	}
	.btn-icon:hover {
		background: var(--bg-muted);
		color: var(--text);
		border-color: var(--text-muted);
	}
	.btn-icon:focus {
		outline: none;
		box-shadow: 0 0 0 2px var(--primary);
	}
	.btn-icon svg {
		width: 1rem;
		height: 1rem;
	}
	.btn-icon-success:hover {
		color: #166534;
		border-color: #86efac;
		background: #f0fdf4;
	}
</style>

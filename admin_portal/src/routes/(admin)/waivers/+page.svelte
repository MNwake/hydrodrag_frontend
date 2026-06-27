<script lang="ts">
	import { onMount } from 'svelte';
	import DataTable from '$lib/components/DataTable.svelte';
	import { fetchWaivers, type WaiverListItem } from '$lib/api/waivers';
	import { formatDateTimeLocal } from '$lib/format/datetime';

	let rows: WaiverListItem[] = [];
	let loading = true;
	let error: string | null = null;

	onMount(async () => {
		const res = await fetchWaivers({ limit: 200 });
		loading = false;
		if (!res.ok) {
			error = res.error ?? 'Failed to load waivers';
			return;
		}
		rows = res.data ?? [];
	});

	const columns = [
		{ key: 'event_name', label: 'Event', sortable: true },
		{ key: 'racer_name', label: 'Racer', sortable: true },
		{ key: 'typed_legal_name', label: 'Legal name', sortable: true },
		{ key: 'signed_at_utc', label: 'Signed', sortable: true },
		{ key: 'waiver_version', label: 'Version', sortable: true, class: 'center' }
	];

	$: tableRows = rows.map((r) => ({
		...r,
		racer_name: r.racer_name || r.racer_email || r.racer_id,
		signed_at_utc: formatDateTimeLocal(r.signed_at_utc)
	}));
</script>

<svelte:head>
	<title>Waivers — HydroDrags Admin</title>
</svelte:head>

<div class="page-header">
	<h1>Event Waivers</h1>
	<p class="muted">Immutable evidence packages — read only</p>
</div>

{#if loading}
	<p>Loading…</p>
{:else if error}
	<p class="error">{error}</p>
{:else}
	<DataTable
		{columns}
		rows={tableRows}
		rowHref={(row) => `/waivers/${row.id}`}
		emptyMessage="No signed waivers yet."
	/>
{/if}

<style>
	.page-header {
		margin-bottom: 1.5rem;
	}
	.muted {
		color: var(--color-text-muted, #666);
		margin-top: 0.25rem;
	}
	.error {
		color: #c00;
	}
</style>

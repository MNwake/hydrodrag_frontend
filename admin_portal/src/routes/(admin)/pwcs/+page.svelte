<script lang="ts">
	import { onMount } from 'svelte';
	import DataTable from '$lib/components/DataTable.svelte';
	import { fetchPwcs, type PwcRow } from '$lib/api/resources';

	let loading = true;
	let error: string | null = null;
	let rows: Record<string, unknown>[] = [];

	const columns = [
		{ key: 'id', label: 'ID' },
		{ key: 'make', label: 'Make' },
		{ key: 'model', label: 'Model' },
		{ key: 'engine_class', label: 'Engine class' },
		{ key: 'is_primary', label: 'Primary' }
	];

	onMount(async () => {
		loading = true;
		error = null;
		const res = await fetchPwcs();
		loading = false;
		if (!res.ok) {
			error = res.error ?? `HTTP ${res.status}`;
			return;
		}
		const raw = (res.data ?? []) as PwcRow[];
		rows = raw.map((p) => ({
			id: p.id,
			make: p.make ?? '—',
			model: p.model ?? '—',
			engine_class: p.engine_class ?? '—',
			is_primary: p.is_primary ?? false
		}));
	});
</script>

<div class="page-header">
	<h1 class="page-title">PWCs</h1>
	<p class="page-subtitle">All PWCs (placeholder until backend adds GET /admin/pwcs or GET /pwcs)</p>
</div>

{#if loading}
	<div class="loading-placeholder">Loading…</div>
{:else if error}
	<div class="error-placeholder">{error}</div>
{:else}
	<DataTable {columns} {rows} emptyMessage="No PWCs. Backend endpoint not yet implemented." />
{/if}

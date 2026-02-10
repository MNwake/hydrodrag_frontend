<script lang="ts">
	/**
	 * Generic DataTable for admin read-only tables.
	 * columns: { key, label, class?: 'num' | 'center', sortable?: boolean }[]
	 * rows: Record<string, unknown>[]
	 * sortKey: optional key to sort by
	 * sortDir: 'asc' | 'desc'
	 */

	type SortDir = 'asc' | 'desc';

	export let columns: { key: string; label: string; class?: 'num' | 'center' | 'seed'; sortable?: boolean }[] = [];
	export let rows: Record<string, unknown>[] = [];
	export let emptyMessage = 'No data';
	export let sortKey: string | null = null;
	export let sortDir: SortDir = 'asc';
	export let onSort: ((key: string) => void) | null = null;
	export let onRowClick: ((row: Record<string, unknown>) => void) | null = null;

	function cellValue(row: Record<string, unknown>, key: string): string {
		const v = row[key];
		if (v == null) return '—';
		if (typeof v === 'boolean') return v ? 'Yes' : 'No';
		if (v instanceof Date) return v.toISOString().slice(0, 10);
		return String(v);
	}

	function handleSort(key: string) {
		if (onSort) {
			onSort(key);
		}
	}
</script>

<div class="data-table-wrap">
	<table class="data-table">
		<thead>
			<tr>
				{#each columns as col}
					<th class={col.class ?? ''}>
						{#if col.sortable !== false && onSort}
							<button
								type="button"
								class="th-sort"
								class:active={sortKey === col.key}
								onclick={() => handleSort(col.key)}
							>
								{col.label}
								{#if sortKey === col.key}
									<span class="th-sort-icon" aria-hidden="true">{sortDir === 'asc' ? '↑' : '↓'}</span>
								{/if}
							</button>
						{:else}
							{col.label}
						{/if}
					</th>
				{/each}
			</tr>
		</thead>
		<tbody>
			{#if rows.length === 0}
				<tr class="data-table-empty-row">
					<td colspan={columns.length} class="center" style="padding: 2rem; color: var(--text-muted);">
						{emptyMessage}
					</td>
				</tr>
			{:else}
				{#each rows as row, index (row.id ?? index)}
					<tr
						role={onRowClick ? 'button' : undefined}
						tabindex={onRowClick ? 0 : undefined}
						class:clickable={onRowClick}
						onclick={(e) => {
							e.preventDefault();
							onRowClick?.(row);
						}}
						onkeydown={(e) => {
							if (onRowClick && (e.key === 'Enter' || e.key === ' ')) {
								e.preventDefault();
								onRowClick(row);
							}
						}}
					>
						{#each columns as col}
							<td class={col.class ?? ''} data-label={col.label}>{cellValue(row, col.key)}</td>
						{/each}
					</tr>
				{/each}
			{/if}
		</tbody>
	</table>
</div>

<style>
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
	tr.clickable {
		cursor: pointer;
		transition: background 0.15s;
	}
	tr.clickable:hover {
		background: var(--bg-muted);
	}
	tr.clickable:focus {
		outline: none;
		box-shadow: inset 0 0 0 2px var(--primary);
	}
</style>

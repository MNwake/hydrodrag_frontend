<script lang="ts">
	import { BracketTreeLayout, type BracketDisplayMatchup, type BracketLayoutMetrics } from '$lib/brackets/bracketTreeLayout';
	import BracketMatchupBox from './BracketMatchupBox.svelte';

	let {
		layout,
		roundIndex,
		matchups,
		isLastRound,
		useTreeLayout
	}: {
		layout: BracketTreeLayout;
		roundIndex: number;
		matchups: BracketDisplayMatchup[];
		isLastRound: boolean;
		useTreeLayout: boolean;
	} = $props();

	const metrics: BracketLayoutMetrics = layout.metrics;

	const contentHeight = $derived(
		useTreeLayout ? layout.columnContentHeight(roundIndex) : 0
	);

	const connectorPaths = $derived(
		!isLastRound && useTreeLayout && contentHeight > 0
			? layout.connectorSegments(roundIndex, contentHeight)
			: []
	);
</script>

{#if matchups.length === 0}
	<!-- empty -->
{:else if !useTreeLayout}
	<div class="bracket-round-compact">
		{#each matchups as matchup, i (matchup.matchupId)}
			{#if i > 0}
				<div style="height: {metrics.compactMatchupGap}px"></div>
			{/if}
			<BracketMatchupBox {matchup} {metrics} />
		{/each}
	</div>
{:else}
	<div class="bracket-round-tree">
		<div
			class="bracket-round-matchups"
			style="width: {metrics.boxWidth}px; height: {contentHeight}px;"
		>
			{#each matchups as matchup, i (matchup.matchupId)}
				<div
					class="bracket-matchup-position"
					style="top: {layout.matchupTop(roundIndex, i)}px; width: {metrics.boxWidth}px;"
				>
					<BracketMatchupBox {matchup} {metrics} />
				</div>
			{/each}
		</div>
		{#if !isLastRound}
			<svg
				class="bracket-connector"
				width={metrics.connectorWidth}
				height={contentHeight}
				aria-hidden="true"
			>
				{#each connectorPaths as d}
					<path {d} fill="none" stroke="#999" stroke-width={1.5} />
				{/each}
			</svg>
		{/if}
	</div>
{/if}

<style>
	.bracket-round-compact {
		display: flex;
		flex-direction: column;
	}
	.bracket-round-tree {
		display: flex;
		flex-direction: row;
		align-items: flex-start;
	}
	.bracket-round-matchups {
		position: relative;
		flex-shrink: 0;
	}
	.bracket-matchup-position {
		position: absolute;
		left: 0;
	}
	.bracket-connector {
		flex-shrink: 0;
		overflow: visible;
	}
</style>

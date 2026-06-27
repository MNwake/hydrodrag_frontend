<script lang="ts">
	import {
		BracketTreeLayout,
		createBracketMetrics,
		type BracketDisplayRound
	} from '$lib/brackets/bracketTreeLayout';
	import BracketRoundColumn from './BracketRoundColumn.svelte';

	let {
		title,
		rounds,
		layoutScale = 1
	}: {
		title: string;
		rounds: BracketDisplayRound[];
		layoutScale?: number;
	} = $props();

	const metrics = $derived(createBracketMetrics(layoutScale));
	const matchupRounds = $derived(rounds.map((r) => r.matchups));
	const treeLayout = $derived(new BracketTreeLayout(metrics, matchupRounds));
	const useTreeLayout = $derived(rounds.length > 1);
	const roundLabelHeight = 26;
</script>

{#if rounds.length > 0}
	<section class="bracket-section">
		<h3 class="bracket-section-title">{title}</h3>
		<div class="bracket-section-columns">
			{#each rounds as round, r (round.roundNumber)}
				<div class="bracket-round-wrap">
					<div class="bracket-round-label" style="height: {roundLabelHeight}px">
						{r === rounds.length - 1 && rounds.length > 1 ? 'Finals' : `Round ${round.roundNumber}`}
					</div>
					<BracketRoundColumn
						layout={treeLayout}
						roundIndex={r}
						matchups={round.matchups}
						isLastRound={r === rounds.length - 1}
						{useTreeLayout}
					/>
				</div>
				{#if r < rounds.length - 1}
					<div
						class="bracket-round-spacer"
						style="width: {useTreeLayout ? 4 * metrics.layoutScale : 12 * metrics.layoutScale}px"
					></div>
				{/if}
			{/each}
		</div>
	</section>
{/if}

<style>
	.bracket-section {
		margin: 0;
		padding: 0;
		background: #fff;
	}
	.bracket-section-title {
		margin: 0 0 1rem;
		padding-bottom: 0.6rem;
		font-size: 1.1rem;
		font-weight: 700;
		color: #111;
		border-bottom: 1px solid #ccc;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.bracket-section-columns {
		display: flex;
		flex-direction: row;
		align-items: flex-start;
	}
	.bracket-round-wrap {
		flex-shrink: 0;
	}
	.bracket-round-label {
		display: flex;
		align-items: center;
		font-size: 0.9rem;
		font-weight: 600;
		color: #333;
	}
	.bracket-round-spacer {
		flex-shrink: 0;
	}
</style>

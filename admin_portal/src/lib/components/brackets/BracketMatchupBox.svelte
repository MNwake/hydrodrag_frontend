<script lang="ts">
	import type { BracketDisplayMatchup } from '$lib/brackets/bracketTreeLayout';
	import type { BracketLayoutMetrics } from '$lib/brackets/bracketTreeLayout';

	let {
		matchup,
		metrics
	}: {
		matchup: BracketDisplayMatchup;
		metrics: BracketLayoutMetrics;
	} = $props();

	const scale = metrics.layoutScale;
	const fontSize = `${Math.round(16 * scale)}px`;
	const pwcSize = `${Math.round(14 * scale)}px`;
</script>

<div
	class="bracket-matchup-box"
	style="width: {metrics.boxWidth}px; height: {metrics.boxHeight}px;"
>
	<div
		class="bracket-participant"
		class:is-winner={matchup.isWinnerA}
		class:is-loser={matchup.isLoserA}
		style="height: {metrics.participantRowHeight}px; padding: 0 {10 * scale}px; font-size: {fontSize};"
	>
		<span class="bracket-name" title={matchup.nameA}>{matchup.nameA}</span>
		{#if matchup.pwcA}
			<span class="bracket-pwc" style="font-size: {pwcSize}">{matchup.pwcA}</span>
		{/if}
	</div>
	<div class="bracket-divider" style="height: {metrics.dividerHeight}px;"></div>
	<div
		class="bracket-participant"
		class:is-winner={matchup.isWinnerB}
		class:is-loser={matchup.isLoserB}
		class:is-pending={matchup.opponentPending}
		style="height: {metrics.participantRowHeight}px; padding: 0 {10 * scale}px; font-size: {fontSize};"
	>
		<span class="bracket-name" title={matchup.nameB}>{matchup.nameB}</span>
		{#if matchup.pwcB}
			<span class="bracket-pwc" style="font-size: {pwcSize}">{matchup.pwcB}</span>
		{/if}
	</div>
</div>

<style>
	.bracket-matchup-box {
		background: #fff;
		border: 1px solid #ccc;
		border-radius: 4px;
		overflow: hidden;
		flex-shrink: 0;
	}
	.bracket-participant {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #fff;
		color: #111;
		font-weight: 500;
		min-width: 0;
	}
	.bracket-participant.is-winner {
		background: #d4edda;
		font-weight: 600;
	}
	.bracket-participant.is-loser {
		background: #f8d7da;
	}
	.bracket-participant.is-pending .bracket-name {
		color: #666;
		font-style: italic;
		font-weight: 400;
	}
	.bracket-name {
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.bracket-pwc {
		flex-shrink: 0;
		color: #333;
		font-weight: 600;
	}
	.bracket-divider {
		background: #ddd;
	}
</style>

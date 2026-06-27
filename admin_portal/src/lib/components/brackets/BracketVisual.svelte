<script lang="ts">
	import {
		buildBracketSections,
		bracketSectionsEmpty,
		type BracketRacerRef,
		type ManageRound
	} from '$lib/brackets/buildBracketSections';
	import BracketSection from './BracketSection.svelte';

	let {
		rounds,
		racerLabel
	}: {
		rounds: ManageRound[];
		racerLabel: (r: BracketRacerRef) => string;
	} = $props();

	const sections = $derived(buildBracketSections(rounds, racerLabel));
	const isEmpty = $derived(bracketSectionsEmpty(sections));

	const visibleSections = $derived(
		[
			{ key: 'winners', title: "Winner's bracket", rounds: sections.winners },
			{ key: 'losers', title: "Loser's bracket", rounds: sections.losers },
			{ key: 'championship', title: 'Championship', rounds: sections.championship }
		].filter((s) => s.rounds.length > 0)
	);
</script>

<div class="bracket-visual">
	{#if isEmpty}
		<p class="bracket-empty">No bracket matchups yet. Generate rounds from the Matchups tab.</p>
	{:else}
		<h2 class="bracket-visual-title">Bracket</h2>
		<div class="bracket-visual-scroll">
			<div class="bracket-sections-stack">
				{#each visibleSections as section, i (section.key)}
					{#if i > 0}
						<div class="bracket-section-divider" aria-hidden="true"></div>
					{/if}
					<div class="bracket-section-panel" data-bracket={section.key}>
						<BracketSection title={section.title} rounds={section.rounds} />
					</div>
				{/each}
			</div>
		</div>
	{/if}
</div>

<style>
	.bracket-visual {
		margin-top: 1rem;
		background: #fff;
		color: #111;
	}
	.bracket-empty {
		color: #666;
		padding: 2rem 1rem;
		text-align: center;
		font-size: 1rem;
	}
	.bracket-visual-title {
		margin: 0 0 1rem;
		font-size: 1.35rem;
		font-weight: 700;
		color: #111;
	}
	.bracket-visual-scroll {
		overflow-x: auto;
		overflow-y: visible;
		padding-bottom: 1rem;
		-webkit-overflow-scrolling: touch;
		background: #fff;
	}
	.bracket-sections-stack {
		display: flex;
		flex-direction: column;
		min-width: min-content;
	}
	.bracket-section-panel {
		border: 2px solid #333;
		border-radius: 8px;
		padding: 1.25rem 1.5rem 1.5rem;
		background: #fff;
	}
	.bracket-section-panel[data-bracket='winners'] {
		border-left-width: 6px;
	}
	.bracket-section-panel[data-bracket='losers'] {
		border-left-width: 6px;
		border-left-color: #666;
	}
	.bracket-section-panel[data-bracket='championship'] {
		border-left-width: 6px;
		border-left-color: #111;
	}
	.bracket-section-divider {
		height: 0;
		margin: 1.75rem 0;
		border: none;
		border-top: 3px double #333;
	}
</style>

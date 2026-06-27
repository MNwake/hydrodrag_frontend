import type { BracketDisplayMatchup } from './bracketTreeLayout';

export type BracketDisplayRound = {
	roundNumber: number;
	matchups: BracketDisplayMatchup[];
};

export type BracketSections = {
	winners: BracketDisplayRound[];
	losers: BracketDisplayRound[];
	championship: BracketDisplayRound[];
};

export type BracketRacerRef = {
	id: string;
	pwc_identifier?: string | null;
	first_name?: string | null;
	last_name?: string | null;
	full_name?: string | null;
	email?: string | null;
	racer?: { full_name?: string | null; email?: string | null } | null;
	racer_model?: { full_name?: string | null; email?: string | null } | null;
};

export type ManageMatchup = {
	matchup_id: string;
	bracket: string;
	seed_a: number;
	seed_b: number | null;
	is_bye?: boolean;
	racerA: BracketRacerRef;
	racerB: BracketRacerRef | null;
	winner: string | null;
};

export type ManageRound = {
	number: number;
	matchups: ManageMatchup[];
};

function racerLabel(r: BracketRacerRef, labelFn: (r: BracketRacerRef) => string): string {
	return labelFn(r);
}

export function buildBracketSections(
	rounds: ManageRound[],
	labelFn: (r: BracketRacerRef) => string
): BracketSections {
	const toDisplay = (m: ManageMatchup): BracketDisplayMatchup => {
		const hasResult = m.winner != null && m.winner !== '';
		const opponentPending = !m.racerB && !(m.is_bye ?? false);
		const isWinnerA = m.winner === m.racerA.id;
		const isWinnerB = Boolean(m.racerB && m.winner === m.racerB.id);
		return {
			matchupId: m.matchup_id,
			nameA: racerLabel(m.racerA, labelFn),
			nameB: m.racerB ? racerLabel(m.racerB, labelFn) : '—',
			pwcA: (m.racerA.pwc_identifier ?? '').trim(),
			pwcB: (m.racerB?.pwc_identifier ?? '').trim(),
			isWinnerA,
			isWinnerB,
			isLoserA: hasResult && !isWinnerA && !opponentPending,
			isLoserB: hasResult && !isWinnerB && Boolean(m.racerB),
			isBye: m.is_bye ?? false,
			opponentPending
		};
	};

	const split = (bracket: 'W' | 'L' | 'C'): BracketDisplayRound[] => {
		const byRound = new Map<number, { m: ManageMatchup; display: BracketDisplayMatchup }[]>();
		for (const r of rounds) {
			for (const m of r.matchups) {
				if ((m.bracket ?? 'W').toUpperCase() !== bracket) continue;
				const list = byRound.get(r.number) ?? [];
				list.push({ m, display: toDisplay(m) });
				byRound.set(r.number, list);
			}
		}
		return [...byRound.entries()]
			.sort(([a], [b]) => a - b)
			.map(([roundNumber, items]) => ({
				roundNumber,
				matchups: items
					.sort((a, b) => a.m.seed_a - b.m.seed_a)
					.map((x) => x.display)
			}));
	};

	return {
		winners: split('W'),
		losers: split('L'),
		championship: split('C')
	};
}

export function bracketSectionsEmpty(sections: BracketSections): boolean {
	return (
		sections.winners.length === 0 &&
		sections.losers.length === 0 &&
		sections.championship.length === 0
	);
}

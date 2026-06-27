/** Bracket tree layout (ported from hydrodrags_app bracket_column.dart). */

export type BracketDisplayMatchup = {
	matchupId: string;
	nameA: string;
	nameB: string;
	pwcA: string;
	pwcB: string;
	isWinnerA: boolean;
	isWinnerB: boolean;
	isLoserA: boolean;
	isLoserB: boolean;
	isBye: boolean;
	opponentPending: boolean;
};

export type BracketLayoutMetrics = {
	layoutScale: number;
	boxWidth: number;
	participantRowHeight: number;
	dividerHeight: number;
	boxHeight: number;
	compactMatchupGap: number;
	slotGap: number;
	connectorWidth: number;
	roundLabelHeight: number;
	slotUnit: number;
};

const BASE = {
	boxWidth: 240,
	participantRowHeight: 36,
	dividerHeight: 1,
	compactMatchupGap: 12,
	slotGap: 16,
	connectorWidth: 20,
	roundLabelHeight: 26
};

export function createBracketMetrics(layoutScale = 1): BracketLayoutMetrics {
	const boxWidth = BASE.boxWidth * layoutScale;
	const participantRowHeight = BASE.participantRowHeight * layoutScale;
	const dividerHeight = BASE.dividerHeight;
	const boxHeight = participantRowHeight * 2 + dividerHeight;
	return {
		layoutScale,
		boxWidth,
		participantRowHeight,
		dividerHeight,
		boxHeight,
		compactMatchupGap: BASE.compactMatchupGap * layoutScale,
		slotGap: BASE.slotGap * layoutScale,
		connectorWidth: BASE.connectorWidth * layoutScale,
		roundLabelHeight: BASE.roundLabelHeight * layoutScale,
		slotUnit: boxHeight + BASE.slotGap * layoutScale
	};
}

export class BracketTreeLayout {
	constructor(
		public metrics: BracketLayoutMetrics,
		public rounds: BracketDisplayMatchup[][]
	) {}

	private prevMatchupIndex(roundIndex: number, slot: number): number {
		const prevLen = this.rounds[roundIndex - 1]?.length ?? 0;
		if (prevLen === 0) return 0;
		return Math.max(0, Math.min(slot, prevLen - 1));
	}

	byeFeederIndex(roundIndex: number, matchIndex: number): number {
		return this.prevMatchupIndex(roundIndex, 2 * matchIndex);
	}

	matchupCenterY(roundIndex: number, matchIndex: number): number {
		if (roundIndex < 0 || roundIndex >= this.rounds.length) return 0;
		const matchups = this.rounds[roundIndex];
		if (!matchups || matchIndex < 0 || matchIndex >= matchups.length) return 0;

		if (roundIndex === 0) {
			return (2 * matchIndex + 1) * this.metrics.slotUnit;
		}

		const prevLen = this.rounds[roundIndex - 1].length;
		if (prevLen === 0) return 0;

		const m = matchups[matchIndex];
		if (m.isBye) {
			return this.matchupCenterY(roundIndex - 1, this.byeFeederIndex(roundIndex, matchIndex));
		}

		const idxA = 2 * matchIndex;
		const idxB = 2 * matchIndex + 1;
		if (idxB >= prevLen) {
			return this.matchupCenterY(roundIndex - 1, this.prevMatchupIndex(roundIndex, idxA));
		}

		const yA = this.matchupCenterY(roundIndex - 1, idxA);
		const yB = this.matchupCenterY(roundIndex - 1, idxB);
		return (yA + yB) / 2;
	}

	matchupTop(roundIndex: number, matchIndex: number): number {
		return this.matchupCenterY(roundIndex, matchIndex) - this.metrics.boxHeight / 2;
	}

	columnContentHeight(roundIndex: number): number {
		const matchups = this.rounds[roundIndex];
		if (!matchups?.length) return 0;
		let maxBottom = 0;
		for (let i = 0; i < matchups.length; i++) {
			const bottom = this.matchupTop(roundIndex, i) + this.metrics.boxHeight;
			if (bottom > maxBottom) maxBottom = bottom;
		}
		return maxBottom;
	}

	/** SVG path segments for connectors between roundIndex and roundIndex+1. */
	connectorSegments(roundIndex: number, columnHeight: number): string[] {
		const nextRound = roundIndex + 1;
		if (nextRound >= this.rounds.length || columnHeight <= 0) return [];

		const halfW = this.metrics.connectorWidth / 2;
		const width = this.metrics.connectorWidth;
		const nextMatchups = this.rounds[nextRound];
		const prevLen = this.rounds[roundIndex].length;
		const segments: string[] = [];

		const line = (x1: number, y1: number, x2: number, y2: number) =>
			`M ${x1} ${y1} L ${x2} ${y2}`;

		for (let i = 0; i < nextMatchups.length; i++) {
			const yOut = this.matchupCenterY(nextRound, i);
			const idxA = 2 * i;
			const idxB = 2 * i + 1;
			const m = nextMatchups[i];

			if (m.isBye || idxB >= prevLen) {
				const prevIdx = m.isBye
					? this.byeFeederIndex(nextRound, i)
					: this.prevMatchupIndex(roundIndex + 1, idxA);
				const y = this.matchupCenterY(roundIndex, prevIdx);
				segments.push(line(0, y, halfW, y));
				segments.push(line(halfW, y, halfW, yOut));
				segments.push(line(halfW, yOut, width, yOut));
				continue;
			}

			const yA = this.matchupCenterY(roundIndex, idxA);
			const yB = this.matchupCenterY(roundIndex, idxB);
			segments.push(line(0, yA, halfW, yA));
			segments.push(line(0, yB, halfW, yB));
			segments.push(line(halfW, yA, halfW, yB));
			segments.push(line(halfW, yOut, width, yOut));
		}

		return segments;
	}
}

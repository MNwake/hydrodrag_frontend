import 'package:flutter/material.dart';
import '../models/matchup.dart';
import '../models/round.dart';

/// Layout constants for Challonge-style bracket
const double _boxWidth = 200;
const double _boxHeight = 56;
const double _roundGap = 56;

/// One matchup cell: two slots (racer A, racer B) with optional seeds and winner highlight.
class _MatchupBox extends StatelessWidget {
  const _MatchupBox({required this.matchup});

  final MatchupBase matchup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: _boxWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ParticipantRow(
            seed: matchup.seedA,
            name: matchup.nameA,
            isWinner: matchup.isWinnerA,
            textColor: onSurface,
          ),
          Container(
            height: 1,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          _ParticipantRow(
            seed: matchup.seedB ?? 0,
            name: matchup.nameB,
            isWinner: matchup.isWinnerB,
            textColor: onSurface,
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.seed,
    required this.name,
    required this.isWinner,
    required this.textColor,
  });

  final int seed;
  final String name;
  final bool isWinner;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: _boxHeight / 2,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: isWinner ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (seed > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$seed',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isWinner ? FontWeight.w600 : FontWeight.normal,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// One bracket section (Winners or Losers): round columns with matchup boxes.
class BracketColumn extends StatelessWidget {
  const BracketColumn({
    super.key,
    required this.rounds,
    required this.title,
    required this.isLosers,
  });

  final List<RoundBase> rounds;
  final String title;
  final bool isLosers;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int r = 0; r < rounds.length; r++) ...[
                  SizedBox(
                    width: _boxWidth + _roundGap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Round ${rounds[r].roundNumber}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        _RoundColumn(matchups: rounds[r].matchups),
                      ],
                    ),
                  ),
                if (r < rounds.length - 1) const SizedBox(width: _roundGap),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({required this.matchups});

  final List<MatchupBase> matchups;

  @override
  Widget build(BuildContext context) {
    // Fixed spacing for all rounds
    const gapBetween = 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < matchups.length; i++) ...[
          if (i > 0) SizedBox(height: gapBetween),
          _MatchupBox(matchup: matchups[i]),
        ],
      ],
    );
  }
}

import 'registration_ref.dart';

/// A single matchup in a bracket round (mirrors server BracketsMatchupBase).
/// racer_a, racer_b, winner are RegistrationRefBase (registration refs with names).
class MatchupBase {
  final String matchupId;
  final RegistrationRefBase? racerA;
  final RegistrationRefBase? racerB;
  final RegistrationRefBase? winner;
  final String bracket;
  final int seedA;
  final int? seedB;

  MatchupBase({
    required this.matchupId,
    this.racerA,
    this.racerB,
    this.winner,
    required this.bracket,
    required this.seedA,
    this.seedB,
  });

  factory MatchupBase.fromJson(Map<String, dynamic> json) {
    RegistrationRefBase? fromRef(dynamic v) {
      if (v == null || v is! Map<String, dynamic>) return null;
      return RegistrationRefBase.fromJson(v);
    }

    return MatchupBase(
      matchupId: json['matchup_id'] as String? ?? '',
      racerA: fromRef(json['racer_a']),
      racerB: fromRef(json['racer_b']),
      winner: fromRef(json['winner']),
      bracket: json['bracket'] as String? ?? 'W',
      seedA: (json['seed_a'] as num?)?.toInt() ?? 0,
      seedB: (json['seed_b'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchup_id': matchupId,
      'racer_a': racerA?.id,
      'racer_b': racerB?.id,
      'winner': winner?.id,
      'bracket': bracket,
      'seed_a': seedA,
      'seed_b': seedB,
    };
  }

  bool get hasWinner => winner != null;

  String get nameA => racerA?.displayName ?? '—';
  String get nameB => racerB?.displayName ?? '—';

  bool get isWinnerA => hasWinner && winner?.id == racerA?.id;
  bool get isWinnerB => hasWinner && winner?.id == racerB?.id;
}

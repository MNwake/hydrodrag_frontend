import 'matchup.dart';

/// A round in an event bracket (mirrors server RoundBase).
class RoundBase {
  final String id;
  final String eventId;
  final String classKey;
  final int roundNumber;
  final List<MatchupBase> matchups;
  final String createdAt;
  final String updatedAt;
  final bool isComplete;

  RoundBase({
    required this.id,
    required this.eventId,
    required this.classKey,
    required this.roundNumber,
    required this.matchups,
    required this.createdAt,
    required this.updatedAt,
    required this.isComplete,
  });

  factory RoundBase.fromJson(Map<String, dynamic> json) {
    final matchupsJson = json['matchups'] as List<dynamic>? ?? [];
    return RoundBase(
      id: json['id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      classKey: json['class_key'] as String? ?? '',
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 0,
      matchups: matchupsJson
          .map((m) => MatchupBase.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'class_key': classKey,
      'round_number': roundNumber,
      'matchups': matchups.map((m) => m.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_complete': isComplete,
    };
  }

  /// True if this round is part of the losers bracket.
  /// matchup.bracket is "W" for winners, "L" for losers.
  bool get isLosersBracket =>
      matchups.isNotEmpty && matchups.first.bracket.toUpperCase() == 'L';
}

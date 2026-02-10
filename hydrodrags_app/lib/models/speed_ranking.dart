/// One entry in the top-speed rankings for an event/class.
class SpeedRankingItem {
  final int place;
  final String registrationId;
  final double topSpeed;
  /// Racer display name when provided by the backend (e.g. from registration).
  final String? racerName;

  SpeedRankingItem({
    required this.place,
    required this.registrationId,
    required this.topSpeed,
    this.racerName,
  });

  factory SpeedRankingItem.fromJson(Map<String, dynamic> json) {
    final firstName = json['racer_first_name'] as String?;
    final lastName = json['racer_last_name'] as String?;
    String? racerName = json['racer_name'] as String?;
    if (racerName == null && (firstName != null || lastName != null)) {
      racerName = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    }
    return SpeedRankingItem(
      place: (json['place'] as num?)?.toInt() ?? 0,
      registrationId: json['registration_id'] as String? ?? '',
      topSpeed: (json['top_speed'] as num?)?.toDouble() ?? 0,
      racerName: racerName?.trim().isEmpty == true ? null : racerName,
    );
  }

  String get displayName => racerName?.trim().isNotEmpty == true
      ? racerName!
      : 'Racer #$place';
}

/// Response from GET /speed/rankings (legacy)
class SpeedRankingResponse {
  final String classKey;
  final List<SpeedRankingItem> rankings;

  SpeedRankingResponse({
    required this.classKey,
    required this.rankings,
  });

  factory SpeedRankingResponse.fromJson(Map<String, dynamic> json) {
    final list = json['rankings'] as List<dynamic>? ?? [];
    return SpeedRankingResponse(
      classKey: json['class_key'] as String? ?? '',
      rankings: list
          .map((e) => SpeedRankingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Speed session from GET /speed/session (event/class).
/// Contains session metadata and rankings.
class SpeedSession {
  final String id;
  final String eventId;
  final String classKey;
  final DateTime? startedAt;
  final DateTime? stoppedAt;
  final DateTime? pausedAt;
  final int durationSeconds;
  final int totalPausedSeconds;
  final int? remainingSeconds; // computed on backend, if present
  final List<SpeedRankingItem> rankings;

  SpeedSession({
    required this.id,
    required this.eventId,
    required this.classKey,
    this.startedAt,
    this.stoppedAt,
    this.pausedAt,
    required this.durationSeconds,
    this.totalPausedSeconds = 0,
    this.remainingSeconds,
    this.rankings = const [],
  });

  factory SpeedSession.fromJson(Map<String, dynamic> json) {
    final list = json['rankings'] as List<dynamic>? ?? [];
    return SpeedSession(
      id: json['id'] as String? ?? '',
      eventId: json['event'] as String? ?? '',
      classKey: json['class_key'] as String? ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      stoppedAt: json['stopped_at'] != null
          ? DateTime.tryParse(json['stopped_at'] as String)
          : null,
      pausedAt: json['paused_at'] != null
          ? DateTime.tryParse(json['paused_at'] as String)
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      totalPausedSeconds: (json['total_paused_seconds'] as num?)?.toInt() ?? 0,
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt(),
      rankings: list
          .map((e) => SpeedRankingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Session is active (started and not stopped).
  bool get isActive =>
      startedAt != null &&
      stoppedAt == null;

  /// Session has ended.
  bool get isStopped => stoppedAt != null;
}

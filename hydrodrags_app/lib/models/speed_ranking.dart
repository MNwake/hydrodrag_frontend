/// One entry in the top-speed rankings for an event/class.
class SpeedRankingItem {
  final int place;
  final String registrationId;
  final double topSpeed;
  /// Racer display name when provided by the backend (e.g. from registration).
  final String? racerName;
  /// PWC number from event registration (speed alley display).
  final String pwcIdentifier;

  SpeedRankingItem({
    required this.place,
    required this.registrationId,
    required this.topSpeed,
    this.racerName,
    this.pwcIdentifier = '',
  });

  factory SpeedRankingItem.fromJson(Map<String, dynamic> json) {
    String? racerName;
    String registrationId = json['registration_id'] as String? ?? '';

    final registration = json['registration'];
    var pwcIdentifier = json['pwc_identifier'] as String? ?? '';

    if (registration is Map<String, dynamic>) {
      registrationId = registration['id'] as String? ?? registrationId;
      if (pwcIdentifier.isEmpty) {
        pwcIdentifier = registration['pwc_identifier'] as String? ?? '';
      }
      final racer = registration['racer'];
      if (racer is Map<String, dynamic>) {
        racerName = racer['full_name'] as String? ??
            _buildRacerName(
              racer['first_name'] as String?,
              racer['last_name'] as String?,
            );
      }
    }
    if (racerName == null) {
      final firstName = json['racer_first_name'] as String?;
      final lastName = json['racer_last_name'] as String?;
      racerName = json['racer_name'] as String?;
      if (racerName == null && (firstName != null || lastName != null)) {
        racerName = _buildRacerName(firstName, lastName);
      }
    }

    return SpeedRankingItem(
      place: (json['place'] as num?)?.toInt() ?? 0,
      registrationId: registrationId,
      topSpeed: (json['top_speed'] as num?)?.toDouble() ?? 0,
      racerName: racerName?.trim().isEmpty == true ? null : racerName,
      pwcIdentifier: pwcIdentifier.trim(),
    );
  }

  static String? _buildRacerName(String? firstName, String? lastName) {
    final parts = [firstName?.trim(), lastName?.trim()]
        .where((s) => s != null && s.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
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

  /// Builds a session from a WebSocket broadcast payload (partial update).
  /// Merges with [existing] for id, durationSeconds, totalPausedSeconds when not in payload.
  static SpeedSession fromWebSocketUpdate(
    String eventId,
    String classKey,
    Map<String, dynamic> payload, {
    SpeedSession? existing,
  }) {
    final sessionMap = payload['session'];
    final session = sessionMap is Map<String, dynamic> ? sessionMap : null;
    final rankingsList = payload['rankings'] as List<dynamic>? ?? [];
    final hasRankingsKey = payload.containsKey('rankings');
    final reset = payload['reset'] == true;

    final id = existing?.id ?? '';
    var durationSeconds = existing?.durationSeconds ?? 0;
    final totalPausedSeconds = existing?.totalPausedSeconds ?? 0;

    if (payload.containsKey('duration_seconds')) {
      durationSeconds = (payload['duration_seconds'] as num?)?.toInt() ?? durationSeconds;
    } else if (session != null && session.containsKey('duration_seconds')) {
      durationSeconds =
          (session['duration_seconds'] as num?)?.toInt() ?? durationSeconds;
    }

    DateTime? startedAt;
    DateTime? stoppedAt;
    DateTime? pausedAt;
    int? remainingSeconds;
    if (session != null) {
      // Respect explicit nulls from websocket payloads (e.g. resume sets paused_at=null).
      if (session.containsKey('started_at')) {
        startedAt = session['started_at'] != null
            ? DateTime.tryParse(session['started_at'] as String)
            : null;
      } else {
        startedAt = existing?.startedAt;
      }
      if (session.containsKey('stopped_at')) {
        stoppedAt = session['stopped_at'] != null
            ? DateTime.tryParse(session['stopped_at'] as String)
            : null;
      } else {
        stoppedAt = existing?.stoppedAt;
      }
      if (session.containsKey('paused_at')) {
        pausedAt = session['paused_at'] != null
            ? DateTime.tryParse(session['paused_at'] as String)
            : null;
      } else {
        pausedAt = existing?.pausedAt;
      }
      remainingSeconds = session.containsKey('remaining_seconds')
          ? (session['remaining_seconds'] as num?)?.toInt()
          : existing?.remainingSeconds;
    } else if (reset) {
      startedAt = null;
      stoppedAt = null;
      pausedAt = null;
      remainingSeconds = durationSeconds;
    } else {
      startedAt = existing?.startedAt;
      stoppedAt = existing?.stoppedAt;
      pausedAt = existing?.pausedAt;
      remainingSeconds = existing?.remainingSeconds;
    }

    final rankings = rankingsList
        .map((e) => SpeedRankingItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return SpeedSession(
      id: id,
      eventId: eventId,
      classKey: classKey,
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      pausedAt: pausedAt,
      durationSeconds: durationSeconds,
      totalPausedSeconds: reset ? 0 : totalPausedSeconds,
      remainingSeconds: remainingSeconds,
      rankings: hasRankingsKey || reset ? rankings : (existing?.rankings ?? []),
    );
  }

  /// Session is active (started and not stopped).
  bool get isActive =>
      startedAt != null &&
      pausedAt == null &&
      stoppedAt == null;

  /// Session is currently paused.
  bool get isPaused =>
      startedAt != null &&
      pausedAt != null &&
      stoppedAt == null;

  /// Session has ended.
  bool get isStopped => stoppedAt != null;
}

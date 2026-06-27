/// One finalized placement from GET /events/{event_id}/results.
class EventResultItem {
  final String racerId;
  final String racerName;
  final String? profileImagePath;
  final String classKey;
  final String className;
  final String pwcIdentifier;
  final int placement;
  final int wins;
  final int losses;
  final int roundsCompleted;
  final double topSpeed;

  EventResultItem({
    required this.racerId,
    required this.racerName,
    this.profileImagePath,
    required this.classKey,
    required this.className,
    this.pwcIdentifier = '',
    required this.placement,
    this.wins = 0,
    this.losses = 0,
    this.roundsCompleted = 0,
    this.topSpeed = 0,
  });

  factory EventResultItem.fromJson(Map<String, dynamic> json) {
    return EventResultItem(
      racerId: json['racer_id'] as String? ?? '',
      racerName: json['racer_name'] as String? ?? 'Racer',
      profileImagePath: json['profile_image_path'] as String?,
      classKey: json['class_key'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      pwcIdentifier: json['pwc_identifier'] as String? ?? '',
      placement: (json['placement'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      roundsCompleted: (json['rounds_completed'] as num?)?.toInt() ?? 0,
      topSpeed: (json['top_speed'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Response from GET /events/{event_id}/results.
class EventResultsResponse {
  final String eventId;
  final String? format;
  final List<EventResultItem> results;

  EventResultsResponse({
    required this.eventId,
    this.format,
    this.results = const [],
  });

  factory EventResultsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['results'] as List<dynamic>? ?? [];
    return EventResultsResponse(
      eventId: json['event_id'] as String? ?? '',
      format: json['format'] as String?,
      results: list
          .map((e) => EventResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

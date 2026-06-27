/// One completed event result from GET /racers/{racer_id}/history.
class RacerHistoryItem {
  final String eventId;
  final String eventName;
  final DateTime? eventDate;
  final String classKey;
  final String className;
  final String? pwcNumber;
  final int placement;
  final int wins;
  final int losses;

  RacerHistoryItem({
    required this.eventId,
    required this.eventName,
    this.eventDate,
    required this.classKey,
    required this.className,
    this.pwcNumber,
    required this.placement,
    this.wins = 0,
    this.losses = 0,
  });

  factory RacerHistoryItem.fromJson(Map<String, dynamic> json) {
    return RacerHistoryItem(
      eventId: json['event_id'] as String? ?? '',
      eventName: json['event_name'] as String? ?? '',
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'] as String)
          : null,
      classKey: json['class_key'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      pwcNumber: json['pwc_number'] as String?,
      placement: (json['placement'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
    );
  }
}

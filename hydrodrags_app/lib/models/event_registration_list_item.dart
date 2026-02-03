/// Lightweight racer data returned inside event registration list (RacerBase).
class RacerSummary {
  final String id;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;

  RacerSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
  });

  factory RacerSummary.fromJson(Map<String, dynamic> json) {
    return RacerSummary(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String? ??
          json['profile_image_path'] as String?,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

/// One event registration row from GET /registrations/event/{event_id}/registrations.
class EventRegistrationListItem {
  final String id;
  final String event;
  final String racer;
  final String pwcIdentifier;
  final String classKey;
  final String className;
  final double price;
  final int losses;
  final bool isPaid;
  final DateTime createdAt;
  final RacerSummary? racerModel;

  EventRegistrationListItem({
    required this.id,
    required this.event,
    required this.racer,
    required this.pwcIdentifier,
    required this.classKey,
    required this.className,
    required this.price,
    required this.losses,
    required this.isPaid,
    required this.createdAt,
    this.racerModel,
  });

  bool get isEliminated => losses >= 2;

  factory EventRegistrationListItem.fromJson(Map<String, dynamic> json) {
    final racerModelJson = json['racer_model'];
    return EventRegistrationListItem(
      id: json['id'] as String? ?? '',
      event: json['event'] as String? ?? '',
      racer: json['racer'] as String? ?? '',
      pwcIdentifier: json['pwc_identifier'] as String? ?? '',
      classKey: json['class_key'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      losses: json['losses'] as int? ?? 0,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      racerModel: racerModelJson != null
          ? RacerSummary.fromJson(racerModelJson as Map<String, dynamic>)
          : null,
    );
  }
}

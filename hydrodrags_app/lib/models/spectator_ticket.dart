/// Spectator ticket (single day or weekend) purchased by the racer.
/// From GET /me/tickets.
/// Event is hydrated (EventBase) so we get name and start_date from it.
class SpectatorTicket {
  final String id;
  final String eventId;
  final String? purchaserName;
  final String phone;
  final String ticketCode;
  final String ticketType; // "single_day" | "weekend"
  final bool isUsed;
  final DateTime? usedAt;
  final String? eventName;
  final DateTime? eventDate;
  final DateTime? createdAt;

  SpectatorTicket({
    required this.id,
    required this.eventId,
    this.purchaserName,
    required this.phone,
    required this.ticketCode,
    required this.ticketType,
    required this.isUsed,
    this.usedAt,
    this.eventName,
    this.eventDate,
    this.createdAt,
  });

  factory SpectatorTicket.fromJson(Map<String, dynamic> json) {
    String eventId = '';
    String? eventName;
    DateTime? eventDate;

    final eventVal = json['event'];
    if (eventVal is Map<String, dynamic>) {
      eventId = eventVal['id'] as String? ?? '';
      eventName = eventVal['name'] as String?;
      final startDate = eventVal['start_date'];
      if (startDate != null) {
        eventDate = DateTime.tryParse(startDate as String);
      }
    } else if (eventVal is String) {
      eventId = eventVal;
    }

    final phone = json['purchaser_phone'] as String? ??
        json['phone'] as String? ??
        '';

    return SpectatorTicket(
      id: json['id'] as String? ?? '',
      eventId: eventId,
      purchaserName: json['purchaser_name'] as String?,
      phone: phone,
      ticketCode: json['ticket_code'] as String? ?? '',
      ticketType: json['ticket_type'] as String? ?? 'single_day',
      isUsed: json['is_used'] as bool? ?? false,
      usedAt: json['used_at'] != null
          ? DateTime.tryParse(json['used_at'] as String)
          : null,
      eventName: eventName ?? json['event_name'] as String?,
      eventDate: eventDate ??
          (json['event_date'] != null
              ? DateTime.tryParse(json['event_date'] as String)
              : null),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get typeDisplayName =>
      ticketType == 'weekend' ? 'Weekend' : 'Single Day';
}

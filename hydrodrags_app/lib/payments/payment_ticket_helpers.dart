import '../models/spectator_ticket.dart';

List<SpectatorTicket> ticketsFromPaymentResult(
  Map<String, dynamic>? result,
  String eventId,
) {
  final raw = result?['tickets'] as List<dynamic>? ?? [];
  return raw.map((item) {
    final map = item as Map<String, dynamic>;
    return SpectatorTicket(
      id: map['ticket_code'] as String? ?? '',
      eventId: eventId,
      phone: '',
      ticketCode: map['ticket_code'] as String? ?? '',
      ticketType: map['ticket_type'] as String? ?? 'single_day',
      isUsed: false,
    );
  }).toList();
}

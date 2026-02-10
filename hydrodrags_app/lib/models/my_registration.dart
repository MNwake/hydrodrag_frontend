/// One event registration row from GET /me/registrations (EventRegistrationClientBase).
/// A racer may have multiple rows per event (one per class).
/// event and racer are always hydrated (EventBase, RacerBase); payment is optional.
class MyRegistration {
  final String id;
  final String eventId;
  final String? eventName;
  final DateTime? eventDate;
  final String? eventLocation;
  final String racerId;
  final String? racerName;
  final String pwcIdentifier;
  final String classKey;
  final String className;
  final double price;
  final int losses;
  final bool isPaid;
  final DateTime? createdAt;
  final bool? isEliminated;
  final bool? hasValidWaiver;
  final bool? isOfAge;
  final bool? hasIhraMembership;
  final PaymentInfo? payment;

  MyRegistration({
    required this.id,
    required this.eventId,
    this.eventName,
    this.eventDate,
    this.eventLocation,
    required this.racerId,
    this.racerName,
    required this.pwcIdentifier,
    required this.classKey,
    required this.className,
    required this.price,
    required this.losses,
    required this.isPaid,
    this.createdAt,
    this.isEliminated,
    this.hasValidWaiver,
    this.isOfAge,
    this.hasIhraMembership,
    this.payment,
  });

  factory MyRegistration.fromJson(Map<String, dynamic> json) {
    String eventId = '';
    String? eventName;
    DateTime? eventDate;
    String? eventLocation;

    final eventVal = json['event'];
    if (eventVal is Map<String, dynamic>) {
      eventId = eventVal['id'] as String? ?? '';
      eventName = eventVal['name'] as String?;
      final startDate = eventVal['start_date'];
      if (startDate != null) {
        eventDate = DateTime.tryParse(startDate as String);
      }
      final loc = eventVal['location'];
      if (loc is Map<String, dynamic>) {
        eventLocation = loc['full_address'] as String? ??
            loc['name'] as String? ??
            _buildLocationFromParts(
              loc['city'] as String?,
              loc['state'] as String?,
              loc['zip_code']?.toString(),
              loc['country'] as String?,
            );
      }
    } else if (eventVal is String) {
      eventId = eventVal;
    }

    PaymentInfo? payment;
    final paymentVal = json['payment'];
    if (paymentVal is Map<String, dynamic>) {
      payment = PaymentInfo(
        isCaptured: paymentVal['is_captured'] as bool? ?? false,
        paypalOrderId: paymentVal['paypal_order_id'] as String?,
        createdAt: paymentVal['created_at'] != null
            ? DateTime.tryParse(paymentVal['created_at'] as String)
            : null,
        spectatorSingleDayPasses: paymentVal['spectator_single_day_passes'] as int? ?? 0,
        spectatorWeekendPasses: paymentVal['spectator_weekend_passes'] as int? ?? 0,
        purchaseIhraMembership: paymentVal['purchase_ihra_membership'] as bool? ?? false,
      );
    }

    String racerId = '';
    String? racerName;
    final racerVal = json['racer'];
    if (racerVal is Map<String, dynamic>) {
      racerId = racerVal['id'] as String? ?? '';
      racerName = racerVal['full_name'] as String? ??
          _buildRacerName(
            racerVal['first_name'] as String?,
            racerVal['last_name'] as String?,
          );
    } else if (racerVal is String) {
      racerId = racerVal;
    }

    return MyRegistration(
      id: json['id'] as String? ?? '',
      eventId: eventId,
      eventName: eventName,
      eventDate: eventDate,
      eventLocation: eventLocation,
      racerId: racerId,
      racerName: racerName,
      pwcIdentifier: json['pwc_identifier'] as String? ?? '',
      classKey: json['class_key'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      losses: json['losses'] as int? ?? 0,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isEliminated: json['is_eliminated'] as bool?,
      hasValidWaiver: json['has_valid_waiver'] as bool?,
      isOfAge: json['is_of_age'] as bool?,
      hasIhraMembership: json['has_ihra_membership'] as bool?,
      payment: payment,
    );
  }
}

/// Payment info from hydrated PayPalCheckoutRead.
class PaymentInfo {
  final bool isCaptured;
  final String? paypalOrderId;
  final DateTime? createdAt;
  final int spectatorSingleDayPasses;
  final int spectatorWeekendPasses;
  final bool purchaseIhraMembership;

  PaymentInfo({
    required this.isCaptured,
    this.paypalOrderId,
    this.createdAt,
    this.spectatorSingleDayPasses = 0,
    this.spectatorWeekendPasses = 0,
    this.purchaseIhraMembership = false,
  });
}

String? _buildLocationFromParts(String? city, String? state, String? zip, String? country) {
  final parts = <String>[];
  if (city != null && city.isNotEmpty) parts.add(city);
  if (state != null && state.isNotEmpty) parts.add(state);
  if (zip != null && zip.isNotEmpty) parts.add(zip);
  if (country != null && country.isNotEmpty) parts.add(country);
  return parts.isEmpty ? null : parts.join(', ');
}

String? _buildRacerName(String? firstName, String? lastName) {
  final parts = [firstName?.trim(), lastName?.trim()].where((s) => s != null && s.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' ');
}

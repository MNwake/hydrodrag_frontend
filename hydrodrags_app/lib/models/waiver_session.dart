class WaiverSessionStatus {
  final bool hasSignedWaiver;
  final String? signedWaiverId;
  final String? activeSessionId;

  WaiverSessionStatus({
    required this.hasSignedWaiver,
    this.signedWaiverId,
    this.activeSessionId,
  });

  factory WaiverSessionStatus.fromJson(Map<String, dynamic> json) {
    return WaiverSessionStatus(
      hasSignedWaiver: json['has_signed_waiver'] as bool? ?? false,
      signedWaiverId: json['signed_waiver_id'] as String?,
      activeSessionId: json['active_session_id'] as String?,
    );
  }
}

class WaiverSessionDetail {
  final String sessionId;
  final String eventId;
  final String eventName;
  final DateTime eventStartDate;
  final DateTime? eventEndDate;
  final String? venueName;
  final String? venueAddress;
  final String waiverText;
  final int waiverVersion;
  final String? governmentIdType;
  final bool governmentIdFrontUploaded;
  final bool governmentIdBackUploaded;
  final bool selfieUploaded;
  final DateTime expiresAt;

  WaiverSessionDetail({
    required this.sessionId,
    required this.eventId,
    required this.eventName,
    required this.eventStartDate,
    this.eventEndDate,
    this.venueName,
    this.venueAddress,
    required this.waiverText,
    required this.waiverVersion,
    this.governmentIdType,
    required this.governmentIdFrontUploaded,
    required this.governmentIdBackUploaded,
    required this.selfieUploaded,
    required this.expiresAt,
  });

  factory WaiverSessionDetail.fromJson(Map<String, dynamic> json) {
    return WaiverSessionDetail(
      sessionId: json['session_id'] as String? ?? '',
      eventId: json['event_id'] as String? ?? '',
      eventName: json['event_name'] as String? ?? '',
      eventStartDate: DateTime.parse(json['event_start_date'] as String),
      eventEndDate: json['event_end_date'] != null
          ? DateTime.tryParse(json['event_end_date'] as String)
          : null,
      venueName: json['venue_name'] as String?,
      venueAddress: json['venue_address'] as String?,
      waiverText: json['waiver_text'] as String? ?? '',
      waiverVersion: json['waiver_version'] as int? ?? 1,
      governmentIdType: json['government_id_type'] as String?,
      governmentIdFrontUploaded:
          json['government_id_front_uploaded'] as bool? ?? false,
      governmentIdBackUploaded:
          json['government_id_back_uploaded'] as bool? ?? false,
      selfieUploaded: json['selfie_uploaded'] as bool? ?? false,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class WaiverSignResult {
  final String waiverId;
  final DateTime signedAtUtc;

  WaiverSignResult({required this.waiverId, required this.signedAtUtc});

  factory WaiverSignResult.fromJson(Map<String, dynamic> json) {
    return WaiverSignResult(
      waiverId: json['waiver_id'] as String? ?? '',
      signedAtUtc: DateTime.parse(json['signed_at_utc'] as String),
    );
  }
}

/// Event available for manual waiver signing from account settings.
class EventManualWaiverItem {
  final String eventId;
  final String eventName;
  final DateTime eventStartDate;
  final DateTime? eventEndDate;
  final String eventStatus;
  final bool hasSignedWaiver;
  final String? signedWaiverId;
  final String? activeSessionId;

  EventManualWaiverItem({
    required this.eventId,
    required this.eventName,
    required this.eventStartDate,
    this.eventEndDate,
    required this.eventStatus,
    required this.hasSignedWaiver,
    this.signedWaiverId,
    this.activeSessionId,
  });

  factory EventManualWaiverItem.fromJson(Map<String, dynamic> json) {
    return EventManualWaiverItem(
      eventId: json['event_id'] as String? ?? '',
      eventName: json['event_name'] as String? ?? '',
      eventStartDate: DateTime.parse(json['event_start_date'] as String),
      eventEndDate: json['event_end_date'] != null
          ? DateTime.tryParse(json['event_end_date'] as String)
          : null,
      eventStatus: json['event_status'] as String? ?? 'posted',
      hasSignedWaiver: json['has_signed_waiver'] as bool? ?? false,
      signedWaiverId: json['signed_waiver_id'] as String?,
      activeSessionId: json['active_session_id'] as String?,
    );
  }

  bool get hasInProgressSession => activeSessionId != null;
}

class ApiConfig {
  // Backend URL configuration.
  // Production (Play Store): use build_appbundle_playstore.sh or
  //   flutter build appbundle --dart-define=API_BASE_URL='https://api.hydrodrags.koesterventures.com'
  // Local dev: flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.hydrodrags.koesterventures.com',
  );

  static String get authEndpoint => '$baseUrl/auth';
  static String get requestCodeEndpoint => '$authEndpoint/request-code';
  static String get verifyCodeEndpoint => '$authEndpoint/verify-code';
  static String get refreshTokenEndpoint => '$authEndpoint/refresh';
  static String get healthEndpoint => '$baseUrl/health';
  static String get meEndpoint => '$baseUrl/me';
  static String get hydrodragsConfigEndpoint => '$baseUrl/hydrodrags/config';
  static String get addPwcEndpoint => '$baseUrl/me/pwc';
  static String get waiverUploadEndpoint => '$baseUrl/me/waiver';

  /// Event-scoped waiver API
  static String eventWaiverStatus(String eventId) =>
      '$baseUrl/mobile/events/$eventId/waiver/status';
  static String eventWaiverSession(String eventId) =>
      '$baseUrl/mobile/events/$eventId/waiver/session';
  static String eventWaiverReplacementSession(String eventId) =>
      '$baseUrl/mobile/events/$eventId/waiver/replacement-session';
  static String get eligibleWaiverEvents =>
      '$baseUrl/mobile/waivers/eligible-events';
  static String waiverSession(String sessionId) =>
      '$baseUrl/mobile/waiver-sessions/$sessionId';
  static String waiverSessionGovernmentId(String sessionId) =>
      '$baseUrl/mobile/waiver-sessions/$sessionId/government-id';
  static String waiverSessionSelfie(String sessionId) =>
      '$baseUrl/mobile/waiver-sessions/$sessionId/selfie';
  static String waiverSessionSign(String sessionId) =>
      '$baseUrl/mobile/waiver-sessions/$sessionId/sign';
  static String myEventWaiver(String eventId) =>
      '$baseUrl/me/events/$eventId/waiver';
  static String get myTicketsEndpoint => '$baseUrl/me/tickets';
  static String get myRegistrationsEndpoint => '$baseUrl/me/registrations';

  /// GET /registrations/event/{event_id}/registrations
  static String eventRegistrations(String eventId) =>
      '$baseUrl/registrations/event/$eventId/registrations';

  /// POST /registrations/promo/verify — verify promo code (valid, code, type)
  static String get promoVerify => '$baseUrl/registrations/promo/verify';

  /// Mobile payment API (replaces legacy /paypal mobile checkout routes)
  static String get mobilePaymentsQuote => '$baseUrl/mobile/payments/quote';
  static String get mobilePaymentsStart => '$baseUrl/mobile/payments/start';
  static String mobilePaymentStatus(String paymentId) =>
      '$baseUrl/mobile/payments/$paymentId/status';
  static String mobilePaymentApprove(String paymentId) =>
      '$baseUrl/mobile/payments/$paymentId/approve';
  static String mobilePaymentCancel(String paymentId) =>
      '$baseUrl/mobile/payments/$paymentId/cancel';
  static String mobilePaymentCheckoutOpened(String paymentId) =>
      '$baseUrl/mobile/payments/$paymentId/checkout-opened';

  /// PayPal SDK return URL — must match PayPal Developer Dashboard + native config
  static const String paypalReturnUrl =
      'com.koesterventures.hydrodrags://paypalpay';

  /// GET /events/{event_id}/results — finalized placements for a completed event
  static String eventResults(String eventId) =>
      '$baseUrl/events/$eventId/results';

  /// GET /events/{event_id}/rounds — list bracket rounds for an event
  /// Pass [classKey] to filter by racing class.
  static String eventRounds(String eventId, {String? classKey}) {
    final base = '$baseUrl/events/$eventId/rounds';
    if (classKey != null && classKey.isNotEmpty) {
      return '$base?class_key=${Uri.encodeComponent(classKey)}';
    }
    return base;
  }

  /// GET /speed/session — speed session for an event/class (includes rankings)
  static String speedSession(String eventId, String classKey) =>
      '$baseUrl/speed/session?event_id=${Uri.encodeComponent(eventId)}&class_key=${Uri.encodeComponent(classKey)}';

  /// WebSocket URL for live event updates (brackets, speed session).
  /// Converts http(s) base URL to ws(s).
  static String eventWebSocketUrl(String eventId) {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final host = uri.host;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://$host$port/ws/events/${Uri.encodeComponent(eventId)}';
  }
}

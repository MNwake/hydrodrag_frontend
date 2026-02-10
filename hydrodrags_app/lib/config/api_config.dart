class ApiConfig {
  // Backend URL configuration
  // For physical devices, use your computer's IP address
  // For simulators/emulators, localhost works
  // Override via: flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000
  // defaultValue: 'http://172.99.99.17:8000',  // public wifi
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
  static String get myTicketsEndpoint => '$baseUrl/me/tickets';
  static String get myRegistrationsEndpoint => '$baseUrl/me/registrations';

  /// GET /registrations/event/{event_id}/registrations
  static String eventRegistrations(String eventId) =>
      '$baseUrl/registrations/event/$eventId/registrations';

  /// POST /paypal/events/{event_id}/checkout/create — create PayPal order
  static String checkoutCreate(String eventId) =>
      '$baseUrl/paypal/events/$eventId/checkout/create';

  /// POST /paypal/events/{event_id}/checkout/capture — capture PayPal order after user approves
  static String checkoutCapture(String eventId) =>
      '$baseUrl/paypal/events/$eventId/checkout/capture';

  /// POST /paypal/spectator-checkout/create — create spectator-only PayPal order (no auth)
  static String get spectatorCheckoutCreate =>
      '$baseUrl/paypal/spectator-checkout/create';

  /// POST /paypal/spectator-checkout/capture — capture spectator PayPal order (no auth)
  static String get spectatorCheckoutCapture =>
      '$baseUrl/paypal/spectator-checkout/capture';

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
}

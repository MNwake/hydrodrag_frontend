class ApiConfig {
  // Backend URL configuration
  // For physical devices, use your computer's IP address
  // For simulators/emulators, localhost works
  // Override via: flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000
  // defaultValue: 'http://172.99.99.17:8000',  // public wifi
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.4.231:8000',
  );

  static String get authEndpoint => '$baseUrl/auth';
  static String get requestCodeEndpoint => '$authEndpoint/request-code';
  static String get verifyCodeEndpoint => '$authEndpoint/verify-code';
  static String get refreshTokenEndpoint => '$authEndpoint/refresh';
  static String get healthEndpoint => '$baseUrl/health';
  static String get meEndpoint => '$baseUrl/me';
  static String get addPwcEndpoint => '$baseUrl/me/pwc';
  static String get waiverUploadEndpoint => '$baseUrl/me/waiver';

  /// GET /registrations/event/{event_id}/registrations
  static String eventRegistrations(String eventId) =>
      '$baseUrl/registrations/event/$eventId/registrations';

  /// POST /events/{event_id}/checkout/create — create PayPal order (server uses client ID/secret), returns approval_url
  static String checkoutCreate(String eventId) =>
      '$baseUrl/events/$eventId/checkout/create';

  /// POST /events/{event_id}/checkout/capture — capture PayPal order after user approves
  static String checkoutCapture(String eventId) =>
      '$baseUrl/events/$eventId/checkout/capture';
}

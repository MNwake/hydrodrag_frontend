class ApiConfig {
  // Backend URL configuration
  // For physical devices, use your computer's IP address
  // For simulators/emulators, localhost works
  // Override via: flutter run --dart-define=API_BASE_URL=http://YOUR_IP:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.4.231:8000',
  );

  static String get authEndpoint => '$baseUrl/auth';
  static String get requestCodeEndpoint => '$authEndpoint/request-code';
  static String get verifyCodeEndpoint => '$authEndpoint/verify-code';
  static String get refreshTokenEndpoint => '$authEndpoint/refresh';
}

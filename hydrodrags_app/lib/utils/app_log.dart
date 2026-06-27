import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Centralized application logging.
///
/// All log output flows through this service. Do not use [print] or
/// [debugPrint] elsewhere in application code.
class AppLog {
  static const _logName = 'HydroDrags';

  /// Development-only diagnostic information. No-op in release builds.
  ///
  /// Set [terminal] to true for occasional debug lines that should appear in
  /// the `flutter run` console (e.g. startup configuration).
  static void debug(String category, String message, {bool terminal = false}) {
    if (!kDebugMode) return;
    _emit('DEBUG', category, message, terminal: terminal);
  }

  /// Important application events (sign-in, registration, payment, etc.).
  static void info(String category, String message) {
    _emit('INFO', category, message);
  }

  /// Unexpected situations the app recovered from.
  static void warning(String category, String message) {
    _emit('WARNING', category, message);
  }

  /// Genuine failures. Stack traces are included in debug builds only.
  ///
  /// Future crash-reporting / analytics integration should hook here.
  static void error(
    String category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool? recoverable,
  }) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write('. ${error.toString()}');
    }
    if (recoverable != null) {
      buffer.write(recoverable ? ' User can retry.' : ' User cannot retry.');
    }
    _emit('ERROR', category, buffer.toString());
    if (kDebugMode && stackTrace != null) {
      developer.log(
        stackTrace.toString(),
        name: _logName,
        level: 1000,
      );
    }
  }

  /// Debug-only concise HTTP summary, e.g. `GET /mobile/events -> 200 (184 ms)`.
  static void api(
    String method,
    String path,
    int statusCode, {
    int? durationMs,
  }) {
    if (!kDebugMode) return;
    final timing = durationMs != null ? ' (${durationMs} ms)' : '';
    final status = statusCode == 0 ? 'FAILED' : '$statusCode';
    final line = '$method $path -> $status$timing';
    developer.log(line, name: _logName);
    debugPrint('[API] $line');
  }

  /// Formats a concise HTTP failure message without response bodies.
  static String httpFailure(String action, int? statusCode) {
    return 'Failed to $action${statusCode != null ? '. HTTP $statusCode' : ''}';
  }

  /// Visible for testing.
  @visibleForTesting
  static String formatMessage(String level, String category, String message) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    return '$timestamp [$level] $category: $message';
  }

  /// Compact format for the debug-build terminal (`flutter run` console).
  @visibleForTesting
  static String formatTerminalMessage(String level, String category, String message) {
    return '[$level] $category: $message';
  }

  static void _emit(
    String level,
    String category,
    String message, {
    bool terminal = false,
  }) {
    final formatted = formatMessage(level, category, message);
    developer.log(formatted, name: _logName);

    // Mirror meaningful events to the flutter run console in debug builds.
    // DEBUG stays DevTools-only unless explicitly marked [terminal].
    if (kDebugMode && (terminal || level != 'DEBUG')) {
      debugPrint(formatTerminalMessage(level, category, message));
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrodrags_app/utils/app_log.dart';

void main() {
  group('AppLog.formatMessage', () {
    test('includes level, category, and message', () {
      final formatted = AppLog.formatMessage('INFO', 'Auth', 'User signed in');
      expect(formatted, contains('[INFO]'));
      expect(formatted, contains('Auth:'));
      expect(formatted, contains('User signed in'));
    });

    test('includes ISO-8601 timestamp prefix', () {
      final formatted = AppLog.formatMessage('DEBUG', 'API', 'test');
      expect(formatted, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
    });
  });

  group('AppLog.formatTerminalMessage', () {
    test('uses compact level category message format', () {
      expect(
        AppLog.formatTerminalMessage('INFO', 'Auth', 'User signed in'),
        '[INFO] Auth: User signed in',
      );
    });
  });

  group('AppLog.httpFailure', () {
    test('includes HTTP status when provided', () {
      expect(
        AppLog.httpFailure('fetch events', 500),
        'Failed to fetch events. HTTP 500',
      );
    });

    test('omits status when null', () {
      expect(
        AppLog.httpFailure('fetch events', null),
        'Failed to fetch events',
      );
    });
  });
}

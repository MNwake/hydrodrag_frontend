import 'package:flutter_test/flutter_test.dart';
import 'package:hydrodrags_app/utils/logged_http.dart';

void main() {
  group('LoggedHttp.pathFromUri', () {
    test('returns path only when no query', () {
      expect(
        LoggedHttp.pathFromUri(Uri.parse('https://api.example.com/events')),
        '/events',
      );
    });

    test('includes query string', () {
      expect(
        LoggedHttp.pathFromUri(Uri.parse('https://api.example.com/events?page=1')),
        '/events?page=1',
      );
    });

    test('returns slash for empty path', () {
      expect(
        LoggedHttp.pathFromUri(Uri.parse('https://api.example.com')),
        '/',
      );
    });
  });
}

import 'dart:convert' show Encoding;

import 'package:http/http.dart' as http;

import 'app_log.dart';

/// HTTP helpers that emit one concise log line per request in debug builds.
abstract final class LoggedHttp {
  static String pathFromUri(Uri uri) {
    final path = uri.hasEmptyPath ? '/' : uri.path;
    if (uri.query.isEmpty) return path;
    return '$path?${uri.query}';
  }

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) =>
      _run('GET', url, () => http.get(url, headers: headers));

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _run(
        'POST',
        url,
        () => http.post(url, headers: headers, body: body, encoding: encoding),
      );

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _run(
        'PATCH',
        url,
        () => http.patch(url, headers: headers, body: body, encoding: encoding),
      );

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _run(
        'DELETE',
        url,
        () => http.delete(url, headers: headers, body: body, encoding: encoding),
      );

  static Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await request.send();
      stopwatch.stop();
      AppLog.api(
        request.method,
        pathFromUri(request.url),
        response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return response;
    } catch (e) {
      stopwatch.stop();
      AppLog.api(
        request.method,
        pathFromUri(request.url),
        0,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  static Future<http.Response> _run(
    String method,
    Uri url,
    Future<http.Response> Function() request,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await request();
      stopwatch.stop();
      AppLog.api(
        method,
        pathFromUri(url),
        response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return response;
    } catch (e) {
      stopwatch.stop();
      AppLog.api(method, pathFromUri(url), 0, durationMs: stopwatch.elapsedMilliseconds);
      rethrow;
    }
  }
}

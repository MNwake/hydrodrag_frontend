import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/health_response.dart';
import '../utils/app_log.dart';
import '../utils/logged_http.dart';

class HealthApiClient {
  static const _cacheBodyKey = 'health_response_body';
  static const _cacheTimestampKey = 'health_response_cached_at';
  static const _cacheTtl = Duration(hours: 6);

  Future<HealthResponse?> fetchHealth() async {
    final cached = await _readCachedResponse();
    if (cached != null) {
      AppLog.debug('VersionCheck', 'Health check OK (cache)');
      return cached;
    }

    try {
      final response = await LoggedHttp.get(
        Uri.parse(ApiConfig.healthEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        AppLog.warning('VersionCheck', 'Health check failed. HTTP ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final healthResponse = HealthResponse.fromJson(body);
      await _writeCache(response.body);
      AppLog.debug('VersionCheck', 'Health check OK (network)');
      return healthResponse;
    } catch (e, stack) {
      AppLog.error(
        'VersionCheck',
        'Health check request failed',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      return null;
    }
  }

  Future<HealthResponse?> _readCachedResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAt = prefs.getInt(_cacheTimestampKey);
    final cachedBody = prefs.getString(_cacheBodyKey);

    if (cachedAt == null || cachedBody == null) {
      return null;
    }

    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (age >= _cacheTtl.inMilliseconds) {
      return null;
    }

    try {
      final body = jsonDecode(cachedBody) as Map<String, dynamic>;
      return HealthResponse.fromJson(body);
    } catch (e, stack) {
      AppLog.error(
        'VersionCheck',
        'Failed to parse cached health response',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      return null;
    }
  }

  Future<void> _writeCache(String body) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheBodyKey, body);
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

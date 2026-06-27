import 'dart:convert';
import '../utils/logged_http.dart';
import '../config/api_config.dart';
import '../models/hydrodrags_config.dart';
import '../utils/app_log.dart';

/// Fetches HydroDrags public config (info tab content). No auth required.
class HydroDragsConfigService {
  Future<HydroDragsConfig?> getConfig() async {
    try {
      final uri = Uri.parse(ApiConfig.hydrodragsConfigEndpoint);
      final response = await LoggedHttp.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HydroDragsConfig.fromJson(json);
      } else {
        AppLog.error(
          'HydroDragsConfig',
          AppLog.httpFailure('fetch config', response.statusCode),
          recoverable: true,
        );
        return null;
      }
    } catch (e, stack) {
      AppLog.error(
        'HydroDragsConfig',
        'Failed to fetch config',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      rethrow;
    }
  }
}

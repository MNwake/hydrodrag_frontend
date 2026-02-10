import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/hydrodrags_config.dart';

/// Fetches HydroDrags public config (info tab content). No auth required.
class HydroDragsConfigService {
  /// GET /hydrodrags/config
  Future<HydroDragsConfig?> getConfig() async {
    try {
      final uri = Uri.parse(ApiConfig.hydrodragsConfigEndpoint);

      if (kDebugMode) {
        print('=== API Request: Get HydroDrags Config ===');
        print('URL: $uri');
      }

      final response = await http.get(uri);

      if (kDebugMode) {
        print('=== API Response: HydroDrags Config ===');
        print('Status Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return HydroDragsConfig.fromJson(json);
      } else {
        if (kDebugMode) {
          print('Failed to get config: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting HydroDrags config: $e');
      }
      rethrow;
    }
  }
}

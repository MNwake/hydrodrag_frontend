import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';
import '../config/api_config.dart';
import '../models/pwc.dart';
import '../utils/app_log.dart';
import 'auth_service.dart';

/// Service for managing PWC (Personal Watercraft) data and API interactions
class PWCService {
  final AuthService _authService;

  PWCService(this._authService);

  /// Get authorization headers with bearer token
  Map<String, String> _getAuthHeaders() {
    final token = _authService.accessToken;
    if (token == null) {
      throw Exception('No access token available');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get all PWCs for the current racer from GET /me (RacerBase.pwc_id list).
  Future<List<PWC>> getPWCs() async {
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse(ApiConfig.meEndpoint);

      final response = await LoggedHttp.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final pwcIdList = body['pwc_id'];
        final List<PWC> pwcs = [];
        if (pwcIdList != null && pwcIdList is List) {
          for (var i = 0; i < pwcIdList.length; i++) {
            final racerNumber = pwcIdList[i]?.toString().trim() ?? '';
            if (racerNumber.isEmpty) continue;
            pwcs.add(PWC(
              id: racerNumber,
              make: racerNumber,
              model: '',
            ));
          }
        }
        return pwcs;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to load PWCs: ${response.statusCode}');
      }
    } catch (e, stack) {
      AppLog.error('PwcService', 'Failed to fetch PWCs', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Add a PWC by racer number (stored as `pwc_id`).
  /// POST /pwc with body: `{"pwc_id": "<racer number>"}`
  Future<bool> addPWC(String pwcId) async {
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse(ApiConfig.addPwcEndpoint);
      final requestBody = jsonEncode({'pwc_id': pwcId});

      final response = await LoggedHttp.post(
        uri,
        headers: _getAuthHeaders(),
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('PwcService', 'Failed to add PWC', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Update an existing PWC
  /// PATCH /me/pwc/{pwc_id} with body: {"new_name": "..."}
  Future<bool> updatePWC(PWC pwc) async {
    try {
      if (pwc.id == null) {
        throw Exception('PWC ID is required for update');
      }

      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/me/pwc/${pwc.id}');
      final requestBody = jsonEncode({'new_name': pwc.displayName});

      final response = await LoggedHttp.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('PwcService', 'Failed to update PWC', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Delete a PWC
  /// DELETE /me/pwc/{pwc_id}
  Future<bool> deletePWC(String pwcId) async {
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/me/pwc/$pwcId');

      final response = await LoggedHttp.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('PwcService', 'Failed to delete PWC', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }
}

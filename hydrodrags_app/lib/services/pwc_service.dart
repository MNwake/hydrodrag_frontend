import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/pwc.dart';
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

      if (kDebugMode) {
        print('=== API Request: Get PWCs (from /me) ===');
        print('URL: $uri');
        print('Method: GET');
        print('Headers: {Authorization: Bearer [REDACTED]}');
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('=== API Response: Get PWCs (from /me) ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final pwcIdList = body['pwc_id'];
        final List<PWC> pwcs = [];
        if (pwcIdList != null && pwcIdList is List) {
          for (var i = 0; i < pwcIdList.length; i++) {
            final name = pwcIdList[i]?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            pwcs.add(PWC(
              id: name,
              make: name,
              model: '',
              isPrimary: i == 0,
            ));
          }
        }

        if (kDebugMode) {
          print('Loaded ${pwcs.length} PWCs from racer pwc_id');
        }
        return pwcs;
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          print('No /me found (404) – returning empty list');
        }
        return [];
      } else {
        if (kDebugMode) {
          print('Failed to get /me: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        throw Exception('Failed to load PWCs: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting PWCs: $e');
      }
      rethrow;
    }
  }

  /// Add a PWC by name (ID).
  /// POST /pwc with body: `{"pwc_id": "<name>"}`
  Future<bool> addPWC(String pwcId) async {
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse(ApiConfig.addPwcEndpoint);
      final requestBody = jsonEncode({'pwc_id': pwcId});

      if (kDebugMode) {
        print('=== API Request: Add PWC ===');
        print('URL: $uri');
        print('Method: POST');
        print('Headers: {Authorization: Bearer [REDACTED], Content-Type: application/json}');
        print('Body: $requestBody');
      }

      final response = await http.post(
        uri,
        headers: _getAuthHeaders(),
        body: requestBody,
      );

      if (kDebugMode) {
        print('=== API Response: Add PWC ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          print('PWC added successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to add PWC: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding PWC: $e');
      }
      rethrow;
    }
  }

  /// Update an existing PWC
  /// PATCH /pwcs/{pwc_id}
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

      final uri = Uri.parse('${ApiConfig.baseUrl}/pwcs/${pwc.id}');

      if (kDebugMode) {
        print('=== API Request: Update PWC ===');
        print('URL: $uri');
        print('Method: PATCH');
        print('Headers: {Authorization: Bearer [REDACTED], Content-Type: application/json}');
      }

      final requestBody = jsonEncode(pwc.toUpdateJson());
      if (kDebugMode) {
        print('Request Body: $requestBody');
      }

      final response = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (kDebugMode) {
        print('=== API Response: Update PWC ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          print('PWC updated successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to update PWC: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating PWC: $e');
      }
      return false;
    }
  }

  /// Delete a PWC
  /// DELETE /pwcs/{pwc_id}
  Future<bool> deletePWC(String pwcId) async {
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/pwcs/$pwcId');

      if (kDebugMode) {
        print('=== API Request: Delete PWC ===');
        print('URL: $uri');
        print('Method: DELETE');
        print('Headers: {Authorization: Bearer [REDACTED]}');
      }

      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('=== API Response: Delete PWC ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (kDebugMode) {
          print('PWC deleted successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to delete PWC: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting PWC: $e');
      }
      return false;
    }
  }
}

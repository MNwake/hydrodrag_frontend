import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event_registration.dart';
import 'auth_service.dart';

/// Response from backend when creating a PayPal order.
class CreateCheckoutResponse {
  final String orderId;
  final String approvalUrl;

  CreateCheckoutResponse({required this.orderId, required this.approvalUrl});

  factory CreateCheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CreateCheckoutResponse(
      orderId: json['order_id'] as String? ?? '',
      approvalUrl: json['approval_url'] as String? ?? '',
    );
  }
}

/// Service for checkout (PayPal). Server holds client ID/secret and creates orders.
class CheckoutService {
  final AuthService _authService;

  CheckoutService(this._authService);

  Future<Map<String, String>> _headers() async {
    await _authService.refreshTokenIfNeeded();
    final token = await _authService.getValidAccessToken();
    if (token == null) throw Exception('No access token available');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Create PayPal order. Backend uses client ID/secret; returns order_id and approval_url.
  /// POST /events/{eventId}/checkout/create
  Future<CreateCheckoutResponse?> createPayPalOrder(
    String eventId,
    EventRegistration registration,
  ) async {
    try {
      final uri = Uri.parse(ApiConfig.checkoutCreate(eventId));
      final body = {
        'class_entries': registration.classEntries
            .map((e) => {'class_key': e.classKey, 'pwc_id': e.pwcId})
            .toList(),
        'purchase_ihra_membership': registration.purchaseIhraMembership,
        'spectator_single_day_passes': registration.spectatorSingleDayPasses,
        'spectator_weekend_passes': registration.spectatorWeekendPasses,
      };

      if (kDebugMode) {
        print('=== API Request: Create Checkout (PayPal) ===');
        print('URL: $uri');
        print('Body: $body');
      }

      final response = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('=== API Response: Create Checkout ===');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return CreateCheckoutResponse.fromJson(json);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error creating checkout: $e');
      rethrow;
    }
  }

  /// Capture PayPal order after user has approved in browser.
  /// POST /events/{eventId}/checkout/capture
  Future<bool> capturePayPalOrder(String eventId, String orderId) async {
    try {
      final uri = Uri.parse(ApiConfig.checkoutCapture(eventId));
      final body = {'order_id': orderId};

      if (kDebugMode) {
        print('=== API Request: Capture Checkout ===');
        print('URL: $uri');
        print('Body: $body');
      }

      final response = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('=== API Response: Capture Checkout ===');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['success'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Error capturing checkout: $e');
      rethrow;
    }
  }
}

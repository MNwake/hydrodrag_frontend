import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/spectator_ticket.dart';

/// Response from create spectator checkout.
class SpectatorCreateCheckoutResponse {
  final String orderId;
  final String approvalUrl;

  SpectatorCreateCheckoutResponse({
    required this.orderId,
    required this.approvalUrl,
  });

  factory SpectatorCreateCheckoutResponse.fromJson(Map<String, dynamic> json) {
    return SpectatorCreateCheckoutResponse(
      orderId: json['paypal_order_id'] as String? ?? json['order_id'] as String? ?? '',
      approvalUrl: json['approval_url'] as String? ?? '',
    );
  }
}

/// Response from capture spectator checkout (includes created tickets).
class SpectatorCaptureResponse {
  final bool success;
  final List<SpectatorTicket> tickets;

  SpectatorCaptureResponse({required this.success, required this.tickets});

  factory SpectatorCaptureResponse.fromJson(Map<String, dynamic> json) {
    final ticketsList = json['tickets'] as List<dynamic>?;
    final tickets = ticketsList != null
        ? ticketsList
            .map((e) => SpectatorTicket.fromJson(e as Map<String, dynamic>))
            .toList()
        : <SpectatorTicket>[];
    // Backend may return "success": true or "status": "captured" / "already_captured"
    final success = json['success'] as bool? ??
        (json['status'] == 'captured' || json['status'] == 'already_captured');
    return SpectatorCaptureResponse(
      success: success,
      tickets: tickets,
    );
  }
}

/// Spectator checkout: no auth. Used for purchasing spectator tickets only.
class SpectatorCheckoutService {
  /// Create PayPal order for spectator tickets.
  /// POST /paypal/spectator-checkout/create
  Future<SpectatorCreateCheckoutResponse?> createSpectatorCheckout({
    required String eventId,
    required String purchaserName,
    required String purchaserEmail,
    required String purchaserPhone,
    required int spectatorSingleDayPasses,
    required int spectatorWeekendPasses,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.spectatorCheckoutCreate);
      final body = {
        'purchaser_name': purchaserName,
        'purchaser_email': purchaserEmail,
        'purchaser_phone': purchaserPhone,
        'spectator_single_day_passes': spectatorSingleDayPasses,
        'spectator_weekend_passes': spectatorWeekendPasses,
      };
      final bodyJson = jsonEncode(body);
      const headers = {'Content-Type': 'application/json'};

      if (kDebugMode) {
        debugPrint('[SpectatorCheckout] POST $uri');
        debugPrint('[SpectatorCheckout] body: $bodyJson');
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: bodyJson,
      );

      if (kDebugMode) {
        debugPrint('[SpectatorCheckout] status: ${response.statusCode}, body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SpectatorCreateCheckoutResponse.fromJson(json);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[SpectatorCheckout] create error: $e');
      rethrow;
    }
  }

  /// Capture spectator PayPal order after user approved in browser.
  /// POST /paypal/spectator-checkout/capture
  Future<SpectatorCaptureResponse> captureSpectatorCheckout({
    required String eventId,
    required String orderId,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.spectatorCheckoutCapture);
      final body = {'paypal_order_id': orderId};
      final bodyJson = jsonEncode(body);
      const headers = {'Content-Type': 'application/json'};

      if (kDebugMode) {
        debugPrint('[SpectatorCheckout] capture POST $uri');
        debugPrint('[SpectatorCheckout] body: $bodyJson');
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: bodyJson,
      );

      if (kDebugMode) {
        debugPrint('[SpectatorCheckout] capture status: ${response.statusCode}, body: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SpectatorCaptureResponse.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('[SpectatorCheckout] capture error: $e');
      rethrow;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';
import '../config/api_config.dart';
import '../models/event_registration.dart';
import '../utils/app_log.dart';
import 'auth_service.dart';

/// Response from backend when creating a PayPal order.
class CreateCheckoutResponse {
  final String orderId;
  final String approvalUrl;
  final bool success;
  final bool freeCheckout;

  CreateCheckoutResponse({
    required this.orderId,
    required this.approvalUrl,
    this.success = false,
    this.freeCheckout = false,
  });

  factory CreateCheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CreateCheckoutResponse(
      orderId: json['paypal_order_id'] as String? ?? json['order_id'] as String? ?? '',
      approvalUrl: json['approval_url'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      freeCheckout: json['free_checkout'] as bool? ?? false,
    );
  }
}

/// Result of POST /registrations/promo/verify.
class PromoVerifyResult {
  final bool valid;
  final String? code;
  final String? type; // e.g. "single_class", "all_classes"
  /// Discount amount in dollars for UI order summary. Optional; backend may include it.
  final double? discountAmount;

  PromoVerifyResult({required this.valid, this.code, this.type, this.discountAmount});

  factory PromoVerifyResult.fromJson(Map<String, dynamic> json) {
    final discount = json['discount_amount'];
    return PromoVerifyResult(
      valid: json['valid'] as bool? ?? false,
      code: json['code'] as String?,
      type: json['type'] as String?,
      discountAmount: discount != null ? (discount is num ? discount.toDouble() : double.tryParse('$discount')) : null,
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

  /// Verify promo code. POST /registrations/promo/verify
  /// Returns valid/code/type for UI; actual discount is applied when creating PayPal order.
  Future<PromoVerifyResult> verifyPromoCode(String code) async {
    try {
      final uri = Uri.parse(ApiConfig.promoVerify);
      final body = {'promo_code': code.trim().toUpperCase()};
      final bodyJson = jsonEncode(body);
      final headers = await _headers();

      final response = await LoggedHttp.post(
        uri,
        headers: headers,
        body: bodyJson,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PromoVerifyResult.fromJson(json);
      }
      return PromoVerifyResult(valid: false);
    } catch (e, stack) {
      AppLog.error('Checkout', 'Failed to verify promo code', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Create PayPal order. Backend uses client ID/secret; returns order_id and approval_url.
  /// POST /events/{eventId}/checkout/create
  /// [promoCode] Optional promo code to apply to the order.
  Future<CreateCheckoutResponse?> createPayPalOrder(
    String eventId,
    EventRegistration registration, {
    String? promoCode,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.checkoutCreate(eventId));
      final body = <String, dynamic>{
        'class_entries': registration.classEntries
            .map((e) => {'class_key': e.classKey, 'pwc_id': e.pwcId})
            .toList(),
        'purchase_ihra_membership': registration.purchaseIhraMembership,
        'spectator_single_day_passes': registration.spectatorSingleDayPasses,
        'spectator_weekend_passes': registration.spectatorWeekendPasses,
      };
      final code = promoCode?.trim();
      if (code != null && code.isNotEmpty) {
        body['promo_code'] = code;
      }
      final bodyJson = jsonEncode(body);
      final headers = await _headers();

      final response = await LoggedHttp.post(
        uri,
        headers: headers,
        body: bodyJson,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return CreateCheckoutResponse.fromJson(json);
      }
      return null;
    } catch (e, stack) {
      AppLog.error('Checkout', 'Payment failed', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Capture PayPal order after user has approved in browser.
  /// POST /webhooks/paypal/events/{eventId}/checkout/capture
  Future<bool> capturePayPalOrder(String eventId, String orderId) async {
    try {
      final uri = Uri.parse(ApiConfig.checkoutCapture(eventId));
      final body = {'paypal_order_id': orderId};
      final bodyJson = jsonEncode(body);
      final headers = await _headers();

      final response = await LoggedHttp.post(
        uri,
        headers: headers,
        body: bodyJson,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['success'] as bool? ?? false;
      }
      return false;
    } catch (e, stack) {
      AppLog.error('Checkout', 'Payment failed', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }
}

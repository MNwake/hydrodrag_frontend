import 'dart:convert';

import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';

import '../config/api_config.dart';
import '../utils/app_log.dart';
import 'mobile_payment_models.dart';

class MobilePaymentApiException implements Exception {
  final int statusCode;
  final String message;

  MobilePaymentApiException(this.statusCode, this.message);

  @override
  String toString() => 'MobilePaymentApiException($statusCode): $message';
}

/// HTTP client for /mobile/payments/* endpoints.
class MobilePaymentService {
  MobilePaymentService({this.authHeaders});

  final Future<Map<String, String>> Function()? authHeaders;

  Future<Map<String, String>> _headers({bool authenticated = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && authHeaders != null) {
      headers.addAll(await authHeaders!());
    }
    return headers;
  }

  Future<PaymentPricing?> quoteRegistration({
    required String eventId,
    required List<Map<String, String>> classEntries,
    bool purchaseIhraMembership = false,
    int spectatorSingleDayPasses = 0,
    int spectatorWeekendPasses = 0,
    String? promoCode,
  }) async {
    final body = {
      'payment_type': 'registration',
      'event_id': eventId,
      'class_entries': classEntries,
      'purchase_ihra_membership': purchaseIhraMembership,
      'spectator_single_day_passes': spectatorSingleDayPasses,
      'spectator_weekend_passes': spectatorWeekendPasses,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    };
    final json = await _postQuote(body, authenticated: true);
    if (json == null) return null;
    return PaymentPricing.fromJson(json['pricing'] as Map<String, dynamic>);
  }

  Future<PaymentPricing?> quoteSpectator({
    required int spectatorSingleDayPasses,
    required int spectatorWeekendPasses,
  }) async {
    final body = {
      'payment_type': 'spectator',
      'spectator_single_day_passes': spectatorSingleDayPasses,
      'spectator_weekend_passes': spectatorWeekendPasses,
    };
    final json = await _postQuote(body, authenticated: false);
    if (json == null) return null;
    return PaymentPricing.fromJson(json['pricing'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>?> _postQuote(
    Map<String, dynamic> body, {
    required bool authenticated,
  }) async {
    try {
      final response = await LoggedHttp.post(
        Uri.parse(ApiConfig.mobilePaymentsQuote),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      AppLog.error(
        'MobilePayment',
        AppLog.httpFailure('load pricing', response.statusCode),
        recoverable: true,
      );
      throw MobilePaymentApiException(
        response.statusCode,
        response.statusCode == 404
            ? 'Payment service not available. The app may need a server update.'
            : 'Could not load pricing (${response.statusCode})',
      );
    } catch (e, stack) {
      if (e is MobilePaymentApiException) rethrow;
      AppLog.error(
        'MobilePayment',
        'Failed to load pricing',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      rethrow;
    }
  }

  Future<PaymentStartResult?> startRegistration({
    required String eventId,
    required List<Map<String, String>> classEntries,
    bool purchaseIhraMembership = false,
    int spectatorSingleDayPasses = 0,
    int spectatorWeekendPasses = 0,
    String? promoCode,
  }) async {
    final body = {
      'payment_type': 'registration',
      'event_id': eventId,
      'class_entries': classEntries,
      'purchase_ihra_membership': purchaseIhraMembership,
      'spectator_single_day_passes': spectatorSingleDayPasses,
      'spectator_weekend_passes': spectatorWeekendPasses,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
    };
    return _start(body, authenticated: true);
  }

  Future<PaymentStartResult?> startSpectator({
    required String purchaserName,
    required String purchaserPhone,
    required String purchaserEmail,
    required int spectatorSingleDayPasses,
    required int spectatorWeekendPasses,
    String? eventId,
    String? purchaserZip,
  }) async {
    final body = {
      'payment_type': 'spectator',
      'purchaser_name': purchaserName,
      'purchaser_phone': purchaserPhone,
      'purchaser_email': purchaserEmail,
      'spectator_single_day_passes': spectatorSingleDayPasses,
      'spectator_weekend_passes': spectatorWeekendPasses,
      if (eventId != null) 'event_id': eventId,
      if (purchaserZip != null) 'purchaser_zip': purchaserZip,
    };
    return _start(body, authenticated: false);
  }

  Future<PaymentStartResult?> _start(
    Map<String, dynamic> body, {
    required bool authenticated,
  }) async {
    try {
      final response = await LoggedHttp.post(
        Uri.parse(ApiConfig.mobilePaymentsStart),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentStartResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      AppLog.error(
        'MobilePayment',
        AppLog.httpFailure('start checkout', response.statusCode),
        recoverable: true,
      );
      return null;
    } catch (e, stack) {
      AppLog.error(
        'MobilePayment',
        'Failed to start checkout',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      rethrow;
    }
  }

  Future<void> markCheckoutOpened(String paymentId) async {
    await LoggedHttp.post(
      Uri.parse(ApiConfig.mobilePaymentCheckoutOpened(paymentId)),
      headers: await _headers(),
    );
  }

  Future<PaymentApproveResult?> approve(String paymentId) async {
    try {
      final response = await LoggedHttp.post(
        Uri.parse(ApiConfig.mobilePaymentApprove(paymentId)),
        headers: await _headers(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentApproveResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      AppLog.error(
        'MobilePayment',
        AppLog.httpFailure('approve payment', response.statusCode),
        recoverable: true,
      );
      return null;
    } catch (e, stack) {
      AppLog.error(
        'MobilePayment',
        'Failed to approve payment',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      rethrow;
    }
  }

  Future<PaymentStatusResult?> getStatus(String paymentId) async {
    try {
      final response = await LoggedHttp.get(
        Uri.parse(ApiConfig.mobilePaymentStatus(paymentId)),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return PaymentStatusResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e, stack) {
      AppLog.error(
        'MobilePayment',
        'Failed to fetch payment status',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      rethrow;
    }
  }

  Future<bool> cancel(String paymentId) async {
    try {
      final response = await LoggedHttp.post(
        Uri.parse(ApiConfig.mobilePaymentCancel(paymentId)),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e, stack) {
      AppLog.error(
        'MobilePayment',
        'Failed to cancel payment',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

import '../config/api_config.dart';
import '../utils/app_log.dart';

/// Launches PayPal checkout via the native PayPal Mobile SDK (in-app sheet).
class PayPalCheckoutLauncher {
  PayPalCheckoutLauncher._();
  static final PayPalCheckoutLauncher instance = PayPalCheckoutLauncher._();

  final FlutterPaypalPayment _paypal = FlutterPaypalPayment();

  String? _initializedClientId;
  PaypalEnvironment? _initializedEnvironment;

  PaypalEnvironment _parseEnvironment(String environment) {
    switch (environment.toLowerCase()) {
      case 'live':
      case 'production':
        return PaypalEnvironment.live;
      default:
        return PaypalEnvironment.sandbox;
    }
  }

  Future<String?> _ensureInit({
    required String clientId,
    required String environment,
  }) async {
    if (clientId.isEmpty) {
      return 'PayPal client ID missing';
    }

    final env = _parseEnvironment(environment);
    if (_initializedClientId == clientId && _initializedEnvironment == env) {
      return null;
    }

    final result = await _paypal.init(
      PaypalConfig(
        clientId: clientId,
        environment: env,
        returnUrl: ApiConfig.paypalReturnUrl,
        debugMode: kDebugMode,
      ),
    );

    return result.fold(
      (failure) => failure.message,
      (_) {
        _initializedClientId = clientId;
        _initializedEnvironment = env;
        return null;
      },
    );
  }

  /// Opens native PayPal checkout. Returns true when user approved, false on cancel/error.
  Future<bool> pay({
    required String paypalOrderId,
    required String clientId,
    required String environment,
  }) async {
    if (paypalOrderId.isEmpty) {
      AppLog.debug('PayPalCheckout', 'Checkout skipped: empty order');
      return false;
    }

    final initError = await _ensureInit(
      clientId: clientId,
      environment: environment,
    );
    if (initError != null) {
      AppLog.error('PayPalCheckout', 'PayPal SDK init failed', recoverable: true);
      return false;
    }

    AppLog.debug('PayPalCheckout', 'Starting native checkout');

    final result = await _paypal.pay(
      PaymentRequest(orderId: paypalOrderId),
    );

    return result.fold(
      (failure) {
        if (failure.code == 'CANCELLED') {
          AppLog.info('PayPalCheckout', 'Payment cancelled');
        } else {
          AppLog.error(
            'PayPalCheckout',
            'Payment failed',
            error: failure.message,
            recoverable: true,
          );
        }
        return false;
      },
      (_) {
        AppLog.info('PayPalCheckout', 'Payment approved');
        return true;
      },
    );
  }
}

import '../utils/app_log.dart';
import 'mobile_payment_service.dart';
import 'paypal_checkout_launcher.dart';
import 'pending_payment_storage.dart';

enum MobilePaymentFlowState {
  idle,
  starting,
  checkoutOpen,
  approving,
  success,
  failed,
  canceled,
}

/// Orchestrates start → in-app PayPal checkout → approve for mobile payments.
class MobilePaymentController {
  MobilePaymentController(this._service);

  final MobilePaymentService _service;

  MobilePaymentFlowState state = MobilePaymentFlowState.idle;
  String? lastError;

  Future<Map<String, dynamic>?> runRegistrationPayment({
    required String eventId,
    required List<Map<String, String>> classEntries,
    bool purchaseIhraMembership = false,
    int spectatorSingleDayPasses = 0,
    int spectatorWeekendPasses = 0,
    String? promoCode,
  }) async {
    state = MobilePaymentFlowState.starting;
    lastError = null;
    AppLog.info('Registration', 'Registration started');

    final start = await _service.startRegistration(
      eventId: eventId,
      classEntries: classEntries,
      purchaseIhraMembership: purchaseIhraMembership,
      spectatorSingleDayPasses: spectatorSingleDayPasses,
      spectatorWeekendPasses: spectatorWeekendPasses,
      promoCode: promoCode,
    );
    if (start == null) {
      state = MobilePaymentFlowState.failed;
      lastError = 'Could not start checkout';
      AppLog.error('MobilePayment', 'Payment failed', recoverable: true);
      return null;
    }

    if (start.freeCheckout || start.completed) {
      state = MobilePaymentFlowState.success;
      await PendingPaymentStorage.clear();
      AppLog.info('Registration', 'Registration completed');
      return start.result;
    }

    return _runPayPalFlow(
      paymentId: start.paymentId,
      paypalOrderId: start.paypalOrderId,
      clientId: start.clientId,
      environment: start.environment,
      paymentType: 'registration',
      eventId: eventId,
    );
  }

  Future<Map<String, dynamic>?> runSpectatorPayment({
    required String purchaserName,
    required String purchaserPhone,
    required String purchaserEmail,
    required int spectatorSingleDayPasses,
    required int spectatorWeekendPasses,
    String? eventId,
    String? purchaserZip,
  }) async {
    state = MobilePaymentFlowState.starting;
    lastError = null;

    final start = await _service.startSpectator(
      purchaserName: purchaserName,
      purchaserPhone: purchaserPhone,
      purchaserEmail: purchaserEmail,
      spectatorSingleDayPasses: spectatorSingleDayPasses,
      spectatorWeekendPasses: spectatorWeekendPasses,
      eventId: eventId,
      purchaserZip: purchaserZip,
    );
    if (start == null) {
      state = MobilePaymentFlowState.failed;
      lastError = 'Could not start checkout';
      AppLog.error('MobilePayment', 'Payment failed', recoverable: true);
      return null;
    }

    return _runPayPalFlow(
      paymentId: start.paymentId,
      paypalOrderId: start.paypalOrderId,
      clientId: start.clientId,
      environment: start.environment,
      paymentType: 'spectator',
      eventId: eventId,
    );
  }

  Future<Map<String, dynamic>?> _runPayPalFlow({
    required String paymentId,
    required String paypalOrderId,
    required String clientId,
    required String environment,
    required String paymentType,
    String? eventId,
  }) async {
    await PendingPaymentStorage.save(
      paymentId: paymentId,
      paymentType: paymentType,
      eventId: eventId,
    );

    state = MobilePaymentFlowState.checkoutOpen;
    await _service.markCheckoutOpened(paymentId);

    final approved = await PayPalCheckoutLauncher.instance.pay(
      paypalOrderId: paypalOrderId,
      clientId: clientId,
      environment: environment,
    );
    if (!approved) {
      state = MobilePaymentFlowState.canceled;
      lastError = 'Payment canceled';
      AppLog.info('MobilePayment', 'Payment cancelled');
      return null;
    }

    state = MobilePaymentFlowState.approving;
    final approve = await _service.approve(paymentId);
    if (approve == null || !approve.isSuccess) {
      state = MobilePaymentFlowState.failed;
      lastError = approve?.error ?? 'Payment could not be confirmed';
      AppLog.error('MobilePayment', 'Payment failed', recoverable: true);
      return null;
    }

    state = MobilePaymentFlowState.success;
    await PendingPaymentStorage.clear();
    AppLog.info('MobilePayment', 'Payment approved');
    if (paymentType == 'registration') {
      AppLog.info('Registration', 'Registration completed');
    }
    return approve.result;
  }

  Future<Map<String, dynamic>?> retryApprove(String paymentId) async {
    state = MobilePaymentFlowState.approving;
    final approve = await _service.approve(paymentId);
    if (approve != null && approve.isSuccess) {
      state = MobilePaymentFlowState.success;
      await PendingPaymentStorage.clear();
      AppLog.info('MobilePayment', 'Payment approved');
      return approve.result;
    }
    state = MobilePaymentFlowState.failed;
    lastError = approve?.error ?? 'Payment could not be confirmed';
    AppLog.error('MobilePayment', 'Payment failed', recoverable: true);
    return null;
  }
}

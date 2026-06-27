import '../utils/app_log.dart';
import 'mobile_payment_models.dart';
import 'mobile_payment_service.dart';
import 'pending_payment_storage.dart';

/// Polls payment status and clears storage when terminal.
class PaymentRecoveryService {
  PaymentRecoveryService(this._paymentService);

  final MobilePaymentService _paymentService;

  Future<PaymentStatusResult?> recoverPendingPayment() async {
    final paymentId = await PendingPaymentStorage.paymentId();
    if (paymentId == null || paymentId.isEmpty) return null;

    AppLog.debug('PaymentRecovery', 'Checking pending checkout');

    final status = await _paymentService.getStatus(paymentId);
    if (status == null) {
      await PendingPaymentStorage.clear();
      return null;
    }

    if (status.status == 'expired') {
      AppLog.warning('PaymentRecovery', 'Pending checkout expired');
    }

    if (_isTerminal(status.status)) {
      if (status.isCompleted) {
        return status;
      }
      await PendingPaymentStorage.clear();
    }
    return status;
  }

  bool _isTerminal(String status) {
    return status == 'completed' ||
        status == 'failed' ||
        status == 'canceled' ||
        status == 'expired';
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event.dart';
import '../screens/registration_complete_screen.dart';
import '../screens/spectator_ticket_complete_screen.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../utils/app_log.dart';
import 'mobile_payment_controller.dart';
import 'mobile_payment_service.dart';
import 'payment_recovery_service.dart';
import 'payment_ticket_helpers.dart';
import 'pending_payment_storage.dart';

/// Checks for a pending payment_id on startup and routes to success if completed.
class PaymentRecoveryHandler extends StatefulWidget {
  const PaymentRecoveryHandler({super.key, required this.child});

  final Widget child;

  @override
  State<PaymentRecoveryHandler> createState() => _PaymentRecoveryHandlerState();
}

class _PaymentRecoveryHandlerState extends State<PaymentRecoveryHandler> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<Event?> _resolveEvent(String eventId) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final events = await EventService(auth).getEvents();
      for (final event in events) {
        if (event.id == eventId) return event;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _recover() async {
    if (_checked) return;
    _checked = true;

    final service = MobilePaymentService();
    final recovery = PaymentRecoveryService(service);
    final paymentId = await PendingPaymentStorage.paymentId();
    if (paymentId == null) return;

    var status = await recovery.recoverPendingPayment();
    if (!mounted || status == null) return;

    if (!status.isCompleted &&
        status.status != 'expired' &&
        status.status != 'canceled' &&
        status.status != 'failed') {
      AppLog.warning('PaymentRecovery', 'Session resumed');
      final controller = MobilePaymentController(service);
      final result = await controller.retryApprove(paymentId);
      if (result != null) {
        status = await service.getStatus(paymentId) ?? status;
      }
    }

    if (!status.isCompleted) return;

    AppLog.info('PaymentRecovery', 'Pending checkout completed');

    final record = await PendingPaymentStorage.load();
    final paymentType = record?['paymentType'] ?? status.paymentType;

    if (paymentType == 'registration') {
      await PendingPaymentStorage.clear();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RegistrationCompleteScreen()),
      );
      return;
    }

    if (paymentType == 'spectator') {
      final eventId = record?['eventId'];
      Event? event;
      if (eventId != null) {
        event = await _resolveEvent(eventId);
      }
      final tickets = ticketsFromPaymentResult(status.result, eventId ?? '');
      await PendingPaymentStorage.clear();
      if (!mounted || event == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpectatorTicketCompleteScreen(
            event: event!,
            tickets: tickets,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/waiver_session.dart';
import '../../payments/pending_waiver_storage.dart';
import '../../services/app_state_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_log.dart';
import '../../services/waiver_service.dart';

/// Routes the user to the correct waiver step based on session state.
class WaiverFlowRouter {
  WaiverFlowRouter._();

  /// Checkout with registration as the only route below it (waiver stack cleared).
  static Future<void> navigateToCheckout(BuildContext context) async {
    await PendingWaiverStorage.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/checkout',
      (route) => route.settings.name == '/event-registration',
    );
  }

  /// Back from checkout → fresh registration at step 0.
  static Future<void> exitToRegistrationStart(BuildContext context) async {
    final event =
        Provider.of<AppStateService>(context, listen: false).selectedEvent;
    await PendingWaiverStorage.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/event-registration',
      (route) => false,
      arguments: event,
    );
  }

  /// If waiver is already signed (registration flow), skip to checkout.
  static Future<bool> redirectIfSignedForRegistration(
    BuildContext context,
  ) async {
    if (await PendingWaiverStorage.isManualResignFlow()) return false;
    final eventId =
        Provider.of<AppStateService>(context, listen: false).selectedEvent?.id;
    if (eventId == null) return false;

    final auth = Provider.of<AuthService>(context, listen: false);
    final status = await WaiverService(auth).getStatus(eventId);
    if (!context.mounted) return true;
    if (status.hasSignedWaiver) {
      await navigateToCheckout(context);
      return true;
    }
    return false;
  }

  static Future<void> navigateToNextStep({
    required BuildContext context,
    required String eventId,
    required WaiverService waiverService,
    String? sessionId,
    bool manualResign = false,
  }) async {
    final status = await waiverService.getStatus(eventId);
    if (!context.mounted) return;

    if (!manualResign && status.hasSignedWaiver) {
      await navigateToCheckout(context);
      return;
    }

    final String resolvedSessionId;
    if (manualResign) {
      if (sessionId != null) {
        resolvedSessionId = sessionId;
      } else if (status.hasSignedWaiver) {
        resolvedSessionId =
            await waiverService.createReplacementSession(eventId);
      } else {
        resolvedSessionId = status.activeSessionId ??
            await waiverService.createReplacementSession(eventId);
      }
    } else {
      resolvedSessionId = sessionId ??
          status.activeSessionId ??
          await waiverService.createOrResumeSession(eventId);
    }

    if (!manualResign &&
        status.activeSessionId != null &&
        sessionId == null) {
      AppLog.warning('Waiver', 'Session resumed');
    }

    final detail = await waiverService.getSession(resolvedSessionId);
    if (!context.mounted) return;

    final route = _routeForSession(detail);
    await PendingWaiverStorage.save(
      eventId: eventId,
      sessionId: resolvedSessionId,
      step: _stepKey(route),
      flowType: manualResign
          ? PendingWaiverStorage.flowTypeManualResign
          : PendingWaiverStorage.flowTypeRegistration,
    );
    if (!context.mounted) return;

    Navigator.of(context).pushNamed(route, arguments: resolvedSessionId);
  }

  static String _routeForSession(WaiverSessionDetail detail) {
    if (!detail.governmentIdFrontUploaded) {
      return '/government-id-upload';
    }
    if (!detail.selfieUploaded) {
      return '/waiver-selfie';
    }
    return '/waiver-overview';
  }

  static String _stepKey(String route) {
    switch (route) {
      case '/government-id-upload':
        return 'government_id';
      case '/waiver-selfie':
        return 'selfie';
      case '/waiver-overview':
        return 'waiver_review';
      default:
        return 'government_id';
    }
  }

  /// Resume from secure storage after app restart.
  static Future<void> resumePending({
    required BuildContext context,
    required WaiverService waiverService,
  }) async {
    final pending = await PendingWaiverStorage.load();
    if (pending == null || !context.mounted) return;

    final eventId = pending['eventId']!;
    final sessionId = pending['sessionId']!;
    final manualResign =
        pending['flowType'] == PendingWaiverStorage.flowTypeManualResign;
    await navigateToNextStep(
      context: context,
      eventId: eventId,
      waiverService: waiverService,
      sessionId: sessionId,
      manualResign: manualResign,
    );
  }
}

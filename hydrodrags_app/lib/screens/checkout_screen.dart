import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/checkout_service.dart';
import '../services/error_handler_service.dart';
import '../widgets/language_toggle.dart';
import '../models/event_registration.dart';
import '../models/event.dart';
import '../l10n/app_localizations.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _orderId;
  bool _isCreatingOrder = false;
  bool _isCapturing = false;

  Future<void> _payWithPayPal() async {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;
    final registration = appState.eventRegistration;

    if (event == null || registration == null) {
      ErrorHandlerService.showError(context, 'Registration or event not found');
      return;
    }

    setState(() => _isCreatingOrder = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final checkoutService = CheckoutService(authService);
      final result = await checkoutService.createPayPalOrder(event.id, registration);

      if (!mounted) return;
      setState(() => _isCreatingOrder = false);

      if (result == null || result.approvalUrl.isEmpty) {
        ErrorHandlerService.showError(context, 'Could not start PayPal checkout');
        return;
      }

      _orderId = result.orderId;
      final uri = Uri.parse(result.approvalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ErrorHandlerService.showError(context, 'Could not open PayPal');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
        ErrorHandlerService.logError(e, context: 'Create Checkout');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _confirmPaymentComplete() async {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;

    if (event == null || _orderId == null || _orderId!.isEmpty) {
      ErrorHandlerService.showError(context, 'No pending order. Start checkout first.');
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final checkoutService = CheckoutService(authService);
      final success = await checkoutService.capturePayPalOrder(event.id, _orderId!);

      if (!mounted) return;
      setState(() => _isCapturing = false);

      if (success) {
        Navigator.of(context).pushReplacementNamed('/registration-complete');
      } else {
        ErrorHandlerService.showError(context, 'Payment could not be confirmed. Try again or contact support.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ErrorHandlerService.logError(e, context: 'Capture Checkout');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateService>(context);
    final event = appState.selectedEvent;
    final registration = appState.eventRegistration;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkout ?? 'Checkout'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (event != null) ...[
                Text(
                  event.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                l10n.orderSummary ?? 'Order Summary',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (registration != null && event != null) ...[
                ..._buildRegistrationSummary(context, event, registration, l10n),
                const Divider(height: 24),
                _buildSummaryRow(
                  context,
                  l10n.total ?? 'Total',
                  '\$${_computeTotal(event, registration).toStringAsFixed(2)}',
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isCreatingOrder ? null : _payWithPayPal,
                  icon: _isCreatingOrder
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payment),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.payWithPayPal ?? 'Pay with PayPal'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.afterPayPalReturn ?? 'After completing payment in the browser, return to this app and tap below.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_orderId == null || _orderId!.isEmpty || _isCapturing)
                            ? null
                            : _confirmPaymentComplete,
                        icon: _isCapturing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline, size: 20),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(l10n.iveCompletedPayment ?? "I've completed payment"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _spectatorSingleDayPrice = 30.0;
  static const double _spectatorWeekendPrice = 40.0;
  static const double _ihraMembershipPrice = 85.0;

  EventClass? _eventClassFor(Event event, String classKey) {
    for (final c in event.classes) {
      if (c.key == classKey) return c;
    }
    return null;
  }

  /// Registration cost from event class price(s). Spectator: $30 single day, $40 weekend.
  double _computeTotal(Event event, EventRegistration registration) {
    double total = 0;
    for (final entry in registration.classEntries) {
      final eventClass = _eventClassFor(event, entry.classKey);
      if (eventClass != null) total += eventClass.price;
    }
    total += registration.spectatorSingleDayPasses * _spectatorSingleDayPrice;
    total += registration.spectatorWeekendPasses * _spectatorWeekendPrice;
    if (registration.purchaseIhraMembership) total += _ihraMembershipPrice;
    return total;
  }

  List<Widget> _buildRegistrationSummary(
    BuildContext context,
    Event event,
    EventRegistration registration,
    AppLocalizations l10n,
  ) {
    final list = <Widget>[];
    for (final entry in registration.classEntries) {
      final eventClass = _eventClassFor(event, entry.classKey);
      if (eventClass != null) {
        list.add(_buildSummaryRow(
          context,
          eventClass.name,
          '\$${eventClass.price.toStringAsFixed(2)}',
        ));
      }
    }
    if (registration.purchaseIhraMembership) {
      list.add(_buildSummaryRow(
        context,
        l10n.purchaseIhraMembershipWithRegistration,
        '\$${_ihraMembershipPrice.toStringAsFixed(2)}',
      ));
    }
    if (registration.spectatorSingleDayPasses > 0) {
      list.add(_buildSummaryRow(
        context,
        '${l10n.spectatorSingleDayPass} × ${registration.spectatorSingleDayPasses}',
        '\$${(registration.spectatorSingleDayPasses * _spectatorSingleDayPrice).toStringAsFixed(2)}',
      ));
    }
    if (registration.spectatorWeekendPasses > 0) {
      list.add(_buildSummaryRow(
        context,
        '${l10n.spectatorWeekendPass} × ${registration.spectatorWeekendPasses}',
        '\$${(registration.spectatorWeekendPasses * _spectatorWeekendPrice).toStringAsFixed(2)}',
      ));
    }
    return list;
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

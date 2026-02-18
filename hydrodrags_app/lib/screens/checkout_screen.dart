import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _promoCodeController = TextEditingController();
  String? _appliedPromoCode;
  String? _appliedPromoType; // "single_class" | "all_classes"
  bool _isVerifyingPromo = false;
  String? _promoError;

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _payWithPayPal() async {
    if (kDebugMode) {
      debugPrint('[Checkout] Pay with PayPal button pressed');
    }
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;
    final registration = appState.eventRegistration;

    if (event == null || registration == null) {
      if (kDebugMode) debugPrint('[Checkout] Abort: event or registration is null');
      ErrorHandlerService.showError(context, 'Registration or event not found');
      return;
    }
    if (kDebugMode) {
      debugPrint('[Checkout] Creating PayPal order for eventId=${event.id}');
    }

    setState(() => _isCreatingOrder = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final checkoutService = CheckoutService(authService);
      final result = await checkoutService.createPayPalOrder(
        event.id,
        registration,
        promoCode: _appliedPromoCode,
      );

      if (!mounted) return;
      setState(() => _isCreatingOrder = false);

      if (kDebugMode) {
        debugPrint('[Checkout] Create order response: orderId=${result?.orderId}, hasApprovalUrl=${result?.approvalUrl.isNotEmpty ?? false}');
      }
      if (result == null || result.approvalUrl.isEmpty) {
        ErrorHandlerService.showError(context, 'Could not start PayPal checkout');
        return;
      }

      _orderId = result.orderId;
      final uri = Uri.parse(result.approvalUrl);
      if (kDebugMode) {
        debugPrint('[Checkout] Opening PayPal approval URL in browser');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ErrorHandlerService.showError(context, 'Could not open PayPal');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Checkout] Pay with PayPal error: $e');
      if (mounted) {
        setState(() => _isCreatingOrder = false);
        ErrorHandlerService.logError(e, context: 'Create Checkout');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _confirmPaymentComplete() async {
    if (kDebugMode) {
      debugPrint('[Checkout] I\'ve completed payment button pressed');
    }
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;

    if (event == null || _orderId == null || _orderId!.isEmpty) {
      if (kDebugMode) debugPrint('[Checkout] Abort: no event or orderId (orderId=$_orderId)');
      ErrorHandlerService.showError(context, 'No pending order. Start checkout first.');
      return;
    }
    if (kDebugMode) {
      debugPrint('[Checkout] Capturing PayPal order for eventId=${event.id}, orderId=$_orderId');
    }

    setState(() => _isCapturing = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final checkoutService = CheckoutService(authService);
      final success = await checkoutService.capturePayPalOrder(event.id, _orderId!);

      if (!mounted) return;
      setState(() => _isCapturing = false);

      if (kDebugMode) {
        debugPrint('[Checkout] Capture response: success=$success');
      }
      if (success) {
        Navigator.of(context).pushReplacementNamed('/registration-complete');
      } else {
        ErrorHandlerService.showError(context, 'Payment could not be confirmed. Try again or contact support.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Checkout] I\'ve completed payment error: $e');
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
                if (_appliedPromoCode != null &&
                    _effectivePromoDiscount(event, registration) > 0)
                  _buildSummaryRow(
                    context,
                    'Promo (${_appliedPromoCode!})',
                    '-\$${_effectivePromoDiscount(event, registration).toStringAsFixed(2)}',
                  ),
                const Divider(height: 24),
                _buildSummaryRow(
                  context,
                  l10n.total ?? 'Total',
                  '\$${_displayTotal(event, registration).toStringAsFixed(2)}',
                ),
              ],
              const SizedBox(height: 20),
              _buildPromoCodeSection(context, theme, l10n),
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

  /// Subtotal from classes, spectator passes, membership. Used for order summary.
  double _computeSubtotal(Event event, EventRegistration registration) {
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

  /// Sum of class registration costs only (no spectators, no membership).
  double _classesSubtotal(Event event, EventRegistration registration) {
    double total = 0;
    for (final entry in registration.classEntries) {
      final eventClass = _eventClassFor(event, entry.classKey);
      if (eventClass != null) total += eventClass.price;
    }
    return total;
  }

  /// Promo discount for UI: single_class = cost of one registered class, all_classes = all class costs.
  double _effectivePromoDiscount(Event event, EventRegistration registration) {
    if (_appliedPromoCode == null || _appliedPromoType == null) return 0.0;
    switch (_appliedPromoType!) {
      case 'single_class':
        // Remove cost of one class (first registered class)
        for (final entry in registration.classEntries) {
          final eventClass = _eventClassFor(event, entry.classKey);
          if (eventClass != null) return eventClass.price;
        }
        return 0.0;
      case 'all_classes':
        return _classesSubtotal(event, registration);
      default:
        return 0.0;
    }
  }

  /// Total shown in UI: subtotal minus promo discount. PayPal order still uses full details on server.
  double _displayTotal(Event event, EventRegistration registration) {
    final subtotal = _computeSubtotal(event, registration);
    return subtotal - _effectivePromoDiscount(event, registration);
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

  Widget _buildPromoCodeSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final hasAppliedCode = _appliedPromoCode != null && _appliedPromoCode!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.promoCode,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (hasAppliedCode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_offer_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _appliedPromoCode!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_appliedPromoType != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _promoTypeLabel(l10n, _appliedPromoType!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _appliedPromoCode = null;
                      _appliedPromoType = null;
                      _promoError = null;
                      _promoCodeController.clear();
                    });
                  },
                  child: Text(l10n.promoCodeRemove),
                ),
              ],
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  decoration: InputDecoration(
                    hintText: l10n.promoCodePlaceholder,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  onSubmitted: (_) => _applyPromoCode(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _isVerifyingPromo ? null : _applyPromoCode,
                child: _isVerifyingPromo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.promoCodeApply),
              ),
            ],
          ),
        if (_promoError != null) ...[
          const SizedBox(height: 8),
          Text(
            _promoError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  String _promoTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'single_class':
        return l10n.promoTypeSingleClass;
      case 'all_classes':
        return l10n.promoTypeAllClasses;
      default:
        return type;
    }
  }

  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isVerifyingPromo = true;
      _promoError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final checkoutService = CheckoutService(authService);
      final result = await checkoutService.verifyPromoCode(code);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isVerifyingPromo = false;
        if (result.valid) {
          _appliedPromoCode = result.code ?? code;
          _appliedPromoType = result.type;
          _promoError = null;
        } else {
          _appliedPromoCode = null;
          _appliedPromoType = null;
          _promoError = l10n.promoCodeInvalid;
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[Checkout] Verify promo error: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isVerifyingPromo = false;
        _promoError = l10n.promoCodeInvalid;
      });
      ErrorHandlerService.logError(e, context: 'Verify Promo');
    }
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

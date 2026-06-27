import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/event.dart';
import '../models/event_registration.dart';
import '../payments/mobile_payment_controller.dart';
import '../payments/mobile_payment_models.dart';
import '../payments/mobile_payment_service.dart';
import '../payments/registration_checkout_helpers.dart';
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/waiver_service.dart';
import '../payments/pending_waiver_storage.dart';
import '../services/error_handler_service.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';
import '../waiver_capture/widgets/waiver_flow_progress.dart';
import '../waiver_capture/services/waiver_flow_router.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PaymentPricing? _pricing;
  bool _isLoadingQuote = true;
  bool _isPaying = false;
  String? _quoteError;
  final TextEditingController _promoCodeController = TextEditingController();
  String? _appliedPromoCode;
  bool _isVerifyingPromo = false;
  String? _promoError;

  @override
  void initState() {
    super.initState();
    _verifyWaiverThenQuote();
  }

  Future<void> _verifyWaiverThenQuote() async {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;
    if (event == null) {
      _loadQuote();
      return;
    }
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final status = await WaiverService(auth).getStatus(event.id);
      if (!mounted) return;
      if (!status.hasSignedWaiver) {
        setState(() {
          _isLoadingQuote = false;
          _quoteError =
              'Event waiver required before payment. Complete the waiver step first.';
        });
        return;
      }
      await PendingWaiverStorage.clear();
      _loadQuote();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _quoteError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<MobilePaymentService> _paymentService() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    return MobilePaymentService(
      authHeaders: () async {
        await auth.refreshTokenIfNeeded();
        final token = await auth.getValidAccessToken();
        if (token == null) throw Exception('No access token available');
        return {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
      },
    );
  }

  Future<void> _loadQuote() async {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;
    final registration = appState.eventRegistration;

    if (event == null || !registrationHasCheckoutData(registration)) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _pricing = null;
          _quoteError = event == null
              ? 'Event not found. Go back and select an event.'
              : 'Registration details are missing. Go back and complete registration.';
        });
      }
      return;
    }

    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });
    try {
      final service = await _paymentService();
      final classEntries = registrationClassEntriesPayload(registration!);
      final quote = await service.quoteRegistration(
        eventId: event.id,
        classEntries: classEntries,
        purchaseIhraMembership: registration.purchaseIhraMembership,
        spectatorSingleDayPasses: registration.spectatorSingleDayPasses,
        spectatorWeekendPasses: registration.spectatorWeekendPasses,
        promoCode: _appliedPromoCode,
      );
      if (!mounted) return;
      if (quote == null) {
        setState(() {
          _pricing = null;
          _isLoadingQuote = false;
          _quoteError = 'Could not load order summary.';
        });
        return;
      }
      setState(() {
        _pricing = quote;
        _isLoadingQuote = false;
        _quoteError = null;
      });
    } on MobilePaymentApiException catch (e) {
      if (mounted) {
        setState(() {
          _pricing = null;
          _isLoadingQuote = false;
          _quoteError = e.message;
        });
      }
      ErrorHandlerService.logError(e, context: 'Load checkout quote');
    } catch (e) {
      if (mounted) {
        setState(() {
          _pricing = null;
          _isLoadingQuote = false;
          _quoteError = 'Could not load order summary. Check your connection and try again.';
        });
      }
      ErrorHandlerService.logError(e, context: 'Load checkout quote');
    }
  }

  Future<void> _payWithPayPal() async {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final event = appState.selectedEvent;
    final registration = appState.eventRegistration;
    if (event == null || registration == null) {
      ErrorHandlerService.showError(context, 'Registration or event not found');
      return;
    }

    setState(() => _isPaying = true);
    try {
      final service = await _paymentService();
      final controller = MobilePaymentController(service);
      final result = await controller.runRegistrationPayment(
        eventId: event.id,
        classEntries: registrationClassEntriesPayload(registration),
        purchaseIhraMembership: registration.purchaseIhraMembership,
        spectatorSingleDayPasses: registration.spectatorSingleDayPasses,
        spectatorWeekendPasses: registration.spectatorWeekendPasses,
        promoCode: _appliedPromoCode,
      );

      if (!mounted) return;
      setState(() => _isPaying = false);

      if (result != null) {
        Navigator.of(context).pushReplacementNamed('/registration-complete');
        return;
      }

      final message = controller.lastError ?? 'Payment could not be completed';
      if (controller.state != MobilePaymentFlowState.canceled) {
        ErrorHandlerService.showError(context, message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        ErrorHandlerService.logError(e, context: 'Registration payment');
        ErrorHandlerService.showError(context, e);
      }
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
      final service = await _paymentService();
      final quote = await service.quoteRegistration(
        eventId: Provider.of<AppStateService>(context, listen: false).selectedEvent!.id,
        classEntries: registrationClassEntriesPayload(
          Provider.of<AppStateService>(context, listen: false).eventRegistration!,
        ),
        purchaseIhraMembership:
            Provider.of<AppStateService>(context, listen: false).eventRegistration!.purchaseIhraMembership,
        spectatorSingleDayPasses:
            Provider.of<AppStateService>(context, listen: false).eventRegistration!.spectatorSingleDayPasses,
        spectatorWeekendPasses:
            Provider.of<AppStateService>(context, listen: false).eventRegistration!.spectatorWeekendPasses,
        promoCode: code,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isVerifyingPromo = false;
        if (quote != null && quote.promoValid == true) {
          _appliedPromoCode = quote.promoCode ?? code;
          _pricing = quote;
          _promoError = null;
        } else {
          _appliedPromoCode = null;
          _promoError = l10n.promoCodeInvalid;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isVerifyingPromo = false;
        _promoError = l10n.promoCodeInvalid;
      });
      ErrorHandlerService.logError(e, context: 'Verify Promo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateService>(context);
    final event = appState.selectedEvent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        WaiverFlowRouter.exitToRegistrationStart(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.checkout ?? 'Checkout'),
        leading: BackButton(
          onPressed: () => WaiverFlowRouter.exitToRegistrationStart(context),
        ),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const WaiverFlowProgressHeader(
            currentStep: WaiverFlowStep.payment,
            idFrontComplete: true,
            idBackSkipped: true,
            selfieComplete: true,
            waiverReadComplete: true,
            signatureComplete: true,
          ),
          Expanded(
            child: SafeArea(
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
              if (_isLoadingQuote)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ))
              else if (_pricing != null) ...[
                ..._pricing!.lineItems.map(
                  (item) => _buildSummaryRow(
                    context,
                    _lineItemLabel(item, l10n),
                    _formatMoney(item.amount),
                  ),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  context,
                  l10n.total ?? 'Total',
                  _formatMoney(_pricing!.totalAmount),
                ),
              ] else if (_quoteError != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _quoteError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadQuote,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildPromoCodeSection(context, theme, l10n),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isPaying || _isLoadingQuote || _pricing == null)
                      ? null
                      : _payWithPayPal,
                  icon: _isPaying
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _lineItemLabel(PaymentLineItem item, AppLocalizations l10n) {
    if (item.quantity != null && item.quantity! > 1) {
      return '${item.label} × ${item.quantity}';
    }
    return item.label;
  }

  String _formatMoney(double amount) {
    final prefix = amount < 0 ? '-\$' : '\$';
    return '$prefix${amount.abs().toStringAsFixed(2)}';
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
                Expanded(child: Text(_appliedPromoCode!)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _appliedPromoCode = null;
                      _promoError = null;
                      _promoCodeController.clear();
                    });
                    _loadQuote();
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
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
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

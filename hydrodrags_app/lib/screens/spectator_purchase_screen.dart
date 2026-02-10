import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event.dart';
import '../models/hydrodrags_config.dart';
import '../services/spectator_checkout_service.dart';
import '../services/hydrodrags_config_service.dart';
import '../services/error_handler_service.dart';
import '../widgets/language_toggle.dart';
import '../utils/phone_formatter.dart';
import '../l10n/app_localizations.dart';
import 'spectator_ticket_complete_screen.dart';

class SpectatorPurchaseScreen extends StatefulWidget {
  final Event event;

  const SpectatorPurchaseScreen({super.key, required this.event});

  @override
  State<SpectatorPurchaseScreen> createState() => _SpectatorPurchaseScreenState();
}

class _SpectatorPurchaseScreenState extends State<SpectatorPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  int _step = 0; // 0: info, 1: tickets, 2: review & pay
  int _singleDayPasses = 0;
  int _weekendPasses = 0;
  HydroDragsConfig? _config;
  bool _configLoading = true;

  String? _orderId;
  bool _isCreatingOrder = false;
  bool _isCapturing = false;

  static const double _fallbackSingleDayPrice = 30.0;
  static const double _fallbackWeekendPrice = 40.0;

  double get _singleDayPrice =>
      _config?.spectatorSingleDayPrice ?? _fallbackSingleDayPrice;
  double get _weekendPrice =>
      _config?.spectatorWeekendPrice ?? _fallbackWeekendPrice;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final service = HydroDragsConfigService();
    try {
      final config = await service.getConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _configLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _configLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_step == 0) {
      if (_formKey.currentState?.validate() ?? false) {
        setState(() => _step = 1);
      }
    } else if (_step == 1) {
      if (_singleDayPasses > 0 || _weekendPasses > 0) {
        setState(() => _step = 2);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one ticket.'),
          ),
        );
      }
    }
  }

  void _previousStep() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _payWithPayPal() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = PhoneFormatter.getDigitsOnly(_phoneController.text);
    if (name.isEmpty || email.isEmpty || phone.length < 10) {
      ErrorHandlerService.showError(context, 'Please enter name, email, and phone.');
      return;
    }
    if (_singleDayPasses == 0 && _weekendPasses == 0) {
      ErrorHandlerService.showError(context, 'Please add at least one ticket.');
      return;
    }

    setState(() => _isCreatingOrder = true);
    try {
      final service = SpectatorCheckoutService();
      final result = await service.createSpectatorCheckout(
        eventId: widget.event.id,
        purchaserName: name,
        purchaserEmail: email,
        purchaserPhone: _phoneController.text.trim(),
        spectatorSingleDayPasses: _singleDayPasses,
        spectatorWeekendPasses: _weekendPasses,
      );
      if (!mounted) return;
      setState(() => _isCreatingOrder = false);

      if (result == null || result.approvalUrl.isEmpty) {
        ErrorHandlerService.showError(context, 'Could not start PayPal checkout.');
        return;
      }
      _orderId = result.orderId;
      final uri = Uri.parse(result.approvalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ErrorHandlerService.showError(context, 'Could not open PayPal.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
        ErrorHandlerService.logError(e, context: 'Spectator Create Checkout');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  Future<void> _confirmPaymentComplete() async {
    if (_orderId == null || _orderId!.isEmpty) {
      ErrorHandlerService.showError(context, 'No pending order. Start checkout first.');
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final service = SpectatorCheckoutService();
      final response = await service.captureSpectatorCheckout(
        eventId: widget.event.id,
        orderId: _orderId!,
      );
      if (!mounted) return;
      setState(() => _isCapturing = false);

      if (response.success && response.tickets.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SpectatorTicketCompleteScreen(
              event: widget.event,
              tickets: response.tickets,
            ),
          ),
        );
      } else if (response.success) {
        // Backend didn't return tickets; still show success and suggest lookup by phone
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SpectatorTicketCompleteScreen(
              event: widget.event,
              tickets: const [],
            ),
          ),
        );
      } else {
        ErrorHandlerService.showError(
          context,
          'Payment could not be confirmed. Try again or contact support.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ErrorHandlerService.logError(e, context: 'Spectator Capture Checkout');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchaseSpectatorTickets),
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
              Text(
                widget.event.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_step == 0) _buildStepInfo(l10n, theme),
              if (_step == 1) _buildStepTickets(l10n, theme),
              if (_step == 2) _buildStepReviewAndPay(l10n, theme),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _previousStep,
                      child: Text(l10n.previous),
                    ),
                  if (_step > 0) const SizedBox(width: 16),
                  if (_step < 2)
                    FilledButton(
                      onPressed: _nextStep,
                      child: Text(l10n.next),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepInfo(AppLocalizations l10n, ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n.purchaserInfo,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.purchaserInfoDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.purchaserName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: l10n.email,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
              if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: l10n.phoneNumber,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneNumberInputFormatter()],
            validator: (v) => PhoneFormatter.validatePhoneNumber(v),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTickets(AppLocalizations l10n, ThemeData theme) {
    if (_configLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.spectatorDayPasses,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.spectatorDayPassesDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.spectatorSingleDayPass,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            IconButton.filled(
              onPressed: _singleDayPasses > 0
                  ? () => setState(() => _singleDayPasses--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_singleDayPasses', style: theme.textTheme.titleMedium),
            ),
            IconButton.filled(
              onPressed: () => setState(() => _singleDayPasses++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.spectatorWeekendPass,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            IconButton.filled(
              onPressed: _weekendPasses > 0
                  ? () => setState(() => _weekendPasses--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_weekendPasses', style: theme.textTheme.titleMedium),
            ),
            IconButton.filled(
              onPressed: () => setState(() => _weekendPasses++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepReviewAndPay(AppLocalizations l10n, ThemeData theme) {
    final total = _singleDayPasses * _singleDayPrice + _weekendPasses * _weekendPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          l10n.orderSummary,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_singleDayPasses > 0)
          _summaryRow(
            theme,
            '${l10n.spectatorSingleDayPass} × $_singleDayPasses',
            '\$${(_singleDayPasses * _singleDayPrice).toStringAsFixed(2)}',
          ),
        if (_weekendPasses > 0)
          _summaryRow(
            theme,
            '${l10n.spectatorWeekendPass} × $_weekendPasses',
            '\$${(_weekendPasses * _weekendPrice).toStringAsFixed(2)}',
          ),
        const SizedBox(height: 8),
        _summaryRow(
          theme,
          l10n.total,
          '\$${total.toStringAsFixed(2)}',
          bold: true,
        ),
        const SizedBox(height: 24),
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
              child: Text(l10n.payWithPayPal),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                l10n.afterPayPalReturn,
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
                    child: Text(l10n.iveCompletedPayment),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w600 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import '../payments/mobile_payment_controller.dart';
import '../payments/mobile_payment_models.dart';
import '../payments/mobile_payment_service.dart';
import '../payments/payment_ticket_helpers.dart';
import '../payments/pending_payment_storage.dart';
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
  final _zipController = TextEditingController();

  int _step = 0; // 0: info, 1: tickets, 2: review & pay
  int _singleDayPasses = 0;
  int _weekendPasses = 0;
  PaymentPricing? _pricing;
  bool _isLoadingQuote = false;
  bool _isPaying = false;

  final _paymentService = MobilePaymentService();

  @override
  void initState() {
    super.initState();
    _loadQuote();
    _checkPendingPayment();
  }

  Future<void> _checkPendingPayment() async {
    final record = await PendingPaymentStorage.load();
    if (!mounted || record == null) return;
    if (record['eventId'] == widget.event.id) {
      setState(() => _step = 2);
    }
  }

  Future<void> _loadQuote() async {
    setState(() => _isLoadingQuote = true);
    try {
      final quote = await _paymentService.quoteSpectator(
        spectatorSingleDayPasses: _singleDayPasses,
        spectatorWeekendPasses: _weekendPasses,
      );
      if (mounted) {
        setState(() {
          _pricing = quote;
          _isLoadingQuote = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingQuote = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      if (_formKey.currentState?.validate() ?? false) {
        setState(() => _step = 1);
      }
    } else if (_step == 1) {
      if (_singleDayPasses > 0 || _weekendPasses > 0) {
        setState(() => _step = 2);
        _loadQuote();
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
    final zip = _zipController.text.trim();
    if (name.isEmpty || email.isEmpty || phone.length < 10) {
      ErrorHandlerService.showError(context, 'Please enter name, email, and phone.');
      return;
    }
    if (zip.length != 5 || int.tryParse(zip) == null) {
      ErrorHandlerService.showError(context, 'Please enter a valid 5-digit ZIP code.');
      return;
    }
    if (_singleDayPasses == 0 && _weekendPasses == 0) {
      ErrorHandlerService.showError(context, 'Please add at least one ticket.');
      return;
    }

    setState(() => _isPaying = true);
    try {
      final controller = MobilePaymentController(_paymentService);
      final result = await controller.runSpectatorPayment(
        purchaserName: name,
        purchaserPhone: _phoneController.text.trim(),
        purchaserEmail: email,
        spectatorSingleDayPasses: _singleDayPasses,
        spectatorWeekendPasses: _weekendPasses,
        eventId: widget.event.id,
        purchaserZip: zip,
      );
      if (!mounted) return;
      setState(() => _isPaying = false);

      if (result != null) {
        final tickets = ticketsFromPaymentResult(result, widget.event.id);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SpectatorTicketCompleteScreen(
              event: widget.event,
              tickets: tickets,
            ),
          ),
        );
        return;
      }

      final message = controller.lastError ?? 'Payment could not be completed';
      if (controller.state != MobilePaymentFlowState.canceled) {
        ErrorHandlerService.showError(context, message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        ErrorHandlerService.logError(e, context: 'Spectator payment');
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _zipController,
            decoration: InputDecoration(
              labelText: l10n.zipPostalCode,
              hintText: '12345',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            validator: (v) {
              final digits = v?.trim() ?? '';
              if (digits.isEmpty) return 'ZIP code is required';
              if (digits.length != 5) return 'Enter a 5-digit ZIP code';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepTickets(AppLocalizations l10n, ThemeData theme) {
    final dayPrice = _pricing?.spectatorSingleDayPrice;
    final weekendPrice = _pricing?.spectatorWeekendPrice;
    final dayLabel = dayPrice != null
        ? '${l10n.spectatorSingleDayPass} (\$${dayPrice.toStringAsFixed(0)})'
        : l10n.spectatorSingleDayPass;
    final weekendLabel = weekendPrice != null
        ? '${l10n.spectatorWeekendPass} (\$${weekendPrice.toStringAsFixed(0)})'
        : l10n.spectatorWeekendPass;

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
              child: Text(dayLabel, style: theme.textTheme.bodyLarge),
            ),
            IconButton.filled(
              onPressed: _singleDayPasses > 0
                  ? () {
                      setState(() => _singleDayPasses--);
                      _loadQuote();
                    }
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_singleDayPasses', style: theme.textTheme.titleMedium),
            ),
            IconButton.filled(
              onPressed: () {
                setState(() => _singleDayPasses++);
                _loadQuote();
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(weekendLabel, style: theme.textTheme.bodyLarge),
            ),
            IconButton.filled(
              onPressed: _weekendPasses > 0
                  ? () {
                      setState(() => _weekendPasses--);
                      _loadQuote();
                    }
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_weekendPasses', style: theme.textTheme.titleMedium),
            ),
            IconButton.filled(
              onPressed: () {
                setState(() => _weekendPasses++);
                _loadQuote();
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepReviewAndPay(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingQuote && _pricing == null) {
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
          l10n.orderSummary,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_pricing != null)
          ..._pricing!.lineItems.map(
            (item) => _summaryRow(
              theme,
              item.quantity != null && item.quantity! > 1
                  ? '${item.label} × ${item.quantity}'
                  : item.label,
              '\$${item.amount.toStringAsFixed(2)}',
            ),
          ),
        const SizedBox(height: 8),
        _summaryRow(
          theme,
          l10n.total,
          '\$${(_pricing?.totalAmount ?? 0).toStringAsFixed(2)}',
          bold: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_isPaying || _pricing == null) ? null : _payWithPayPal,
            icon: _isPaying
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

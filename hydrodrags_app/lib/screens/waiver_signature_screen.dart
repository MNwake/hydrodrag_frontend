import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/racer_service.dart';
import '../services/error_handler_service.dart';
import '../utils/waiver_pdf.dart';
import '../widgets/language_toggle.dart';
import '../models/waiver.dart';
import '../models/racer_profile.dart';

class WaiverSignatureScreen extends StatefulWidget {
  const WaiverSignatureScreen({super.key});

  @override
  State<WaiverSignatureScreen> createState() => _WaiverSignatureScreenState();
}

class _WaiverSignatureScreenState extends State<WaiverSignatureScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _nameController = TextEditingController();
  bool _agreeToTerms = false;
  final _formKey = GlobalKey<FormState>();
  DateTime _signedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppStateService>(context, listen: false);
    final profile = appState.racerProfile;
    if (profile != null) {
      _nameController.text = profile.fullName;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _signedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Date of signature',
    );
    if (picked != null && mounted) {
      setState(() => _signedDate = picked);
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must agree to the terms')),
      );
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your signature')),
      );
      return;
    }

    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null || !mounted) return;

    final appState = Provider.of<AppStateService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final racerService = RacerService(authService);

    // Build full waiver PDF: text + initials + signature + date + name
    final initials = appState.waiverInitials ?? [];
    final initialsPadded = List<String>.from(initials);
    while (initialsPadded.length < 8) {
      initialsPadded.add('');
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final pdfBytes = await buildWaiverPdf(
        initials: initialsPadded,
        signaturePngBytes: signatureBytes,
        signedDate: _signedDate,
        fullLegalName: _nameController.text.trim(),
      );

      final uploaded = await racerService.uploadWaiver(
        pdfBytes,
        filename: 'waiver.pdf',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (uploaded) {
        final signatureData = base64Encode(signatureBytes);
        final event = appState.selectedEvent;
        final waiverId = event?.id ?? 'default-waiver';

        final signature = WaiverSignature(
          waiverId: waiverId,
          fullLegalName: _nameController.text,
          signatureData: signatureData,
          signedAt: _signedDate,
          initials: initials.isNotEmpty ? initials : null,
        );

        appState.setWaiverSignature(signature);
        Navigator.of(context).pushReplacementNamed('/checkout');
      } else {
        ErrorHandlerService.showError(
          context,
          'Failed to save waiver. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ErrorHandlerService.logError(e, context: 'Upload Waiver');
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiver Signature'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '2026 HydroDrag Waiver — Signature',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete the date and sign below. You have already initialed all sections on the previous screen.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                // Date
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${_signedDate.year}-${_signedDate.month.toString().padLeft(2, '0')}-${_signedDate.day.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Legal Name',
                    helperText: 'Enter your full legal name as it appears on your ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  "Competitor/Participant's Legal Signature:",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.colorScheme.outline),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.draw, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sign in the box below',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _signatureController.clear(),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _agreeToTerms,
                  onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                  title: const Text(
                    'I certify that I have read and agree to the terms and conditions of this waiver.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
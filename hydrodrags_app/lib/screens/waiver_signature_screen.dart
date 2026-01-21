import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
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

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppStateService>(context, listen: false);
    final profile = appState.racerProfile;
    if (profile != null) {
      _nameController.text = profile.fullName;
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
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

    _signatureController.toPngBytes().then((bytes) {
      if (bytes != null) {
        final signatureData = base64Encode(bytes);
        final signature = WaiverSignature(
          waiverId: 'waiver-1', // TODO: Get actual waiver ID
          fullLegalName: _nameController.text,
          signatureData: signatureData,
          signedAt: DateTime.now(),
        );

        Provider.of<AppStateService>(context, listen: false).setWaiverSignature(signature);
        Navigator.of(context).pushReplacementNamed('/registration-complete');
      }
    });
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
                  'Sign Waiver',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Legal Name',
                    helperText: 'Enter your full legal name as it appears on your ID',
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                Card(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.colorScheme.outline),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.draw, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sign below',
                                style: theme.textTheme.titleMedium,
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
                Text(
                  'Date: ${DateTime.now().toString().split(' ')[0]}',
                  style: theme.textTheme.bodyMedium,
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
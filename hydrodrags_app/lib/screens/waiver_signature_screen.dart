import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../payments/pending_waiver_storage.dart';
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/error_handler_service.dart';
import '../services/waiver_service.dart';
import '../widgets/language_toggle.dart';
import '../waiver_capture/widgets/waiver_flow_progress.dart';
import '../waiver_capture/services/waiver_flow_router.dart';

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
  bool _confirmIdentity = false;
  final _formKey = GlobalKey<FormState>();
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppStateService>(context, listen: false);
    final profile = appState.racerProfile;
    if (profile != null) {
      _nameController.text = profile.fullName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionId = ModalRoute.of(context)?.settings.arguments as String?;
      if (await WaiverFlowRouter.redirectIfSignedForRegistration(context)) {
        return;
      }
    });
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _collectEvidence() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();
    String platform = 'unknown';
    String os = 'unknown';
    String? deviceModel;

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      platform = 'android';
      os = 'Android ${android.version.release}';
      deviceModel = android.model;
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      platform = 'ios';
      os = 'iOS ${ios.systemVersion}';
      deviceModel = ios.utsname.machine;
    }

    final now = DateTime.now();
    return {
      'device_timestamp': now.toUtc().toIso8601String(),
      'timezone_name': now.timeZoneName,
      'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
      'platform': platform,
      'operating_system': os,
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      'device_model': deviceModel,
      'locale': Localizations.localeOf(context).toLanguageTag(),
      'gps_available': false,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms || !_confirmIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must confirm your identity and agree to the waiver'),
        ),
      );
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your signature')),
      );
      return;
    }
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiver session missing')),
      );
      return;
    }

    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final service = WaiverService(auth);
      final evidence = await _collectEvidence();
      await service.signWaiver(
        sessionId: _sessionId!,
        typedLegalName: _nameController.text.trim(),
        confirmedIdentity: _confirmIdentity,
        confirmedRead: _agreeToTerms,
        evidence: evidence,
        signaturePngBytes: signatureBytes,
      );
      final manualResign = await PendingWaiverStorage.isManualResignFlow();
      await PendingWaiverStorage.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (manualResign) {
        Navigator.of(context).pushReplacementNamed('/event-waivers');
        return;
      }
      await WaiverFlowRouter.navigateToCheckout(context);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ErrorHandlerService.logError(e, context: 'Sign Waiver');
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
      body: Column(
        children: [
          const WaiverFlowProgressHeader(
            currentStep: WaiverFlowStep.signature,
            idFrontComplete: true,
            idBackSkipped: true,
            selfieComplete: true,
            waiverReadComplete: true,
          ),
          Expanded(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        appState.waiverTitle ?? 'Waiver — Signature',
                        style: theme.textTheme.headlineMedium,
                      ),
                const SizedBox(height: 8),
                Text(
                  'Type your full legal name as shown on your government ID.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full legal name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _confirmIdentity,
                  onChanged: (v) => setState(() => _confirmIdentity = v ?? false),
                  title: const Text(
                    'I am the individual shown on my government-issued ID',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _agreeToTerms,
                  onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
                  title: const Text(
                    'I have read and agree to the waiver terms',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                Text('Draw your signature', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => _signatureController.clear(),
                  child: const Text('Clear signature'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Submit waiver'),
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

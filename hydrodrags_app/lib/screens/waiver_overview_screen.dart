import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/waiver_service.dart';
import '../waiver_capture/widgets/waiver_flow_progress.dart';
import '../waiver_capture/services/waiver_flow_router.dart';

class WaiverOverviewScreen extends StatefulWidget {
  const WaiverOverviewScreen({super.key});

  @override
  State<WaiverOverviewScreen> createState() => _WaiverOverviewScreenState();
}

class _WaiverOverviewScreenState extends State<WaiverOverviewScreen> {
  bool _loading = true;
  String? _error;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    _sessionId = routeArgs as String?;
    if (_sessionId == null) {
      setState(() {
        _loading = false;
        _error = 'Waiver session not found';
      });
      return;
    }
    if (await WaiverFlowRouter.redirectIfSignedForRegistration(context)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final service = WaiverService(auth);
      final detail = await service.getSession(_sessionId!);
      if (!mounted) return;
      final appState = Provider.of<AppStateService>(context, listen: false);
      appState.setWaiverFromConfig(
        content: detail.waiverText,
        title: 'Event Waiver — ${detail.eventName}',
      );
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      if (await WaiverFlowRouter.redirectIfSignedForRegistration(context)) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openWaiverReading() {
    Navigator.of(context).pushNamed(
      '/waiver-reading',
      arguments: _sessionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.waiver),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const WaiverFlowProgressHeader(
            currentStep: WaiverFlowStep.waiver,
            idFrontComplete: true,
            idBackSkipped: true,
            selfieComplete: true,
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error loading waiver.', style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: _loadSession, child: Text(l10n.retry)),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),
                        Icon(Icons.description, size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          Provider.of<AppStateService>(context).waiverTitle ?? l10n.waiver,
                          style: theme.textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.waiverExplanation,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _openWaiverReading,
                          icon: const Icon(Icons.visibility),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(l10n.viewWaiver),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

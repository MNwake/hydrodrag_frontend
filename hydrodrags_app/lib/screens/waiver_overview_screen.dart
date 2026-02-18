import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';
import '../models/hydrodrags_config.dart';
import '../services/hydrodrags_config_service.dart';
import '../services/app_state_service.dart';

class WaiverOverviewScreen extends StatefulWidget {
  const WaiverOverviewScreen({super.key});

  @override
  State<WaiverOverviewScreen> createState() => _WaiverOverviewScreenState();
}

class _WaiverOverviewScreenState extends State<WaiverOverviewScreen> {
  final HydroDragsConfigService _configService = HydroDragsConfigService();
  HydroDragsConfig? _config;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await _configService.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openWaiverReading() {
    final waiver = _config?.waiver;
    if (waiver == null || !waiver.isActive || waiver.content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiver is not available.'),
        ),
      );
      return;
    }
    final appState = Provider.of<AppStateService>(context, listen: false);
    appState.setWaiverFromConfig(
      content: waiver.content,
      title: waiver.title,
    );
    Navigator.of(context).pushNamed('/waiver-reading');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final waiverAvailable =
        _config?.waiver != null &&
        _config!.waiver!.isActive &&
        _config!.waiver!.content.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.waiver),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error loading waiver.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _loadConfig,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),
                        Icon(
                          Icons.description,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _config?.waiver?.title ?? l10n.waiver,
                          style: theme.textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.waiverExplanation,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  l10n.importantInformation,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.readWaiverCarefully,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.language,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.languageToggleHint,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: waiverAvailable ? _openWaiverReading : null,
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
    );
  }
}
import 'package:flutter/material.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';

class WaiverOverviewScreen extends StatelessWidget {
  const WaiverOverviewScreen({super.key});

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
                l10n.waiver,
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
                        l10n.importantInformation ?? 'Important Information',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.readWaiverCarefully ?? 'Read the full waiver carefully before signing',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.language, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.languageToggleHint ?? 'You can change the language using the toggle in the app bar',
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
                onPressed: () {
                  Navigator.of(context).pushNamed('/waiver-reading');
                },
                icon: const Icon(Icons.visibility),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l10n.viewWaiver),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Download PDF - will be implemented when backend provides PDF endpoint
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.downloadPdfComingSoon ?? 'PDF download coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: Text(l10n.downloadPdf),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
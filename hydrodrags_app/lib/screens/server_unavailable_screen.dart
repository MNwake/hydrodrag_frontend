import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';

class ServerUnavailableScreen extends StatelessWidget {
  const ServerUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serverUnavailableTitle),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.serverUnavailableTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.serverUnavailableMessage,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    await authService.retryConnection();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.retryConnection),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    await authService.logout();
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.continueOffline),
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

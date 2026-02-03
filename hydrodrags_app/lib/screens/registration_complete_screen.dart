import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../widgets/language_toggle.dart';
import '../models/racer_profile.dart';
import '../models/event.dart';
import '../l10n/app_localizations.dart';

class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateService>(context);
    final racerProfile = appState.racerProfile;
    final event = appState.selectedEvent;
    final registrationId = 'REG-${DateTime.now().millisecondsSinceEpoch}'; // Generate unique ID

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registrationComplete),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.success,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        context,
                        l10n.racer,
                        racerProfile?.fullName ?? 'N/A',
                        Icons.person,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        l10n.events,
                        event?.name ?? 'N/A',
                        Icons.event,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        l10n.registrationId,
                        registrationId,
                        Icons.confirmation_number,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        l10n.waiverStatus,
                        l10n.signed,
                        Icons.verified,
                        isSuccess: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/main',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.event),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l10n.backToEvents),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: View registration details - will navigate to registration detail screen when implemented
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.viewRegistrationComingSoon ?? 'Registration details coming soon'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: Text(l10n.viewRegistration),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Download waiver PDF - will be implemented when backend provides PDF endpoint
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.downloadPdfComingSoon ?? 'PDF download coming soon'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: Text(l10n.downloadWaiverPdf),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isSuccess = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isSuccess ? theme.colorScheme.primary : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isSuccess)
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 20,
            ),
        ],
      ),
    );
  }
}
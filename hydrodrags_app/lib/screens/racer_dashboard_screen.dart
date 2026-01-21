import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../widgets/language_toggle.dart';
import '../models/racer_profile.dart';
import '../models/event.dart';
import '../models/event_registration.dart';

class RacerDashboardScreen extends StatelessWidget {
  const RacerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppStateService>(context);
    final racerProfile = appState.racerProfile;
    final event = appState.selectedEvent;
    final registration = appState.eventRegistration;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Event Dashboard'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${racerProfile?.firstName ?? 'Racer'}!',
                        style: theme.textTheme.headlineMedium,
                      ),
                      if (event != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          event.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Registration Status
              Text(
                'Registration Status',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Registered',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (registration != null) ...[
                        const SizedBox(height: 16),
                        _buildInfoRow(context, 'Class', registration.classSelection ?? 'N/A'),
                        _buildInfoRow(context, 'Entries', '${registration.numberOfEntries ?? 1}'),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Class & Vehicle Summary
              Text(
                'Class & Vehicle Summary',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: registration != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(context, 'Craft Type', registration.craftType ?? 'N/A'),
                            _buildInfoRow(context, 'Make', registration.make ?? 'N/A'),
                            _buildInfoRow(context, 'Model', registration.model ?? 'N/A'),
                            _buildInfoRow(context, 'Engine Class', registration.engineClass ?? 'N/A'),
                            if (registration.modifications.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Modifications:',
                                style: theme.textTheme.bodySmall,
                              ),
                              ...registration.modifications.map(
                                (mod) => Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(mod, style: theme.textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : Text(
                          'No vehicle information',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Heat Assignments (placeholder)
              Text(
                'Heat Assignments',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        'Heat assignments will be available closer to the event date',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Bracket Position (placeholder)
              Text(
                'Bracket Position',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.leaderboard, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        'Bracket positions will be available after registration closes',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action buttons
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/events');
                  },
                  icon: const Icon(Icons.event),
                  label: const Text('View All Events'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
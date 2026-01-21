import 'package:flutter/material.dart';
import '../widgets/language_toggle.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
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
              Text(
                'Continue as:',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              
              // Racer card
              Card(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed('/racer-profile');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Racer',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register for events, manage profile, sign waivers',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Spectator card
              Card(
                child: InkWell(
                  onTap: () {
                    // Spectators can view events without registration
                    Navigator.of(context).pushNamed('/events');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 48,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Spectator',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'View events and schedules (no account required)',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Admin/Staff card (can be hidden or PIN-gated in production)
              Card(
                child: InkWell(
                  onTap: () {
                    // TODO: Add admin authentication
                    Navigator.of(context).pushNamed('/admin');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 48,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Admin / Staff',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage events, racers, and registrations',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Lightweight auth option
              Text(
                'Or identify yourself:',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/auth');
                },
                icon: const Icon(Icons.phone),
                label: const Text('Phone Number / Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../models/language_preference.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo placeholder - replace with actual logo asset
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.water,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'HydroDrags',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Racer Registration & Event Management',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),
              
              // Language selector
              Text(
                'Language / Idioma',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Consumer<LanguageService>(
                builder: (context, languageService, child) {
                  return SegmentedButton<LanguagePreference>(
                    segments: [
                      ButtonSegment<LanguagePreference>(
                        value: LanguagePreference.english,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(languageService.currentLanguage == LanguagePreference.english 
                                ? 'English' 
                                : 'Inglés'),
                          ],
                        ),
                      ),
                      ButtonSegment<LanguagePreference>(
                        value: LanguagePreference.spanish,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇪🇸', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(languageService.currentLanguage == LanguagePreference.spanish 
                                ? 'Español' 
                                : 'Spanish'),
                          ],
                        ),
                      ),
                    ],
                    selected: {languageService.currentLanguage},
                    onSelectionChanged: (Set<LanguagePreference> selection) {
                      languageService.setLanguage(selection.first);
                    },
                  );
                },
              ),
              const SizedBox(height: 48),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
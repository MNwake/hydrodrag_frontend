import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../models/language_preference.dart';

class LanguageToggle extends StatelessWidget {
  final bool isCompact;

  const LanguageToggle({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        final currentLang = languageService.currentLanguage;

        if (isCompact) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => languageService.toggleLanguage(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentLang == LanguagePreference.english ? 'EN' : 'ES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentLang == LanguagePreference.english ? '🇺🇸' : '🇪🇸',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SegmentedButton<LanguagePreference>(
          segments: [
            ButtonSegment<LanguagePreference>(
              value: LanguagePreference.english,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇺🇸'),
                  const SizedBox(width: 4),
                  const Text('EN'),
                ],
              ),
            ),
            ButtonSegment<LanguagePreference>(
              value: LanguagePreference.spanish,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇪🇸'),
                  const SizedBox(width: 4),
                  const Text('ES'),
                ],
              ),
            ),
          ],
          selected: {currentLang},
          onSelectionChanged: (Set<LanguagePreference> selection) {
            languageService.setLanguage(selection.first);
          },
        );
      },
    );
  }
}
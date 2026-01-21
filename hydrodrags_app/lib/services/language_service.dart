import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language_preference.dart';

class LanguageService extends ChangeNotifier {
  LanguagePreference _currentLanguage = LanguagePreference.english;
  static const String _languageKey = 'selected_language';

  LanguagePreference get currentLanguage => _currentLanguage;
  Locale get currentLocale => Locale(_currentLanguage.code);

  LanguageService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en';
    
    _currentLanguage = languageCode == 'es'
        ? LanguagePreference.spanish
        : LanguagePreference.english;
    
    notifyListeners();
  }

  Future<void> setLanguage(LanguagePreference language) async {
    if (_currentLanguage == language) return;

    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
    
    notifyListeners();
  }

  void toggleLanguage() {
    final newLanguage = _currentLanguage == LanguagePreference.english
        ? LanguagePreference.spanish
        : LanguagePreference.english;
    setLanguage(newLanguage);
  }
}
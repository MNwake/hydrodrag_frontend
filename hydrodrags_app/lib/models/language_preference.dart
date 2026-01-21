enum LanguagePreference {
  english('en', 'English', '🇺🇸'),
  spanish('es', 'Español', '🇪🇸');

  final String code;
  final String displayName;
  final String flag;

  const LanguagePreference(this.code, this.displayName, this.flag);
}
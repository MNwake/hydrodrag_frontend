class EventRegistration {
  // Step 1 - Vehicle/Craft Info
  String? craftType;
  String? make;
  String? model;
  String? engineClass;
  List<String> modifications;
  String? classSelection;

  // Step 2 - Race Options
  int? numberOfEntries;
  String? heatPreferences;
  String? transponderId;

  EventRegistration({
    this.craftType,
    this.make,
    this.model,
    this.engineClass,
    this.modifications = const [],
    this.classSelection,
    this.numberOfEntries,
    this.heatPreferences,
    this.transponderId,
  });

  bool get isStep1Complete =>
      craftType != null &&
      craftType!.isNotEmpty &&
      make != null &&
      make!.isNotEmpty &&
      model != null &&
      model!.isNotEmpty &&
      engineClass != null &&
      engineClass!.isNotEmpty &&
      classSelection != null &&
      classSelection!.isNotEmpty;

  bool get isStep2Complete =>
      numberOfEntries != null && numberOfEntries! > 0;

  bool get isStep3Complete => isStep1Complete && isStep2Complete;
}
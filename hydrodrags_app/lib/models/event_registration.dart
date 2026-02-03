/// One class + PWC pairing. Same PWC can be used in multiple entries.
class ClassPwcEntry {
  final String classKey;  // Event class key (e.g. "pro_stock")
  final String pwcId;    // Selected PWC id

  ClassPwcEntry({required this.classKey, required this.pwcId});
}

class EventRegistration {
  // Multi-class: list of class + PWC entries (same PWC may appear in multiple entries)
  List<ClassPwcEntry> classEntries;

  // Legacy single entry (backward compat; use classEntries when non-empty)
  String? pwcId;
  String? classDivision;

  // IHRA membership: if user doesn't have valid membership, they add purchase with registration
  bool purchaseIhraMembership;

  // Spectator passes: $30 single day, $40 weekend pass
  int spectatorSingleDayPasses;
  int spectatorWeekendPasses;

  /// Total spectator day passes (single + weekend) for backward compat / display.
  int get spectatorDayPasses => spectatorSingleDayPasses + spectatorWeekendPasses;

  // Optional race preferences
  int? numberOfEntries;
  String? heatPreferences;

  // Payment info (to be added)
  String? paymentTransactionId;
  String? paymentStatus; // pending, completed, failed

  EventRegistration({
    List<ClassPwcEntry>? classEntries,
    this.pwcId,
    this.classDivision,
    this.purchaseIhraMembership = false,
    this.spectatorSingleDayPasses = 0,
    this.spectatorWeekendPasses = 0,
    this.numberOfEntries,
    this.heatPreferences,
    this.paymentTransactionId,
    this.paymentStatus,
  }) : classEntries = classEntries ?? [];

  /// True if at least one class+PWC entry is present (from list or legacy single).
  bool get hasClassEntries =>
      classEntries.isNotEmpty ||
      (pwcId != null && pwcId!.isNotEmpty && classDivision != null && classDivision!.isNotEmpty);

  // Legacy fields for backward compatibility (deprecated)
  @Deprecated('Use classEntries or pwcId instead')
  String? get craftType => null;

  @Deprecated('Use classEntries or pwcId instead')
  String? get make => null;

  @Deprecated('Use classEntries or pwcId instead')
  String? get model => null;

  @Deprecated('Use classEntries or pwcId instead')
  String? get engineClass => null;

  @Deprecated('Use classEntries or pwcId instead')
  List<String> get modifications => const [];

  @Deprecated('Use classEntries or classDivision instead')
  String? get classSelection => classDivision;

  bool get isStep1Complete => hasClassEntries;

  bool get isStep2Complete => true; // Waiver is separate step

  bool get isStep3Complete => paymentStatus == 'completed';

  bool get isComplete => isStep1Complete && isStep3Complete;
}

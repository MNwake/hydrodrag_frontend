/// Lightweight registration reference in bracket matchups (mirrors server RegistrationRefBase).
class RegistrationRefBase {
  final String id;
  final String racerId;
  final String? racerFirstName;
  final String? racerLastName;
  final String pwcIdentifier;
  final String classKey;
  final int losses;
  final bool isPaid;

  RegistrationRefBase({
    required this.id,
    required this.racerId,
    this.racerFirstName,
    this.racerLastName,
    this.pwcIdentifier = '',
    required this.classKey,
    required this.losses,
    required this.isPaid,
  });

  factory RegistrationRefBase.fromJson(Map<String, dynamic> json) {
    return RegistrationRefBase(
      id: json['id'] as String? ?? '',
      racerId: json['racer_id'] as String? ?? '',
      racerFirstName: json['racer_first_name'] as String?,
      racerLastName: json['racer_last_name'] as String?,
      pwcIdentifier: json['pwc_identifier'] as String? ?? '',
      classKey: json['class_key'] as String? ?? '',
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      isPaid: json['is_paid'] as bool? ?? false,
    );
  }

  String get fullName {
    final first = racerFirstName?.trim() ?? '';
    final last = racerLastName?.trim() ?? '';
    return '$first $last'.trim();
  }

  String get displayName => fullName.isEmpty ? '—' : fullName;

  /// Compact bracket label: first initial + last name (e.g. "D. Cracco").
  String get compactDisplayName {
    final first = racerFirstName?.trim() ?? '';
    final last = racerLastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) {
      return compactFromDisplayName(displayName);
    }
    if (last.isEmpty) return first;
    if (first.isEmpty) return last;
    return '${first[0].toUpperCase()}. $last';
  }

  static String compactFromDisplayName(String full) {
    if (full.isEmpty || full == '—') return full;
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return full;
    final initial = parts.first[0].toUpperCase();
    return '$initial. ${parts.last}';
  }
}

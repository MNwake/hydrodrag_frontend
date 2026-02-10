/// Lightweight registration reference in bracket matchups (mirrors server RegistrationRefBase).
class RegistrationRefBase {
  final String id;
  final String racerId;
  final String? racerFirstName;
  final String? racerLastName;
  final String classKey;
  final int losses;
  final bool isPaid;

  RegistrationRefBase({
    required this.id,
    required this.racerId,
    this.racerFirstName,
    this.racerLastName,
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
}

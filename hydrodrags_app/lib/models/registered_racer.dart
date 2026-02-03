/// Represents a racer who has registered for an event
class RegisteredRacer {
  final String id;
  final String racerId;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final String? classDivision; // The class/division they registered for
  final String? pwcMake;
  final String? pwcModel;
  final String? pwcEngineClass;
  final DateTime registeredAt;
  final String? registrationNumber; // Optional registration number/transponder ID

  RegisteredRacer({
    required this.id,
    required this.racerId,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    this.classDivision,
    this.pwcMake,
    this.pwcModel,
    this.pwcEngineClass,
    required this.registeredAt,
    this.registrationNumber,
  });

  factory RegisteredRacer.fromJson(Map<String, dynamic> json) {
    return RegisteredRacer(
      id: json['id'] as String,
      racerId: json['racer_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      classDivision: json['class_division'] as String?,
      pwcMake: json['pwc_make'] as String?,
      pwcModel: json['pwc_model'] as String?,
      pwcEngineClass: json['pwc_engine_class'] as String?,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      registrationNumber: json['registration_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'racer_id': racerId,
      'first_name': firstName,
      'last_name': lastName,
      'profile_image_url': profileImageUrl,
      'class_division': classDivision,
      'pwc_make': pwcMake,
      'pwc_model': pwcModel,
      'pwc_engine_class': pwcEngineClass,
      'registered_at': registeredAt.toIso8601String(),
      'registration_number': registrationNumber,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
  
  String get pwcDisplayName {
    if (pwcMake != null && pwcModel != null) {
      return '$pwcMake $pwcModel';
    }
    return 'N/A';
  }
}

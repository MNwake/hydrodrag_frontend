class RacerProfile {
  // Step 1 - Personal Info
  String? firstName;
  String? lastName;
  DateTime? dateOfBirth;
  String? gender;
  String? nationality;

  // Step 2 - Contact Info
  String? phoneNumber;
  String? email;
  String? emergencyContactName;
  String? emergencyContactPhone;

  // Step 3 - Address
  String? street;
  String? city;
  String? stateProvince;
  String? country;
  String? zipPostalCode;

  // Step 4 - Membership Details
  String? organization;
  String? membershipNumber;
  String? classCategory;

  RacerProfile({
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.phoneNumber,
    this.email,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.street,
    this.city,
    this.stateProvince,
    this.country,
    this.zipPostalCode,
    this.organization,
    this.membershipNumber,
    this.classCategory,
  });

  bool get isStep1Complete =>
      firstName != null &&
      firstName!.isNotEmpty &&
      lastName != null &&
      lastName!.isNotEmpty &&
      dateOfBirth != null;

  bool get isStep2Complete =>
      phoneNumber != null &&
      phoneNumber!.isNotEmpty &&
      email != null &&
      email!.isNotEmpty &&
      emergencyContactName != null &&
      emergencyContactName!.isNotEmpty &&
      emergencyContactPhone != null &&
      emergencyContactPhone!.isNotEmpty;

  bool get isStep3Complete =>
      street != null &&
      street!.isNotEmpty &&
      city != null &&
      city!.isNotEmpty &&
      stateProvince != null &&
      stateProvince!.isNotEmpty &&
      country != null &&
      country!.isNotEmpty &&
      zipPostalCode != null &&
      zipPostalCode!.isNotEmpty;

  bool get isStep4Complete =>
      classCategory != null && classCategory!.isNotEmpty;

  bool get isComplete =>
      isStep1Complete && isStep2Complete && isStep3Complete && isStep4Complete;

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
}
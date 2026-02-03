class RacerProfile {
  String? id;

  // Step 1 - Personal Info
  String? firstName;
  String? lastName;
  DateTime? dateOfBirth;
  String? gender;
  String? nationality;
  String? profileImagePath; // Path to profile image file

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
  DateTime? membershipPurchasedAt;
  String? classCategory;

  // Additional Profile Info
  String? bio;
  List<String>? sponsors;
  String? bannerImagePath; // Path to banner image file
  DateTime? profileImageUpdatedAt; // Timestamp when profile image was last updated
  DateTime? bannerImageUpdatedAt; // Timestamp when banner image was last updated

  /// From backend: racer has a signed waiver that is still valid (e.g. within 365 days).
  bool? hasValidWaiver;
  /// When the waiver was signed (from backend waiver_signed_at).
  DateTime? waiverSignedAt;

  RacerProfile({
    this.id,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.profileImagePath,
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
    this.membershipPurchasedAt,
    this.classCategory,
    this.bio,
    this.sponsors,
    this.bannerImagePath,
    this.profileImageUpdatedAt,
    this.bannerImageUpdatedAt,
    this.hasValidWaiver,
    this.waiverSignedAt,
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

  bool get isStep4Complete => true; // IHRA Membership # is optional

  bool get isComplete =>
      isStep1Complete && isStep2Complete && isStep3Complete && isStep4Complete;

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();
}
import 'package:flutter/material.dart';
import '../models/racer_profile.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../models/waiver.dart';

class AppStateService extends ChangeNotifier {
  RacerProfile? _racerProfile;
  Event? _selectedEvent;
  EventRegistration? _eventRegistration;
  WaiverSignature? _waiverSignature;

  RacerProfile? get racerProfile => _racerProfile;
  Event? get selectedEvent => _selectedEvent;
  EventRegistration? get eventRegistration => _eventRegistration;
  WaiverSignature? get waiverSignature => _waiverSignature;

  void setRacerProfile(RacerProfile profile) {
    _racerProfile = profile;
    notifyListeners();
  }

  void updateRacerProfileStep1({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? nationality,
  }) {
    _racerProfile ??= RacerProfile();
    _racerProfile!.firstName = firstName ?? _racerProfile!.firstName;
    _racerProfile!.lastName = lastName ?? _racerProfile!.lastName;
    _racerProfile!.dateOfBirth = dateOfBirth ?? _racerProfile!.dateOfBirth;
    _racerProfile!.gender = gender ?? _racerProfile!.gender;
    _racerProfile!.nationality = nationality ?? _racerProfile!.nationality;
    notifyListeners();
  }

  void updateRacerProfileStep2({
    String? phoneNumber,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    _racerProfile ??= RacerProfile();
    _racerProfile!.phoneNumber = phoneNumber ?? _racerProfile!.phoneNumber;
    _racerProfile!.email = email ?? _racerProfile!.email;
    _racerProfile!.emergencyContactName =
        emergencyContactName ?? _racerProfile!.emergencyContactName;
    _racerProfile!.emergencyContactPhone =
        emergencyContactPhone ?? _racerProfile!.emergencyContactPhone;
    notifyListeners();
  }

  void updateRacerProfileStep3({
    String? street,
    String? city,
    String? stateProvince,
    String? country,
    String? zipPostalCode,
  }) {
    _racerProfile ??= RacerProfile();
    _racerProfile!.street = street ?? _racerProfile!.street;
    _racerProfile!.city = city ?? _racerProfile!.city;
    _racerProfile!.stateProvince = stateProvince ?? _racerProfile!.stateProvince;
    _racerProfile!.country = country ?? _racerProfile!.country;
    _racerProfile!.zipPostalCode = zipPostalCode ?? _racerProfile!.zipPostalCode;
    notifyListeners();
  }

  void updateRacerProfileStep4({
    String? organization,
    String? membershipNumber,
    String? classCategory,
  }) {
    _racerProfile ??= RacerProfile();
    _racerProfile!.organization = organization ?? _racerProfile!.organization;
    _racerProfile!.membershipNumber =
        membershipNumber ?? _racerProfile!.membershipNumber;
    _racerProfile!.classCategory =
        classCategory ?? _racerProfile!.classCategory;
    notifyListeners();
  }

  void setSelectedEvent(Event event) {
    _selectedEvent = event;
    notifyListeners();
  }

  void setEventRegistration(EventRegistration registration) {
    _eventRegistration = registration;
    notifyListeners();
  }

  void setWaiverSignature(WaiverSignature signature) {
    _waiverSignature = signature;
    notifyListeners();
  }

  void clearRegistration() {
    _selectedEvent = null;
    _eventRegistration = null;
    _waiverSignature = null;
    notifyListeners();
  }
}
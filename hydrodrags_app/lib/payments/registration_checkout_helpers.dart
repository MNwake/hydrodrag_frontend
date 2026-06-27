import '../models/event_registration.dart';

/// Build API class_entries payload from registration state.
List<Map<String, String>> registrationClassEntriesPayload(EventRegistration registration) {
  if (registration.classEntries.isNotEmpty) {
    return registration.classEntries
        .map((e) => {'class_key': e.classKey, 'pwc_id': e.pwcId})
        .toList();
  }
  final pwcId = registration.pwcId;
  final classKey = registration.classDivision;
  if (pwcId != null &&
      pwcId.isNotEmpty &&
      classKey != null &&
      classKey.isNotEmpty) {
    return [
      {'class_key': classKey, 'pwc_id': pwcId},
    ];
  }
  return [];
}

bool registrationHasCheckoutData(EventRegistration? registration) {
  if (registration == null) return false;
  return registrationClassEntriesPayload(registration).isNotEmpty;
}

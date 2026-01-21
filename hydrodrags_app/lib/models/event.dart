enum EventRegistrationStatus {
  open,
  closed,
}

class Event {
  final String id;
  final String name;
  final String location;
  final DateTime date;
  final EventRegistrationStatus registrationStatus;

  Event({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.registrationStatus,
  });

  bool get isOpen => registrationStatus == EventRegistrationStatus.open;
}
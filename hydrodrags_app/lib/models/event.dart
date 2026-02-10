enum EventRegistrationStatus {
  open,
  closed,
  upcoming, // Registration not yet open
  past, // Event has ended
}

/// Schedule item for a specific day/time
class EventScheduleItem {
  final String id;
  final String day; // e.g., "Saturday", "Sunday", or date string
  final DateTime? startTime;
  final DateTime? endTime;
  final String description; // e.g., "Stock and Spec Classes, Turbo No Nitrous"
  final int? order; // For sorting

  EventScheduleItem({
    required this.id,
    required this.day,
    this.startTime,
    this.endTime,
    required this.description,
    this.order,
  });

  factory EventScheduleItem.fromJson(Map<String, dynamic> json) {
    return EventScheduleItem(
      id: json['id'] as String? ?? '',
      day: json['day'] as String? ?? '',
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'] as String)
          : null,
      description: json['description'] as String? ?? '',
      order: json['order'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'description': description,
      'order': order,
    };
  }
}

/// Event class/division (racing class with price)
class EventClass {
  final String key;       // stable identifier (e.g. "pro_stock")
  final String name;     // display name (e.g. "Pro Stock")
  final double price;    // registration cost
  final String? description;
  final bool isActive;

  EventClass({
    required this.key,
    required this.name,
    required this.price,
    this.description,
    this.isActive = true,
  });

  factory EventClass.fromJson(Map<String, dynamic> json) {
    return EventClass(
      key: json['key'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      'is_active': isActive,
    };
  }
}

/// Event rule (category + description)
class EventRule {
  final String category;
  final String description;

  EventRule({required this.category, required this.description});

  factory EventRule.fromJson(Map<String, dynamic> json) {
    return EventRule(
      category: json['category'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'category': category, 'description': description};
  }
}

/// Event information details (parking, tickets, seating, additional_info)
class EventInfo {
  final String? parking;
  final String? tickets;
  final String? foodAndDrink;
  final String? seating;
  /// Backend: additional_info as Dict[str, str]
  final Map<String, String>? additionalInfo;

  EventInfo({
    this.parking,
    this.tickets,
    this.foodAndDrink,
    this.seating,
    this.additionalInfo,
  });

  factory EventInfo.fromJson(Map<String, dynamic> json) {
    return EventInfo(
      parking: json['parking'] as String?,
      tickets: json['tickets'] as String?,
      foodAndDrink: json['food_and_drink'] as String?,
      seating: json['seating'] as String?,
      additionalInfo: json['additional_info'] != null && json['additional_info'] is Map
          ? Map<String, String>.from(
              (json['additional_info'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parking': parking,
      'tickets': tickets,
      'food_and_drink': foodAndDrink,
      'seating': seating,
      'additional_info': additionalInfo,
    };
  }
}

/// Location information
class EventLocation {
  final String name; // e.g., "Burt Aaronson South County Regional Park"
  final String? address; // Street address
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? fullAddress; // Full formatted address for display

  EventLocation({
    required this.name,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.latitude,
    this.longitude,
    this.fullAddress,
  });

  factory EventLocation.fromJson(Map<String, dynamic> json) {
    return EventLocation(
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code']?.toString(),
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      fullAddress: json['full_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'full_address': fullAddress,
    };
  }

  /// Get formatted location string for display
  String get displayString {
    if (fullAddress != null && fullAddress!.isNotEmpty) {
      return fullAddress!;
    }
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    return parts.join(', ');
  }

  /// Get short formatted location string (city, state, zip only)
  String get shortDisplayString {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (zipCode != null && zipCode!.isNotEmpty) parts.add(zipCode!);
    return parts.join(', ');
  }
}

/// Comprehensive Event model
class Event {
  final String id;
  final String name; // Event title
  final String? description; // Full event description
  final String? imageUrl; // URL to event image/banner
  final String? imagePath; // Local path to cached image
  
  // Dates
  final DateTime startDate; // Event start date
  final DateTime? endDate; // Event end date (null if single day)
  final DateTime? registrationOpenDate; // When registration opens
  final DateTime? registrationCloseDate; // When registration closes
  
  // Location
  final EventLocation location;
  
  // Schedule
  final List<EventScheduleItem> schedule;

  // Classes (racing classes with price)
  final List<EventClass> classes;

  // Rules (category + description)
  final List<EventRule> rules;
  
  // Event Information
  final EventInfo eventInfo;
  
  // Format: "double_elimination" (bracket) or "top_speed"
  final String? format;

  // Status
  final EventRegistrationStatus registrationStatus;

  // Results (optional, populated after event)
  final String? resultsUrl; // URL to results page/document
  final Map<String, dynamic>? results; // Structured results data
  
  // Admin/Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublished; // Whether event is visible to public
  final String? createdBy; // Admin user ID who created the event

  Event({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.imagePath,
    required this.startDate,
    this.endDate,
    this.registrationOpenDate,
    this.registrationCloseDate,
    required this.location,
    this.schedule = const [],
    this.classes = const [],
    this.rules = const [],
    required this.eventInfo,
    this.format,
    required this.registrationStatus,
    this.resultsUrl,
    this.results,
    required this.createdAt,
    required this.updatedAt,
    this.isPublished = true,
    this.createdBy,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      imagePath: json['image_path'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      registrationOpenDate: json['registration_open_date'] != null
          ? DateTime.parse(json['registration_open_date'] as String)
          : null,
      registrationCloseDate: json['registration_close_date'] != null
          ? DateTime.parse(json['registration_close_date'] as String)
          : null,
      location: json['location'] != null && json['location'] is Map<String, dynamic>
          ? EventLocation.fromJson(json['location'] as Map<String, dynamic>)
          : EventLocation(name: ''),
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((item) => EventScheduleItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      classes: (json['classes'] as List<dynamic>?)
              ?.map((item) => EventClass.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      rules: (json['rules'] as List<dynamic>?)
              ?.map((item) => EventRule.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      eventInfo: json['event_info'] != null && json['event_info'] is Map<String, dynamic>
          ? EventInfo.fromJson(json['event_info'] as Map<String, dynamic>)
          : EventInfo(),
      format: json['format'] as String?,
      registrationStatus: _parseRegistrationStatus(json['registration_status'] as String? ?? 'closed'),
      resultsUrl: json['results_url'] as String?,
      results: json['results'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPublished: json['is_published'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'image_path': imagePath,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'registration_open_date': registrationOpenDate?.toIso8601String(),
      'registration_close_date': registrationCloseDate?.toIso8601String(),
      'location': location.toJson(),
      'schedule': schedule.map((item) => item.toJson()).toList(),
      'classes': classes.map((item) => item.toJson()).toList(),
      'rules': rules.map((item) => item.toJson()).toList(),
      'event_info': eventInfo.toJson(),
      'format': format,
      'registration_status': _registrationStatusToString(registrationStatus),
      'results_url': resultsUrl,
      'results': results,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_published': isPublished,
      'created_by': createdBy,
    };
  }

  static EventRegistrationStatus _parseRegistrationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return EventRegistrationStatus.open;
      case 'closed':
        return EventRegistrationStatus.closed;
      case 'upcoming':
        return EventRegistrationStatus.upcoming;
      case 'past':
        return EventRegistrationStatus.past;
      default:
        return EventRegistrationStatus.closed;
    }
  }

  static String _registrationStatusToString(EventRegistrationStatus status) {
    switch (status) {
      case EventRegistrationStatus.open:
        return 'open';
      case EventRegistrationStatus.closed:
        return 'closed';
      case EventRegistrationStatus.upcoming:
        return 'upcoming';
      case EventRegistrationStatus.past:
        return 'past';
    }
  }

  /// Check if registration is currently open
  bool get isOpen => registrationStatus == EventRegistrationStatus.open;

  /// True if event format is top-speed (speed rankings). False for bracket / double elimination.
  bool get isTopSpeed => format == 'top_speed';

  /// True if event uses bracket (double elimination) format.
  bool get isBracketFormat => format == null || format == 'double_elimination';

  /// Check if event is in the past
  bool get isPast {
    final end = endDate ?? startDate;
    return end.isBefore(DateTime.now());
  }

  /// Check if event is upcoming (not started yet)
  bool get isUpcoming => startDate.isAfter(DateTime.now());

  /// Schedule sorted by day then start_time (matches backend ordered_schedule)
  List<EventScheduleItem> get orderedSchedule {
    if (schedule.isEmpty) return [];
    final list = List<EventScheduleItem>.from(schedule);
    list.sort((a, b) {
      final dayCmp = a.day.compareTo(b.day);
      if (dayCmp != 0) return dayCmp;
      if (a.startTime == null && b.startTime == null) return 0;
      if (a.startTime == null) return 1;
      if (b.startTime == null) return -1;
      return a.startTime!.compareTo(b.startTime!);
    });
    return list;
  }

  /// Get primary date for display (start date)
  DateTime get date => startDate;

  /// Get formatted date range
  String get dateRange {
    if (endDate == null) {
      return _formatDate(startDate);
    }
    if (startDate.year == endDate!.year &&
        startDate.month == endDate!.month &&
        startDate.day == endDate!.day) {
      return _formatDate(startDate);
    }
    return '${_formatDate(startDate)} - ${_formatDate(endDate!)}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

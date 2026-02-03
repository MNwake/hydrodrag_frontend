class PWC {
  String? id;
  String make; // e.g., Yamaha, Sea-Doo, Kawasaki
  String model; // e.g., GP1800, RXP-X, Ultra 310
  int? year; // Manufacturing year
  String? engineSize; // e.g., "1100cc", "1500cc", "1800cc"
  String? engineClass; // e.g., "250cc", "500cc", "750cc", "1000cc", "Open"
  String? color;
  String? registrationNumber; // Hull ID or registration number
  String? serialNumber; // Engine or hull serial number
  List<String> modifications; // e.g., ["Turbocharger", "Supercharger", "Nitrous Oxide", "ECU Tune", "Exhaust", "Prop", "Intake"]
  String? notes; // Additional notes or custom modifications
  bool isPrimary; // Whether this is the primary PWC for racing
  DateTime? createdAt;
  DateTime? updatedAt;

  PWC({
    this.id,
    required this.make,
    required this.model,
    this.year,
    this.engineSize,
    this.engineClass,
    this.color,
    this.registrationNumber,
    this.serialNumber,
    this.modifications = const [],
    this.notes,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  // Create from JSON (backend response)
  factory PWC.fromJson(Map<String, dynamic> json) {
    return PWC(
      id: json['id'] as String?,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int?,
      engineSize: json['engine_size'] as String?,
      engineClass: json['engine_class'] as String?,
      color: json['color'] as String?,
      registrationNumber: json['registration_number'] as String?,
      serialNumber: json['serial_number'] as String?,
      modifications: json['modifications'] != null
          ? List<String>.from(json['modifications'] as List)
          : [],
      notes: json['notes'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Convert to JSON (for backend requests)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'make': make,
      'model': model,
      if (year != null) 'year': year,
      if (engineSize != null) 'engine_size': engineSize,
      if (engineClass != null) 'engine_class': engineClass,
      if (color != null) 'color': color,
      if (registrationNumber != null) 'registration_number': registrationNumber,
      if (serialNumber != null) 'serial_number': serialNumber,
      'modifications': modifications,
      if (notes != null) 'notes': notes,
      'is_primary': isPrimary,
    };
  }

  /// Payload for POST /pwcs (PWCCreate). Omits id.
  Map<String, dynamic> toCreateJson() {
    return {
      'make': make,
      'model': model,
      if (year != null) 'year': year,
      if (engineSize != null) 'engine_size': engineSize,
      if (engineClass != null) 'engine_class': engineClass,
      if (color != null) 'color': color,
      if (registrationNumber != null) 'registration_number': registrationNumber,
      if (serialNumber != null) 'serial_number': serialNumber,
      'modifications': modifications,
      if (notes != null) 'notes': notes,
      'is_primary': isPrimary,
    };
  }

  /// Payload for PATCH /pwcs/{id} (PWCUpdate). Only non-null fields; omits id.
  Map<String, dynamic> toUpdateJson() {
    final map = <String, dynamic>{};
    if (make.isNotEmpty) map['make'] = make;
    if (model.isNotEmpty) map['model'] = model;
    if (year != null) map['year'] = year;
    if (engineSize != null) map['engine_size'] = engineSize;
    if (engineClass != null) map['engine_class'] = engineClass;
    if (color != null) map['color'] = color;
    if (registrationNumber != null) map['registration_number'] = registrationNumber;
    if (serialNumber != null) map['serial_number'] = serialNumber;
    map['modifications'] = modifications;
    if (notes != null) map['notes'] = notes;
    map['is_primary'] = isPrimary;
    return map;
  }

  // Display name for the PWC (uses id/name when make+model empty)
  String get displayName {
    if (make.isEmpty && model.isEmpty && id != null && id!.isNotEmpty) {
      return id!;
    }
    final parts = <String>[];
    if (year != null) parts.add(year.toString());
    parts.add(make);
    parts.add(model);
    if (engineSize != null) parts.add('($engineSize)');
    final joined = parts.join(' ').trim();
    return joined.isEmpty && id != null ? id! : joined;
  }

  // Short display name
  String get shortDisplayName => '$make $model';

  // Check if PWC has required fields for racing
  bool get isCompleteForRacing =>
      make.isNotEmpty &&
      model.isNotEmpty &&
      engineClass != null &&
      engineClass!.isNotEmpty;
}

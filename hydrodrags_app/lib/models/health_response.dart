import 'mobile_release_config.dart';

class HealthResponse {
  final String status;
  final String serverVersion;
  final MobileReleaseConfig? mobile;
  final Map<String, dynamic>? database;

  const HealthResponse({
    required this.status,
    required this.serverVersion,
    this.mobile,
    this.database,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    final mobileJson = json['mobile'];
    return HealthResponse(
      status: json['status'] as String,
      serverVersion: json['server_version'] as String,
      mobile: mobileJson is Map<String, dynamic>
          ? MobileReleaseConfig.fromJson(mobileJson)
          : null,
      database: json['database'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['database'] as Map)
          : null,
    );
  }
}

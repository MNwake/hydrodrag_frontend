class MobileReleaseConfig {
  final String latest;
  final String minimum;
  final String iosStore;
  final String androidStore;
  final String? message;

  const MobileReleaseConfig({
    required this.latest,
    required this.minimum,
    required this.iosStore,
    required this.androidStore,
    this.message,
  });

  factory MobileReleaseConfig.fromJson(Map<String, dynamic> json) {
    return MobileReleaseConfig(
      latest: json['latest'] as String,
      minimum: json['minimum'] as String,
      iosStore: json['ios_store'] as String,
      androidStore: json['android_store'] as String,
      message: json['message'] as String?,
    );
  }
}

import 'package:pub_semver/pub_semver.dart';

class VersionCheckResult {
  final Version latestVersion;
  final Version minimumVersion;
  final String storeUrl;
  final String? message;
  final bool updateAvailable;
  final bool forceUpdate;

  const VersionCheckResult({
    required this.latestVersion,
    required this.minimumVersion,
    required this.storeUrl,
    this.message,
    required this.updateAvailable,
    required this.forceUpdate,
  });
}

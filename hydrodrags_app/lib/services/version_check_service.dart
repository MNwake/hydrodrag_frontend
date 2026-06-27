import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../models/version_check_result.dart';
import '../utils/app_log.dart';
import 'health_api_client.dart';

class VersionCheckService {
  VersionCheckService({HealthApiClient? healthApiClient})
      : _healthApiClient = healthApiClient ?? HealthApiClient();

  final HealthApiClient _healthApiClient;

  Future<VersionCheckResult?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installed = Version.parse(packageInfo.version);

      AppLog.debug(
        'VersionCheck',
        'Installed version ${packageInfo.version} (build ${packageInfo.buildNumber})',
      );

      final health = await _healthApiClient.fetchHealth();
      final mobile = health?.mobile;
      if (mobile == null) {
        AppLog.debug('VersionCheck', 'No mobile version data — skipping check');
        return null;
      }

      final latest = Version.parse(mobile.latest);
      final minimum = Version.parse(mobile.minimum);
      final storeUrl = Platform.isIOS ? mobile.iosStore : mobile.androidStore;

      final updateAvailable = installed < latest;
      final forceUpdate = installed < minimum;

      AppLog.debug(
        'VersionCheck',
        'Version comparison: installed=$installed latest=$latest minimum=$minimum',
      );

      if (updateAvailable) {
        AppLog.info(
          'VersionCheck',
          forceUpdate ? 'App update required' : 'App update detected',
        );
      }

      return VersionCheckResult(
        latestVersion: latest,
        minimumVersion: minimum,
        storeUrl: storeUrl,
        message: mobile.message,
        updateAvailable: updateAvailable,
        forceUpdate: forceUpdate,
      );
    } catch (e, stack) {
      AppLog.error(
        'VersionCheck',
        'Version check failed',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      return null;
    }
  }
}

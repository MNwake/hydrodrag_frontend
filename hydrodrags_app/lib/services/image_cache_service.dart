import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../utils/app_log.dart';

/// Service for caching images from the backend
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  Future<File?> getCachedImage(String? imagePath, {DateTime? updatedAt}) async {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    try {
      final localFile = File(imagePath);
      if (localFile.existsSync()) {
        return localFile;
      }

      String assetUrl;
      if (imagePath.startsWith('/assets/') || imagePath.startsWith('assets/')) {
        assetUrl = imagePath.startsWith('/') ? imagePath : '/$imagePath';
      } else {
        assetUrl = '/assets/$imagePath';
      }

      final fullUrl = '${ApiConfig.baseUrl}$assetUrl';

      final cacheDir = await getApplicationCacheDirectory();
      final imagesDir = Directory(path.join(cacheDir.path, 'images'));
      if (!imagesDir.existsSync()) {
        imagesDir.createSync(recursive: true);
      }

      final safePath = assetUrl.replaceAll(RegExp(r'^/'), '').replaceAll('/', '_');
      final fileName = safePath.isEmpty ? path.basename(assetUrl) : safePath;
      final cacheFile = File(path.join(imagesDir.path, fileName));
      final metadataFile = File(path.join(imagesDir.path, '$fileName.meta'));

      bool needsDownload = true;
      if (cacheFile.existsSync()) {
        if (updatedAt != null && metadataFile.existsSync()) {
          try {
            final metadataContent = await metadataFile.readAsString();
            final metadata = jsonDecode(metadataContent) as Map<String, dynamic>;
            final cachedTimestampStr = metadata['updated_at'] as String?;
            if (cachedTimestampStr != null) {
              final cachedTimestamp = DateTime.parse(cachedTimestampStr);
              if (cachedTimestamp.isAtSameMomentAs(updatedAt) || cachedTimestamp.isAfter(updatedAt)) {
                needsDownload = false;
                AppLog.debug('ImageCache', 'Cache hit');
              } else {
                AppLog.debug('ImageCache', 'Cache outdated, re-downloading');
              }
            }
          } catch (e, stack) {
            AppLog.error(
              'ImageCache',
              'Failed to read cache metadata',
              error: e,
              stackTrace: stack,
              recoverable: true,
            );
            needsDownload = true;
          }
        } else if (updatedAt == null) {
          needsDownload = false;
          AppLog.debug('ImageCache', 'Cache hit');
        }
      }

      if (!needsDownload) {
        return cacheFile;
      }

      AppLog.debug('ImageCache', 'Downloading image');

      final response = await LoggedHttp.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        await cacheFile.writeAsBytes(response.bodyBytes);

        if (updatedAt != null) {
          final metadata = {
            'updated_at': updatedAt.toIso8601String(),
            'cached_at': DateTime.now().toIso8601String(),
          };
          await metadataFile.writeAsString(jsonEncode(metadata));
        }

        AppLog.debug('ImageCache', 'Image cached');
        return cacheFile;
      } else {
        AppLog.error(
          'ImageCache',
          AppLog.httpFailure('download image', response.statusCode),
          recoverable: true,
        );
        return null;
      }
    } catch (e, stack) {
      AppLog.error(
        'ImageCache',
        'Failed to cache image',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final imagesDir = Directory(path.join(cacheDir.path, 'images'));
      if (imagesDir.existsSync()) {
        imagesDir.deleteSync(recursive: true);
        AppLog.debug('ImageCache', 'Cache cleared');
      }
    } catch (e, stack) {
      AppLog.error(
        'ImageCache',
        'Failed to clear image cache',
        error: e,
        stackTrace: stack,
        recoverable: false,
      );
    }
  }

  static String? getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    if (File(imagePath).existsSync()) {
      return null;
    }

    String assetUrl;
    if (imagePath.startsWith('/assets/') || imagePath.startsWith('assets/')) {
      assetUrl = imagePath.startsWith('/') ? imagePath : '/$imagePath';
    } else {
      assetUrl = '/assets/$imagePath';
    }

    return '${ApiConfig.baseUrl}$assetUrl';
  }
}

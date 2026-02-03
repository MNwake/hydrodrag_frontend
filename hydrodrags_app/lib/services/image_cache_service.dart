import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';

/// Service for caching images from the backend
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  /// Get cached image file, downloading if necessary
  /// Returns null if image path is null/empty or download fails
  /// [updatedAt] is the timestamp when the image was last updated on the server.
  /// If provided and the cached image is older, it will be re-downloaded.
  Future<File?> getCachedImage(String? imagePath, {DateTime? updatedAt}) async {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    try {
      // Check if it's already a local file path
      final localFile = File(imagePath);
      if (localFile.existsSync()) {
        return localFile;
      }

      // Check if it's a relative path from /assets/
      String assetUrl;
      if (imagePath.startsWith('/assets/') || imagePath.startsWith('assets/')) {
        // Already formatted
        assetUrl = imagePath.startsWith('/') ? imagePath : '/$imagePath';
      } else {
        // Assume it's a relative path from assets
        assetUrl = '/assets/$imagePath';
      }

      // Build full URL
      final fullUrl = '${ApiConfig.baseUrl}$assetUrl';

      // Get cache directory
      final cacheDir = await getApplicationCacheDirectory();
      final imagesDir = Directory(path.join(cacheDir.path, 'images'));
      if (!imagesDir.existsSync()) {
        imagesDir.createSync(recursive: true);
      }

      // Create cache file name from full path (not just basename) to avoid
      // collisions when multiple racers use profile.jpg / banner.jpg.
      final safePath = assetUrl.replaceAll(RegExp(r'^/'), '').replaceAll('/', '_');
      final fileName = safePath.isEmpty ? path.basename(assetUrl) : safePath;
      final cacheFile = File(path.join(imagesDir.path, fileName));
      final metadataFile = File(path.join(imagesDir.path, '$fileName.meta'));

      // Check if we need to re-download based on timestamp
      bool needsDownload = true;
      if (cacheFile.existsSync()) {
        if (updatedAt != null && metadataFile.existsSync()) {
          try {
            final metadataContent = await metadataFile.readAsString();
            final metadata = jsonDecode(metadataContent) as Map<String, dynamic>;
            final cachedTimestampStr = metadata['updated_at'] as String?;
            if (cachedTimestampStr != null) {
              final cachedTimestamp = DateTime.parse(cachedTimestampStr);
              // If cached timestamp is same or newer, use cache
              if (cachedTimestamp.isAtSameMomentAs(updatedAt) || cachedTimestamp.isAfter(updatedAt)) {
                needsDownload = false;
                if (kDebugMode) {
                  print('Image cache hit (up to date): $fileName');
                }
              } else {
                if (kDebugMode) {
                  print('Image cache outdated, re-downloading: $fileName');
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error reading metadata, will re-download: $e');
            }
            // If metadata is corrupted, re-download
            needsDownload = true;
          }
        } else if (updatedAt == null) {
          // No timestamp provided, use cached file if it exists
          needsDownload = false;
          if (kDebugMode) {
            print('Image cache hit (no timestamp check): $fileName');
          }
        }
      }

      if (!needsDownload) {
        return cacheFile;
      }

      // Download image
      if (kDebugMode) {
        print('Downloading image: $fullUrl');
      }

      final response = await http.get(Uri.parse(fullUrl));
      
      if (response.statusCode == 200) {
        // Save to cache
        await cacheFile.writeAsBytes(response.bodyBytes);
        
        // Save metadata with timestamp if provided
        if (updatedAt != null) {
          final metadata = {
            'updated_at': updatedAt.toIso8601String(),
            'cached_at': DateTime.now().toIso8601String(),
          };
          await metadataFile.writeAsString(jsonEncode(metadata));
        }
        
        if (kDebugMode) {
          print('Image cached: $fileName');
        }
        return cacheFile;
      } else {
        if (kDebugMode) {
          print('Failed to download image: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching image: $e');
      }
      return null;
    }
  }

  /// Clear image cache
  Future<void> clearCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final imagesDir = Directory(path.join(cacheDir.path, 'images'));
      if (imagesDir.existsSync()) {
        imagesDir.deleteSync(recursive: true);
        if (kDebugMode) {
          print('Image cache cleared');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }

  /// Get image URL for NetworkImage (for direct loading without caching)
  static String? getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // Check if it's already a full URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Check if it's already a local file path
    if (File(imagePath).existsSync()) {
      return null; // Return null to use FileImage instead
    }

    // Build asset URL
    String assetUrl;
    if (imagePath.startsWith('/assets/') || imagePath.startsWith('assets/')) {
      assetUrl = imagePath.startsWith('/') ? imagePath : '/$imagePath';
    } else {
      assetUrl = '/assets/$imagePath';
    }

    return '${ApiConfig.baseUrl}$assetUrl';
  }
}

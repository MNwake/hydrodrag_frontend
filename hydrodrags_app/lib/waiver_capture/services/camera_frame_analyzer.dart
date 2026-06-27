import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'frame_stability_detector.dart';

/// Extracts a downscaled grayscale buffer from a camera frame for edge analysis.
class CameraFrameAnalyzer {
  static const _targetWidth = 200;

  static double? edgeDensityFromCameraImage(CameraImage image) {
    try {
      final gray = _toGrayscale(image);
      if (gray == null) return null;
      final w = gray.$1;
      final h = gray.$2;
      final pixels = gray.$3;
      return computeEdgeDensity(pixels, w, h);
    } catch (_) {
      return null;
    }
  }

  static (int, int, List<int>)? _toGrayscale(CameraImage image) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _fromBgra(image);
    }
    return _fromYuv(image);
  }

  static (int, int, List<int>)? _fromYuv(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final yPlane = image.planes[0];
    final srcW = image.width;
    final srcH = image.height;
    final scale = _targetWidth / srcW;
    final dstW = _targetWidth;
    final dstH = (srcH * scale).round().clamp(1, 400);

    final out = List<int>.filled(dstW * dstH, 0);
    final rowStride = yPlane.bytesPerRow;

    for (var y = 0; y < dstH; y++) {
      final srcY = (y / scale).floor().clamp(0, srcH - 1);
      for (var x = 0; x < dstW; x++) {
        final srcX = (x / scale).floor().clamp(0, srcW - 1);
        final idx = srcY * rowStride + srcX;
        if (idx < yPlane.bytes.length) {
          out[y * dstW + x] = yPlane.bytes[idx];
        }
      }
    }
    return (dstW, dstH, out);
  }

  static (int, int, List<int>)? _fromBgra(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes[0];
    final srcW = image.width;
    final srcH = image.height;
    final scale = _targetWidth / srcW;
    final dstW = _targetWidth;
    final dstH = (srcH * scale).round().clamp(1, 400);

    final out = List<int>.filled(dstW * dstH, 0);
    final bytes = plane.bytes;

    for (var y = 0; y < dstH; y++) {
      final srcY = (y / scale).floor().clamp(0, srcH - 1);
      for (var x = 0; x < dstW; x++) {
        final srcX = (x / scale).floor().clamp(0, srcW - 1);
        final offset = (srcY * srcW + srcX) * 4;
        if (offset + 2 < bytes.length) {
          final b = bytes[offset];
          final g = bytes[offset + 1];
          final r = bytes[offset + 2];
          out[y * dstW + x] = ((r + g + b) / 3).round();
        }
      }
    }
    return (dstW, dstH, out);
  }

  /// Crop captured image file to approximate document frame region.
  static Future<Uint8List?> cropToDocumentFrame(
    Uint8List jpegBytes,
    double frameLeftRatio,
    double frameTopRatio,
    double frameWidthRatio,
    double frameHeightRatio,
  ) async {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) return null;

    final x = (decoded.width * frameLeftRatio).round().clamp(0, decoded.width - 1);
    final y = (decoded.height * frameTopRatio).round().clamp(0, decoded.height - 1);
    final w = (decoded.width * frameWidthRatio).round().clamp(1, decoded.width - x);
    final h = (decoded.height * frameHeightRatio).round().clamp(1, decoded.height - y);

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }
}

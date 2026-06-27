import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/capture_validation_result.dart';

/// Tunable blur and glare thresholds.
class ImageQualityConfig {
  const ImageQualityConfig({
    this.minLaplacianVariance = 28.0,
    this.blurAnalysisMaxDimension = 960,
    this.blurCenterCropRatio = 0.65,
    this.maxGlarePixelRatio = 0.16,
    this.glareThreshold = 240,
    this.minAverageLuminance = 35,
    this.maxAverageLuminance = 225,
  });

  final double minLaplacianVariance;
  final int blurAnalysisMaxDimension;
  final double blurCenterCropRatio;
  final double maxGlarePixelRatio;
  final int glareThreshold;
  final int minAverageLuminance;
  final int maxAverageLuminance;
}

class ImageQualityValidator {
  ImageQualityValidator({ImageQualityConfig? config})
      : _config = config ?? const ImageQualityConfig();

  final ImageQualityConfig _config;

  CaptureValidationResult validateBlur(
    File file, {
    required String blurMessage,
  }) {
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return CaptureValidationResult.failed(blurMessage);
    }

    final cropped = _centerCrop(decoded, _config.blurCenterCropRatio);
    final scaled = _downscale(cropped, _config.blurAnalysisMaxDimension);
    final gray = img.grayscale(scaled);
    final variance = _laplacianVariance(gray);
    if (variance < _config.minLaplacianVariance) {
      return CaptureValidationResult.failed(blurMessage);
    }
    return const CaptureValidationResult.passed();
  }

  CaptureValidationResult validateGlare(
    File file, {
    required String glareMessage,
  }) {
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return CaptureValidationResult.failed(glareMessage);
    }

    final w = decoded.width;
    final h = decoded.height;
    final marginX = (w * 0.15).round();
    final marginY = (h * 0.15).round();
    var bright = 0;
    var total = 0;

    for (var y = marginY; y < h - marginY; y++) {
      for (var x = marginX; x < w - marginX; x++) {
        final pixel = decoded.getPixel(x, y);
        final lum = img.getLuminance(pixel).round();
        if (lum >= _config.glareThreshold) bright++;
        total++;
      }
    }

    if (total == 0) return const CaptureValidationResult.passed();
    if (bright / total > _config.maxGlarePixelRatio) {
      return CaptureValidationResult.failed(glareMessage);
    }
    return const CaptureValidationResult.passed();
  }

  CaptureValidationResult validateExposure(
    File file, {
    required String tooDarkMessage,
    required String tooBrightMessage,
  }) {
    final bytes = file.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return CaptureValidationResult.failed(tooDarkMessage);
    }

    final avg = _averageLuminance(decoded);
    if (avg < _config.minAverageLuminance) {
      return CaptureValidationResult.failed(tooDarkMessage);
    }
    if (avg > _config.maxAverageLuminance) {
      return CaptureValidationResult.failed(tooBrightMessage);
    }
    return const CaptureValidationResult.passed();
  }

  double _averageLuminance(img.Image decoded) {
    final w = decoded.width;
    final h = decoded.height;
    final marginX = (w * 0.1).round();
    final marginY = (h * 0.1).round();
    var sum = 0.0;
    var count = 0;

    for (var y = marginY; y < h - marginY; y++) {
      for (var x = marginX; x < w - marginX; x++) {
        sum += img.getLuminance(decoded.getPixel(x, y));
        count++;
      }
    }

    if (count == 0) return 128;
    return sum / count;
  }

  img.Image _centerCrop(img.Image source, double ratio) {
    final cropW = (source.width * ratio).round().clamp(1, source.width);
    final cropH = (source.height * ratio).round().clamp(1, source.height);
    final x = ((source.width - cropW) / 2).round();
    final y = ((source.height - cropH) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: cropW, height: cropH);
  }

  img.Image _downscale(img.Image source, int maxDimension) {
    final longest = math.max(source.width, source.height);
    if (longest <= maxDimension) return source;
    final scale = maxDimension / longest;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
    );
  }

  double _laplacianVariance(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    if (w < 3 || h < 3) return 0;

    final values = <double>[];
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = gray.getPixel(x, y).r.toDouble();
        final lap = -4 * c +
            gray.getPixel(x - 1, y).r +
            gray.getPixel(x + 1, y).r +
            gray.getPixel(x, y - 1).r +
            gray.getPixel(x, y + 1).r;
        values.add(lap);
      }
    }

    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        values.length;
    return math.max(0, variance);
  }
}

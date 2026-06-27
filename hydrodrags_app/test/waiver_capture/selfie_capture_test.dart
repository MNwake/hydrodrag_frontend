import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrodrags_app/waiver_capture/services/image_quality_validator.dart';
import 'package:hydrodrags_app/waiver_capture/widgets/selfie_frame_overlay.dart';
import 'package:image/image.dart' as img;

void main() {
  group('selfieGuideRect', () {
    test('returns centered oval within phone bounds', () {
      const phone = Size(390, 700);
      final rect = selfieGuideRect(phone);
      expect(rect.width, greaterThan(220));
      expect(rect.width, lessThan(phone.width));
      expect(rect.center.dx, closeTo(phone.width / 2, 1));
    });

    test('caps width on tablet layout', () {
      const tablet = Size(800, 1100);
      final rect = selfieGuideRect(tablet);
      expect(rect.width, lessThanOrEqualTo(360));
    });
  });

  group('ImageQualityValidator exposure', () {
    late Directory tempDir;
    late ImageQualityValidator validator;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('selfie_exposure_test');
      validator = ImageQualityValidator(
        config: const ImageQualityConfig(
          minAverageLuminance: 45,
          maxAverageLuminance: 215,
        ),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<File> writeSolid(int lum) async {
      final image = img.Image(width: 120, height: 160);
      img.fill(image, color: img.ColorRgb8(lum, lum, lum));
      final file = File('${tempDir.path}/lum_$lum.jpg');
      await file.writeAsBytes(img.encodeJpg(image));
      return file;
    }

    test('rejects dark image', () async {
      final file = await writeSolid(20);
      final result = validator.validateExposure(
        file,
        tooDarkMessage: 'dark',
        tooBrightMessage: 'bright',
      );
      expect(result.passed, isFalse);
    });

    test('accepts balanced exposure', () async {
      final file = await writeSolid(120);
      final result = validator.validateExposure(
        file,
        tooDarkMessage: 'dark',
        tooBrightMessage: 'bright',
      );
      expect(result.passed, isTrue);
    });
  });
}

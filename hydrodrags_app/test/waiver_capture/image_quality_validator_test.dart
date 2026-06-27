import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydrodrags_app/waiver_capture/services/image_quality_validator.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tempDir;
  late ImageQualityValidator validator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('waiver_capture_test');
    validator = ImageQualityValidator(
      config: const ImageQualityConfig(
        minLaplacianVariance: 50,
        maxGlarePixelRatio: 0.5,
      ),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writeImage(img.Image image, String name) async {
    final file = File('${tempDir.path}/$name.jpg');
    await file.writeAsBytes(img.encodeJpg(image));
    return file;
  }

  test('rejects blurry flat image', () {
    final image = img.Image(width: 200, height: 120);
    img.fill(image, color: img.ColorRgb8(120, 120, 120));
    final file = writeImage(image, 'flat');
    expect(
      file.then(
        (f) => validator.validateBlur(f, blurMessage: 'blurry').passed,
      ),
      completion(isFalse),
    );
  });

  test('accepts sharp checkerboard image', () async {
    final image = img.Image(width: 200, height: 120);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final v = (x + y) % 2 == 0 ? 30 : 220;
        image.setPixel(x, y, img.ColorRgb8(v, v, v));
      }
    }
    final file = await writeImage(image, 'sharp');
    expect(
      validator.validateBlur(file, blurMessage: 'blurry').passed,
      isTrue,
    );
  });

  test('rejects high-glare image', () async {
    final image = img.Image(width: 200, height: 120);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final file = await writeImage(image, 'glare');
    expect(
      validator.validateGlare(file, glareMessage: 'glare').passed,
      isFalse,
    );
  });
}

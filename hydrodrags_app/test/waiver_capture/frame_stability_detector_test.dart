import 'package:flutter_test/flutter_test.dart';
import 'package:hydrodrags_app/waiver_capture/models/capture_validation_result.dart';
import 'package:hydrodrags_app/waiver_capture/services/frame_stability_detector.dart';

void main() {
  group('FrameStabilityDetector', () {
    test('returns false until enough stable in-range samples', () {
      final detector = FrameStabilityDetector(
        config: const FrameStabilityConfig(
          stableDurationMs: 100,
          sampleIntervalMs: 10,
        ),
      );

      expect(detector.addSample(0.01), isFalse);
      expect(detector.addSample(0.20), isFalse);
      expect(detector.addSample(0.21), isFalse);

      expect(detector.alignmentState, FrameAlignmentState.detecting);
    });

    test('resets when edge density leaves range', () {
      final detector = FrameStabilityDetector();
      detector.addSample(0.20);
      detector.addSample(0.21);
      detector.addSample(0.22);
      detector.addSample(0.01);
      expect(detector.alignmentState, FrameAlignmentState.searching);
    });
  });

  group('computeEdgeDensity', () {
    test('returns higher density for sharp edge pattern', () {
      const w = 20;
      const h = 20;
      final pixels = List<int>.filled(w * h, 128);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          pixels[y * w + x] = x < w ~/ 2 ? 30 : 220;
        }
      }
      final density = computeEdgeDensity(pixels, w, h);
      expect(density, greaterThan(0.05));
    });

    test('returns low density for flat image', () {
      const w = 20;
      const h = 20;
      final pixels = List<int>.filled(w * h, 128);
      final density = computeEdgeDensity(pixels, w, h);
      expect(density, lessThan(0.05));
    });
  });
}

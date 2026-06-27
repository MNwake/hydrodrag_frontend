import '../models/capture_validation_result.dart';

/// Tunable thresholds for edge-density auto-capture heuristic.
class FrameStabilityConfig {
  const FrameStabilityConfig({
    this.minEdgeDensity = 0.08,
    this.maxEdgeDensity = 0.45,
    this.maxSampleVariance = 0.0025,
    this.stableDurationMs = 1200,
    this.sampleIntervalMs = 400,
  });

  final double minEdgeDensity;
  final double maxEdgeDensity;
  final double maxSampleVariance;
  final int stableDurationMs;
  final int sampleIntervalMs;
}

/// Tracks edge-density samples to detect a stable document in frame.
class FrameStabilityDetector {
  FrameStabilityDetector({FrameStabilityConfig? config})
      : _config = config ?? const FrameStabilityConfig();

  final FrameStabilityConfig _config;
  final List<double> _recentSamples = [];
  DateTime? _stableSince;

  FrameAlignmentState get alignmentState {
    if (_recentSamples.isEmpty) return FrameAlignmentState.searching;
    final latest = _recentSamples.last;
    if (latest >= _config.minEdgeDensity &&
        latest <= _config.maxEdgeDensity) {
      if (_stableSince != null) return FrameAlignmentState.stable;
      return FrameAlignmentState.detecting;
    }
    return FrameAlignmentState.searching;
  }

  void reset() {
    _recentSamples.clear();
    _stableSince = null;
  }

  /// Returns true when the document has been stable long enough to auto-capture.
  bool addSample(double edgeDensity) {
    _recentSamples.add(edgeDensity);
    if (_recentSamples.length > 8) {
      _recentSamples.removeAt(0);
    }

    if (_recentSamples.length < 3) {
      _stableSince = null;
      return false;
    }

    final inRange = _recentSamples.every(
      (v) => v >= _config.minEdgeDensity && v <= _config.maxEdgeDensity,
    );
    if (!inRange) {
      _stableSince = null;
      return false;
    }

    final mean =
        _recentSamples.reduce((a, b) => a + b) / _recentSamples.length;
    final variance = _recentSamples
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        _recentSamples.length;

    if (variance > _config.maxSampleVariance) {
      _stableSince = null;
      return false;
    }

    final now = DateTime.now();
    _stableSince ??= now;
    return now.difference(_stableSince!).inMilliseconds >=
        _config.stableDurationMs;
  }
}

/// Computes normalized edge density (0–1) from a grayscale byte buffer.
double computeEdgeDensity(List<int> grayPixels, int width, int height) {
  if (width < 3 || height < 3 || grayPixels.length < width * height) {
    return 0;
  }

  var edgeCount = 0;
  var total = 0;

  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final idx = y * width + x;
      final left = grayPixels[idx - 1];
      final right = grayPixels[idx + 1];
      final top = grayPixels[idx - width];
      final bottom = grayPixels[idx + width];
      final grad = (right - left).abs() + (bottom - top).abs();
      if (grad > 30) edgeCount++;
      total++;
    }
  }

  if (total == 0) return 0;
  return edgeCount / total;
}

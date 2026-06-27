import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/capture_validation_result.dart';
import '../models/selfie_guide_feedback.dart';
import '../widgets/selfie_frame_overlay.dart';

/// Tunable thresholds for live selfie framing.
class SelfieGuideConfig {
  const SelfieGuideConfig({
    this.minFaceAreaRatio = 0.04,
    this.maxFaceAreaRatio = 0.78,
    this.minOvalOverlapRatio = 0.25,
    this.maxCenterOffsetRatio = 0.45,
    this.edgeMarginRatio = 0.0,
    this.stableDurationMs = 450,
    this.capturedMinFaceAreaRatio = 0.008,
    this.capturedMaxFaceAreaRatio = 0.95,
  });

  /// More permissive thresholds (Android front-camera detection varies by device).
  const SelfieGuideConfig.lenient()
      : minFaceAreaRatio = 0.03,
        maxFaceAreaRatio = 0.85,
        minOvalOverlapRatio = 0.18,
        maxCenterOffsetRatio = 0.55,
        edgeMarginRatio = 0.0,
        stableDurationMs = 350,
        capturedMinFaceAreaRatio = 0.005,
        capturedMaxFaceAreaRatio = 0.98;

  final double minFaceAreaRatio;
  final double maxFaceAreaRatio;
  final double minOvalOverlapRatio;
  final double maxCenterOffsetRatio;
  final double edgeMarginRatio;
  final int stableDurationMs;
  final double capturedMinFaceAreaRatio;
  final double capturedMaxFaceAreaRatio;
}

/// Result of analyzing faces against the on-screen oval guide.
class SelfieGuideAnalysis {
  const SelfieGuideAnalysis({
    required this.feedback,
    required this.isReady,
    required this.shouldAutoCapture,
    required this.hasFaceDetected,
  });

  final SelfieGuideFeedback feedback;
  final bool isReady;
  final bool shouldAutoCapture;
  /// True when at least one face is visible (looser than [isReady]).
  final bool hasFaceDetected;
}

/// On-device face framing analysis for live camera preview and captured files.
class LiveSelfieFaceAnalyzer {
  LiveSelfieFaceAnalyzer({SelfieGuideConfig? config})
      : _config = config ?? const SelfieGuideConfig(),
        _liveDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.fast,
            enableLandmarks: false,
            enableClassification: false,
            enableTracking: true,
          ),
        ),
        _captureDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableLandmarks: false,
            enableClassification: false,
            enableTracking: false,
          ),
        );

  final SelfieGuideConfig _config;
  final FaceDetector _liveDetector;
  final FaceDetector _captureDetector;

  DateTime? _readySince;

  void resetStability() {
    _readySince = null;
  }

  /// Live preview: compare detected face against the on-screen oval guide.
  Future<SelfieGuideAnalysis> analyzeLiveFrame(
    InputImage input, {
    required Size previewSize,
    bool mirrorHorizontally = false,
  }) async {
    try {
      final faces = await _liveDetector.processImage(input);
      final guide = selfieGuideRect(previewSize);
      final imageSize = input.metadata?.size ?? previewSize;

      final feedback = _feedbackForLiveFaces(
        faces: faces,
        guide: guide,
        imageSize: imageSize,
        previewSize: previewSize,
        mirrorHorizontally: mirrorHorizontally,
      );

      final hasFace = faces.isNotEmpty;
      final isReady = feedback == SelfieGuideFeedback.ready ||
          (hasFace &&
              feedback != SelfieGuideFeedback.noFace &&
              feedback != SelfieGuideFeedback.multipleFaces &&
              feedback != SelfieGuideFeedback.moveFarther);

      if (isReady) {
        _readySince ??= DateTime.now();
      } else {
        _readySince = null;
      }

      final stableMs = _readySince == null
          ? 0
          : DateTime.now().difference(_readySince!).inMilliseconds;

      return SelfieGuideAnalysis(
        feedback: isReady && feedback != SelfieGuideFeedback.ready
            ? SelfieGuideFeedback.ready
            : feedback,
        isReady: isReady,
        hasFaceDetected: hasFace,
        shouldAutoCapture: isReady && stableMs >= _config.stableDurationMs,
      );
    } catch (_) {
      _readySince = null;
      return const SelfieGuideAnalysis(
        feedback: SelfieGuideFeedback.noFace,
        isReady: false,
        shouldAutoCapture: false,
        hasFaceDetected: false,
      );
    }
  }

  /// Captured photo: lenient presence check (live framing already validated).
  Future<CaptureValidationResult> validateCapturedImage(
    InputImage input, {
    required String noFaceMessage,
    required String multipleFacesMessage,
    required String faceSizeMessage,
    required String notFullyVisibleMessage,
    bool trustLiveFraming = false,
  }) async {
    try {
      final faces = await _captureDetector.processImage(input);
      if (faces.isEmpty) {
        if (trustLiveFraming) {
          return const CaptureValidationResult.passed();
        }
        return CaptureValidationResult.failed(noFaceMessage);
      }

      final size = input.metadata?.size;
      if (size == null) {
        return const CaptureValidationResult.passed();
      }

      final box = _largestFaceBox(faces);
      final imageArea = size.width * size.height;
      if (imageArea <= 0) {
        return const CaptureValidationResult.passed();
      }

      final ratio = (box.width * box.height) / imageArea;
      if (ratio < _config.capturedMinFaceAreaRatio ||
          ratio > _config.capturedMaxFaceAreaRatio) {
        if (trustLiveFraming) {
          return const CaptureValidationResult.passed();
        }
        return CaptureValidationResult.failed(faceSizeMessage);
      }

      return const CaptureValidationResult.passed();
    } catch (_) {
      if (trustLiveFraming) {
        return const CaptureValidationResult.passed();
      }
      return CaptureValidationResult.failed(noFaceMessage);
    }
  }

  Rect _largestFaceBox(List<Face> faces) {
    return faces
        .map((face) => face.boundingBox)
        .reduce(
          (a, b) =>
              (a.width * a.height) >= (b.width * b.height) ? a : b,
        );
  }

  SelfieGuideFeedback _feedbackForLiveFaces({
    required List<Face> faces,
    required Rect guide,
    required Size imageSize,
    required Size previewSize,
    required bool mirrorHorizontally,
  }) {
    if (faces.isEmpty) return SelfieGuideFeedback.noFace;

    final face = faces.length == 1
        ? faces.first
        : faces.reduce(
            (a, b) =>
                (a.boundingBox.width * a.boundingBox.height) >=
                        (b.boundingBox.width * b.boundingBox.height)
                    ? a
                    : b,
          );

    final faceBox = _mapFaceToPreview(
      face.boundingBox,
      imageSize: imageSize,
      previewSize: previewSize,
      mirrorHorizontally: mirrorHorizontally,
    );

    if (!_isFullyVisible(faceBox, previewSize)) {
      return SelfieGuideFeedback.faceNotFullyVisible;
    }

    final previewArea = previewSize.width * previewSize.height;
    final faceArea = faceBox.width * faceBox.height;
    final areaRatio = faceArea / previewArea;

    if (areaRatio < _config.minFaceAreaRatio) {
      return SelfieGuideFeedback.moveCloser;
    }
    if (areaRatio > _config.maxFaceAreaRatio) {
      return SelfieGuideFeedback.moveFarther;
    }

    final faceCenter = faceBox.center;
    final guideCenter = guide.center;
    final dx = (faceCenter.dx - guideCenter.dx).abs() / guide.width;
    final dy = (faceCenter.dy - guideCenter.dy).abs() / guide.height;
    if (dx > _config.maxCenterOffsetRatio ||
        dy > _config.maxCenterOffsetRatio) {
      return SelfieGuideFeedback.centerFace;
    }

    final overlap = _intersectionArea(faceBox, guide) / faceArea;
    if (overlap < _config.minOvalOverlapRatio) {
      return SelfieGuideFeedback.centerFace;
    }

    return SelfieGuideFeedback.ready;
  }

  Rect _mapFaceToPreview(
    Rect face, {
    required Size imageSize,
    required Size previewSize,
    required bool mirrorHorizontally,
  }) {
    if (imageSize.width == 0 || imageSize.height == 0) return face;

    final scale = (previewSize.width / imageSize.width)
        .clamp(previewSize.height / imageSize.height, double.infinity);
    final scaledW = imageSize.width * scale;
    final scaledH = imageSize.height * scale;
    final dx = (previewSize.width - scaledW) / 2;
    final dy = (previewSize.height - scaledH) / 2;

    var mapped = Rect.fromLTWH(
      face.left * scale + dx,
      face.top * scale + dy,
      face.width * scale,
      face.height * scale,
    );

    // Front-camera preview is mirrored; ML Kit coordinates are not.
    if (mirrorHorizontally) {
      mapped = Rect.fromLTWH(
        previewSize.width - mapped.right,
        mapped.top,
        mapped.width,
        mapped.height,
      );
    }

    return mapped;
  }

  bool _isFullyVisible(Rect faceBox, Size previewSize) {
    final margin = previewSize.shortestSide * _config.edgeMarginRatio;
    return faceBox.left >= margin &&
        faceBox.top >= margin &&
        faceBox.right <= previewSize.width - margin &&
        faceBox.bottom <= previewSize.height - margin;
  }

  double _intersectionArea(Rect a, Rect b) {
    final intersect = a.intersect(b);
    if (intersect.isEmpty) return 0;
    return intersect.width * intersect.height;
  }

  void dispose() {
    _liveDetector.close();
    _captureDetector.close();
  }
}

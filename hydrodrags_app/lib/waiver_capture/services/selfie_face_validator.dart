import 'dart:io';

import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import '../models/capture_validation_result.dart';
import 'live_selfie_face_analyzer.dart';

/// Post-capture selfie face validation (image-space checks only).
class SelfieFaceValidator {
  SelfieFaceValidator({SelfieGuideConfig? config})
      : _analyzer = LiveSelfieFaceAnalyzer(config: config);

  final LiveSelfieFaceAnalyzer _analyzer;

  Future<CaptureValidationResult> validate(
    File file, {
    required String noFaceMessage,
    required String multipleFacesMessage,
    required String faceSizeMessage,
    required String notFullyVisibleMessage,
    bool trustLiveFraming = false,
  }) async {
    final input = InputImage.fromFilePath(file.path);
    return _analyzer.validateCapturedImage(
      input,
      noFaceMessage: noFaceMessage,
      multipleFacesMessage: multipleFacesMessage,
      faceSizeMessage: faceSizeMessage,
      notFullyVisibleMessage: notFullyVisibleMessage,
      trustLiveFraming: trustLiveFraming,
    );
  }

  void dispose() {
    _analyzer.dispose();
  }
}

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/capture_validation_result.dart';

/// OCR is used only as a readability gate — extracted text is never stored or logged.
class IdOcrValidator {
  IdOcrValidator({
    this.minTextBlocks = 2,
    this.minAlphanumericChars = 20,
  });

  final int minTextBlocks;
  final int minAlphanumericChars;

  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<CaptureValidationResult> validate(
    File file, {
    required String failureMessage,
  }) async {
    try {
      final input = InputImage.fromFilePath(file.path);
      final result = await _recognizer.processImage(input);

      final blockCount = result.blocks.length;
      var alnumCount = 0;
      for (final block in result.blocks) {
        for (final line in block.lines) {
          for (final codeUnit in line.text.codeUnits) {
            final ch = String.fromCharCode(codeUnit);
            if (RegExp(r'[A-Za-z0-9]').hasMatch(ch)) alnumCount++;
          }
        }
      }

      if (blockCount >= minTextBlocks && alnumCount >= minAlphanumericChars) {
        return const CaptureValidationResult.passed();
      }
      return CaptureValidationResult.failed(failureMessage);
    } catch (_) {
      return CaptureValidationResult.failed(failureMessage);
    }
  }

  void dispose() {
    _recognizer.close();
  }
}

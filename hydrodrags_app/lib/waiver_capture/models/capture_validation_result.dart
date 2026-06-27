/// Result of on-device capture validation (no PII stored).
class CaptureValidationResult {
  final bool passed;
  final String? failureMessage;

  const CaptureValidationResult._({required this.passed, this.failureMessage});

  const CaptureValidationResult.passed() : this._(passed: true);

  const CaptureValidationResult.failed(String message)
      : this._(passed: false, failureMessage: message);
}

/// Alignment feedback for live document framing.
enum FrameAlignmentState {
  searching,
  detecting,
  stable,
}

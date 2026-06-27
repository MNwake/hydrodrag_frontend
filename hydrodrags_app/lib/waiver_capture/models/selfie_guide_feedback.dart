/// Live positioning feedback while framing a selfie.
enum SelfieGuideFeedback {
  searching,
  noFace,
  multipleFaces,
  moveCloser,
  moveFarther,
  centerFace,
  faceNotFullyVisible,
  ready,
}

extension SelfieGuideFeedbackX on SelfieGuideFeedback {
  bool get isReady => this == SelfieGuideFeedback.ready;
}

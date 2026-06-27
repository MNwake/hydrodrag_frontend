import 'package:flutter/material.dart';

import '../models/selfie_guide_feedback.dart';

/// Computes the oval face guide rect for the given preview size.
Rect selfieGuideRect(Size size) {
  final w = size.width;
  final h = size.height;
  final maxW = w < 600 ? w * 0.72 : 360.0;
  final ovalW = maxW.clamp(220.0, w * 0.85);
  final ovalH = ovalW * 1.25;
  final left = (w - ovalW) / 2;
  final top = (h - ovalH) / 2;
  return Rect.fromLTWH(left, top, ovalW, ovalH);
}

/// Oval face guide overlay with live feedback.
class SelfieFrameOverlay extends StatelessWidget {
  const SelfieFrameOverlay({
    super.key,
    required this.instructionPrimary,
    required this.instructionSecondary,
    this.accessoriesHint = 'Remove sunglasses or hats',
    this.feedback = SelfieGuideFeedback.searching,
    this.feedbackMessage,
  });

  final String instructionPrimary;
  final String instructionSecondary;
  final String accessoriesHint;
  final SelfieGuideFeedback feedback;
  final String? feedbackMessage;

  Color get _borderColor {
    switch (feedback) {
      case SelfieGuideFeedback.ready:
        return Colors.greenAccent;
      case SelfieGuideFeedback.searching:
      case SelfieGuideFeedback.noFace:
        return Colors.white;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = selfieGuideRect(size);
        final hint = feedbackMessage ?? instructionSecondary;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SelfieCutoutPainter(
                frame: frame,
                borderColor: _borderColor,
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: frame.top - 56,
              child: Text(
                instructionPrimary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
            if (feedback == SelfieGuideFeedback.searching ||
                feedback == SelfieGuideFeedback.noFace)
              Positioned(
                left: 24,
                right: 24,
                top: frame.bottom + 8,
                child: Text(
                  accessoriesHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: feedback.isReady ? Colors.greenAccent : Colors.white70,
                  fontSize: 14,
                  fontWeight:
                      feedback.isReady ? FontWeight.w600 : FontWeight.normal,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelfieCutoutPainter extends CustomPainter {
  _SelfieCutoutPainter({required this.frame, required this.borderColor});

  final Rect frame;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final oval = Path()..addOval(frame);
    final scrim = Path.combine(PathOperation.difference, outer, oval);
    canvas.drawPath(scrim, Paint()..color = const Color(0xAA000000));

    canvas.drawOval(
      frame,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SelfieCutoutPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.borderColor != borderColor;
  }
}

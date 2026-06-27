import 'package:flutter/material.dart';

import '../models/capture_validation_result.dart';

/// ID-1 card aspect ratio (85.6 × 53.98 mm).
const double kIdCardAspectRatio = 1.586;

/// Computes the document frame rect for the given screen size.
Rect documentFrameRect(Size size) {
  final maxWidth = size.width < 600 ? size.width * 0.88 : 480.0 * 0.88;
  final frameWidth = maxWidth.clamp(240.0, size.width * 0.92);
  final frameHeight = frameWidth / kIdCardAspectRatio;
  final left = (size.width - frameWidth) / 2;
  final top = (size.height - frameHeight) / 2;
  return Rect.fromLTWH(left, top, frameWidth, frameHeight);
}

/// Semi-transparent overlay with a driver's-license-shaped cutout and corner guides.
class DocumentFrameOverlay extends StatelessWidget {
  const DocumentFrameOverlay({
    super.key,
    required this.instructionPrimary,
    required this.instructionSecondary,
    this.sideLabel,
    this.alignmentState = FrameAlignmentState.searching,
  });

  final String instructionPrimary;
  final String instructionSecondary;
  final String? sideLabel;
  final FrameAlignmentState alignmentState;

  Color get _borderColor {
    switch (alignmentState) {
      case FrameAlignmentState.searching:
        return Colors.white;
      case FrameAlignmentState.detecting:
        return Colors.amber;
      case FrameAlignmentState.stable:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = documentFrameRect(size);

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _DocumentCutoutPainter(
                frame: frame,
                borderColor: _borderColor,
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: (frame.top - 88).clamp(72.0, frame.top - 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    instructionPrimary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                  ),
                  if (sideLabel != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sideLabel!,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: frame.bottom + 16,
              child: Text(
                instructionSecondary,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DocumentCutoutPainter extends CustomPainter {
  _DocumentCutoutPainter({required this.frame, required this.borderColor});

  final Rect frame;
  final Color borderColor;

  static const _cornerLen = 28.0;
  static const _radius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final cutout = RRect.fromRectAndRadius(frame, const Radius.circular(_radius));
    final hole = Path()..addRRect(cutout);
    final scrim = Path.combine(PathOperation.difference, outer, hole);
    canvas.drawPath(scrim, Paint()..color = const Color(0xAA000000));

    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(cutout, border);

    final corner = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    _drawCorner(canvas, frame.topLeft, 1, 1, corner);
    _drawCorner(canvas, frame.topRight, -1, 1, corner);
    _drawCorner(canvas, frame.bottomLeft, 1, -1, corner);
    _drawCorner(canvas, frame.bottomRight, -1, -1, corner);
  }

  void _drawCorner(
    Canvas canvas,
    Offset origin,
    int xDir,
    int yDir,
    Paint paint,
  ) {
    canvas.drawLine(origin, origin + Offset(_cornerLen * xDir, 0), paint);
    canvas.drawLine(origin, origin + Offset(0, _cornerLen * yDir), paint);
  }

  @override
  bool shouldRepaint(covariant _DocumentCutoutPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.borderColor != borderColor;
  }
}

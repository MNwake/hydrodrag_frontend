import 'package:flutter/material.dart';

/// High-level waiver registration steps shown across the flow.
enum WaiverFlowStep {
  governmentId,
  selfie,
  waiver,
  signature,
  payment,
}

/// Horizontal step chip bar used across the waiver → payment pipeline.
class WaiverFlowProgress extends StatelessWidget {
  const WaiverFlowProgress({
    super.key,
    required this.currentStep,
    this.idFrontComplete = false,
    this.idBackComplete = false,
    this.idBackSkipped = false,
    this.selfieComplete = false,
    this.waiverReadComplete = false,
    this.signatureComplete = false,
  });

  final WaiverFlowStep currentStep;
  final bool idFrontComplete;
  final bool idBackComplete;
  final bool idBackSkipped;
  final bool selfieComplete;
  final bool waiverReadComplete;
  final bool signatureComplete;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _chip('ID', WaiverFlowStep.governmentId,
          idFrontComplete && (idBackComplete || idBackSkipped)),
      _chip('Selfie', WaiverFlowStep.selfie, selfieComplete),
      _chip('Waiver', WaiverFlowStep.waiver, waiverReadComplete),
      _chip('Sign', WaiverFlowStep.signature, signatureComplete),
      _chip('Pay', WaiverFlowStep.payment, false),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              steps[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, WaiverFlowStep step, bool done) {
    final active = currentStep == step;
    final color = done
        ? Colors.greenAccent
        : active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.55);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done
              ? Icons.check_circle
              : active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Standard top padding for [WaiverFlowProgress] on non-camera screens.
class WaiverFlowProgressHeader extends StatelessWidget {
  const WaiverFlowProgressHeader({
    super.key,
    required this.currentStep,
    this.idFrontComplete = false,
    this.idBackComplete = false,
    this.idBackSkipped = false,
    this.selfieComplete = false,
    this.waiverReadComplete = false,
    this.signatureComplete = false,
  });

  final WaiverFlowStep currentStep;
  final bool idFrontComplete;
  final bool idBackComplete;
  final bool idBackSkipped;
  final bool selfieComplete;
  final bool waiverReadComplete;
  final bool signatureComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: WaiverFlowProgress(
        currentStep: currentStep,
        idFrontComplete: idFrontComplete,
        idBackComplete: idBackComplete,
        idBackSkipped: idBackSkipped,
        selfieComplete: selfieComplete,
        waiverReadComplete: waiverReadComplete,
        signatureComplete: signatureComplete,
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../payments/pending_waiver_storage.dart';
import '../../services/app_state_service.dart';
import '../../services/auth_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/waiver_service.dart';
import '../../utils/app_log.dart';
import '../../widgets/language_toggle.dart';
import '../models/selfie_guide_feedback.dart';
import '../capture_fallback_timing.dart';
import '../services/camera_input_image_converter.dart';
import '../services/document_capture_controller.dart';
import '../services/image_quality_validator.dart';
import '../services/live_selfie_face_analyzer.dart';
import '../services/selfie_face_validator.dart';
import '../widgets/capture_review_sheet.dart';
import '../widgets/selfie_frame_overlay.dart';
import '../widgets/waiver_flow_progress.dart';

enum _SelfiePhase { initializing, live, validating, uploading }

/// Guided front-camera selfie capture with live face feedback and auto-capture.
class WaiverSelfieCaptureScreen extends StatefulWidget {
  const WaiverSelfieCaptureScreen({super.key});

  @override
  State<WaiverSelfieCaptureScreen> createState() =>
      _WaiverSelfieCaptureScreenState();
}

class _WaiverSelfieCaptureScreenState extends State<WaiverSelfieCaptureScreen> {
  final _captureController = DocumentCaptureController();
  final _liveAnalyzer = LiveSelfieFaceAnalyzer(
    config: const SelfieGuideConfig.lenient(),
  );
  final _postCaptureValidator = SelfieFaceValidator(
    config: const SelfieGuideConfig.lenient(),
  );
  final _qualityValidator = ImageQualityValidator(
    config: const ImageQualityConfig(
      minLaplacianVariance: 12,
      minAverageLuminance: 25,
      maxAverageLuminance: 240,
    ),
  );

  String? _sessionId;
  _SelfiePhase _phase = _SelfiePhase.initializing;
  bool _idFrontComplete = true;
  bool _idBackSkipped = true;

  SelfieGuideFeedback _feedback = SelfieGuideFeedback.searching;
  bool _isAnalyzingFrame = false;
  bool _captureEnabled = false;
  bool _isCapturing = false;
  bool _liveFramingReady = false;
  bool _faceDetectedRecently = false;
  bool _manualCaptureEnabled = false;
  Size _previewSize = Size.zero;

  Timer? _manualCaptureTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (_sessionId == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final detail = await WaiverService(auth).getSession(_sessionId!);
      if (!mounted) return;
      _idFrontComplete = detail.governmentIdFrontUploaded;
      _idBackSkipped = !detail.governmentIdBackUploaded;

      await _startLiveCapture();
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
    }
  }

  Future<void> _startLiveCapture() async {
    setState(() {
      _phase = _SelfiePhase.initializing;
      _feedback = SelfieGuideFeedback.searching;
      _captureEnabled = false;
      _isCapturing = false;
      _liveFramingReady = false;
      _faceDetectedRecently = false;
      _manualCaptureEnabled = false;
      _previewSize = Size.zero;
    });
    _liveAnalyzer.resetStability();
    _manualCaptureTimer?.cancel();
    await _stopImageStream();

    try {
      await _captureController.initialize(useFrontCamera: true);
      if (!mounted) return;

      _manualCaptureTimer = Timer(kManualCaptureFallbackDelay, () {
        if (mounted && _phase == _SelfiePhase.live) {
          setState(() {
            _manualCaptureEnabled = true;
            _captureEnabled = true;
          });
        }
      });

      final controller = _captureController.controller!;
      if (!controller.value.isInitialized) {
        throw StateError('Front camera not initialized');
      }
      await controller.startImageStream(_onCameraFrame);
      if (!mounted) return;
      setState(() => _phase = _SelfiePhase.live);
    } catch (e) {
      AppLog.info('WaiverCapture', 'Selfie camera init failed: $e');
      if (mounted) ErrorHandlerService.showError(context, e);
    }
  }

  Future<void> _stopImageStream() async {
    final controller = _captureController.controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _onCameraFrame(CameraImage image) async {
    if (_phase != _SelfiePhase.live ||
        _isAnalyzingFrame ||
        _isCapturing ||
        _previewSize == Size.zero) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameAt).inMilliseconds < 450) return;
    _lastFrameAt = now;

    final controller = _captureController.controller;
    if (controller == null) return;

    final input = CameraInputImageConverter.fromCameraImage(
      image,
      controller.description,
    );
    if (input == null) return;

    _isAnalyzingFrame = true;
    try {
      final analysis = await _liveAnalyzer.analyzeLiveFrame(
        input,
        previewSize: _previewSize,
        mirrorHorizontally: true,
      );

      if (!mounted || _phase != _SelfiePhase.live) return;

      if (analysis.hasFaceDetected) {
        _faceDetectedRecently = true;
      }

      final enabled = analysis.isReady ||
          analysis.hasFaceDetected ||
          _manualCaptureEnabled;
      _liveFramingReady = analysis.isReady || analysis.hasFaceDetected;
      if (analysis.feedback != _feedback || enabled != _captureEnabled) {
        setState(() {
          _feedback = analysis.feedback;
          _captureEnabled = enabled;
        });
      }

      if (analysis.shouldAutoCapture && !_isCapturing) {
        await _captureSelfie(auto: true);
      }
    } finally {
      _isAnalyzingFrame = false;
    }
  }

  String _feedbackMessage(AppLocalizations l10n) {
    return switch (_feedback) {
      SelfieGuideFeedback.searching => l10n.selfieInstructionSecondary,
      SelfieGuideFeedback.noFace => l10n.selfieFeedbackNoFace,
      SelfieGuideFeedback.multipleFaces => l10n.selfieMultipleFacesMessage,
      SelfieGuideFeedback.moveCloser => l10n.selfieFeedbackMoveCloser,
      SelfieGuideFeedback.moveFarther => l10n.selfieFeedbackMoveFarther,
      SelfieGuideFeedback.centerFace => l10n.selfieFeedbackCenterFace,
      SelfieGuideFeedback.faceNotFullyVisible =>
        l10n.selfieFeedbackNotFullyVisible,
      SelfieGuideFeedback.ready => l10n.selfieFeedbackReady,
    };
  }

  Future<void> _captureSelfie({bool auto = false}) async {
    if (_phase != _SelfiePhase.live || _isCapturing) return;
    if (!auto && !_captureEnabled) return;

    final trustLiveFraming =
        _liveFramingReady || _faceDetectedRecently || _manualCaptureEnabled;
    _isCapturing = true;
    _manualCaptureTimer?.cancel();
    setState(() => _phase = _SelfiePhase.validating);
    await _stopImageStream();

    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await _captureController.captureToTempFile(prefix: 'selfie');

      var result = _qualityValidator.validateBlur(
        file,
        blurMessage: l10n.selfieBlurMessage,
      );
      if (!result.passed && !trustLiveFraming) {
        await _rejectCapture('blur', result.failureMessage!);
        return;
      }

      result = _qualityValidator.validateExposure(
        file,
        tooDarkMessage: l10n.selfieTooDarkMessage,
        tooBrightMessage: l10n.selfieTooBrightMessage,
      );
      if (!result.passed && !trustLiveFraming) {
        await _rejectCapture('exposure', result.failureMessage!);
        return;
      }

      result = await _postCaptureValidator.validate(
        file,
        noFaceMessage: l10n.selfieNoFaceMessage,
        multipleFacesMessage: l10n.selfieMultipleFacesMessage,
        faceSizeMessage: l10n.selfieFaceSizeMessage,
        notFullyVisibleMessage: l10n.selfieFeedbackNotFullyVisible,
        trustLiveFraming: trustLiveFraming,
      );
      if (!result.passed) {
        await _rejectCapture('face', result.failureMessage!);
        return;
      }

      if (!mounted) return;
      final usePhoto = await CaptureReviewSheet.show(
        context,
        imageFile: file,
        usePhotoLabel: l10n.idCaptureUsePhoto,
        retakeLabel: l10n.idCaptureRetake,
      );

      if (usePhoto != true) {
        AppLog.info('WaiverCapture', 'Selfie retake requested');
        await _startLiveCapture();
        return;
      }

      await _upload(file);
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
      await _startLiveCapture();
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _rejectCapture(String reason, String message) async {
    AppLog.info('WaiverCapture', 'Selfie rejected: $reason');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    await _startLiveCapture();
  }

  Future<void> _upload(File file) async {
    setState(() => _phase = _SelfiePhase.uploading);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await WaiverService(auth).uploadSelfie(
        sessionId: _sessionId!,
        file: file,
      );
      AppLog.info('WaiverCapture', 'Selfie uploaded');

      final eventId = Provider.of<AppStateService>(context, listen: false)
              .selectedEvent
              ?.id ??
          '';
      await PendingWaiverStorage.save(
        eventId: eventId,
        sessionId: _sessionId!,
        step: 'waiver_review',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/waiver-overview',
        arguments: _sessionId,
      );
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
      await _startLiveCapture();
    }
  }

  @override
  void dispose() {
    _manualCaptureTimer?.cancel();
    unawaited(_stopImageStream().then((_) => _captureController.dispose()));
    _liveAnalyzer.dispose();
    _postCaptureValidator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.selfieCaptureTitle),
        actions: const [LanguageToggle(isCompact: true), SizedBox(width: 8)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _previewSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_captureController.isInitialized)
                CameraPreview(_captureController.controller!)
              else
                const Center(child: CircularProgressIndicator()),
              if (_phase == _SelfiePhase.live)
                SelfieFrameOverlay(
                  instructionPrimary: l10n.selfieInstructionPrimary,
                  instructionSecondary: l10n.selfieInstructionSecondary,
                  accessoriesHint: l10n.selfieRemoveAccessoriesHint,
                  feedback: _feedback,
                  feedbackMessage: _feedbackMessage(l10n),
                ),
              if (_phase == _SelfiePhase.validating ||
                  _phase == _SelfiePhase.uploading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          _phase == _SelfiePhase.uploading
                              ? l10n.selfieUploading
                              : l10n.selfieValidating,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: WaiverFlowProgress(
                    currentStep: WaiverFlowStep.selfie,
                    idFrontComplete: _idFrontComplete,
                    idBackSkipped: _idBackSkipped,
                    selfieComplete: false,
                  ),
                ),
              ),
              if (_phase == _SelfiePhase.live)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      onPressed:
                          _captureEnabled ? () => _captureSelfie() : null,
                      backgroundColor:
                          _captureEnabled ? null : Colors.white24,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

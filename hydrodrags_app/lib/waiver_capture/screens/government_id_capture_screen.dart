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
import '../models/capture_validation_result.dart';
import '../capture_fallback_timing.dart';
import '../services/camera_frame_analyzer.dart';
import '../services/document_capture_controller.dart';
import '../services/frame_stability_detector.dart';
import '../services/id_ocr_validator.dart';
import '../services/image_quality_validator.dart';
import '../widgets/capture_review_sheet.dart';
import '../widgets/document_frame_overlay.dart';
import '../widgets/waiver_flow_progress.dart';

enum _IdSide { front, back }

enum _CapturePhase { initializing, live, validating, uploading }

/// Camera-only government ID capture with on-device validation.
class GovernmentIdCaptureScreen extends StatefulWidget {
  const GovernmentIdCaptureScreen({super.key});

  @override
  State<GovernmentIdCaptureScreen> createState() =>
      _GovernmentIdCaptureScreenState();
}

class _GovernmentIdCaptureScreenState extends State<GovernmentIdCaptureScreen> {
  static const _idType = 'driver_license';

  final _captureController = DocumentCaptureController();
  final _stabilityDetector = FrameStabilityDetector();
  final _qualityValidator = ImageQualityValidator();
  late final IdOcrValidator _ocrValidator = IdOcrValidator();

  String? _sessionId;
  _IdSide _side = _IdSide.front;
  _CapturePhase _phase = _CapturePhase.initializing;
  FrameAlignmentState _alignment = FrameAlignmentState.searching;

  bool _frontComplete = false;
  bool _backComplete = false;
  bool _backSkipped = false;
  bool _showManualShutter = false;
  bool _cameraReleased = false;

  Timer? _manualShutterTimer;

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

      if (detail.governmentIdFrontUploaded) {
        _frontComplete = true;
        _side = _IdSide.back;
      }
      if (detail.governmentIdBackUploaded) {
        _backComplete = true;
      }

      await _startLiveCapture();
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
    }
  }

  Future<void> _startLiveCapture() async {
    setState(() => _phase = _CapturePhase.initializing);
    _stabilityDetector.reset();
    _showManualShutter = false;
    _manualShutterTimer?.cancel();
    await _stopImageStream();

    try {
      await _captureController.initialize(useFrontCamera: false);
      if (!mounted) return;

      _manualShutterTimer = Timer(kManualCaptureFallbackDelay, () {
        if (mounted && _phase == _CapturePhase.live) {
          setState(() => _showManualShutter = true);
        }
      });

      await _captureController.controller!.startImageStream(_onCameraFrame);
      setState(() => _phase = _CapturePhase.live);
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
    }
  }

  Future<void> _releaseCamera() async {
    if (_cameraReleased) return;
    _cameraReleased = true;
    _manualShutterTimer?.cancel();
    await _stopImageStream();
    await _captureController.dispose();
  }

  Future<void> _goToSelfieCapture() async {
    await _releaseCamera();
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(
      '/waiver-selfie',
      arguments: _sessionId,
    );
  }

  Future<void> _stopImageStream() async {
    final controller = _captureController.controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  DateTime _lastSampleAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _onCameraFrame(CameraImage image) {
    if (_phase != _CapturePhase.live) return;
    final now = DateTime.now();
    if (now.difference(_lastSampleAt).inMilliseconds < 400) return;
    _lastSampleAt = now;

    final density = CameraFrameAnalyzer.edgeDensityFromCameraImage(image);
    if (density == null || !mounted) return;

    final ready = _stabilityDetector.addSample(density);
    final alignment = _stabilityDetector.alignmentState;
    if (alignment != _alignment) {
      setState(() => _alignment = alignment);
    }
    if (ready) {
      _triggerCapture(auto: true);
    }
  }

  Future<void> _triggerCapture({required bool auto}) async {
    if (_phase != _CapturePhase.live) return;
    _manualShutterTimer?.cancel();
    setState(() => _phase = _CapturePhase.validating);
    await _stopImageStream();

    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await _captureController.captureToTempFile(
        prefix: _side == _IdSide.front ? 'id_front' : 'id_back',
      );

      var result = _qualityValidator.validateBlur(
        file,
        blurMessage: l10n.idCaptureBlurMessage,
      );
      if (!result.passed) {
        _handleValidationFailure(result);
        return;
      }

      result = _qualityValidator.validateGlare(
        file,
        glareMessage: l10n.idCaptureGlareMessage,
      );
      if (!result.passed) {
        _handleValidationFailure(result);
        return;
      }

      result = await _ocrValidator.validate(
        file,
        failureMessage: l10n.idCaptureOcrMessage,
      );
      if (!result.passed) {
        _handleValidationFailure(result);
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
        AppLog.info('WaiverCapture', '${_side.name} retake requested');
        await _startLiveCapture();
        return;
      }

      await _upload(file);
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
      await _startLiveCapture();
    }
  }

  void _handleValidationFailure(CaptureValidationResult result) {
    AppLog.info('WaiverCapture', '${_side.name} validation failed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureMessage ??
                AppLocalizations.of(context)!.idCaptureRetake,
          ),
        ),
      );
    }
    _startLiveCapture();
  }

  Future<void> _upload(File file) async {
    setState(() => _phase = _CapturePhase.uploading);
    final auth = Provider.of<AuthService>(context, listen: false);
    final service = WaiverService(auth);
    final side = _side == _IdSide.front ? 'front' : 'back';

    try {
      await service.uploadGovernmentId(
        sessionId: _sessionId!,
        side: side,
        idType: _idType,
        file: file,
      );
      AppLog.info('WaiverCapture', '$side uploaded');

      if (_side == _IdSide.front) {
        setState(() {
          _frontComplete = true;
          _side = _IdSide.back;
        });
        await PendingWaiverStorage.save(
          eventId: Provider.of<AppStateService>(context, listen: false)
                  .selectedEvent
                  ?.id ??
              '',
          sessionId: _sessionId!,
          step: 'government_id',
        );
      if (!mounted) return;
      await _startLiveCapture();
        return;
      }

      setState(() => _backComplete = true);
      await PendingWaiverStorage.save(
        eventId: Provider.of<AppStateService>(context, listen: false)
                .selectedEvent
                ?.id ??
            '',
        sessionId: _sessionId!,
        step: 'selfie',
      );
      if (!mounted) return;
      await _goToSelfieCapture();
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
      await _startLiveCapture();
    }
  }

  Future<void> _skipBack() async {
    setState(() => _backSkipped = true);
    await PendingWaiverStorage.save(
      eventId: Provider.of<AppStateService>(context, listen: false)
              .selectedEvent
              ?.id ??
          '',
      sessionId: _sessionId!,
      step: 'selfie',
    );
    if (!mounted) return;
    await _goToSelfieCapture();
  }

  @override
  void dispose() {
    _manualShutterTimer?.cancel();
    if (!_cameraReleased) {
      unawaited(_releaseCamera());
    }
    _ocrValidator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBack = _side == _IdSide.back;
    final title = isBack ? l10n.idCaptureBackTitle : l10n.idCaptureFrontTitle;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        actions: const [LanguageToggle(isCompact: true), SizedBox(width: 8)],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_captureController.isInitialized)
            CameraPreview(_captureController.controller!)
          else
            const Center(child: CircularProgressIndicator()),
          if (_phase == _CapturePhase.live)
            DocumentFrameOverlay(
              instructionPrimary: isBack
                  ? l10n.idCaptureBackInstructionPrimary
                  : l10n.idCaptureFrontInstructionPrimary,
              instructionSecondary: l10n.idCaptureInstructionSecondary,
              sideLabel: isBack
                  ? l10n.idCaptureBackSideLabel
                  : l10n.idCaptureFrontSideLabel,
              alignmentState: _alignment,
            ),
          if (_phase == _CapturePhase.validating ||
              _phase == _CapturePhase.uploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _phase == _CapturePhase.uploading
                          ? l10n.idCaptureUploading
                          : l10n.idCaptureValidating,
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
                currentStep: WaiverFlowStep.governmentId,
                idFrontComplete: _frontComplete,
                idBackComplete: _backComplete,
                idBackSkipped: _backSkipped,
              ),
            ),
          ),
          if (_phase == _CapturePhase.live && _showManualShutter)
            Positioned(
              bottom: isBack ? 72 : 32,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.large(
                  onPressed: () => _triggerCapture(auto: false),
                  child: const Icon(Icons.camera_alt),
                ),
              ),
            ),
          if (isBack && _phase == _CapturePhase.live)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: TextButton(
                  onPressed: _skipBack,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(l10n.idCaptureSkipBack),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

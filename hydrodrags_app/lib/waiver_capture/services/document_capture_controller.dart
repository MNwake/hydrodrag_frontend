import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages [CameraController] lifecycle for ID and selfie capture.
class DocumentCaptureController {
  /// Serializes camera open/close across capture screens (iOS needs this).
  static Future<void> _cameraGate = Future.value();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _disposed = false;

  CameraController? get controller => _controller;
  bool get isInitialized =>
      !_disposed &&
      _controller != null &&
      _controller!.value.isInitialized;

  Future<void> initialize({
    required bool useFrontCamera,
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _initializeOnce(useFrontCamera);
        return;
      } catch (e) {
        lastError = e;
        if (attempt == maxAttempts) break;
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    throw StateError('Camera failed to initialize: $lastError');
  }

  Future<void> _initializeOnce(bool useFrontCamera) async {
    final previous = _cameraGate;
    final gate = Completer<void>();
    _cameraGate = gate.future;

    await previous;
    try {
      await dispose();
      // Give the OS time to release the previous lens (back → front switch).
      await Future<void>.delayed(const Duration(milliseconds: 400));

      _disposed = false;
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw StateError('No cameras available');
      }

      final selected = useFrontCamera
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            )
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first,
            );

      _controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
    } finally {
      gate.complete();
    }
  }

  Future<File> captureToTempFile({String prefix = 'capture'}) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw StateError('Camera not initialized');
    }
    final xFile = await _controller!.takePicture();
    final dir = await getTemporaryDirectory();
    final dest = File(
      p.join(
        dir.path,
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    await File(xFile.path).copy(dest.path);
    try {
      await File(xFile.path).delete();
    } catch (_) {}
    return dest;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) {
          await c.stopImageStream();
        }
      } catch (_) {}
      try {
        await c.dispose();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

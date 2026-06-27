import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Converts [CameraImage] frames to [InputImage] for on-device ML Kit analysis.
class CameraInputImageConverter {
  CameraInputImageConverter._();

  static InputImage? fromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final rotation = _rotation(camera);
    if (rotation == null) return null;

    if (Platform.isIOS) {
      return _fromIos(image, rotation);
    }
    return _fromAndroid(image, rotation);
  }

  static InputImageRotation? _rotation(CameraDescription camera) {
    return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
  }

  static InputImage? _fromIos(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static InputImage? _fromAndroid(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    if (image.planes.length < 3) return null;
    final nv21 = _yuv420ToNv21(image);
    if (nv21 == null) return null;

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }

  static Uint8List? _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    var offset = 0;

    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    var uvOffset = width * height;

    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final uvIndex = row * uvRowStride + col * uvPixelStride;
        nv21[uvOffset++] = vPlane.bytes[uvIndex];
        nv21[uvOffset++] = uPlane.bytes[uvIndex];
      }
    }

    return nv21;
  }
}

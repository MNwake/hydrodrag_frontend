import 'dart:io';

import 'package:flutter/material.dart';

/// Bottom sheet to confirm a captured photo before upload.
class CaptureReviewSheet extends StatelessWidget {
  const CaptureReviewSheet({
    super.key,
    required this.imageFile,
    required this.onRetake,
    required this.onUsePhoto,
    required this.usePhotoLabel,
    required this.retakeLabel,
  });

  final File imageFile;
  final VoidCallback onRetake;
  final VoidCallback onUsePhoto;
  final String usePhotoLabel;
  final String retakeLabel;

  static Future<bool?> show(
    BuildContext context, {
    required File imageFile,
    required String usePhotoLabel,
    required String retakeLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CaptureReviewSheet(
        imageFile: imageFile,
        usePhotoLabel: usePhotoLabel,
        retakeLabel: retakeLabel,
        onRetake: () => Navigator.of(ctx).pop(false),
        onUsePhoto: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                imageFile,
                height: 220,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetake,
                    child: Text(retakeLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onUsePhoto,
                    child: Text(usePhotoLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

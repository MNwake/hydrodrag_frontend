import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class UpdateDialog {
  static Future<void> showOptional({
    required BuildContext context,
    required String storeUrl,
    String? message,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.updateAvailableTitle),
          content: _buildContent(l10n.updateAvailableMessage, message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.updateLaterButton),
            ),
            TextButton(
              onPressed: () => _openStore(dialogContext, storeUrl),
              child: Text(l10n.updateButton),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showForce({
    required BuildContext context,
    required String storeUrl,
    String? message,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.updateAvailableTitle),
            content: _buildContent(l10n.updateAvailableMessage, message),
            actions: [
              TextButton(
                onPressed: () => _openStore(dialogContext, storeUrl),
                child: Text(l10n.updateButton),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildContent(String intro, String? message) {
    if (message == null || message.isEmpty) {
      return Text(intro);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro),
        const SizedBox(height: 12),
        Text(message),
      ],
    );
  }

  static Future<void> _openStore(BuildContext context, String storeUrl) async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

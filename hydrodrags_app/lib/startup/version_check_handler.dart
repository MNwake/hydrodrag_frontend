import 'package:flutter/material.dart';

import '../services/version_check_service.dart';
import '../widgets/update_dialog.dart';

/// Runs a version check on startup and shows update dialogs when required.
class VersionCheckHandler extends StatefulWidget {
  const VersionCheckHandler({super.key, required this.child});

  final Widget child;

  @override
  State<VersionCheckHandler> createState() => _VersionCheckHandlerState();
}

class _VersionCheckHandlerState extends State<VersionCheckHandler> {
  final VersionCheckService _versionCheckService = VersionCheckService();
  bool _checked = false;
  bool _forceUpdateActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  Future<void> _checkVersion() async {
    if (_checked) return;
    _checked = true;

    final result = await _versionCheckService.checkForUpdate();
    if (!mounted || result == null) return;

    // Wait until the Navigator is available (home route may not be attached on first frame).
    await _waitForNavigator();

    if (!mounted) return;

    if (result.forceUpdate) {
      setState(() => _forceUpdateActive = true);
      await UpdateDialog.showForce(
        context: context,
        storeUrl: result.storeUrl,
        message: result.message,
      );
      return;
    }

    if (result.updateAvailable) {
      await UpdateDialog.showOptional(
        context: context,
        storeUrl: result.storeUrl,
        message: result.message,
      );
    }
  }

  Future<void> _waitForNavigator() async {
    const maxAttempts = 10;
    for (var i = 0; i < maxAttempts; i++) {
      if (!mounted) return;
      if (Navigator.maybeOf(context, rootNavigator: true) != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_forceUpdateActive) {
      return Stack(
        children: [
          AbsorbPointer(child: widget.child),
          const ModalBarrier(dismissible: false),
        ],
      );
    }

    return widget.child;
  }
}

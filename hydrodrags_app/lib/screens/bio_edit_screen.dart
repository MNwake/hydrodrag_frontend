import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_toggle.dart';

/// Full-screen screen for editing racer bio.
/// Automatically saves changes when the user hits back.
class BioEditScreen extends StatefulWidget {
  final String initialBio;
  final Function(String)? onBioChanged;

  const BioEditScreen({
    super.key,
    this.initialBio = '',
    this.onBioChanged,
  });

  @override
  State<BioEditScreen> createState() => _BioEditScreenState();
}

class _BioEditScreenState extends State<BioEditScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Save bio when user hits back
          widget.onBioChanged?.call(_controller.text.trim());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.editBio ?? 'Edit Bio'),
          actions: [
            const LanguageToggle(isCompact: true),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: l10n.bio ?? 'Bio',
                hintText: l10n.bioHint ?? 'Tell us about yourself...',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLength: 400,
              maxLines: 16,
              minLines: 8,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
  }
}

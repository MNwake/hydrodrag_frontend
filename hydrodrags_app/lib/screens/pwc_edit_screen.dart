import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pwc.dart';
import '../services/auth_service.dart';
import '../services/pwc_service.dart';
import '../services/error_handler_service.dart';
import '../l10n/app_localizations.dart';

class PWCEditScreen extends StatefulWidget {
  final PWC? pwc;

  const PWCEditScreen({super.key, this.pwc});

  @override
  State<PWCEditScreen> createState() => _PWCEditScreenState();
}

class _PWCEditScreenState extends State<PWCEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.pwc != null) {
      _nameController.text = widget.pwc!.displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _savePWC() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final pwcService = PWCService(authService);

      bool success;
      if (widget.pwc?.id == null) {
        // Add: POST /pwc with pwc_id (name)
        success = await pwcService.addPWC(name);
      } else {
        // Edit: PATCH with minimal PWC (name as make so displayName shows it)
        final pwc = PWC(
          id: widget.pwc!.id,
          make: name,
          model: '',
          isPrimary: widget.pwc!.isPrimary,
          modifications: widget.pwc!.modifications,
        );
        success = await pwcService.updatePWC(pwc);
      }

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ErrorHandlerService.showError(context, 'Failed to save PWC');
          setState(() {
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Save PWC');
      if (mounted) {
        ErrorHandlerService.showError(context, e);
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pwc == null ? l10n.addPWC : l10n.editPWC),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _savePWC,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.pwcName,
                hintText: l10n.pwcNameHint,
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.required;
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePWC,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

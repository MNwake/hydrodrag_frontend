import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pwc.dart';
import '../services/auth_service.dart';
import '../services/pwc_service.dart';
import '../services/error_handler_service.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';
import 'pwc_edit_screen.dart';

class PWCManagementScreen extends StatefulWidget {
  const PWCManagementScreen({super.key});

  @override
  State<PWCManagementScreen> createState() => _PWCManagementScreenState();
}

class _PWCManagementScreenState extends State<PWCManagementScreen> {
  List<PWC> _pwcs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPWCs();
  }

  Future<void> _loadPWCs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final pwcService = PWCService(authService);
      final pwcs = await pwcService.getPWCs();

      if (mounted) {
        setState(() {
          _pwcs = pwcs;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load PWCs');
      if (mounted) {
        setState(() {
          _error = ErrorHandlerService.getErrorMessage(context, e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePWC(PWC pwc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deletePWC),
        content: Text(AppLocalizations.of(context)!.deletePWCConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && pwc.id != null) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final pwcService = PWCService(authService);
        final success = await pwcService.deletePWC(pwc.id!);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.pwcDeleted),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
          _loadPWCs();
        } else if (mounted) {
          ErrorHandlerService.showError(context, 'Failed to delete PWC');
        }
      } catch (e) {
        ErrorHandlerService.logError(e, context: 'Delete PWC');
        if (mounted) {
          ErrorHandlerService.showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pwcManagement),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadPWCs,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : _pwcs.isEmpty
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      onRefresh: _loadPWCs,
                      child: _buildPWCsList(context),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PWCEditScreen(),
            ),
          );
          if (result == true) {
            _loadPWCs();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addPWC),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noPWCs,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addPWCToGetStarted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPWCsList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pwcs.length,
      itemBuilder: (context, index) {
        final pwc = _pwcs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () async {
              // Tap card to edit
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PWCEditScreen(pwc: pwc),
                ),
              );
              if (result == true && mounted) {
                _loadPWCs();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.water,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with primary badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pwc.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (pwc.isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l10n.primary,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Optional details (when present)
                        if (pwc.engineClass != null || pwc.color != null || pwc.modifications.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          if (pwc.engineClass != null)
                            _buildInfoChip(context, l10n.engineClass, pwc.engineClass!),
                          if (pwc.color != null)
                            _buildInfoChip(context, l10n.color, pwc.color!),
                          if (pwc.modifications.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: pwc.modifications.take(3).map((mod) {
                                return Chip(
                                  label: Text(
                                    mod,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          if (pwc.modifications.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                l10n.andMore(pwc.modifications.length - 3),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  // Actions menu
                  PopupMenuButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: theme.colorScheme.onSurface),
                            const SizedBox(width: 12),
                            Text(l10n.edit),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'set_primary',
                        enabled: !pwc.isPrimary,
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 20, color: theme.colorScheme.onSurface),
                            const SizedBox(width: 12),
                            Text(l10n.setAsPrimary),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Text(
                              l10n.delete,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PWCEditScreen(pwc: pwc),
                          ),
                        );
                        if (result == true && mounted) {
                          _loadPWCs();
                        }
                      } else if (value == 'set_primary') {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        final pwcService = PWCService(authService);
                        if (pwc.id != null) {
                          final primaryPwc = PWC(
                            id: pwc.id,
                            make: pwc.make,
                            model: pwc.model,
                            year: pwc.year,
                            engineSize: pwc.engineSize,
                            engineClass: pwc.engineClass,
                            color: pwc.color,
                            registrationNumber: pwc.registrationNumber,
                            serialNumber: pwc.serialNumber,
                            modifications: List.from(pwc.modifications),
                            notes: pwc.notes,
                            isPrimary: true,
                            createdAt: pwc.createdAt,
                            updatedAt: pwc.updatedAt,
                          );
                          final success = await pwcService.updatePWC(primaryPwc);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${pwc.displayName} ${l10n.setAsPrimary.toLowerCase()}'),
                              ),
                            );
                            _loadPWCs();
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.error),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      } else if (value == 'delete') {
                        _deletePWC(pwc);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

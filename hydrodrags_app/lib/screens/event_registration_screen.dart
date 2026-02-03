import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../services/auth_service.dart';
import '../services/pwc_service.dart';
import '../services/racer_service.dart';
import '../services/error_handler_service.dart';
import '../widgets/language_toggle.dart';
import '../widgets/step_progress_indicator.dart';
import '../models/event.dart';
import '../models/event_registration.dart';
import '../models/pwc.dart';
import '../l10n/app_localizations.dart';
import 'pwc_edit_screen.dart';

class EventRegistrationScreen extends StatefulWidget {
  final Event? event;

  const EventRegistrationScreen({super.key, this.event});

  @override
  State<EventRegistrationScreen> createState() => _EventRegistrationScreenState();
}

/// Sentinel value for "Add a new PWC" in the PWC dropdown (not a real PWC id).
const String _kAddNewPwcValue = '__add_new_pwc__';

/// One row in the class+PWC list (classKey and pwcId can be null until selected).
class _ClassRow {
  String? classKey;
  String? pwcId;
  _ClassRow({this.classKey, this.pwcId});
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  // 0: Classes/PWC + IHRA, 1: Waiver, 2: Day passes, 3: Payment
  int _currentStep = 0;
  final _step1FormKey = GlobalKey<FormState>();

  // Step 0: Multiple class + PWC entries (same PWC can be used in multiple classes)
  List<_ClassRow> _classRows = [_ClassRow()];
  List<PWC> _pwcs = [];
  bool _isLoadingPWCs = true;
  PWC? _primaryPWC;

  // IHRA: if user doesn't have valid membership (number + purchased this year), they can add purchase
  bool _purchaseIhraMembership = false;

  // Step 2: Spectator passes — $30 single day, $40 weekend
  int _spectatorSingleDayPasses = 0;
  int _spectatorWeekendPasses = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeEvent = ModalRoute.of(context)?.settings.arguments;
      final event = widget.event ?? (routeEvent is Event ? routeEvent : null);
      if (event != null) {
        Provider.of<AppStateService>(context, listen: false).setSelectedEvent(event);
      }
    });
    _loadPWCs();
    _loadExistingData();
    _refreshRacerProfileForWaiverStatus();
  }

  /// Refresh racer profile from server so we have latest hasValidWaiver when deciding waiver step.
  Future<void> _refreshRacerProfileForWaiverStatus() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final appState = Provider.of<AppStateService>(context, listen: false);
    final racerService = RacerService(authService);
    try {
      final profile = await racerService.getCurrentRacerProfile();
      if (mounted && profile != null) {
        appState.setRacerProfile(profile);
        if (kDebugMode) {
          print('[EventRegistration] Racer profile refreshed: hasValidWaiver=${profile.hasValidWaiver}, waiverSignedAt=${profile.waiverSignedAt}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[EventRegistration] Could not refresh racer profile for waiver status: $e');
      }
    }
  }

  Future<void> _loadPWCs() async {
    setState(() {
      _isLoadingPWCs = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final pwcService = PWCService(authService);
      final pwcs = await pwcService.getPWCs();

      if (mounted) {
        setState(() {
          _pwcs = pwcs;
          if (pwcs.isNotEmpty) {
            _primaryPWC = pwcs.firstWhere((p) => p.isPrimary, orElse: () => pwcs.first);
            if (_classRows.length == 1 && _classRows.first.pwcId == null) {
              _classRows.first.pwcId = _primaryPWC?.id;
            }
          }
          _isLoadingPWCs = false;
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load PWCs for Registration');
      if (mounted) {
        setState(() {
          _isLoadingPWCs = false;
        });
        ErrorHandlerService.showError(context, e);
      }
    }
  }

  void _loadExistingData() {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final registration = appState.eventRegistration;
    if (registration != null) {
      if (registration.classEntries.isNotEmpty) {
        _classRows = registration.classEntries
            .map((e) => _ClassRow(classKey: e.classKey, pwcId: e.pwcId))
            .toList();
      } else if (registration.pwcId != null && registration.classDivision != null) {
        _classRows = [_ClassRow(classKey: registration.classDivision, pwcId: registration.pwcId)];
      }
      _purchaseIhraMembership = registration.purchaseIhraMembership;
      _spectatorSingleDayPasses = registration.spectatorSingleDayPasses;
      _spectatorWeekendPasses = registration.spectatorWeekendPasses;
    }
  }

  /// Valid IHRA = membership number present and purchased within current calendar year.
  bool _hasValidIhra(BuildContext context) {
    final profile = Provider.of<AppStateService>(context, listen: false).racerProfile;
    if (profile == null) return false;
    final hasNumber = profile.membershipNumber != null && profile.membershipNumber!.trim().isNotEmpty;
    final currentYear = DateTime.now().year;
    final purchasedThisYear = profile.membershipPurchasedAt != null &&
        profile.membershipPurchasedAt!.year == currentYear;
    return hasNumber && purchasedThisYear;
  }

  List<ClassPwcEntry> get _completeClassEntries {
    return _classRows
        .where((r) =>
            r.classKey != null &&
            r.classKey!.isNotEmpty &&
            r.pwcId != null &&
            r.pwcId!.isNotEmpty &&
            r.pwcId != _kAddNewPwcValue &&
            _pwcs.any((p) => p.id == r.pwcId))
        .map((r) => ClassPwcEntry(classKey: r.classKey!, pwcId: r.pwcId!))
        .toList();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _saveStep1() {
    if (!_step1FormKey.currentState!.validate()) {
      return;
    }

    final entries = _completeClassEntries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.classDivisionRequired),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final hasValidIhra = _hasValidIhra(context);
    if (!hasValidIhra && !_purchaseIhraMembership) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.validIhraMembershipDescription),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final registration = EventRegistration(
      classEntries: entries,
      pwcId: entries.first.pwcId,
      classDivision: entries.first.classKey,
      purchaseIhraMembership: _purchaseIhraMembership,
      spectatorSingleDayPasses: _spectatorSingleDayPasses,
      spectatorWeekendPasses: _spectatorWeekendPasses,
    );

    final appState = Provider.of<AppStateService>(context, listen: false);
    appState.setEventRegistration(registration);

    final profile = appState.racerProfile;
    final waiver = appState.waiverSignature;
    final currentYear = DateTime.now().year;
    final inAppWaiverValid = waiver != null && waiver.signedAt.year == currentYear;
    final backendHasValidWaiver = profile?.hasValidWaiver == true;
    final skipWaiver = inAppWaiverValid || backendHasValidWaiver;

    if (kDebugMode) {
      print('[EventRegistration] Waiver check: racer.hasValidWaiver=${profile?.hasValidWaiver}, racer.waiverSignedAt=${profile?.waiverSignedAt}, appState.waiverSignature=${waiver != null ? "signed ${waiver.signedAt}" : "null"}, skipWaiver=$skipWaiver');
    }

    if (skipWaiver) {
      setState(() => _currentStep = 2);
      return;
    }

    setState(() => _currentStep = 1);
  }

  void _saveStep2DayPasses() {
    final appState = Provider.of<AppStateService>(context, listen: false);
    final reg = appState.eventRegistration;
    if (reg != null) {
      appState.setEventRegistration(EventRegistration(
        classEntries: reg.classEntries,
        pwcId: reg.pwcId,
        classDivision: reg.classDivision,
        purchaseIhraMembership: reg.purchaseIhraMembership,
        spectatorSingleDayPasses: _spectatorSingleDayPasses,
        spectatorWeekendPasses: _spectatorWeekendPasses,
        paymentTransactionId: reg.paymentTransactionId,
        paymentStatus: reg.paymentStatus,
      ));
    }
    if (mounted) {
      Navigator.of(context).pushNamed('/checkout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final event = widget.event ?? Provider.of<AppStateService>(context).selectedEvent;

    return Scaffold(
      appBar: AppBar(
        title: Text(event?.name ?? l10n.eventRegistration),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          StepProgressIndicator(
            currentStep: _currentStep + 1,
            totalSteps: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStep(_currentStep),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return _buildStep1(); // Classes/PWC + IHRA
      case 1:
        return _buildStep2(); // Waiver (navigates to waiver screens)
      case 2:
        return _buildStep2DayPasses(); // Spectator day passes
      case 3:
        return _buildStep3(); // Payment (placeholder)
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final event = widget.event ?? Provider.of<AppStateService>(context).selectedEvent;
    final activeClasses = event?.classes.where((c) => c.isActive).toList() ?? [];
    final hasValidIhra = _hasValidIhra(context);

    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.classesAndPwc,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selectClassAndPWCDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoadingPWCs)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_pwcs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_boat_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noPWCsFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.addPWCFirst,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => const PWCEditScreen(),
                        ),
                      );
                      if (result == true && mounted) _loadPWCs();
                    },
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(l10n.addPWC),
                  ),
                ],
              ),
            )
          else ...[
            // Multiple class + PWC rows (same PWC can be used in multiple classes)
            ...List.generate(_classRows.length, (i) {
              final row = _classRows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: activeClasses.any((c) => c.key == row.classKey)
                              ? row.classKey
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.classDivision,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: activeClasses.isEmpty
                              ? []
                              : activeClasses
                                  .map((c) => DropdownMenuItem<String>(
                                        value: c.key,
                                        child: Text(
                                          c.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                          onChanged: (value) {
                            setState(() => row.classKey = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: row.pwcId != null &&
                                  row.pwcId != _kAddNewPwcValue &&
                                  _pwcs.any((p) => p.id == row.pwcId)
                              ? row.pwcId
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.selectPWC,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            ..._pwcs.map((p) => DropdownMenuItem<String>(
                                  value: p.id ?? '',
                                  child: Text(
                                    p.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                            DropdownMenuItem<String>(
                              value: _kAddNewPwcValue,
                              child: Row(
                                children: [
                                  Icon(Icons.add, size: 20, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(l10n.addPWC, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == _kAddNewPwcValue) {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => const PWCEditScreen(),
                                ),
                              );
                              if (mounted) {
                                if (result == true) _loadPWCs();
                                setState(() {}); // Rebuild so dropdown value stays row.pwcId, not sentinel
                              }
                              return;
                            }
                            setState(() => row.pwcId = value);
                          },
                        ),
                      ),
                      if (_classRows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              _classRows.removeAt(i);
                              if (_classRows.isEmpty) {
                                _classRows.add(_ClassRow());
                              }
                            });
                          },
                          tooltip: l10n.removeClassEntry,
                        ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _classRows.add(_ClassRow()));
              },
              icon: const Icon(Icons.add, size: 20),
              label: Text(l10n.addClassEntry),
            ),
            const SizedBox(height: 24),

            // IHRA membership: add purchase if user doesn't have valid membership
            if (!hasValidIhra) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.validIhraMembershipDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _purchaseIhraMembership,
                      onChanged: (value) {
                        setState(() => _purchaseIhraMembership = value ?? false);
                      },
                      title: Text(
                        l10n.purchaseIhraMembershipWithRegistration,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ],
      ),
    );
  }

  static const double _spectatorSingleDayPrice = 30.0;
  static const double _spectatorWeekendPrice = 40.0;

  /// Spectator day passes step (before checkout): $30 single day, $40 weekend.
  Widget _buildStep2DayPasses() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.spectatorDayPasses,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.spectatorDayPassesDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        // Single day pass — $30
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.spectatorSingleDayPass,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton.filled(
              onPressed: _spectatorSingleDayPasses > 0
                  ? () => setState(() => _spectatorSingleDayPasses--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$_spectatorSingleDayPasses',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton.filled(
              onPressed: () => setState(() => _spectatorSingleDayPasses++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Weekend pass — $40
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.spectatorWeekendPass,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton.filled(
              onPressed: _spectatorWeekendPasses > 0
                  ? () => setState(() => _spectatorWeekendPasses--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$_spectatorWeekendPasses',
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton.filled(
              onPressed: () => setState(() => _spectatorWeekendPasses++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    // This step will navigate to waiver screens
    // For now, show a message and auto-navigate
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/waiver-overview');
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.proceedingToWaiver,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    // Payment step - placeholder for now
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.paymentStep,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.paymentStepDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                child: Text(l10n.previous),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                switch (_currentStep) {
                  case 0:
                    _saveStep1();
                    break;
                  case 1:
                    // Waiver step auto-navigates; button not normally visible
                    break;
                  case 2:
                    _saveStep2DayPasses();
                    break;
                  case 3:
                    // Checkout is a separate screen; step 3 not used
                    break;
                }
              },
              child: Text(
                _currentStep == 0
                    ? l10n.next
                    : _currentStep == 1
                        ? l10n.continueToWaiver
                        : _currentStep == 2
                            ? l10n.next
                            : l10n.completePayment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

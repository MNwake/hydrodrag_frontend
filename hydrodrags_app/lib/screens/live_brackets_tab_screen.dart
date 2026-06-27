import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../models/event_registration_list_item.dart';
import '../models/matchup.dart';
import '../models/round.dart';
import '../models/speed_ranking.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/error_handler_service.dart';
import '../services/event_websocket_service.dart';
import '../utils/app_log.dart';
import '../widgets/bracket_column.dart';

/// A class option for the dropdown (event's racing class).
class _ClassOption {
  const _ClassOption({required this.classKey, required this.displayName});

  final String classKey;
  final String displayName;
}

class _UnscoredRacer {
  const _UnscoredRacer({required this.registrationId, required this.racerName});

  final String registrationId;
  final String racerName;
}

class LiveBracketsTabScreen extends StatefulWidget {
  const LiveBracketsTabScreen({super.key, this.isTabSelected = false});

  /// True when the Results tab is the currently selected tab in main navigation.
  /// Used to connect/disconnect the event WebSocket when the user switches to this tab.
  final bool isTabSelected;

  @override
  State<LiveBracketsTabScreen> createState() => _LiveBracketsTabScreenState();
}

class _LiveBracketsTabScreenState extends State<LiveBracketsTabScreen> {
  List<Event> _events = [];
  Event? _selectedEvent;
  String? _selectedClassKey;
  List<RoundBase> _rounds = [];
  SpeedSession? _speedSession;
  Map<String, List<EventRegistrationListItem>> _registrationsByClass = {};
  Map<String, List<_UnscoredRacer>> _wsUnscoredByClass = {};
  /// Latest connect snapshot; applied when class is selected after connect.
  Map<String, dynamic>? _pendingEventSnapshot;
  /// Live countdown for top-speed session; synced from API on refresh.
  int? _displayRemainingSeconds;
  Timer? _countdownTimer;
  EventWebSocketService? _eventWsService;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  /// Event id we're currently connected to; avoid disconnect/reconnect when same event.
  String? _connectedEventId;
  bool _isLoadingEvents = true;
  bool _isLoadingBrackets = false;
  bool _isLoadingRegistrations = false;
  String? _error;

  List<_ClassOption> get _classOptions {
    final event = _selectedEvent;
    if (event == null || event.classes.isEmpty) return [];
    return event.classes
        .map((c) => _ClassOption(classKey: c.key, displayName: c.name))
        .toList();
  }

  /// Split rounds by matchup.bracket: "W" → Winners, "L" → Losers.
  /// Each API round can contain both W and L matchups, so we split per matchup
  /// and group by round_number so Losers Bracket is a separate section below.
  List<RoundBase> get _winnersRounds {
    final byRound = <int, List<MatchupBase>>{};
    final roundTemplate = <int, RoundBase>{};
    for (final r in _rounds) {
      roundTemplate[r.roundNumber] ??= r;
      for (final m in r.matchups) {
        if (m.bracket.toUpperCase() != 'W') continue;
        byRound.putIfAbsent(r.roundNumber, () => []).add(m);
      }
    }
    return byRound.keys
        .map((roundNum) {
          final t = roundTemplate[roundNum]!;
          return RoundBase(
            id: '${t.id}_w',
            eventId: t.eventId,
            classKey: t.classKey,
            roundNumber: roundNum,
            matchups: byRound[roundNum]!,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            isComplete: t.isComplete,
          );
        })
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
  }

  /// Championship (grand finals): bracket "C" — head-to-head until someone has two losses.
  List<RoundBase> get _championshipRounds {
    final byRound = <int, List<MatchupBase>>{};
    final roundTemplate = <int, RoundBase>{};
    for (final r in _rounds) {
      roundTemplate[r.roundNumber] ??= r;
      for (final m in r.matchups) {
        if (m.bracket.toUpperCase() != 'C') continue;
        byRound.putIfAbsent(r.roundNumber, () => []).add(m);
      }
    }
    return byRound.keys
        .map((roundNum) {
          final t = roundTemplate[roundNum]!;
          return RoundBase(
            id: '${t.id}_c',
            eventId: t.eventId,
            classKey: t.classKey,
            roundNumber: roundNum,
            matchups: byRound[roundNum]!,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            isComplete: t.isComplete,
          );
        })
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
  }

  List<RoundBase> get _losersRounds {
    final byRound = <int, List<MatchupBase>>{};
    final roundTemplate = <int, RoundBase>{};
    for (final r in _rounds) {
      roundTemplate[r.roundNumber] ??= r;
      for (final m in r.matchups) {
        if (m.bracket.toUpperCase() != 'L') continue;
        byRound.putIfAbsent(r.roundNumber, () => []).add(m);
      }
    }
    return byRound.keys
        .map((roundNum) {
          final t = roundTemplate[roundNum]!;
          return RoundBase(
            id: '${t.id}_l',
            eventId: t.eventId,
            classKey: t.classKey,
            roundNumber: roundNum,
            matchups: byRound[roundNum]!,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            isComplete: t.isComplete,
          );
        })
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _disconnectEventWebSocket();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveBracketsTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only connect when user switches TO the Results tab. Do not disconnect when
    // they switch away — keep the connection so we still receive broadcasts and
    // the view is up to date when they return.
    if (widget.isTabSelected && !oldWidget.isTabSelected) {
      _connectEventWebSocket(forceReconnect: true);
    }
  }

  void _connectEventWebSocket({bool forceReconnect = false}) {
    if (!widget.isTabSelected) return;
    final event = _selectedEvent;
    if (event == null) return;
    if (!forceReconnect &&
        _connectedEventId == event.id &&
        _eventWsService != null) {
      return;
    }
    _disconnectEventWebSocket();
    _connectedEventId = event.id;
    final wsUrl = ApiConfig.eventWebSocketUrl(event.id);
    AppLog.debug('LiveBrackets', 'Connecting to event stream');
    _eventWsService = EventWebSocketService();
    _eventWsService!.connect(wsUrl);
    _wsSubscription = _eventWsService!.messages.listen(_onWsMessage);
  }

  void _disconnectEventWebSocket() {
    if (_eventWsService != null || _wsSubscription != null) {
      AppLog.debug('LiveBrackets', 'Disconnecting from event stream');
    }
    _connectedEventId = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _eventWsService?.disconnect();
    _eventWsService = null;
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    try {
      final type = msg['type'] as String?;
      final eventId = msg['event_id'] as String?;
      final classKey = msg['class_key'];
      final selectedId = _selectedEvent?.id;
      final selectedClass = _selectedClassKey;

      if (eventId != selectedId) {
        return;
      }
      if (type != 'brackets_update' && type != 'speed_session_update') {
        if (type == 'event_snapshot') {
          _applyEventSnapshot(msg);
        }
        return;
      }

      if (type == 'brackets_update') {
        if (selectedClass == null || classKey != selectedClass) {
          return;
        }
        final roundsList = msg['rounds'] as List<dynamic>? ?? [];
        AppLog.debug('LiveBrackets', 'Applying brackets update');
        setState(() {
          _rounds = roundsList
              .map((r) => RoundBase.fromJson(r as Map<String, dynamic>))
              .toList();
        });
      } else if (type == 'speed_session_update') {
        if (selectedClass == null || classKey != selectedClass) {
          return;
        }
        AppLog.debug('LiveBrackets', 'Applying speed session update');
        _applySpeedClassPayload(
          eventId: eventId!,
          classKey: classKey is String ? classKey as String : selectedClass!,
          payload: msg,
        );
      }
    } catch (e, st) {
      AppLog.error(
        'LiveBrackets',
        'Failed to process WebSocket message',
        error: e,
        stackTrace: st,
        recoverable: true,
      );
    }
  }

  void _applyEventSnapshot(Map<String, dynamic> msg) {
    AppLog.debug('LiveBrackets', 'Applying event snapshot');
    _pendingEventSnapshot = msg;
    _applyPendingSnapshotForSelectedClass();
  }

  List<_UnscoredRacer> _parseUnscoredList(List<dynamic> raw) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (entry) => _UnscoredRacer(
            registrationId: entry['registration_id'] as String? ?? '',
            racerName: entry['racer_name'] as String? ?? 'Racer',
          ),
        )
        .where((entry) => entry.registrationId.isNotEmpty)
        .toList();
  }

  void _applySpeedClassPayload({
    required String eventId,
    required String classKey,
    required Map<String, dynamic> payload,
  }) {
    final unscoredRaw = payload['unscored'] as List<dynamic>? ?? const [];
    final updated = SpeedSession.fromWebSocketUpdate(
      eventId,
      classKey,
      payload,
      existing: payload['reset'] == true ? null : _speedSession,
    );
    setState(() {
      if (unscoredRaw.isNotEmpty || payload.containsKey('unscored')) {
        _wsUnscoredByClass = {
          ..._wsUnscoredByClass,
          classKey: _parseUnscoredList(unscoredRaw),
        };
      }
      _speedSession = updated;
      if (updated.remainingSeconds != null) {
        _displayRemainingSeconds = updated.remainingSeconds;
      } else if (payload['reset'] == true) {
        _displayRemainingSeconds = updated.durationSeconds > 0
            ? updated.durationSeconds
            : null;
      }
      if (updated.isActive && updated.remainingSeconds != null) {
        _startCountdownTimer();
      } else {
        _stopCountdownTimer(clearDisplay: false);
      }
    });
  }

  void _applyPendingSnapshotForSelectedClass() {
    final snapshot = _pendingEventSnapshot;
    final selectedClass = _selectedClassKey;
    final eventId = _selectedEvent?.id ?? snapshot?['event_id'] as String?;
    if (snapshot == null || selectedClass == null || eventId == null) return;

    final speedSessions = snapshot['speed_sessions'] as List<dynamic>? ?? const [];
    final unscoredByClass = <String, List<_UnscoredRacer>>{};

    for (final raw in speedSessions) {
      if (raw is! Map<String, dynamic>) continue;
      final classKey = raw['class_key'] as String?;
      if (classKey == null || classKey.isEmpty) continue;
      final unscored = raw['unscored'] as List<dynamic>? ?? const [];
      unscoredByClass[classKey] = _parseUnscoredList(unscored);
    }

    Map<String, dynamic>? selectedSnapshot;
    for (final raw in speedSessions) {
      if (raw is Map<String, dynamic> && raw['class_key'] == selectedClass) {
        selectedSnapshot = raw;
        break;
      }
    }

    if (selectedSnapshot == null) return;

    setState(() {
      _wsUnscoredByClass = {..._wsUnscoredByClass, ...unscoredByClass};
    });
    _applySpeedClassPayload(
      eventId: eventId,
      classKey: selectedClass,
      payload: selectedSnapshot,
    );
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_displayRemainingSeconds != null && _displayRemainingSeconds! > 0) {
          _displayRemainingSeconds = _displayRemainingSeconds! - 1;
        }
      });
    });
  }

  void _stopCountdownTimer({bool clearDisplay = true}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (clearDisplay) {
      _displayRemainingSeconds = null;
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final events = await eventService.getEvents();

      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
          if (_selectedEvent == null && events.isNotEmpty) {
            final first = events.first;
            _selectedEvent = first;
            _selectedClassKey = first.classes.isNotEmpty ? first.classes.first.key : null;
            _loadResults(first, _selectedClassKey);
            _loadEventRegistrations(first.id);
          }
        });
        if (widget.isTabSelected) _connectEventWebSocket(forceReconnect: true);
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Events');
      if (mounted) {
        setState(() {
          _error = ErrorHandlerService.getErrorMessage(context, e);
          _isLoadingEvents = false;
        });
      }
    }
  }

  void _loadResults(Event? event, String? classKey) {
    if (event == null || classKey == null) return;
    if (event.isTopSpeed) {
      _loadSpeedRankings(event.id, classKey);
    } else {
      _loadBrackets(event.id, classKey);
    }
  }

  Future<void> _loadBrackets(String eventId, String? classKey) async {
    setState(() {
      _isLoadingBrackets = true;
      _error = null;
      _rounds = [];
      _speedSession = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final rounds = await eventService.getRounds(eventId, classKey: classKey);

      if (mounted) {
        setState(() {
          _rounds = rounds;
          _isLoadingBrackets = false;
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Brackets');
      if (mounted) {
        setState(() {
          _error = ErrorHandlerService.getErrorMessage(context, e);
          _isLoadingBrackets = false;
          _rounds = [];
        });
      }
    }
  }

  Future<void> _loadSpeedRankings(String eventId, String classKey) async {
    setState(() {
      _isLoadingBrackets = true;
      _error = null;
      _rounds = [];
      _speedSession = null;
      _stopCountdownTimer();
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final session = await eventService.getSpeedSession(eventId, classKey);

      if (mounted) {
        setState(() {
          _speedSession = session;
          _isLoadingBrackets = false;
          if (session != null &&
              session.isActive &&
              session.remainingSeconds != null) {
            _displayRemainingSeconds = session.remainingSeconds;
            _startCountdownTimer();
          } else {
            _stopCountdownTimer();
          }
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Speed Session');
      if (mounted) {
        setState(() {
          _error = ErrorHandlerService.getErrorMessage(context, e);
          _isLoadingBrackets = false;
        });
      }
    }
  }

  void _onEventSelected(Event? event) {
    if (event == null) return;
    _disconnectEventWebSocket();
    final firstClassKey = event.classes.isNotEmpty ? event.classes.first.key : null;
    setState(() {
      _selectedEvent = event;
      _selectedClassKey = firstClassKey;
      _registrationsByClass = {};
      _wsUnscoredByClass = {};
      _pendingEventSnapshot = null;
      _speedSession = null;
    });
    _loadResults(event, firstClassKey);
    _loadEventRegistrations(event.id);
    if (widget.isTabSelected) _connectEventWebSocket(forceReconnect: true);
  }

  Future<void> _loadEventRegistrations(String eventId) async {
    setState(() => _isLoadingRegistrations = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final registrations = await eventService.getEventRegistrations(eventId);
      if (!mounted) return;

      final byClass = <String, List<EventRegistrationListItem>>{};
      for (final reg in registrations) {
        byClass.putIfAbsent(reg.classKey, () => []).add(reg);
      }
      setState(() {
        _registrationsByClass = byClass;
        _isLoadingRegistrations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRegistrations = false);
    }
  }

  void _onClassSelected(_ClassOption? option) {
    if (option == null || _selectedEvent == null) return;
    setState(() => _selectedClassKey = option.classKey);
    _applyPendingSnapshotForSelectedClass();
    _loadResults(_selectedEvent, option.classKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoadingEvents
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rounds.isEmpty && _speedSession == null && !_isLoadingBrackets
              ? _buildError(theme)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEventAndClassFilters(theme),
                    if (_selectedEvent != null && _isLoadingBrackets)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_selectedEvent != null && _selectedEvent!.isTopSpeed)
                      Expanded(
                        child: _speedSession != null
                            ? _buildSpeedRankingsContent(theme, l10n)
                            : _buildEmptySpeedRankings(theme, l10n),
                      )
                    else if (_selectedEvent != null && _rounds.isEmpty && _error == null)
                      Expanded(
                        child: _buildEmptyBrackets(theme, l10n),
                      )
                    else if (_selectedEvent != null && _rounds.isNotEmpty)
                      Expanded(
                        child: ClipRect(
                          child: _buildBracketContent(theme, l10n),
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Text(
                            l10n?.noResultsAvailable ?? 'No results available yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _filterChip({
    required ThemeData theme,
    required String label,
    required VoidCallback? onTap,
  }) {
    final interactive = onTap != null;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: interactive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (interactive) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEventPicker(ThemeData theme) async {
    final picked = await showModalBottomSheet<Event>(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select event',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final selected = _selectedEvent?.id == event.id;
                  return ListTile(
                    title: Text(event.name),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                        : null,
                    selected: selected,
                    onTap: () => Navigator.pop(ctx, event),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) _onEventSelected(picked);
  }

  Future<void> _showClassPicker(ThemeData theme) async {
    final options = _classOptions;
    if (options.length <= 1) return;

    final picked = await showModalBottomSheet<_ClassOption>(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.55;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Select class',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final option in options)
                        ListTile(
                          title: Text(option.displayName),
                          trailing: option.classKey == _selectedClassKey
                              ? Icon(
                                  Icons.check_rounded,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          selected: option.classKey == _selectedClassKey,
                          onTap: () => Navigator.pop(ctx, option),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) _onClassSelected(picked);
  }

  Widget _buildEventAndClassFilters(ThemeData theme) {
    final options = _classOptions;
    final selectedClass = options.isEmpty
        ? null
        : options.any((o) => o.classKey == _selectedClassKey)
            ? options.firstWhere((o) => o.classKey == _selectedClassKey)
            : options.first;

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _filterChip(
                theme: theme,
                label: _selectedEvent?.name ?? 'Select event',
                onTap: _events.isEmpty ? null : () => _showEventPicker(theme),
              ),
            ),
            if (_selectedEvent != null && selectedClass != null) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _filterChip(
                  theme: theme,
                  label: selectedClass.displayName,
                  onTap: options.length > 1 ? () => _showClassPicker(theme) : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadEvents,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBrackets(ThemeData theme, AppLocalizations? l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noBracketsAvailable ?? 'No brackets available yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.noBracketsAvailableDescription ??
                  'Brackets will appear when the tournament is started.',
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

  Map<String, String> get _pwcByRegistrationId {
    final classKey = _selectedClassKey ?? '';
    final regs = _registrationsByClass[classKey] ?? const <EventRegistrationListItem>[];
    return {
      for (final reg in regs)
        if (reg.pwcIdentifier.trim().isNotEmpty) reg.id: reg.pwcIdentifier.trim(),
    };
  }

  Widget _buildBracketContent(ThemeData theme, AppLocalizations? l10n) {
    final pwcLookup = _pwcByRegistrationId;

    return BracketZoomableView(
      scrollHeader: const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: DoubleEliminationBracketHeader(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_winnersRounds.isNotEmpty)
              BracketColumn(
                rounds: _winnersRounds,
                title: "Winner's Bracket",
                isLosers: false,
                pwcByRegistrationId: pwcLookup,
              ),
            if (_winnersRounds.isNotEmpty && _losersRounds.isNotEmpty)
              const SizedBox(height: 16),
            if (_losersRounds.isNotEmpty)
              BracketColumn(
                rounds: _losersRounds,
                title: "Loser's Bracket",
                isLosers: true,
                pwcByRegistrationId: pwcLookup,
              ),
            if (_championshipRounds.isNotEmpty) ...[
              const SizedBox(height: 16),
              BracketColumn(
                rounds: _championshipRounds,
                title: 'Championship',
                isLosers: false,
                pwcByRegistrationId: pwcLookup,
              ),
            ],
            const DoubleEliminationBracketFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedRankingsContent(ThemeData theme, AppLocalizations? l10n) {
    final session = _speedSession!;
    final rankings = session.rankings;
    final eventId = _selectedEvent!.id;
    final classKey = _selectedClassKey ?? '';
    final classRegistrations = _registrationsByClass[classKey] ?? const <EventRegistrationListItem>[];
    final wsUnscored = _wsUnscoredByClass[classKey] ?? const <_UnscoredRacer>[];
    final registrationNameById = <String, String>{
      for (final reg in classRegistrations)
        reg.id: reg.racerModel?.fullName ?? 'Racer',
      for (final entry in wsUnscored) entry.registrationId: entry.racerName,
    };
    final registrationPwcById = <String, String>{
      for (final reg in classRegistrations)
        if (reg.pwcIdentifier.trim().isNotEmpty) reg.id: reg.pwcIdentifier.trim(),
    };
    final scoredIds = rankings.map((r) => r.registrationId).toSet();
    final unscoredRegistrations = classRegistrations.where((r) => !scoredIds.contains(r.id)).toList();
    final unscoredFallback = wsUnscored.where((u) => !scoredIds.contains(u.registrationId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n?.topSpeedRankings ?? 'Top speed',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (session.remainingSeconds != null || session.isActive || session.isStopped)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildSessionStatus(theme, session, l10n),
          ),
        Expanded(
          child: rankings.isEmpty
              ? _buildEmptySpeedRankings(theme, l10n)
              : RefreshIndicator(
                  onRefresh: () async => _loadSpeedRankings(eventId, classKey),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rankings.length + (unscoredRegistrations.isNotEmpty ? unscoredRegistrations.length : unscoredFallback.length),
              itemBuilder: (context, index) {
                final isScored = index < rankings.length;
                final item = isScored ? rankings[index] : null;
                final unscored = isScored
                    ? null
                    : (unscoredRegistrations.isNotEmpty
                        ? unscoredRegistrations[index - rankings.length]
                        : null);
                final unscoredWs = isScored
                    ? null
                    : (unscoredRegistrations.isEmpty
                        ? unscoredFallback[index - rankings.length]
                        : null);
                final displayName = isScored
                    ? ((item!.racerName?.trim().isNotEmpty == true)
                        ? item.racerName!
                        : (registrationNameById[item.registrationId] ?? item.displayName))
                    : (unscored?.racerModel?.fullName ?? unscoredWs?.racerName ?? 'Racer');
                final pwcLabel = isScored
                    ? (item!.pwcIdentifier.trim().isNotEmpty
                        ? item.pwcIdentifier.trim()
                        : (registrationPwcById[item.registrationId] ?? '—'))
                    : (unscored?.pwcIdentifier.trim().isNotEmpty == true
                        ? unscored!.pwcIdentifier.trim()
                        : '—');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            pwcLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: isScored && item!.place == 1
                        ? Text(
                            l10n?.topSpeedLeader ?? 'Fastest',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : !isScored
                            ? Text(
                                'Awaiting first run',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                        : null,
                    trailing: Text(
                      isScored ? '${item!.topSpeed.toStringAsFixed(1)} mph' : '--',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
                ),
              ),
      ],
    );
  }

  Widget _buildSessionStatus(
    ThemeData theme,
    SpeedSession session,
    AppLocalizations? l10n,
  ) {
    String status;
    if (session.isStopped) {
      status = l10n?.speedSessionEnded ?? 'Session ended';
    } else if (session.isPaused) {
      final secs = _displayRemainingSeconds ?? session.remainingSeconds;
      if (secs != null) {
        final mins = secs ~/ 60;
        final s = secs % 60;
        status = 'Session paused: $mins:${s.toString().padLeft(2, '0')} remaining';
      } else {
        status = 'Session paused';
      }
    } else if (session.isActive) {
      final secs = _displayRemainingSeconds ?? session.remainingSeconds;
      if (secs != null) {
        final mins = secs ~/ 60;
        final s = secs % 60;
        final timeStr = '$mins:${s.toString().padLeft(2, '0')}';
        status = '${l10n?.speedSessionRemaining ?? 'Time remaining'}: $timeStr';
      } else {
        status = l10n?.speedSessionActive ?? 'Session in progress';
      }
    } else if (session.startedAt == null) {
      status = l10n?.speedSessionNotStarted ?? 'Session not started';
    } else {
      status = l10n?.speedSessionActive ?? 'Session in progress';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            session.isStopped
                ? Icons.check_circle_outline
                : session.isPaused
                    ? Icons.pause_circle_outline
                : session.isActive
                    ? Icons.timer_outlined
                    : Icons.schedule_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySpeedRankings(ThemeData theme, AppLocalizations? l10n) {
    final classKey = _selectedClassKey ?? '';
    final classRegistrations = _registrationsByClass[classKey] ?? const <EventRegistrationListItem>[];
    final wsUnscored = _wsUnscoredByClass[classKey] ?? const <_UnscoredRacer>[];
    final showNamesFromWs = classRegistrations.isEmpty && wsUnscored.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.speed_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noSpeedRankingsYet ?? 'No speed results yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.noSpeedRankingsDescription ??
                  'Top speeds will appear here as they are recorded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_isLoadingRegistrations) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(strokeWidth: 2),
            ] else if (classRegistrations.isNotEmpty || showNamesFromWs) ...[
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: showNamesFromWs ? wsUnscored.length : classRegistrations.length,
                  itemBuilder: (context, index) {
                    final name = showNamesFromWs
                        ? wsUnscored[index].racerName
                        : (classRegistrations[index].racerModel?.fullName ?? 'Racer');
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline),
                      title: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '--',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

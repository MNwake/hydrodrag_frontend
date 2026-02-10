import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../models/matchup.dart';
import '../models/round.dart';
import '../models/speed_ranking.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/error_handler_service.dart';
import '../widgets/bracket_column.dart';
import '../widgets/language_toggle.dart';

/// A class option for the dropdown (event's racing class).
class _ClassOption {
  const _ClassOption({required this.classKey, required this.displayName});

  final String classKey;
  final String displayName;
}

class LiveBracketsTabScreen extends StatefulWidget {
  const LiveBracketsTabScreen({super.key});

  @override
  State<LiveBracketsTabScreen> createState() => _LiveBracketsTabScreenState();
}

class _LiveBracketsTabScreenState extends State<LiveBracketsTabScreen> {
  List<Event> _events = [];
  Event? _selectedEvent;
  String? _selectedClassKey;
  List<RoundBase> _rounds = [];
  SpeedSession? _speedSession;
  bool _isLoadingEvents = true;
  bool _isLoadingBrackets = false;
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
          }
        });
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
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final session = await eventService.getSpeedSession(eventId, classKey);

      if (mounted) {
        setState(() {
          _speedSession = session;
          _isLoadingBrackets = false;
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
    final firstClassKey = event.classes.isNotEmpty ? event.classes.first.key : null;
    setState(() {
      _selectedEvent = event;
      _selectedClassKey = firstClassKey;
    });
    _loadResults(event, firstClassKey);
  }

  void _onClassSelected(_ClassOption? option) {
    if (option == null || _selectedEvent == null) return;
    setState(() => _selectedClassKey = option.classKey);
    _loadResults(_selectedEvent, option.classKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.resultsTab ?? 'Results'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoadingEvents
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rounds.isEmpty && _speedSession == null && !_isLoadingBrackets
              ? _buildError(theme)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEventSelector(theme),
                    if (_selectedEvent != null) _buildClassSelector(theme),
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
                        child: _buildBracketContent(theme, l10n),
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
    );
  }

  Widget _buildEventSelector(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Text(
              'Event:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<Event>(
                value: _selectedEvent,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _events
                    .map((e) => DropdownMenuItem<Event>(
                          value: e,
                          child: Text(
                            e.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ))
                    .toList(),
                onChanged: (Event? value) => _onEventSelected(value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelector(ThemeData theme) {
    final options = _classOptions;
    if (options.isEmpty) return const SizedBox.shrink();

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Text(
              'Class:',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<_ClassOption>(
                value: options.any((o) => o.classKey == _selectedClassKey)
                    ? options.firstWhere((o) => o.classKey == _selectedClassKey)
                    : options.first,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: options
                    .map((o) => DropdownMenuItem<_ClassOption>(
                          value: o,
                          child: Text(
                            o.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ))
                    .toList(),
                onChanged: options.length > 1 ? _onClassSelected : null,
              ),
            ),
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

  Widget _buildBracketContent(ThemeData theme, AppLocalizations? l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_winnersRounds.isNotEmpty)
            BracketColumn(
              rounds: _winnersRounds,
              title: 'Winners Bracket',
              isLosers: false,
            ),
          if (_winnersRounds.isNotEmpty && _losersRounds.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(
              color: theme.colorScheme.outline.withOpacity(0.5),
              thickness: 1.5,
              indent: 0,
              endIndent: 0,
            ),
            const SizedBox(height: 24),
            BracketColumn(
              rounds: _losersRounds,
              title: 'Losers Bracket',
              isLosers: true,
            ),
          ] else if (_losersRounds.isNotEmpty)
            BracketColumn(
              rounds: _losersRounds,
              title: 'Losers Bracket',
              isLosers: true,
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedRankingsContent(ThemeData theme, AppLocalizations? l10n) {
    final session = _speedSession!;
    final rankings = session.rankings;
    final eventId = _selectedEvent!.id;
    final classKey = _selectedClassKey ?? '';

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
                    itemCount: rankings.length,
              itemBuilder: (context, index) {
                final item = rankings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${item.place}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      item.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item.place == 1
                        ? Text(
                            l10n?.topSpeedLeader ?? 'Fastest',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                    trailing: Text(
                      '${item.topSpeed.toStringAsFixed(1)} mph',
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
    } else if (session.isActive && session.remainingSeconds != null) {
      final secs = session.remainingSeconds!;
      final mins = secs ~/ 60;
      final s = secs % 60;
      final timeStr = '$mins:${s.toString().padLeft(2, '0')}';
      status = '${l10n?.speedSessionRemaining ?? 'Time remaining'}: $timeStr';
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
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/language_toggle.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../services/error_handler_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'event_detail_screen.dart';

enum _EventsFilter { upcoming, past, all }

class EventsTabScreen extends StatefulWidget {
  const EventsTabScreen({super.key});

  @override
  State<EventsTabScreen> createState() => _EventsTabScreenState();
}

class _EventsTabScreenState extends State<EventsTabScreen> {
  List<Event> _upcomingEvents = [];
  List<Event> _pastEvents = [];
  bool _isLoading = true;
  String? _error;
  _EventsFilter _filter = _EventsFilter.all;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final upcoming = await eventService.getUpcomingEvents();
      final past = await eventService.getPastEvents();

      if (mounted) {
        setState(() {
          _upcomingEvents = upcoming;
          _pastEvents = past;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Events');
      if (mounted) {
        setState(() {
          _error = ErrorHandlerService.getErrorMessage(context, e);
          _isLoading = false;
        });
      }
    }
  }

  void _openEventDetails(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    );
  }

  void _openRegistration(Event event) {
    Navigator.of(context).pushNamed('/event-registration', arguments: event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadEvents)
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  edgeOffset: 16,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _FilterBar(
                            filter: _filter,
                            upcomingCount: _upcomingEvents.length,
                            pastCount: _pastEvents.length,
                            onChanged: (value) => setState(() => _filter = value),
                          ),
                        ),
                      ),
                      ..._buildEventSlivers(),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildEventSlivers() {
    if (_upcomingEvents.isEmpty && _pastEvents.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No events yet',
            subtitle: 'Check back soon for new races and speed alley sessions.',
          ),
        ),
      ];
    }

    final showUpcoming =
        _filter == _EventsFilter.upcoming || _filter == _EventsFilter.all;
    final showPast =
        _filter == _EventsFilter.past || _filter == _EventsFilter.all;

    final slivers = <Widget>[];

    if (showUpcoming) {
      slivers.add(
        _SectionHeader(
          icon: Icons.upcoming_outlined,
          title: 'Upcoming',
          count: _upcomingEvents.length,
        ),
      );
      if (_upcomingEvents.isEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: _InlineEmptyHint(
              message: 'No upcoming events posted yet.',
            ),
          ),
        );
      } else {
        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final event = _upcomingEvents[index];
                final isLoggedIn =
                    context.watch<AuthService>().isAuthenticated;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _EventCard(
                    event: event,
                    isPast: false,
                    onTap: () => _openEventDetails(event),
                    onRegister: event.isOpen
                        ? () {
                            if (isLoggedIn) {
                              _openRegistration(event);
                            } else {
                              _openEventDetails(event);
                            }
                          }
                        : null,
                  ),
                );
              },
              childCount: _upcomingEvents.length,
            ),
          ),
        );
      }
    }

    if (showPast) {
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(height: showUpcoming ? 8 : 0),
        ),
      );
      slivers.add(
        _SectionHeader(
          icon: Icons.history_rounded,
          title: 'Past',
          count: _pastEvents.length,
        ),
      );
      if (_pastEvents.isEmpty) {
        slivers.add(
          const SliverToBoxAdapter(
            child: _InlineEmptyHint(
              message: 'Completed events will appear here.',
            ),
          ),
        );
      } else {
        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _EventCard(
                  event: _pastEvents[index],
                  isPast: true,
                  onTap: () => _openEventDetails(_pastEvents[index]),
                ),
              ),
              childCount: _pastEvents.length,
            ),
          ),
        );
      }
    }

    return slivers;
  }
}

class _FilterBar extends StatelessWidget {
  final _EventsFilter filter;
  final int upcomingCount;
  final int pastCount;
  final ValueChanged<_EventsFilter> onChanged;

  const _FilterBar({
    required this.filter,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: filter == _EventsFilter.all,
            onTap: () => onChanged(_EventsFilter.all),
          ),
          _FilterChip(
            label: 'Upcoming',
            count: upcomingCount,
            selected: filter == _EventsFilter.upcoming,
            onTap: () => onChanged(_EventsFilter.upcoming),
          ),
          _FilterChip(
            label: 'Past',
            count: pastCount,
            selected: filter == _EventsFilter.past,
            onTap: () => onChanged(_EventsFilter.past),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppTheme.primaryColor
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryColor.withValues(alpha: 0.22)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppTheme.primaryColor
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isPast;
  final VoidCallback onTap;
  final VoidCallback? onRegister;

  const _EventCard({
    required this.event,
    required this.isPast,
    required this.onTap,
    this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLoggedIn = context.watch<AuthService>().isAuthenticated;
    final date = event.date.toLocal();
    final month = _monthAbbrev(date.month);
    final accent = isPast
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPast
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
                  : AppTheme.primaryColor.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isPast ? 0.12 : 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBadge(
                  month: month,
                  day: date.day,
                  accent: accent,
                  muted: isPast,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            event: event,
                            isPast: isPast,
                            closedLabel: l10n?.closed ?? 'Closed',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MetaRow(
                        icon: Icons.location_on_outlined,
                        label: event.location.shortDisplayString,
                      ),
                      const SizedBox(height: 6),
                      _MetaRow(
                        icon: Icons.calendar_month_outlined,
                        label: event.dateRange,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FormatChip(event: event),
                          if (!isPast && event.isOpen)
                            _ActionChip(
                              label: isLoggedIn
                                  ? (l10n?.register ?? 'Register')
                                  : (l10n?.open ?? 'Open'),
                              onTap: onRegister ?? onTap,
                              filled: true,
                            ),
                          _ActionChip(
                            label: 'Details',
                            onTap: onTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthAbbrev(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return months[month - 1];
  }
}

class _DateBadge extends StatelessWidget {
  final String month;
  final int day;
  final Color accent;
  final bool muted;

  const _DateBadge({
    required this.month,
    required this.day,
    required this.accent,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: muted
            ? theme.colorScheme.surfaceContainerHighest
            : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: muted
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
              : accent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(
            month,
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted ? theme.colorScheme.onSurfaceVariant : accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$day',
            style: theme.textTheme.titleLarge?.copyWith(
              color: muted ? theme.colorScheme.onSurface : accent,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Event event;
  final bool isPast;
  final String closedLabel;

  const _StatusBadge({
    required this.event,
    required this.isPast,
    required this.closedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final String label;
    late final Color bg;
    late final Color fg;

    if (isPast || event.eventStatus == EventStatus.completed) {
      label = 'Completed';
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    } else if (event.isOpen) {
      label = 'Open';
      bg = AppTheme.secondaryColor.withValues(alpha: 0.18);
      fg = AppTheme.secondaryColor;
    } else {
      label = closedLabel;
      bg = theme.colorScheme.errorContainer.withValues(alpha: 0.35);
      fg = theme.colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final Event event;

  const _FormatChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = event.isTopSpeed ? 'Top Speed' : 'Bracket Racing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionChip({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: filled
          ? AppTheme.primaryColor
          : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: filled
                ? null
                : Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.45),
                  ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: filled ? Colors.black : AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InlineEmptyHint extends StatelessWidget {
  final String message;

  const _InlineEmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Could not load events', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

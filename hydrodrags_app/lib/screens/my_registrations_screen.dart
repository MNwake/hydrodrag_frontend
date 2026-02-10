import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/my_registration.dart';
import '../services/auth_service.dart';
import '../services/racer_service.dart';

class MyRegistrationsScreen extends StatefulWidget {
  const MyRegistrationsScreen({super.key});

  @override
  State<MyRegistrationsScreen> createState() => _MyRegistrationsScreenState();
}

class _MyRegistrationsScreenState extends State<MyRegistrationsScreen> {
  List<MyRegistration> _registrations = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final racerService = RacerService(authService);
      final list = await racerService.getMyRegistrations();
      if (mounted) {
        setState(() {
          _registrations = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  /// Group registrations by event id for display.
  /// Returns entries sorted by event date (most recent first).
  List<MapEntry<String, List<MyRegistration>>> _groupByEvent() {
    final map = <String, List<MyRegistration>>{};
    for (final r in _registrations) {
      map.putIfAbsent(r.eventId, () => []).add(r);
    }
    final entries = map.entries.toList();
    entries.sort((a, b) {
      final dateA = a.value.first.eventDate;
      final dateB = b.value.first.eventDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return entries;
  }

  static final _dateFormat = DateFormat('EEE, MMM d, y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Registrations'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                          'Could not load registrations',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadRegistrations,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _registrations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No registrations yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When you register for events they will appear here.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRegistrations,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _buildGroupedList(theme),
                      ),
                    ),
    );
  }

  List<Widget> _buildGroupedList(ThemeData theme) {
    final entries = _groupByEvent();
    final widgets = <Widget>[];

    for (final entry in entries) {
      final regs = entry.value;
      final first = regs.first;
      final eventName = first.eventName ?? first.eventId;
      final eventDate = first.eventDate;
      final eventLocation = first.eventLocation;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              eventName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (eventDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _dateFormat.format(eventDate),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (eventLocation != null && eventLocation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                eventLocation,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: regs.asMap().entries.map((regEntry) {
                    final r = regEntry.value;
                    final isLast = regEntry.key == regs.length - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRegistrationTile(theme, r),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: theme.colorScheme.outlineVariant,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildRegistrationTile(ThemeData theme, MyRegistration r) {
    final subtitleParts = <String>[
      if (r.pwcIdentifier.isNotEmpty) 'PWC: ${r.pwcIdentifier}',
      if (r.losses > 0) 'Losses: ${r.losses}',
    ];
    if (r.payment != null) {
      final p = r.payment!;
      subtitleParts.add(p.isCaptured ? 'Paid' : 'Pending');
      if (p.spectatorSingleDayPasses > 0 || p.spectatorWeekendPasses > 0) {
        final passParts = <String>[];
        if (p.spectatorSingleDayPasses > 0) {
          passParts.add('${p.spectatorSingleDayPasses} day pass(es)');
        }
        if (p.spectatorWeekendPasses > 0) {
          passParts.add('${p.spectatorWeekendPasses} weekend pass(es)');
        }
        subtitleParts.add(passParts.join(', '));
      }
      if (p.purchaseIhraMembership) {
        subtitleParts.add('IHRA membership');
      }
    } else {
      subtitleParts.add(r.isPaid ? 'Paid' : 'Pending payment');
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: r.isPaid
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
        child: Icon(
          r.isPaid ? Icons.check_circle : Icons.pending,
          color: r.isPaid
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
          size: 24,
        ),
      ),
      title: Text(
        r.className.isNotEmpty ? r.className : r.classKey,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitleParts.join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: r.isPaid
          ? null
          : Chip(
              label: Text(
                '\$${r.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
    );
  }
}

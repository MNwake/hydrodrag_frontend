import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/waiver_session.dart';
import '../services/auth_service.dart';
import '../services/error_handler_service.dart';
import '../services/waiver_service.dart';
import '../waiver_capture/services/waiver_flow_router.dart';

/// Account settings entry point for signing or re-signing event waivers.
class EventWaiversScreen extends StatefulWidget {
  const EventWaiversScreen({super.key});

  @override
  State<EventWaiversScreen> createState() => _EventWaiversScreenState();
}

class _EventWaiversScreenState extends State<EventWaiversScreen> {
  List<EventManualWaiverItem> _events = [];
  bool _loading = true;
  Object? _error;
  String? _startingEventId;

  static final _dateFormat = DateFormat('EEE, MMM d, y');

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final events = await WaiverService(auth).listEligibleEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _startWaiver(EventManualWaiverItem item) async {
    setState(() => _startingEventId = item.eventId);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final waiverService = WaiverService(auth);
      await WaiverFlowRouter.navigateToNextStep(
        context: context,
        eventId: item.eventId,
        waiverService: waiverService,
        sessionId: item.activeSessionId,
        manualResign: true,
      );
      if (mounted) await _loadEvents();
    } catch (e) {
      if (mounted) ErrorHandlerService.showError(context, e);
    } finally {
      if (mounted) setState(() => _startingEventId = null);
    }
  }

  String _statusLabel(EventManualWaiverItem item) {
    if (item.hasInProgressSession) return 'In progress';
    if (item.hasSignedWaiver) return 'Signed';
    return 'Not signed';
  }

  Color _statusColor(EventManualWaiverItem item, ThemeData theme) {
    if (item.hasInProgressSession) return theme.colorScheme.tertiary;
    if (item.hasSignedWaiver) return Colors.green.shade700;
    return theme.colorScheme.error;
  }

  String _actionLabel(EventManualWaiverItem item) {
    if (item.hasInProgressSession) return 'Continue';
    if (item.hasSignedWaiver) return 'Sign new waiver';
    return 'Sign waiver';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Waivers'),
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
                          size: 56,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load events',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadEvents,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 56,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No open events',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You can sign a waiver here when you are registered for an event that has not finished yet.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEvents,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Text(
                              'Sign or update your waiver for upcoming events. If you need to submit a new waiver at the track, choose the event and tap Sign new waiver.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }

                          final item = _events[index - 1];
                          final isStarting = _startingEventId == item.eventId;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    item.eventName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dateFormat.format(item.eventStartDate),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        item.hasSignedWaiver
                                            ? Icons.verified_user
                                            : item.hasInProgressSession
                                                ? Icons.pending
                                                : Icons.warning_amber_rounded,
                                        size: 18,
                                        color: _statusColor(item, theme),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _statusLabel(item),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: _statusColor(item, theme),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: isStarting
                                        ? null
                                        : () => _startWaiver(item),
                                    child: isStarting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(_actionLabel(item)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

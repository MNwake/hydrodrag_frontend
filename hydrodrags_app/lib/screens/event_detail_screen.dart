import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import '../models/event.dart';
import '../models/event_registration_list_item.dart';
import '../models/racer_profile.dart';
import '../screens/racer_profile_detail_screen.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';
import '../services/racer_service.dart';
import '../services/error_handler_service.dart';
import '../services/image_cache_service.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> with SingleTickerProviderStateMixin {
  Event? _event; // Fresh data from API; null until loaded
  List<EventRegistrationListItem> _registrations = [];
  bool _isLoadingRacers = false;
  bool _racersLoaded = false;
  bool _isLoadingEvent = true;
  final ImageCacheService _imageCache = ImageCacheService();
  late TabController _tabController;
  /// Class keys that are collapsed in the Racers tab (default: all collapsed).
  final Set<String> _collapsedClassKeys = {};

  /// Current event to display: fresh from API when available, else the one passed in.
  Event get _currentEvent => _event ?? widget.event;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadEvent();
    _loadEventRegistrations();
  }

  Future<void> _loadEvent() async {
    final eventId = _currentEvent.id;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final updated = await eventService.getEvent(eventId);
      if (mounted) {
        setState(() {
          _event = updated;
          _isLoadingEvent = false;
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Event');
      if (mounted) {
        setState(() {
          _isLoadingEvent = false;
          // Keep _event null so we keep showing widget.event (initial data)
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadEventRegistrations() async {
    if (_racersLoaded) return;

    setState(() {
      _isLoadingRacers = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = EventService(authService);
      final list = await eventService.getEventRegistrations(_currentEvent.id);

      if (mounted) {
        setState(() {
          _registrations = list;
          _isLoadingRacers = false;
          _racersLoaded = true;
          // Default all class sections to collapsed (only on first load)
          if (_collapsedClassKeys.isEmpty && list.isNotEmpty) {
            for (final reg in list) {
              final key = reg.classKey.isNotEmpty ? reg.classKey : reg.className;
              _collapsedClassKeys.add(key);
            }
          }
        });
      }
    } catch (e) {
      ErrorHandlerService.logError(e, context: 'Load Event Registrations');
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        setState(() {
          _isLoadingRacers = false;
          _racersLoaded = true;
        });
        final isAuthenticated = authService.isAuthenticated;
        if (isAuthenticated) {
          ErrorHandlerService.showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          if (_isLoadingEvent)
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 12, bottom: 12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const LanguageToggle(isCompact: true),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _tabController.animateTo(3),
                    borderRadius: BorderRadius.circular(20),
                    child: Chip(
                      label: Text(
                        _currentEvent.isOpen ? 'Registration Open' : 'Registration Closed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      backgroundColor: _currentEvent.isOpen
                          ? Colors.green.withOpacity(0.8)
                          : Colors.red.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentEvent.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Tabs below banner
            Material(
              color: theme.colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                padding: const EdgeInsets.only(left: 0, right: 0, top: 0, bottom: 0),
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: 'Information', icon: Icon(Icons.info_outline, size: 20)),
                  Tab(text: 'Schedule', icon: Icon(Icons.schedule, size: 20)),
                  Tab(text: 'Rules', icon: Icon(Icons.rule, size: 20)),
                  Tab(text: 'Racers', icon: Icon(Icons.people, size: 20)),
                  Tab(text: 'Results', icon: Icon(Icons.emoji_events, size: 20)),
                ],
              ),
            ),
            // Tab content (scrolls with banner and tabs)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTabContent(context, _tabController.index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, int index) {
    switch (index) {
      case 0:
        return _buildInformationTabContent(context);
      case 1:
        return _buildScheduleTabContent(context);
      case 2:
        return _buildRulesTabContent(context);
      case 3:
        return _buildRacersTabContent(context);
      case 4:
        return _buildResultsTabContent(context);
      default:
        return _buildInformationTabContent(context);
    }
  }

  Widget _sectionLabel(ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Tab content builders (no scroll — parent SingleChildScrollView handles it)
  Widget _buildInformationTabContent(BuildContext context) {
    final theme = Theme.of(context);
    final classes = _currentEvent.classes.where((c) => c.isActive).toList();
    final loc = _currentEvent.location;
    final hasLocation = (loc.latitude != null && loc.longitude != null) ||
        (loc.displayString.isNotEmpty || loc.fullAddress != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location with inline "Open in Maps" icon
        _buildInfoBlockWithAction(
          context,
          icon: Icons.location_on,
          title: 'Location',
          content: loc.displayString.isNotEmpty
              ? loc.displayString
              : loc.shortDisplayString,
          actionIcon: hasLocation ? Icons.map_outlined : null,
          actionTooltip: hasLocation ? 'Open in Maps' : null,
          onAction: hasLocation ? () => _openEventInMaps(context) : null,
        ),
        // Date & Time with inline "Add to Calendar" icon
        _buildInfoBlockWithAction(
          context,
          icon: Icons.calendar_today,
          title: 'Date & Time',
          content: _currentEvent.dateRange,
          actionIcon: Icons.event_available_outlined,
          actionTooltip: 'Add to Calendar',
          onAction: () => _addEventToCalendar(context),
        ),
        if (_currentEvent.isOpen) ...[
          const SizedBox(height: 24),
          _buildPurchaseSpectatorTicketsSection(context),
        ],
        const SizedBox(height: 24),
        if (_currentEvent.description != null && _currentEvent.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionLabel(theme, Icons.description, 'Description'),
          Text(
            _currentEvent.description!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (classes.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildClassesSection(context, classes),
        ],
        const SizedBox(height: 24),
        _buildEventInfoSection(context, _currentEvent.eventInfo),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPurchaseSpectatorTicketsSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(
          theme,
          Icons.confirmation_number_outlined,
          l10n?.purchaseSpectatorTickets ?? 'Purchase event tickets',
        ),
        const SizedBox(height: 8),
        Text(
          l10n?.purchaseSpectatorTicketsDescription ??
              'Buy spectator tickets to attend the event. No racer registration required.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(
                '/spectator-purchase',
                arguments: _currentEvent,
              );
            },
            icon: const Icon(Icons.confirmation_number, size: 20),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n?.purchaseSpectatorTickets ?? 'Purchase spectator tickets',
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassesSection(BuildContext context, List<EventClass> classes) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final isOpen = _currentEvent.isOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, Icons.emoji_events, 'Racing Classes'),
        const SizedBox(height: 8),
        ...classes.asMap().entries.map((entry) {
          final c = entry.value;
          final isLast = entry.key == classes.length - 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '\$${c.price.toStringAsFixed(0)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (c.description != null && c.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  c.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!isLast) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 12),
              ],
            ],
          );
        }),
        if (authService.isAuthenticated && isOpen) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/event-registration',
                  arguments: _currentEvent,
                );
              },
              icon: const Icon(Icons.how_to_reg, size: 20),
              label: const Text('Register for This Event'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleTabContent(BuildContext context) {
    final ordered = _currentEvent.orderedSchedule;
    if (ordered.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.schedule_outlined,
        message: 'No schedule available for this event.',
      );
    }
    return _buildScheduleSection(context, ordered);
  }

  Widget _buildRulesTabContent(BuildContext context) {
    final theme = Theme.of(context);
    final rules = _currentEvent.rules;

    if (rules.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.rule_outlined,
        message: 'No rules available for this event.',
      );
    }

    // Group rules by category (header)
    final byCategory = <String, List<EventRule>>{};
    for (final rule in rules) {
      final key = rule.category.isEmpty ? 'Other' : rule.category;
      byCategory.putIfAbsent(key, () => []).add(rule);
    }
    final categoryOrder = byCategory.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, Icons.rule, 'Rules & Regulations'),
        const SizedBox(height: 12),
        ...categoryOrder.expand((category) {
          final items = byCategory[category]!;
          return [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                category,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ...items.asMap().entries.map((entry) {
              final rule = entry.value;
              final isLast = entry.key == items.length - 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!isLast)
                    const SizedBox(height: 12),
                ],
              );
            }),
            if (category != categoryOrder.last)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ),
          ];
        }),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRacersTabContent(BuildContext context) {
    return _buildRegistrationAndRacersSection(context);
  }

  Widget _buildResultsTabContent(BuildContext context) {
    return _buildResultsSection(context);
  }

  Widget _buildInfoBlock(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, icon, title),
        Text(
          content,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Info block with optional inline icon action on the same row as the section title.
  Widget _buildInfoBlockWithAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    IconData? actionIcon,
    String? actionTooltip,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (actionIcon != null && onAction != null)
                IconButton(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 22, color: theme.colorScheme.primary),
                  tooltip: actionTooltip,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        Text(
          content,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _openEventInMaps(BuildContext context) async {
    final loc = _currentEvent.location;
    Uri? uri;
    if (loc.latitude != null && loc.longitude != null) {
      if (Platform.isIOS) {
        uri = Uri.parse(
          'https://maps.apple.com/?ll=${loc.latitude},${loc.longitude}',
        );
      } else {
        uri = Uri.parse('geo:${loc.latitude},${loc.longitude}');
      }
    } else {
      final query = loc.fullAddress ?? loc.displayString;
      if (query.isEmpty) return;
      if (Platform.isIOS) {
        uri = Uri.parse(
          'https://maps.apple.com/?q=${Uri.encodeComponent(query)}',
        );
      } else {
        uri = Uri.parse(
          'geo:0,0?q=${Uri.encodeComponent(query)}',
        );
      }
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open maps: $e')),
      );
    }
  }

  Future<void> _addEventToCalendar(BuildContext context) async {
    if (kDebugMode) {
      print('[Add2Calendar] _addEventToCalendar called');
    }
    final event = _currentEvent;
    final start = event.startDate;
    final end = event.endDate ?? start.add(const Duration(hours: 1));
    final description = _buildCalendarEventDescription(event);
    final location = event.location.displayString;

    if (kDebugMode) {
      print('[Add2Calendar] Building event: title=${event.name}, start=$start, end=$end');
    }
    try {
      final calEvent = add2cal.Event(
        title: event.name,
        description: description,
        location: location.isNotEmpty ? location : null,
        startDate: start,
        endDate: end,
      );
      if (kDebugMode) {
        print('[Add2Calendar] Calling Add2Calendar.addEvent2Cal...');
      }
      await add2cal.Add2Calendar.addEvent2Cal(calEvent);
      if (kDebugMode) {
        print('[Add2Calendar] addEvent2Cal completed successfully');
      }
    } on MissingPluginException catch (e, stackTrace) {
      if (kDebugMode) {
        print('[Add2Calendar] MissingPluginException: ${e.message}');
        print('[Add2Calendar] StackTrace: $stackTrace');
      }
      // Native calendar not available (simulator, desktop, web) — do not open browser
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add to calendar is available on a physical device. Run the app on your phone to add events to your device calendar.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[Add2Calendar] Caught exception: $e');
        print('[Add2Calendar] Type: ${e.runtimeType}');
        print('[Add2Calendar] StackTrace: $stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to calendar: $e')),
      );
    }
  }

  String _buildCalendarEventDescription(Event event) {
    final parts = <String>[];
    if (event.description != null && event.description!.isNotEmpty) {
      parts.add(event.description!);
    }
    final info = event.eventInfo;
    if (info.parking != null && info.parking!.isNotEmpty) {
      parts.add('Parking: ${info.parking}');
    }
    if (info.tickets != null && info.tickets!.isNotEmpty) {
      parts.add('Tickets: ${info.tickets}');
    }
    if (info.foodAndDrink != null && info.foodAndDrink!.isNotEmpty) {
      parts.add('Food & Drink: ${info.foodAndDrink}');
    }
    if (info.seating != null && info.seating!.isNotEmpty) {
      parts.add('Seating: ${info.seating}');
    }
    if (event.location.displayString.isNotEmpty) {
      parts.add('Address: ${event.location.displayString}');
    }
    if (event.classes.isNotEmpty) {
      parts.add('Racing classes: ${event.classes.map((c) => c.name).join(', ')}');
    }
    if (info.additionalInfo != null && info.additionalInfo!.isNotEmpty) {
      for (final e in info.additionalInfo!.entries) {
        parts.add('${e.key}: ${e.value}');
      }
    }
    return parts.join('\n\n');
  }

  /// Groups schedule items by day (preserves order from orderedSchedule).
  List<MapEntry<String, List<EventScheduleItem>>> _groupScheduleByDay(List<EventScheduleItem> schedule) {
    if (schedule.isEmpty) return [];
    final groups = <String, List<EventScheduleItem>>{};
    final dayOrder = <String>[];
    for (final item in schedule) {
      final day = item.day.isEmpty ? 'Day' : item.day;
      if (!groups.containsKey(day)) {
        dayOrder.add(day);
        groups[day] = [];
      }
      groups[day]!.add(item);
    }
    return dayOrder.map((day) => MapEntry(day, groups[day]!)).toList();
  }

  Widget _buildScheduleSection(BuildContext context, List<EventScheduleItem> schedule) {
    final theme = Theme.of(context);
    final byDay = _groupScheduleByDay(schedule);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, Icons.schedule, 'Race Schedule'),
        const SizedBox(height: 16),
        ...byDay.map((entry) {
          final day = entry.key;
          final items = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header (once per day)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  day,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              // Items for this day (time + description only)
              ...items.asMap().entries.map((itemEntry) {
                final item = itemEntry.value;
                final isLast = itemEntry.key == items.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 40,
                        child: Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withOpacity(0.8),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildScheduleItemRow(
                            context,
                            item.description,
                            item.startTime,
                            item.endTime,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildScheduleItemRow(
    BuildContext context,
    String description,
    DateTime? startTime,
    DateTime? endTime,
  ) {
    final theme = Theme.of(context);
    String timeText = '';
    if (startTime != null) {
      timeText = _formatTime(startTime);
      if (endTime != null) {
        timeText += ' - ${_formatTime(endTime)}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timeText.isNotEmpty) ...[
            Text(
              timeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildEventInfoSection(BuildContext context, EventInfo eventInfo) {
    final theme = Theme.of(context);
    final hasInfo = eventInfo.parking != null ||
        eventInfo.tickets != null ||
        eventInfo.foodAndDrink != null ||
        eventInfo.seating != null ||
        (eventInfo.additionalInfo != null && eventInfo.additionalInfo!.isNotEmpty);

    if (!hasInfo) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, Icons.info_outline, 'Event Information'),
        const SizedBox(height: 8),
        if (eventInfo.parking != null)
          _buildInfoRow(context, 'Spectator Parking', eventInfo.parking!),
        if (eventInfo.tickets != null)
          _buildInfoRow(context, 'Tickets', eventInfo.tickets!),
        if (eventInfo.foodAndDrink != null)
          _buildInfoRow(context, 'Food & Drink', eventInfo.foodAndDrink!),
        if (eventInfo.seating != null)
          _buildInfoRow(context, 'Seating', eventInfo.seating!),
        if (eventInfo.additionalInfo != null)
          ...eventInfo.additionalInfo!.entries.map((e) =>
              _buildInfoRow(context, e.key, e.value)),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationAndRacersSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context);
    final isAuthenticated = authService.isAuthenticated;
    final isOpen = _currentEvent.isOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top: Register for This Event button (green like banner)
        if (isAuthenticated && isOpen) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/event-registration',
                  arguments: _currentEvent,
                );
              },
              icon: const Icon(Icons.how_to_reg, size: 20),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Register for This Event'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Subheading: Registered Racers + total count
        Row(
          children: [
            Expanded(
              child: _sectionLabel(theme, Icons.people, l10n?.registeredRacers ?? 'Registered Racers'),
            ),
            if (_registrations.isNotEmpty)
              Text(
                '${_registrations.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingRacers)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_registrations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n?.noRacersRegistered ?? 'No racers registered yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          _buildRegistrationsByClass(theme),
      ],
    );
  }

  Widget _buildResultsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, Icons.emoji_events, 'Results'),
        const SizedBox(height: 8),
        Text(
          'Results will be posted after the event concludes.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }


  /// Groups registrations by class_key and builds sections with class header + racer list.
  Widget _buildRegistrationsByClass(ThemeData theme) {
    final byClass = <String, List<EventRegistrationListItem>>{};
    for (final reg in _registrations) {
      final key = reg.classKey.isNotEmpty ? reg.classKey : reg.className;
      byClass.putIfAbsent(key, () => []).add(reg);
    }
    final List<String> classOrder;
    if (_currentEvent.classes.isEmpty) {
      classOrder = byClass.keys.toList()..sort();
    } else {
      classOrder = _currentEvent.classes
          .map((c) => c.key)
          .where(byClass.containsKey)
          .toList();
      classOrder.addAll(
          byClass.keys.where((k) => !_currentEvent.classes.any((c) => c.key == k)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final classKey in classOrder) ...[
          InkWell(
            onTap: () {
              setState(() {
                if (_collapsedClassKeys.contains(classKey)) {
                  _collapsedClassKeys.remove(classKey);
                } else {
                  _collapsedClassKeys.add(classKey);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _collapsedClassKeys.contains(classKey)
                        ? Icons.expand_more
                        : Icons.expand_less,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                  Icon(Icons.emoji_events, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      byClass[classKey]!.first.className.isNotEmpty
                          ? byClass[classKey]!.first.className
                          : classKey,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '(${byClass[classKey]!.length})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_collapsedClassKeys.contains(classKey))
            ...(byClass[classKey]!.asMap().entries.map((entry) {
              final index = entry.key;
              final reg = entry.value;
              return Column(
                children: [
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
                    ),
                  _buildRegistrationListItem(context, reg),
                ],
              );
            })),
        ],
      ],
    );
  }

  Widget _buildRegistrationListItem(BuildContext context, EventRegistrationListItem reg) {
    final theme = Theme.of(context);
    final racer = reg.racerModel;
    final displayName = racer?.fullName ?? 'Racer';
    final initials = racer != null && racer.firstName.isNotEmpty
        ? racer.firstName[0].toUpperCase()
        : 'R';
    final profileImageUrl = racer?.profileImageUrl;
    final racerId = reg.racer.isNotEmpty ? reg.racer : (racer?.id ?? '');

    return InkWell(
      onTap: racerId.isEmpty
          ? null
          : () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final racerService = RacerService(authService);
              final profile = await racerService.getRacerById(racerId);
              if (!context.mounted) return;
              if (profile != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => RacerProfileDetailScreen(racer: profile),
                  ),
                );
              }
            },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            FutureBuilder<File?>(
              future: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? _imageCache.getCachedImage(profileImageUrl, updatedAt: null)
                  : Future.value(null),
              builder: (context, snapshot) {
                return CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: snapshot.hasData && snapshot.data != null
                      ? FileImage(snapshot.data!)
                      : null,
                  child: snapshot.data == null
                      ? Text(
                          initials,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (reg.isEliminated)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Eliminated',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (reg.pwcIdentifier.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.water,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reg.pwcIdentifier,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (racerId.isNotEmpty)
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

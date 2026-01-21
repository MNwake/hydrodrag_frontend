import 'package:flutter/material.dart';
import '../widgets/language_toggle.dart';
import '../models/event.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  // TODO: Replace with actual data from backend
  List<Event> get _events => [
        Event(
          id: '1',
          name: 'Summer Championship 2024',
          location: 'Lake Tahoe, CA',
          date: DateTime(2024, 7, 15),
          registrationStatus: EventRegistrationStatus.open,
        ),
        Event(
          id: '2',
          name: 'Fall Classic',
          location: 'Lake Havasu, AZ',
          date: DateTime(2024, 9, 20),
          registrationStatus: EventRegistrationStatus.open,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Events'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: _events.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No events available',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/event-registration',
                        arguments: event,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.name,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  event.isOpen ? 'Open' : 'Closed',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: event.isOpen
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.errorContainer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(event.location, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${event.date.month}/${event.date.day}/${event.date.year}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          if (event.isOpen) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    '/event-registration',
                                    arguments: event,
                                  );
                                },
                                child: const Text('Register for Event'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
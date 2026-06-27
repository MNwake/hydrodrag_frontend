import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';
import '../config/api_config.dart';
import '../models/event.dart';
import '../utils/app_log.dart';
import '../models/event_registration_list_item.dart';
import '../models/event_result.dart';
import '../models/round.dart';
import '../models/speed_ranking.dart';
import 'auth_service.dart';

/// Service for managing event data and API interactions
class EventService {
  final AuthService _authService;

  EventService(this._authService);

  /// Get authorization headers with bearer token (optional for public endpoints)
  Map<String, String>? _getAuthHeaders({bool required = false}) {
    final token = _authService.accessToken;
    if (token == null) {
      if (required) {
        throw Exception('No access token available');
      }
      return null;
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get all events
  /// GET /events
  Future<List<Event>> getEvents() async {
    return getUpcomingEvents();
  }

  /// Get upcoming posted events.
  Future<List<Event>> getUpcomingEvents() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/events');

      final response = await LoggedHttp.get(uri);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> eventsJson = responseBody['events'] ?? responseBody;
        final events = eventsJson
            .map((json) => Event.fromJson(json as Map<String, dynamic>))
            .toList();
        final total = responseBody is Map ? responseBody['total'] as int? : null;
        final statuses = events.map((e) => e.eventStatus.name).join(', ');
        AppLog.debug(
          'EventService',
          'GET /events returned ${events.length} upcoming'
          '${total != null ? ' (backend total=$total)' : ''}'
          '${statuses.isNotEmpty ? ' [statuses: $statuses]' : ''}',
          terminal: true,
        );
        return events;
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e, stack) {
      AppLog.error('EventService', 'Failed to fetch events', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Get completed events for historical browsing.
  Future<List<Event>> getPastEvents() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/events/past');
      final response = await LoggedHttp.get(uri);
      if (response.statusCode != 200) {
        return [];
      }
      final responseBody = jsonDecode(response.body);
      final List<dynamic> eventsJson = responseBody['events'] ?? responseBody;
      final events = eventsJson
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();
      final total = responseBody is Map ? responseBody['total'] as int? : null;
      final statuses = events.map((e) => e.eventStatus.name).join(', ');
      AppLog.debug(
        'EventService',
        'GET /events/past returned ${events.length} past'
        '${total != null ? ' (backend total=$total)' : ''}'
        '${statuses.isNotEmpty ? ' [statuses: $statuses]' : ''}',
        terminal: true,
      );
      return events;
    } catch (_) {
      return [];
    }
  }

  /// Get a single event by ID
  /// GET /events/{event_id}
  Future<Event?> getEvent(String eventId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/events/$eventId');

      final response = await LoggedHttp.get(uri);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final eventJson = responseBody['event'] ?? responseBody;
        final event = Event.fromJson(eventJson as Map<String, dynamic>);
        return event;
      } else {
        return null;
      }
    } catch (e, stack) {
      AppLog.error('EventService', 'Failed to fetch event', error: e, stackTrace: stack, recoverable: true);
      return null;
    }
  }

  /// Get event registrations (group by class on UI).
  /// GET /registrations/event/{event_id}/registrations
  Future<List<EventRegistrationListItem>> getEventRegistrations(String eventId) async {
    try {
      final uri = Uri.parse(ApiConfig.eventRegistrations(eventId));
      final headers = _getAuthHeaders() ?? <String, String>{};
      headers['Content-Type'] = 'application/json';
      headers['accept'] = 'application/json';

      final response = await LoggedHttp.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> list =
            responseBody is List ? responseBody : (responseBody['registrations'] as List? ?? []);
        final registrations = list
            .map((json) =>
                EventRegistrationListItem.fromJson(json as Map<String, dynamic>))
            .toList();
        return registrations;
      } else {
        return [];
      }
    } catch (e, stack) {
      AppLog.error('EventService', 'Failed to fetch event registrations', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Get finalized results for a completed event.
  /// GET /events/{event_id}/results
  Future<EventResultsResponse> getEventResults(String eventId) async {
    try {
      final uri = Uri.parse(ApiConfig.eventResults(eventId));

      final response = await LoggedHttp.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return EventResultsResponse.fromJson(json);
      }
      if (response.statusCode == 404) {
        return EventResultsResponse(eventId: eventId, results: []);
      }
      throw Exception('Failed to load event results: ${response.statusCode}');
    } catch (e, stack) {
      AppLog.error('EventService', 'Failed to fetch event results', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Get bracket rounds for an event.
  /// GET /events/{event_id}/rounds
  /// Pass [classKey] to filter by racing class.
  Future<List<RoundBase>> getRounds(String eventId, {String? classKey}) async {
    try {
      final uri = Uri.parse(ApiConfig.eventRounds(eventId, classKey: classKey));
      final headers = _getAuthHeaders() ?? <String, String>{};
      headers['Content-Type'] = 'application/json';
      headers['accept'] = 'application/json';

      final response = await LoggedHttp.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> list =
            responseBody is List ? responseBody : (responseBody['rounds'] as List? ?? []);
        final rounds = list
            .map((json) => RoundBase.fromJson(json as Map<String, dynamic>))
            .toList();
        return rounds;
      } else {
        return [];
      }
    } catch (e, stack) {
      AppLog.error('EventService', 'Failed to fetch rounds', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Get speed session for an event/class (includes rankings).
  /// GET /speed/session?event_id=...&class_key=...
  /// Returns null if 404 (no session found).
  Future<SpeedSession?> getSpeedSession(String eventId, String classKey) async {
    try {
      final uri = Uri.parse(ApiConfig.speedSession(eventId, classKey));

      final response = await LoggedHttp.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SpeedSession.fromJson(json);
      }
      if (response.statusCode == 404) {
        return null;
      }
      return null;
    } catch (e, stack) {
      AppLog.error('EventService', 'Failed to fetch speed session', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }
}

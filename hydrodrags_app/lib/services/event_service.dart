import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event.dart';
import '../models/event_registration_list_item.dart';
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
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/events');

      if (kDebugMode) {
        print('=== API Request: Get Events ===');
        print('URL: $uri');
        print('Method: GET');
      }

      final response = await http.get(uri);

      if (kDebugMode) {
        print('=== API Response: Get Events ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> eventsJson = responseBody['events'] ?? responseBody;
        final events = eventsJson
            .map((json) => Event.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          print('Loaded ${events.length} events');
        }
        return events;
      } else {
        if (kDebugMode) {
          print('Failed to get events: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting events: $e');
      }
      rethrow;
    }
  }

  /// Get a single event by ID
  /// GET /events/{event_id}
  Future<Event?> getEvent(String eventId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/events/$eventId');

      if (kDebugMode) {
        print('=== API Request: Get Event ===');
        print('URL: $uri');
        print('Method: GET');
      }

      final response = await http.get(uri);

      if (kDebugMode) {
        print('=== API Response: Get Event ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final eventJson = responseBody['event'] ?? responseBody;
        final event = Event.fromJson(eventJson as Map<String, dynamic>);

        if (kDebugMode) {
          print('Loaded event: ${event.name}');
        }
        return event;
      } else {
        if (kDebugMode) {
          print('Failed to get event: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event: $e');
      }
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

      if (kDebugMode) {
        print('=== API Request: Get Event Registrations ===');
        print('URL: $uri');
        print('Method: GET');
      }

      final response = await http.get(uri, headers: headers);

      if (kDebugMode) {
        print('=== API Response: Get Event Registrations ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> list =
            responseBody is List ? responseBody : (responseBody['registrations'] as List? ?? []);
        final registrations = list
            .map((json) =>
                EventRegistrationListItem.fromJson(json as Map<String, dynamic>))
            .toList();
        if (kDebugMode) {
          print('Loaded ${registrations.length} event registrations');
        }
        return registrations;
      } else {
        if (kDebugMode) {
          print('Failed to get event registrations: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting event registrations: $e');
      }
      rethrow;
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';
import '../config/api_config.dart';
import '../models/pwc.dart';
import '../utils/app_log.dart';
import '../models/racer_profile.dart';
import '../models/racer_history_item.dart';
import '../models/my_registration.dart';
import '../models/spectator_ticket.dart';
import 'auth_service.dart';

/// Service for managing racer profile data and API interactions
class RacerService {
  final AuthService _authService;

  RacerService(this._authService);

  /// Parse sponsors from API: can be List or String.
  /// Returns List<String> for model, or null if empty.
  static List<String>? _parseSponsorsList(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final list = v
          .map((e) => e?.toString().trim())
          .where((e) => e != null && e.isNotEmpty)
          .map((e) => e as String)
          .toList();
      return list.isEmpty ? null : list;
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return [s];
    }
    return null;
  }

  /// Decode JWT token to get payload
  /// JWT format: header.payload.signature
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode base64url encoded payload
      final payload = parts[1];
      // Add padding if needed
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 1:
          normalizedPayload += '===';
          break;
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
      }
      
      // Replace URL-safe characters
      normalizedPayload = normalizedPayload.replaceAll('-', '+').replaceAll('_', '/');
      
      final decoded = utf8.decode(base64Decode(normalizedPayload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to decode profile token', error: e, stackTrace: stack, recoverable: true);
      return null;
    }
  }

  /// Get racer ID from JWT token
  String? _getRacerIdFromToken() {
    final token = _authService.accessToken;
    if (token == null) return null;

    final payload = _decodeJwtPayload(token);
    if (payload == null) return null;

    // Get 'sub' claim which contains the racer_id
    return payload['sub'] as String?;
  }

  /// Get authorization headers with bearer token
  Map<String, String> _getAuthHeaders() {
    final token = _authService.accessToken;
    if (token == null) {
      throw Exception('No access token available');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Upload profile image
  /// POST /me/profile-image
  Future<bool> uploadProfileImage(File imageFile) async {
    try {
      // Ensure we have a valid token
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/me/profile-image');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'profile.jpg',
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await LoggedHttp.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Image upload failed', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Upload banner image
  /// POST /me/banner-image
  Future<bool> uploadBannerImage(File imageFile) async {
    try {
      // Ensure we have a valid token
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/me/banner-image');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: 'banner.jpg',
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await LoggedHttp.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Image upload failed', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Upload signed waiver document (PDF or image) to backend.
  /// POST /me/waiver — saves the waiver file to the database.
  /// [fileBytes] — PDF bytes (use filename 'waiver.pdf') or signature PNG (use 'waiver-signature.png').
  Future<bool> uploadWaiver(
    List<int> fileBytes, {
    String filename = 'waiver-signature.png',
  }) async {
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse(ApiConfig.waiverUploadEndpoint);

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      );
      request.files.add(multipartFile);

      final streamedResponse = await LoggedHttp.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Waiver upload failed', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Get current racer profile from backend
  /// GET /me
  Future<RacerProfile?> getCurrentRacerProfile() async {
    try {
      // Ensure we have a valid token
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/me');

      final response = await LoggedHttp.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        // Map backend response to RacerProfile model
        final profile = RacerProfile(
          id: responseBody['id'] as String?,
          firstName: responseBody['first_name'] as String?,
          lastName: responseBody['last_name'] as String?,
          dateOfBirth: responseBody['date_of_birth'] != null
              ? DateTime.parse(responseBody['date_of_birth'] as String)
              : null,
          gender: responseBody['gender'] as String?,
          nationality: responseBody['nationality'] as String?,
          phoneNumber: responseBody['phone'] as String?,
          email: responseBody['email'] as String?,
          emergencyContactName: responseBody['emergency_contact_name'] as String?,
          emergencyContactPhone: responseBody['emergency_contact_phone'] as String?,
          street: responseBody['street'] as String?,
          city: responseBody['city'] as String?,
          stateProvince: responseBody['state_province'] as String?,
          country: responseBody['country'] as String?,
          zipPostalCode: responseBody['zip_postal_code'] as String?,
          organization: responseBody['organization'] as String?,
          membershipNumber: responseBody['membership_number'] as String?,
          membershipPurchasedAt: responseBody['membership_purchased_at'] != null
              ? DateTime.tryParse(responseBody['membership_purchased_at'] as String)
              : null,
          classCategory: responseBody['class_category'] as String?,
          bio: responseBody['bio'] as String?,
          sponsors: RacerService._parseSponsorsList(responseBody['sponsors']),
          profileImagePath: responseBody['profile_image_path'] as String?,
          bannerImagePath: responseBody['banner_image_path'] as String?,
          profileImageUpdatedAt: responseBody['profile_image_updated_at'] != null
              ? DateTime.parse(responseBody['profile_image_updated_at'] as String)
              : null,
          bannerImageUpdatedAt: responseBody['banner_image_updated_at'] != null
              ? DateTime.parse(responseBody['banner_image_updated_at'] as String)
              : null,
          hasValidWaiver: responseBody['has_valid_waiver'] as bool?,
          waiverSignedAt: responseBody['waiver_signed_at'] != null
              ? DateTime.tryParse(responseBody['waiver_signed_at'] as String)
              : null,
        );
        return profile;
      } else {
        return null;
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch racer profile', error: e, stackTrace: stack, recoverable: true);
      return null;
    }
  }

  /// GET /me/tickets — list spectator tickets for the current racer
  Future<List<SpectatorTicket>> getMyTickets() async {
    try {
      await _authService.refreshTokenIfNeeded();
      final headers = _getAuthHeaders();
      final uri = Uri.parse(ApiConfig.myTicketsEndpoint);

      final response = await LoggedHttp.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => SpectatorTicket.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch tickets', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// GET /me/registrations — list event registrations for the current racer
  Future<List<MyRegistration>> getMyRegistrations() async {
    try {
      await _authService.refreshTokenIfNeeded();
      final headers = _getAuthHeaders();
      final uri = Uri.parse(ApiConfig.myRegistrationsEndpoint);

      final response = await LoggedHttp.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((e) => MyRegistration.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch registrations', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Get all racers from backend
  /// GET /racers/all
  Future<List<RacerProfile>> getAllRacers() async {
    try {
      // Ensure we have a valid token
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/racers/all');

      final response = await LoggedHttp.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final List<dynamic> racersJson = responseBody is List ? responseBody : [];
        
        final racers = racersJson.map((racerJson) {
          return RacerService._racerProfileFromJson(racerJson as Map<String, dynamic>);
        }).toList();
        return racers;
      } else {
        throw Exception('Failed to load racers: ${response.statusCode}');
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch racers', error: e, stackTrace: stack, recoverable: true);
      rethrow;
    }
  }

  /// Update racer profile
  /// PATCH /racers/{racer_id}
  Future<bool> updateRacerProfile(RacerProfile profile) async {
    try {
      // Ensure we have a valid token
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No access token available');
      }

      // Get racer ID from token
      final racerId = _getRacerIdFromToken();
      if (racerId == null) {
        throw Exception('Could not get racer ID from token');
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/racers/$racerId');
      
      // Build request payload matching RacerUpdate schema
      final payload = <String, dynamic>{};
      
      if (profile.firstName != null) payload['first_name'] = profile.firstName;
      if (profile.lastName != null) payload['last_name'] = profile.lastName;
      if (profile.dateOfBirth != null) {
        payload['date_of_birth'] = profile.dateOfBirth!.toIso8601String().split('T')[0]; // Format as YYYY-MM-DD
      }
      if (profile.gender != null) payload['gender'] = profile.gender;
      if (profile.nationality != null) payload['nationality'] = profile.nationality;
      
      if (profile.phoneNumber != null) payload['phone'] = profile.phoneNumber;
      if (profile.emergencyContactName != null) payload['emergency_contact_name'] = profile.emergencyContactName;
      if (profile.emergencyContactPhone != null) payload['emergency_contact_phone'] = profile.emergencyContactPhone;
      
      if (profile.street != null) payload['street'] = profile.street;
      if (profile.city != null) payload['city'] = profile.city;
      if (profile.stateProvince != null) payload['state_province'] = profile.stateProvince;
      if (profile.country != null) payload['country'] = profile.country;
      if (profile.zipPostalCode != null) payload['zip_postal_code'] = profile.zipPostalCode;
      
      if (profile.organization != null) payload['organization'] = profile.organization;
      if (profile.membershipNumber != null) payload['membership_number'] = profile.membershipNumber;
      if (profile.membershipPurchasedAt != null) {
        payload['membership_purchased_at'] = profile.membershipPurchasedAt!.toIso8601String().split('T')[0];
      }
      if (profile.classCategory != null) payload['class_category'] = profile.classCategory;
      payload['bio'] = profile.bio;
      payload['sponsors'] = profile.sponsors ?? [];

      // Send PATCH request
      final requestBody = jsonEncode(payload);

      final response = await LoggedHttp.patch(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to update racer profile', error: e, stackTrace: stack, recoverable: true);
      return false;
    }
  }

  /// Get a single racer profile by ID.
  /// GET /racers/{racer_id}
  Future<RacerProfile?> getRacerById(String racerId) async {
    if (racerId.isEmpty) return null;
    try {
      await _authService.refreshTokenIfNeeded();
      final token = await _authService.getValidAccessToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/racers/$racerId');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'accept': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await LoggedHttp.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final racerJson = body is Map<String, dynamic> ? body : (body['racer'] as Map<String, dynamic>?);
        if (racerJson == null) return null;
        return RacerService._racerProfileFromJson(racerJson);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch racer', error: e, stackTrace: stack, recoverable: true);
      return null;
    }
  }

  static RacerProfile _racerProfileFromJson(Map<String, dynamic> racerJson) {
    return RacerProfile(
      id: racerJson['id'] as String?,
      firstName: racerJson['first_name'] as String?,
      lastName: racerJson['last_name'] as String?,
      dateOfBirth: racerJson['date_of_birth'] != null
          ? DateTime.parse(racerJson['date_of_birth'] as String)
          : null,
      gender: racerJson['gender'] as String?,
      nationality: racerJson['nationality'] as String?,
      phoneNumber: racerJson['phone'] as String?,
      email: racerJson['email'] as String?,
      emergencyContactName: racerJson['emergency_contact_name'] as String?,
      emergencyContactPhone: racerJson['emergency_contact_phone'] as String?,
      street: racerJson['street'] as String?,
      city: racerJson['city'] as String?,
      stateProvince: racerJson['state_province'] as String?,
      country: racerJson['country'] as String?,
      zipPostalCode: racerJson['zip_postal_code'] as String?,
      organization: racerJson['organization'] as String?,
      membershipNumber: racerJson['membership_number'] as String?,
      membershipPurchasedAt: racerJson['membership_purchased_at'] != null
          ? DateTime.tryParse(racerJson['membership_purchased_at'] as String)
          : null,
      classCategory: racerJson['class_category'] as String?,
      bio: racerJson['bio'] as String?,
      sponsors: RacerService._parseSponsorsList(racerJson['sponsors']),
      profileImagePath: racerJson['profile_image_path'] as String?,
      bannerImagePath: racerJson['banner_image_path'] as String?,
      profileImageUpdatedAt: racerJson['profile_image_updated_at'] != null
          ? DateTime.parse(racerJson['profile_image_updated_at'] as String)
          : null,
      bannerImageUpdatedAt: racerJson['banner_image_updated_at'] != null
          ? DateTime.parse(racerJson['banner_image_updated_at'] as String)
          : null,
      hasValidWaiver: racerJson['has_valid_waiver'] as bool?,
      waiverSignedAt: racerJson['waiver_signed_at'] != null
          ? DateTime.tryParse(racerJson['waiver_signed_at'] as String)
          : null,
    );
  }

  /// GET /racers/{racer_id}/history — completed event results for a racer.
  Future<List<RacerHistoryItem>> getRacerHistory(String racerId) async {
    if (racerId.isEmpty) return [];
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/racers/$racerId/history');

      final response = await LoggedHttp.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> itemsJson = body is List ? body : [];
        return itemsJson
            .map((e) => RacerHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        return [];
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch racer history', error: e, stackTrace: stack, recoverable: true);
      return [];
    }
  }

  /// Get PWCs for a racer (public, no auth).
  /// GET /racers/{racer_id}/pwcs
  Future<List<PWC>> getRacerPWCs(String racerId) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/racers/$racerId/pwcs');

      final response = await LoggedHttp.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> pwcsJson = body is List ? body : (body['pwcs'] as List? ?? []);
        final pwcs = pwcsJson.map((json) => PWC.fromJson(json as Map<String, dynamic>)).toList();
        return pwcs;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        return [];
      }
    } catch (e, stack) {
      AppLog.error('RacerService', 'Failed to fetch racer PWCs', error: e, stackTrace: stack, recoverable: true);
      return [];
    }
  }
}

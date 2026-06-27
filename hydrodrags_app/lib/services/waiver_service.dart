import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../utils/logged_http.dart';

import '../config/api_config.dart';
import '../models/waiver_session.dart';
import '../utils/app_log.dart';
import 'auth_service.dart';

class WaiverService {
  final AuthService _authService;

  WaiverService(this._authService);

  Future<Map<String, String>> _headers({bool json = true}) async {
    await _authService.refreshTokenIfNeeded();
    final token = await _authService.getValidAccessToken();
    if (token == null) throw Exception('Not authenticated');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
    };
    if (json) headers['Content-Type'] = 'application/json';
    return headers;
  }

  Future<WaiverSessionStatus> getStatus(String eventId) async {
    final uri = Uri.parse(ApiConfig.eventWaiverStatus(eventId));
    final res = await LoggedHttp.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load waiver status (${res.statusCode})');
    }
    return WaiverSessionStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<String> createOrResumeSession(String eventId) async {
    final uri = Uri.parse(ApiConfig.eventWaiverSession(eventId));
    final res = await LoggedHttp.post(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to create waiver session (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['session_id'] as String;
  }

  Future<List<EventManualWaiverItem>> listEligibleEvents() async {
    final uri = Uri.parse(ApiConfig.eligibleWaiverEvents);
    final res = await LoggedHttp.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load waiver events (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => EventManualWaiverItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createReplacementSession(String eventId) async {
    final uri = Uri.parse(ApiConfig.eventWaiverReplacementSession(eventId));
    final res = await LoggedHttp.post(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to start waiver session (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['session_id'] as String;
  }

  Future<WaiverSessionDetail> getSession(String sessionId) async {
    final uri = Uri.parse(ApiConfig.waiverSession(sessionId));
    final res = await LoggedHttp.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load waiver session (${res.statusCode})');
    }
    return WaiverSessionDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> uploadGovernmentId({
    required String sessionId,
    required String side,
    required String idType,
    required File file,
  }) async {
    final uri = Uri.parse(ApiConfig.waiverSessionGovernmentId(sessionId));
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(json: false));
    request.fields['side'] = side;
    request.fields['id_type'] = idType;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await LoggedHttp.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Government ID upload failed (${response.statusCode})');
    }
  }

  Future<void> uploadSelfie({
    required String sessionId,
    required File file,
  }) async {
    final uri = Uri.parse(ApiConfig.waiverSessionSelfie(sessionId));
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(json: false));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await LoggedHttp.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Selfie upload failed (${response.statusCode})');
    }
  }

  Future<WaiverSignResult> signWaiver({
    required String sessionId,
    required String typedLegalName,
    required bool confirmedIdentity,
    required bool confirmedRead,
    required Map<String, dynamic> evidence,
    required List<int> signaturePngBytes,
  }) async {
    final uri = Uri.parse(ApiConfig.waiverSessionSign(sessionId));
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _headers(json: false));
    request.fields['typed_legal_name'] = typedLegalName;
    request.fields['confirmed_identity'] = confirmedIdentity.toString();
    request.fields['confirmed_read'] = confirmedRead.toString();
    request.fields['evidence_json'] = jsonEncode(evidence);
    request.files.add(
      http.MultipartFile.fromBytes(
        'signature',
        signaturePngBytes,
        filename: 'signature.png',
      ),
    );
    final streamed = await LoggedHttp.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      AppLog.error(
        'Waiver',
        AppLog.httpFailure('sign waiver', response.statusCode),
        recoverable: true,
      );
      throw Exception('Failed to sign waiver (${response.statusCode})');
    }
    AppLog.info('Waiver', 'Waiver completed');
    return WaiverSignResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

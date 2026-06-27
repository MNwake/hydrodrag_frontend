import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists in-progress waiver session during registration (pre-payment).
class PendingWaiverStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyEventId = 'pending_waiver_event_id';
  static const _keySessionId = 'pending_waiver_session_id';
  static const _keyStep = 'pending_waiver_step';
  static const _keyFlowType = 'pending_waiver_flow_type';

  static const flowTypeRegistration = 'registration';
  static const flowTypeManualResign = 'manual_resign';

  static Future<void> save({
    required String eventId,
    required String sessionId,
    String step = 'government_id',
    String flowType = flowTypeRegistration,
  }) async {
    await _storage.write(key: _keyEventId, value: eventId);
    await _storage.write(key: _keySessionId, value: sessionId);
    await _storage.write(key: _keyStep, value: step);
    await _storage.write(key: _keyFlowType, value: flowType);
  }

  static Future<Map<String, String>?> load() async {
    final eventId = await _storage.read(key: _keyEventId);
    final sessionId = await _storage.read(key: _keySessionId);
    final step = await _storage.read(key: _keyStep);
    final flowType = await _storage.read(key: _keyFlowType);
    if (eventId == null || sessionId == null) return null;
    return {
      'eventId': eventId,
      'sessionId': sessionId,
      'step': step ?? 'government_id',
      'flowType': flowType ?? flowTypeRegistration,
    };
  }

  static Future<void> clear() async {
    await _storage.delete(key: _keyEventId);
    await _storage.delete(key: _keySessionId);
    await _storage.delete(key: _keyStep);
    await _storage.delete(key: _keyFlowType);
  }

  static Future<bool> isManualResignFlow() async {
    final flowType = await _storage.read(key: _keyFlowType);
    return flowType == flowTypeManualResign;
  }
}

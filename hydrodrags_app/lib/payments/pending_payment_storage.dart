import 'dart:convert';

import '../utils/secure_storage_config.dart';

/// Persists in-progress mobile payment_id for recovery after app restart.
class PendingPaymentStorage {
  static const _key = 'pending_mobile_payment';

  static const _storage = appSecureStorage;

  static Future<void> save({
    required String paymentId,
    required String paymentType,
    String? eventId,
  }) async {
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'paymentId': paymentId,
        'paymentType': paymentType,
        if (eventId != null) 'eventId': eventId,
      }),
    );
  }

  static Future<Map<String, String>?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> paymentId() async {
    final record = await load();
    return record?['paymentId'];
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}

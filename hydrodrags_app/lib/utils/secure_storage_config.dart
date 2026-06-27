import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared Android secure-storage options.
///
/// Uses EncryptedSharedPreferences for reliable persistence on physical devices.
/// Avoid [AndroidOptions.resetOnError] — it wipes all stored values on any read/write error.
const AndroidOptions androidSecureStorageOptions = AndroidOptions(
  encryptedSharedPreferences: true,
  sharedPreferencesName: 'flutter_secure_storage_hydrodrags',
);

/// App-wide secure storage instance with consistent platform options.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  aOptions: androidSecureStorageOptions,
);

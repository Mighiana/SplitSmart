import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the SQLCipher key for the local database.
///
/// The key is a random 64-hex-char string generated once per install and kept
/// in the platform secure store (Android Keystore-backed EncryptedSharedPrefs,
/// iOS Keychain). It never leaves the device — portable backups are re-keyed
/// to a user passphrase instead (see BackupService).
class DbKeyService {
  DbKeyService._();

  static const _storageKey = 'db_cipher_key_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String? _cached;

  /// Returns the device DB key, creating and persisting it on first use.
  static Future<String> getOrCreateKey() async {
    if (_cached != null) return _cached!;
    var key = await _storage.read(key: _storageKey);
    if (key == null || key.isEmpty) {
      key = _randomHex(64);
      await _storage.write(key: _storageKey, value: key);
      // Read back to be sure the secure store actually persisted it — losing
      // the key after encrypting the DB would orphan all local data.
      final verify = await _storage.read(key: _storageKey);
      if (verify != key) {
        throw StateError('Secure storage failed to persist the DB key.');
      }
    }
    _cached = key;
    return key;
  }

  static String _randomHex(int chars) {
    const alphabet = '0123456789abcdef';
    final rng = Random.secure();
    return List.generate(chars, (_) => alphabet[rng.nextInt(16)]).join();
  }
}

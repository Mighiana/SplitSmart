import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  SecurityService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _lockPrefKey = 'app_lock_enabled';

  // ─── Settings ─────────────────────────────────────────────────────────────

  static Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockPrefKey) ?? false;
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockPrefKey, enabled);
  }

  // ─── Device capability ────────────────────────────────────────────────────

  static Future<bool> canAuthenticate() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('[SecurityService] canAuthenticate error: $e');
      return false;
    }
  }

  static Future<bool> hasBiometrics() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ─── Authentication ───────────────────────────────────────────────────────

  static Future<bool> authenticate() async {
    try {
      final bool result = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock SplitSmart',
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('[SecurityService] PlatformException: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[SecurityService] Auth error: $e');
      return false;
    }
  }

  static Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}

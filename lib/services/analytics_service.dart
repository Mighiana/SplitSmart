import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Static analytics service — wraps Firebase Analytics with privacy-safe event tracking.
///
/// All methods are static, async, and wrapped in try/catch so that
/// analytics failures **never** crash the app.
///
/// Privacy: We track **feature usage only** — no financial amounts, no names,
/// no descriptions, no personally identifiable information.
class AnalyticsService {
  AnalyticsService._();

  /// Set to `false` to disable analytics in debug builds.
  static const bool kTrackInDebug = false;

  static FirebaseAnalytics? _instance;

  static FirebaseAnalytics get _analytics {
    _instance ??= FirebaseAnalytics.instance;
    return _instance!;
  }

  static bool get _shouldTrack => kTrackInDebug || !kDebugMode;

  // ─── Screen Tracking ──────────────────────────────────────────────────────

  static Future<void> logScreen(String screenName) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('[Analytics] logScreen error: $e');
    }
  }

  // ─── Groups ───────────────────────────────────────────────────────────────

  static Future<void> logGroupCreated() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'group_created');
    } catch (e) {
      debugPrint('[Analytics] logGroupCreated error: $e');
    }
  }

  static Future<void> logGroupArchived() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'group_archived');
    } catch (e) {
      debugPrint('[Analytics] logGroupArchived error: $e');
    }
  }

  static Future<void> logGroupDeleted() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'group_deleted');
    } catch (e) {
      debugPrint('[Analytics] logGroupDeleted error: $e');
    }
  }

  static Future<void> logGroupQRShared() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'group_qr_shared');
    } catch (e) {
      debugPrint('[Analytics] logGroupQRShared error: $e');
    }
  }

  static Future<void> logGroupQRScanned() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'group_qr_scanned');
    } catch (e) {
      debugPrint('[Analytics] logGroupQRScanned error: $e');
    }
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  static Future<void> logExpenseAdded({
    required bool isCustomSplit,
    required bool hasReceipt,
  }) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'expense_added',
        parameters: {
          'is_custom_split': isCustomSplit.toString(),
          'has_receipt': hasReceipt.toString(),
        },
      );
    } catch (e) {
      debugPrint('[Analytics] logExpenseAdded error: $e');
    }
  }

  static Future<void> logExpenseEdited() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'expense_edited');
    } catch (e) {
      debugPrint('[Analytics] logExpenseEdited error: $e');
    }
  }

  static Future<void> logExpenseDeleted() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'expense_deleted');
    } catch (e) {
      debugPrint('[Analytics] logExpenseDeleted error: $e');
    }
  }

  static Future<void> logSettledUp() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'settled_up');
    } catch (e) {
      debugPrint('[Analytics] logSettledUp error: $e');
    }
  }

  static Future<void> logExportedPDF() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'exported_pdf');
    } catch (e) {
      debugPrint('[Analytics] logExportedPDF error: $e');
    }
  }

  static Future<void> logExportedText() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'exported_text');
    } catch (e) {
      debugPrint('[Analytics] logExportedText error: $e');
    }
  }

  // ─── Personal Finance ─────────────────────────────────────────────────────

  static Future<void> logTransactionAdded(String type) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'transaction_added',
        parameters: {'type': type},
      );
    } catch (e) {
      debugPrint('[Analytics] logTransactionAdded error: $e');
    }
  }

  static Future<void> logTransactionEdited() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'transaction_edited');
    } catch (e) {
      debugPrint('[Analytics] logTransactionEdited error: $e');
    }
  }

  static Future<void> logTransactionDeleted() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'transaction_deleted');
    } catch (e) {
      debugPrint('[Analytics] logTransactionDeleted error: $e');
    }
  }

  static Future<void> logBudgetSet(String period) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'budget_set',
        parameters: {'period': period},
      );
    } catch (e) {
      debugPrint('[Analytics] logBudgetSet error: $e');
    }
  }

  static Future<void> logSubscriptionAdded(String cycle) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'subscription_added',
        parameters: {'cycle': cycle},
      );
    } catch (e) {
      debugPrint('[Analytics] logSubscriptionAdded error: $e');
    }
  }

  static Future<void> logSavingGoalAdded() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'saving_goal_added');
    } catch (e) {
      debugPrint('[Analytics] logSavingGoalAdded error: $e');
    }
  }

  static Future<void> logReminderAdded() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'reminder_added');
    } catch (e) {
      debugPrint('[Analytics] logReminderAdded error: $e');
    }
  }

  // ─── App Features ─────────────────────────────────────────────────────────

  static Future<void> logBackupCreated() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'backup_created');
    } catch (e) {
      debugPrint('[Analytics] logBackupCreated error: $e');
    }
  }

  static Future<void> logBackupRestored() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'backup_restored');
    } catch (e) {
      debugPrint('[Analytics] logBackupRestored error: $e');
    }
  }

  static Future<void> logBackupShared() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'backup_shared');
    } catch (e) {
      debugPrint('[Analytics] logBackupShared error: $e');
    }
  }

  static Future<void> logSupportLogsShared() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'support_logs_shared');
    } catch (e) {
      debugPrint('[Analytics] logSupportLogsShared error: $e');
    }
  }

  static Future<void> logThemeToggled(bool isDark) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'theme_toggled',
        parameters: {'is_dark': isDark.toString()},
      );
    } catch (e) {
      debugPrint('[Analytics] logThemeToggled error: $e');
    }
  }

  static Future<void> logLanguageChanged(String langCode) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'language_changed',
        parameters: {'lang_code': langCode},
      );
    } catch (e) {
      debugPrint('[Analytics] logLanguageChanged error: $e');
    }
  }

  static Future<void> logAppLockEnabled() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'app_lock_enabled');
    } catch (e) {
      debugPrint('[Analytics] logAppLockEnabled error: $e');
    }
  }

  static Future<void> logOnboardingCompleted() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'onboarding_completed');
    } catch (e) {
      debugPrint('[Analytics] logOnboardingCompleted error: $e');
    }
  }

  static Future<void> logOnboardingSkipped() async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(name: 'onboarding_skipped');
    } catch (e) {
      debugPrint('[Analytics] logOnboardingSkipped error: $e');
    }
  }

  static Future<void> logCurrencyWalletCreated(String currencyCode) async {
    if (!_shouldTrack) return;
    try {
      await _analytics.logEvent(
        name: 'currency_wallet_created',
        parameters: {'currency_code': currencyCode},
      );
    } catch (e) {
      debugPrint('[Analytics] logCurrencyWalletCreated error: $e');
    }
  }

  // ─── User Properties ──────────────────────────────────────────────────────

  static Future<void> setUserProperties(Map<String, String> props) async {
    if (!_shouldTrack) return;
    try {
      for (final entry in props.entries) {
        await _analytics.setUserProperty(
          name: entry.key,
          value: entry.value,
        );
      }
    } catch (e) {
      debugPrint('[Analytics] setUserProperties error: $e');
    }
  }
}

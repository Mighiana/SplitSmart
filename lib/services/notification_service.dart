import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../providers/app_state.dart';

/// Handles scheduling / cancelling local notifications for subscriptions.
/// All offline — zero internet required.
///
/// Updated for flutter_local_notifications 21.x:
///   - initialize() uses named `settings` parameter
///   - zonedSchedule() uses named parameters throughout
///   - UILocalNotificationDateInterpretation removed (Android-only path)
///   - cancel() uses named `id` parameter
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId   = 'splitsmart_subs';
  static const _channelName = 'Subscription Reminders';
  static const _channelDesc = 'Upcoming subscription billing reminders';

  // ─── Initialise ────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Resolve local timezone purely in Dart: scan the tz database for any
    // location whose current DST-aware offset matches the device offset.
    // This is more reliable than constructing a GMT+HH:MM key (which is not
    // a valid IANA name) and doesn't require any native plugin.
    final deviceOffset = DateTime.now().timeZoneOffset;
    try {
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => loc.currentTimeZone.offset == deviceOffset,
      );
      tz.setLocalLocation(match);
    } catch (_) {
      // No exact match (can happen during rare DST edge cases) — use UTC.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );

    // v21: initialize() uses named `settings` param
    await _plugin.initialize(settings: initSettings);

    // Request Android 13+ notification permission (delayed so it doesn't block runApp)
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await androidImpl?.requestNotificationsPermission();
        await androidImpl?.requestExactAlarmsPermission();
      } catch (_) {
        // Permission denied — notifications won't fire but app won't crash
      }
    });

    _initialized = true;
  }

  // ─── Schedule notifications for one subscription ───────────────────────────
  static Future<void> scheduleForSub(SubscriptionData sub) async {
    if (!_initialized) await init();
    await cancelForSub(sub.id);
    if (!sub.isActive) return;

    final nextBilling  = sub.nextBillingDate;
    final threeDayWarn = nextBilling.subtract(const Duration(days: 3));
    final now          = DateTime.now();

    const androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority:   Priority.high,
      icon:       '@mipmap/launcher_icon',
    );
    const details = NotificationDetails(android: androidDetails);

    // Notification ID scheme (BUG-4 fix: safe modular arithmetic to avoid int32 overflow):
    //   _safeSubId(sub.id)       → billing day notification
    //   _safeSubId(sub.id) + 1   → 3-day warning notification
    //   _safeRemId(r.id)         → custom reminder notification
    //   IDs 0–9 reserved for future app-level notifications
    // ── 3-day warning ─────────────────────────────────────────────────────
    if (threeDayWarn.isAfter(now)) {
      final tzWarn = tz.TZDateTime.from(threeDayWarn, tz.local);
      // v21: zonedSchedule() uses named params; no uiLocalNotificationDateInterpretation on Android
      await _plugin.zonedSchedule(
        id:                   _safeSubId(sub.id) + 1,
        title:                '⚠️ ${sub.name} — due in 3 days',
        body:                 '${sub.sym}${sub.amount.toStringAsFixed(2)} will be '
                              'charged on ${_fmtDate(nextBilling)}',
        scheduledDate:        tzWarn,
        notificationDetails:  details,
        androidScheduleMode:  AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: _repeatComponents(sub.cycle),
      );
    }

    // ── Billing day ───────────────────────────────────────────────────────
    if (nextBilling.isAfter(now)) {
      final tzBilling = tz.TZDateTime.from(nextBilling, tz.local);
      await _plugin.zonedSchedule(
        id:                   _safeSubId(sub.id),
        title:                '💳 ${sub.name} — ${sub.sym}${sub.amount.toStringAsFixed(2)} due today',
        body:                 'Your ${sub.name} subscription renews today',
        scheduledDate:        tzBilling,
        notificationDetails:  details,
        androidScheduleMode:  AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: _repeatComponents(sub.cycle),
      );
    }
  }

  // ─── Cancel all notifications for one subscription ─────────────────────────
  static Future<void> cancelForSub(int subId) async {
    if (!_initialized) await init();
    // v21: cancel() uses named `id` param
    await _plugin.cancel(id: _safeSubId(subId));
    await _plugin.cancel(id: _safeSubId(subId) + 1);
  }

  // ─── Reschedule everything (e.g. on app start / after reboot) ─────────────
  static Future<void> rescheduleAll(List<SubscriptionData> subs) async {
    if (!_initialized) await init();
    for (final sub in subs) {
      await scheduleForSub(sub);
    }
  }

  // ─── Custom Reminders ──────────────────────────────────────────────────────

  static Future<void> scheduleReminder(ReminderData r) async {
    if (!_initialized) await init();
    await cancelReminder(r.id);
    if (r.isCompleted) return;

    final now = DateTime.now();
    // Default to 10:00 AM on the selected date if the time is exactly midnight 
    // from the DatePicker, or keep time if explicitly set.
    DateTime remindTime = r.date;
    if (r.date.hour == 0 && r.date.minute == 0) {
      remindTime = DateTime(r.date.year, r.date.month, r.date.day, 10, 0);
    }
    
    // If the time is already past today, but date is today, let's bump it to 5 mins from now so they get it today.
    if (!remindTime.isAfter(now) && r.date.year == now.year && r.date.month == now.month && r.date.day == now.day) {
      remindTime = now.add(const Duration(minutes: 5));
    }

    if (remindTime.isAfter(now)) {
      final tzTime = tz.TZDateTime.from(remindTime, tz.local);
      const androidDetails = AndroidNotificationDetails(
        _channelId, _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority:   Priority.high,
        icon:       '@mipmap/launcher_icon',
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        id:                   _safeRemId(r.id),
        title:                '🔔 Reminder: ${r.title}',
        body:                 r.amountStr.isNotEmpty ? 'Amount: ${r.amountStr}' : 'You have a scheduled reminder today.',
        scheduledDate:        tzTime,
        notificationDetails:  details,
        androidScheduleMode:  AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null, // one-shot
      );
    }
  }

  static Future<void> cancelReminder(int rId) async {
    if (!_initialized) await init();
    await _plugin.cancel(id: _safeRemId(rId));
  }

  static Future<void> rescheduleAllReminders(List<ReminderData> reminders) async {
    if (!_initialized) await init();
    for (final r in reminders) {
      await scheduleReminder(r);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  static DateTimeComponents? _repeatComponents(String cycle) {
    switch (cycle) {
      case 'monthly': return DateTimeComponents.dayOfMonthAndTime;
      case 'weekly':  return DateTimeComponents.dayOfWeekAndTime;
      default:        return null; // yearly: one-shot; app reschedules on open
    }
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  /// Safe notification ID for subscriptions: stays within int32 range.
  /// Maps sub.id into the 10–199_998 range (even numbers for billing, +1 for warnings).
  static int _safeSubId(int subId) => 10 + (subId.abs() % 99995) * 2;

  /// Safe notification ID for reminders: stays within int32 range.
  /// Maps r.id into the 200_000–299_999 range.
  static int _safeRemId(int rId) => 200000 + (rId.abs() % 100000);
}

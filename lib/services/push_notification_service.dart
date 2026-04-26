import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here if needed (e.g., update local SQLite cache).
  debugPrint('[FCM] Background message received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  // Notification channel for group activity — separate from subscriptions channel
  static const _channelId   = 'splitsmart_group';
  static const _channelName = 'Group Activity';
  static const _channelDesc = 'Notifications when group members add expenses or settlements';

  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;

    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[FCM] User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Setup background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Initialize flutter_local_notifications for foreground heads-up
      await _initLocalNotifications();

      // 4. Handle foreground messages — show as local notification
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 5. Save device token
      await _saveTokenToFirestore();

      // 6. Listen for token refreshes
      _fcm.onTokenRefresh.listen((token) {
        _updateTokenInFirestore(token);
      });
    }

    _initialized = true;
  }

  // ─── Foreground notification display via flutter_local_notifications ───────

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested above
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localPlugin.initialize(settings: initSettings);
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message received: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      showWhen: true,
    );
    const details = NotificationDetails(android: androidDetails);

    // Use a unique ID from the message hash to avoid collisions
    final notifId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    _localPlugin.show(
      id: notifId,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }

  // ─── Token management ──────────────────────────────────────────────────────

  Future<void> _saveTokenToFirestore() async {
    final uid = AuthService.instance.uid;
    if (uid == null) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final uid = AuthService.instance.uid;
    if (uid == null) return;

    try {
      // BUG-6 fix: Limit stored tokens to prevent unbounded array growth.
      // First add the new token, then prune old ones to keep max 5.
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await docRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Prune: if more than 5 tokens, keep only the latest 5
      final snap = await docRef.get();
      final data = snap.data();
      if (data != null) {
        final tokens = List<String>.from(data['fcmTokens'] ?? []);
        if (tokens.length > 5) {
          final trimmed = tokens.sublist(tokens.length - 5);
          await docRef.update({'fcmTokens': trimmed});
        }
      }

      debugPrint('[FCM] Token saved for user $uid');
    } catch (e) {
      debugPrint('[FCM] Error saving token to Firestore: $e');
    }
  }
}

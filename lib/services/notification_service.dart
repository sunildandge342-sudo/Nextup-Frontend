import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static void Function(String? payload)? onNotificationTap;

  // ✅ Initialize local notifications (existing)
  static Future<void> init({
    void Function(String? payload)? onTap,
  }) async {
    onNotificationTap = onTap;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
        onNotificationTap?.call(response.payload);
      },
    );

    // ✅ Create foreground service channel (queue_tracking)
    await _notificationsPlugin.show(
      0,
      null,
      null,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'queue_tracking',
          'Queue Tracking',
          channelDescription: 'Shown while tracking your queue position',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
    await _notificationsPlugin.cancel(0);

    // ✅ Create alerts channel (queue_channel)
    await _notificationsPlugin.show(
      0,
      null,
      null,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'queue_channel',
          'Queue Notifications',
          channelDescription: 'Alerts when your queue position changes',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    await _notificationsPlugin.cancel(0);
  }

  // ✅ Initialize OneSignal (NEW)
  static Future<void> initOneSignal() async {
    OneSignal.initialize("070e3d48-4c64-4f41-b7f0-e9e43ee901de");
    await OneSignal.Notifications.requestPermission(true);
    final id = await OneSignal.User.getOnesignalId();
    debugPrint("OneSignal Player ID: $id");
  }

  // ✅ Link OneSignal to logged-in user (NEW)
  static Future<void> setUserId(String userId) async {
    await OneSignal.login(userId);
    debugPrint("OneSignal linked to userId: $userId");
  }

  // ✅ Unlink on logout (NEW)
  static Future<void> logoutOneSignal() async {
    await OneSignal.logout();
  }

  // ✅ Show local notification (existing)
  static Future<void> showNotification(
      String title,
      String body, {
        String? payload,
      }) async {
    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'queue_channel',
      'Queue Notifications',
      channelDescription: 'Queue update notifications',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: true,
        htmlFormatContentTitle: true,
      ),
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
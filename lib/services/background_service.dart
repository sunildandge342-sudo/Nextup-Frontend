import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:nextup/services/notifications_store.dart';
import 'package:flutter/widgets.dart';

// ✅ Move your base URL here so it's easy to change
const String _baseUrl = "https://nextup-backend-zlou.onrender.com";

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'queue_tracking',
      initialNotificationTitle: 'NextUp',
      initialNotificationContent: 'Tracking your queue position...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  int previousPosition = -1; // ✅ Fixed: was 0, which skips position 0 notifications
  String serviceName = "";
  int userId = 0;
  Timer? pollingTimer;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await notificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Notification channel details — reused for all alerts
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'queue_channel',
    'Queue Notifications',
    channelDescription: 'Queue update notifications',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails notificationDetails =
  NotificationDetails(android: androidDetails);

  service.on('startTracking').listen((data) async {
    if (data == null) return;

    serviceName = data['serviceName'];
    userId = data['userId'];
    previousPosition = data['currentPosition'] ?? -1;

    debugPrint("Background tracking started for userId: $userId at position: $previousPosition");

    pollingTimer?.cancel();

    pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final url = Uri.parse("$_baseUrl/api/queue/user/$userId");

        // ✅ Added timeout so the timer doesn't hang
        final response = await http.get(url).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);

          if (data.isEmpty) {
            timer.cancel();
            service.stopSelf();
            return;
          }

          final queue = data.first;
          final int position = queue["position"] ?? 0;
          final String fetchedServiceName = queue["serviceName"] ?? serviceName;
          final String status = queue["status"] ?? "";

          debugPrint("Background position: $position");

          if (previousPosition != position) {
            // ✅ Fixed: use fixed IDs per alert type so they replace, not stack
            if (position == 3) {
              await notificationsPlugin.show(
                1001,
                "Almost Your Turn",
                "$fetchedServiceName - Only 2 people ahead",
                notificationDetails,
              );
              NotificationStore.addNotification(
                fetchedServiceName,
                "Almost Your Turn",
                "Only 2 people ahead of you. Get ready!",
              );
            } else if (position == 1) {
              await notificationsPlugin.show(
                1002,
                "You Are Next!",
                "$fetchedServiceName - Be ready to proceed to the counter",
                notificationDetails,
              );
              NotificationStore.addNotification(
                fetchedServiceName,
                "You Are Next",
                "Be ready to proceed to the service counter",
              );
            } else if (position == 0) {
              await notificationsPlugin.show(
                1003,
                "It's Your Turn!",
                "$fetchedServiceName - Please proceed to the counter now",
                notificationDetails,
              );
              // ✅ Fixed: was missing NotificationStore call for position 0
              NotificationStore.addNotification(
                fetchedServiceName,
                "It's Your Turn!",
                "Please proceed to the counter now",
              );
              timer.cancel();
              service.stopSelf();
              return;
            }

            previousPosition = position;
          }

          if (status == "SERVED" || status == "COMPLETED") {
            timer.cancel();
            service.stopSelf();
          }
        }
      } catch (e) {
        debugPrint("Background tracking error: $e");
      }
    });
  });

  service.on('stopTracking').listen((data) {
    pollingTimer?.cancel();
    service.stopSelf();
  });
}
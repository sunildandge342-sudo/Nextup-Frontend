import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/queue_notifications.dart';

class NotificationStore {
  static final List<QueueNotification> notifications = [];

  static const String _key = 'stored_notifications';

  // ✅ Load from SharedPreferences on app start
  static Future<void> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_key);
      if (stored != null) {
        final List decoded = jsonDecode(stored);
        notifications.clear();
        notifications.addAll(
          decoded.map((e) => QueueNotification.fromJson(e)).toList(),
        );
      }
    } catch (_) {}
  }

  // ✅ Save to SharedPreferences
  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded =
      jsonEncode(notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (_) {}
  }

  // ✅ Add and persist
  static Future<void> addNotification(
      String serviceName,
      String title,
      String message,
      ) async {
    notifications.insert(
      0,
      QueueNotification(
        serviceName: serviceName,
        title: title,
        message: message,
        time: DateTime.now(),
      ),
    );
    await _save();
  }

  // ✅ Clear all notifications
  static Future<void> clearNotifications() async {
    notifications.clear();
    await _save();
  }
}
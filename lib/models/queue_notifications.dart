class QueueNotification {
  final String serviceName;
  final String title;
  final String message;
  final DateTime time;

  QueueNotification({
    required this.serviceName,
    required this.title,
    required this.message,
    required this.time,
  });

  // ✅ Convert to JSON for saving
  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'title': title,
    'message': message,
    'time': time.toIso8601String(),
  };

  // ✅ Create from JSON for loading
  factory QueueNotification.fromJson(Map<String, dynamic> json) =>
      QueueNotification(
        serviceName: json['serviceName'] ?? '',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      );
}
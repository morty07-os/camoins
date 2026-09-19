class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type;
  final int? relatedId;
  final int? conversationId;
  final int? tripId;
  final int? requestId;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.conversationId,
    this.tripId,
    this.requestId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      relatedId: json['related_id'] as int?,
      conversationId: json['conversation_id'] as int?,
      tripId: json['trip_id'] as int?,
      requestId: json['request_id'] as int?,
      isRead: (json['is_read'] as int? ?? 0) == 1,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'related_id': relatedId,
      'conversation_id': conversationId,
      'trip_id': tripId,
      'request_id': requestId,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt,
    };
  }
}

class NotificationResponse {
  final List<AppNotification> notifications;
  final int unreadCount;

  NotificationResponse({
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      notifications: (json['notifications'] as List? ?? [])
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
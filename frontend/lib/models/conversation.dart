class Conversation {
  final int id;
  final int requestId;
  final int driverId;
  final int customerId;
  final String createdAt;
  final String? lastMessage;
  final String? lastMessageTime;
  final String? otherUserName;
  final int unreadCount;
  final String requestStatus;

  Conversation({
    required this.id,
    required this.requestId,
    required this.driverId,
    required this.customerId,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    this.otherUserName,
    this.unreadCount = 0,
    required this.requestStatus,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      requestId: json['request_id'],
      driverId: json['driver_id'],
      customerId: json['customer_id'],
      createdAt: json['created_at'],
      lastMessage: json['last_message']?['message'],
      lastMessageTime: json['last_message']?['created_at'],
      otherUserName: json['other_user_name'],
      unreadCount: json['unread_count'] ?? 0,
      requestStatus: json['request_status'],
    );
  }
}

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String message;
  final String createdAt;
  final String? readAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'] ?? 'Unknown',
      message: json['message'],
      createdAt: json['created_at'],
      readAt: json['read_at'],
    );
  }

  bool get isRead => readAt != null;
}

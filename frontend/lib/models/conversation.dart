class Conversation {
  final int id;
  final int requestId;
  final int driverId;
  final int customerId;
  final String createdAt;
  final String? lastMessage;
  final String? lastMessageTime;
  final int? lastMessageSenderId;
  final String? lastMessageSenderName;
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
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.otherUserName,
    this.unreadCount = 0,
    required this.requestStatus,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final lastMessage = json['last_message'];
    return Conversation(
      id: json['id'],
      requestId: json['request_id'],
      driverId: json['driver_id'],
      customerId: json['customer_id'],
      createdAt: json['created_at'],
      lastMessage: lastMessage?['message'],
      lastMessageTime: lastMessage?['created_at'],
      lastMessageSenderId: lastMessage?['sender_id'],
      lastMessageSenderName: lastMessage?['sender_name'],
      otherUserName: json['other_user_name'],
      unreadCount: json['unread_count'] ?? 0,
      requestStatus: json['request_status'],
    );
  }

  bool get hasUnread => unreadCount > 0;

  bool isLastMessageMine(int? userId) =>
      userId != null && lastMessageSenderId == userId;
}

enum MessageStatus { sending, sent, failed }

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String message;
  final String createdAt;
  final String? readAt;

  /// Client-generated id used to reconcile optimistic messages with the
  /// server broadcast (mirrors the server's `client_id` field).
  final String? clientId;

  final MessageStatus status;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.readAt,
    this.clientId,
    this.status = MessageStatus.sent,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _asInt(json['id']),
      conversationId: _asInt(json['conversation_id']),
      senderId: _asInt(json['sender_id']),
      senderName: json['sender_name'] ?? 'Unknown',
      message: json['message'] ?? '',
      createdAt: json['created_at'] ?? '',
      readAt: json['read_at'],
      clientId: json['client_id']?.toString(),
    );
  }

  /// Creates a local placeholder shown until the server confirms the message.
  factory Message.pending({
    required int conversationId,
    required int senderId,
    required String senderName,
    required String message,
    required String clientId,
  }) {
    return Message(
      id: -DateTime.now().microsecondsSinceEpoch,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      createdAt: DateTime.now().toIso8601String(),
      clientId: clientId,
      status: MessageStatus.sending,
    );
  }

  bool get isRead => readAt != null;

  bool get isPending => status == MessageStatus.sending;

  bool get isFailed => status == MessageStatus.failed;

  bool matches(String? otherClientId) =>
      clientId != null && otherClientId != null && clientId == otherClientId;

  Message copyWith({
    int? id,
    String? readAt,
    String? clientId,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }
}


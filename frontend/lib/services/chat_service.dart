import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../config/app_config.dart';
import '../models/conversation.dart';

/// A "messages read" broadcast emitted by the server.
class ReadReceipt {
  final int conversationId;
  final int readerId;
  final List<int> messageIds;
  final String? readAt;

  ReadReceipt({
    required this.conversationId,
    required this.readerId,
    required this.messageIds,
    this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    final ids = json['message_ids'];
    return ReadReceipt(
      conversationId: _asInt(json['conversation_id']),
      readerId: _asInt(json['reader_id']),
      messageIds: ids is List
          ? ids.map(_asInt).where((id) => id > 0).toList()
          : const <int>[],
      readAt: json['read_at']?.toString(),
    );
  }
}

/// A typing indicator broadcast emitted by the server.
class TypingEvent {
  final int conversationId;
  final int userId;
  final String userName;
  final bool isTyping;

  TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.userName,
    required this.isTyping,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) {
    return TypingEvent(
      conversationId: _asInt(json['conversation_id']),
      userId: _asInt(json['user_id']),
      userName: json['user_name']?.toString() ?? 'Unknown',
      isTyping: json['is_typing'] == true,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

/// Owns the single Socket.IO connection for the whole app.
///
/// Lifecycle guarantees:
/// * [initialize] is idempotent for the same token/host and never registers
///   duplicate listeners.
/// * Joined conversation rooms are remembered and re-joined on every
///   (re)connection.
/// * Consumers subscribe through broadcast streams instead of adding listeners
///   directly to the socket.
class ChatService {
  ChatService._internal();

  static final ChatService _instance = ChatService._internal();

  factory ChatService() => _instance;

  socket_io.Socket? _socket;
  String? _token;
  String? _url;
  bool _connected = false;
  bool _connecting = false;

  final Set<int> _desiredConversations = <int>{};

  final _messageController = StreamController<Message>.broadcast();
  final _readController = StreamController<ReadReceipt>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Message> get messages => _messageController.stream;
  Stream<ReadReceipt> get readReceipts => _readController.stream;
  Stream<TypingEvent> get typingEvents => _typingController.stream;
  Stream<bool> get connectionState => _connectionController.stream;

  bool get isConnected => _connected;
  /// Connects (or reconnects) to the socket using [token].
  ///
  /// Safe to call on every screen entry: the connection is reused when the
  /// token and host are unchanged.
  Future<void> initialize(String token, {String? baseUrl}) async {
    final url = baseUrl ?? AppConfig.baseUrl;

    if (_socket != null && _token == token && _url == url) {
      if (!_connected && !_connecting) _connect();
      return;
    }

    // Token or host changed: dispose the previous socket first so listeners
    // and the underlying connection are never duplicated.
    await _teardown();

    _token = token;
    _url = url;
    _socket = socket_io.io(
      url,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .setTimeout(20000)
          .setAuth({'token': token})
          .build(),
    );

    _bindEvents(_socket!);
    _connect();
  }

  void _connect() {
    final socket = _socket;
    if (socket == null || _connected || _connecting) return;
    _connecting = true;
    socket.connect();
  }

  void _bindEvents(socket_io.Socket socket) {
    socket.onConnect((_) {
      _connecting = false;
      _setConnected(true);
      _rejoinConversations();
    });

    socket.onDisconnect((_) {
      _connecting = false;
      _setConnected(false);
    });

    socket.onConnectError((error) {
      _connecting = false;
      _setConnected(false);
      if (kDebugMode) {
        debugPrint('Chat socket connection error: $error');
      }
    });

    socket.onReconnect((_) {
      _connecting = false;
      _setConnected(true);
      _rejoinConversations();
    });

    socket.onReconnectFailed((_) {
      _connecting = false;
      _setConnected(false);
    });

    socket.on('message-received', (dynamic data) {
      if (data is Map) {
        final message = Message.fromJson(Map<String, dynamic>.from(data));
        if (!_messageController.isClosed) _messageController.add(message);
      }
    });

    socket.on('messages-read', (dynamic data) {
      if (data is Map) {
        final receipt = ReadReceipt.fromJson(Map<String, dynamic>.from(data));
        if (!_readController.isClosed) _readController.add(receipt);
      }
    });

    socket.on('typing', (dynamic data) {
      if (data is Map) {
        final event = TypingEvent.fromJson(Map<String, dynamic>.from(data));
        if (!_typingController.isClosed) _typingController.add(event);
      }
    });
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_connectionController.isClosed) _connectionController.add(value);
  }

  void _rejoinConversations() {
    for (final id in _desiredConversations) {
      _socket?.emit('join-conversation', id);
    }
  }

  /// Joins a conversation room. Safe before the socket connects: the room is
  /// re-joined automatically once (re)connected.
  void joinConversation(int conversationId) {
    _desiredConversations.add(conversationId);
    if (_connected) _socket?.emit('join-conversation', conversationId);
  }

  void leaveConversation(int conversationId) {
    _desiredConversations.remove(conversationId);
    if (_connected) _socket?.emit('leave-conversation', conversationId);
  }

  /// Emits a message over the socket.
  ///
  /// Returns `false` when not connected so the caller can fall back to REST,
  /// guaranteeing the message is created exactly once.
  bool sendMessage(int conversationId, String message, {String? clientId}) {
    if (!_connected) return false;
    _socket?.emit('send-message', {
      'conversationId': conversationId,
      'message': message,
      'clientId': clientId,
    });
    return true;
  }

  void setTyping(int conversationId, bool isTyping) {
    if (!_connected) return;
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void markConversationRead(int conversationId) {
    if (!_connected) return;
    _socket?.emit('mark-read', {'conversationId': conversationId});
  }

  /// Disconnects the socket but keeps the singleton (and its streams) alive.
  Future<void> disconnect() => _teardown();

  Future<void> _teardown() async {
    final socket = _socket;
    _socket = null;
    _connected = false;
    _connecting = false;
    _token = null;
    _url = null;
    _desiredConversations.clear();

    if (socket != null) {
      try {
        socket.dispose();
      } catch (_) {
        /* already disposed */
      }
    }
  }

  bool get isConnecting => _connecting;
}

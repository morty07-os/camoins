import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../models/notification.dart';
import 'api_service.dart';
import 'chat_service.dart';
import 'storage_service.dart';

/// Single entry point for chat: UI never talks to HTTP or the socket directly.
///
/// It composes the REST API ([ApiService]) with the socket client
/// ([ChatService]) so the duplicate-creation rules live in one place.
class ChatRepository {
  ChatRepository({
    ApiService? apiService,
    ChatService? chatService,
    StorageService? storageService,
  })  : _api = apiService ?? ApiService(),
        _chat = chatService ?? ChatService(),
        _storage = storageService ?? StorageService();

  final ApiService _api;
  final ChatService _chat;
  final StorageService _storage;

  Stream<Message> get incomingMessages => _chat.messages;
  Stream<ReadReceipt> get readReceipts => _chat.readReceipts;
  Stream<TypingEvent> get typingEvents => _chat.typingEvents;
  Stream<bool> get connectionState => _chat.connectionState;
  Stream<AppNotification> get notifications => _chat.notifications;

  bool get isConnected => _chat.isConnected;

  /// Ensures the socket is connected using the stored token.
  Future<void> connect() async {
    final token = await _storage.getToken();
    if (token == null) return;
    await _chat.initialize(token);
  }

  Future<void> disconnect() => _chat.disconnect();

  Future<List<Conversation>> getConversations() => _api.getConversations();

  Future<List<Message>> getMessages(int conversationId) =>
      _api.getMessages(conversationId);

  void joinConversation(int conversationId) =>
      _chat.joinConversation(conversationId);

  void leaveConversation(int conversationId) =>
      _chat.leaveConversation(conversationId);

  void setTyping(int conversationId, bool isTyping) =>
      _chat.setTyping(conversationId, isTyping);

  void markConversationRead(int conversationId) =>
      _chat.markConversationRead(conversationId);

  Future<void> markMessageAsRead(int messageId) =>
      _api.markMessageAsRead(messageId);

  /// Sends a message exactly once.
  ///
  /// Prefers the socket while connected (the server persists and broadcasts it);
  /// otherwise falls back to REST. The optional [clientId] lets the UI reconcile
  /// the optimistic message with the server confirmation.
  ///
  /// Returns the confirmed [Message] for the REST fallback, or `null` when the
  /// message went out over the socket (confirmation arrives via
  /// [incomingMessages]).
  Future<Message?> sendMessage(
    int conversationId,
    String text, {
    String? clientId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    await connect();

    if (_chat.sendMessage(conversationId, trimmed, clientId: clientId)) {
      return null;
    }

    return _api.sendMessage(conversationId, trimmed, clientId: clientId);
  }
}

/// Shared chat repository used by the conversation list and chat screens.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});
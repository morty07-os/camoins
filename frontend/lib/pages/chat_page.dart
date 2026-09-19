import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import '../providers/auth_provider.dart';
import '../services/chat_repository.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/states.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late final ChatRepository _repository;

  Timer? _typingDebounce;
  Timer? _typingClear;
  bool _isLoading = true;
  String? _error;
  bool _isOtherTyping = false;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(chatRepositoryProvider);
    _initialize();
  }

  Future<void> _initialize() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Not authenticated';
        });
      }
      return;
    }

    // Idempotent: reuses the existing socket when already connected.
    await _repository.connect();
    _repository.joinConversation(widget.conversationId);

    _subscriptions.add(_repository.incomingMessages.listen(_onMessage));
    _subscriptions.add(_repository.readReceipts.listen(_onReadReceipt));
    _subscriptions.add(_repository.typingEvents.listen(_onTyping));
    _subscriptions.add(_repository.connectionState.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    }));

    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _repository.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _isLoading = false;
        _error = null;
      });
      _scrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les messages';
      });
    }
  }

  /// Handles a message broadcast by the server (own echo or from the peer).
  void _onMessage(Message incoming) {
    if (incoming.conversationId != widget.conversationId || !mounted) return;

    final user = ref.read(authProvider).currentUser;

    setState(() {
      final pendingIndex =
          _messages.indexWhere((m) => m.matches(incoming.clientId));
      if (pendingIndex != -1) {
        // Reconcile the optimistic message with the server confirmation.
        _messages[pendingIndex] = incoming;
        return;
      }

      final existingIndex = _messages.indexWhere((m) => m.id == incoming.id);
      if (existingIndex != -1) {
        _messages[existingIndex] = incoming;
        return;
      }

      // Guard against a duplicate echo of a message we already sent.
      final isDuplicate = incoming.clientId != null &&
          _messages.any((m) => m.matches(incoming.clientId));
      if (!isDuplicate) {
        _messages.add(incoming);
      }
    });

    if (user != null && incoming.senderId != user.id && !incoming.isRead) {
      _markRead(incoming);
    }

    _scrollToBottom();
  }

  void _onReadReceipt(ReadReceipt receipt) {
    if (receipt.conversationId != widget.conversationId || !mounted) return;

    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final message = _messages[i];
        // Only receipts for messages I sent matter for the check marks.
        if (message.senderId == receipt.readerId) continue;
        if (receipt.messageIds.contains(message.id) && !message.isRead) {
          _messages[i] = message.copyWith(
            readAt: receipt.readAt ?? DateTime.now().toIso8601String(),
          );
        }
      }
    });
  }

  void _onTyping(TypingEvent event) {
    if (event.conversationId != widget.conversationId || !mounted) return;

    final user = ref.read(authProvider).currentUser;
    if (user != null && event.userId == user.id) return;

    _typingClear?.cancel();
    setState(() => _isOtherTyping = event.isTyping);

    if (event.isTyping) {
      // Safety net in case a stop-typing event is lost.
      _typingClear = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _isOtherTyping = false);
      });
    }
  }

  Future<void> _markRead(Message message) async {
    try {
      await _repository.markMessageAsRead(message.id);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1 && !_messages[index].isRead) {
          _messages[index] = _messages[index].copyWith(
            readAt: DateTime.now().toIso8601String(),
          );
        }
      });
    } catch (_) {
      // Read receipts are best effort; ignore transient failures.
    }
  }

  void _onComposerChanged(String value) {
    if (ref.read(authProvider).currentUser == null) return;

    _repository.setTyping(widget.conversationId, value.trim().isNotEmpty);

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _repository.setTyping(widget.conversationId, false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    _messageController.clear();
    _onComposerChanged('');

    // Optimistic bubble, reconciled later through the shared clientId.
    final clientId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message.pending(
      conversationId: widget.conversationId,
      senderId: user.id,
      senderName: user.profile.fullName,
      message: text,
      clientId: clientId,
    );

    setState(() => _messages.add(pending));
    _scrollToBottom();

    try {
      // Sent exactly once: socket when connected, REST otherwise.
      final confirmed = await _repository.sendMessage(
        widget.conversationId,
        text,
        clientId: clientId,
      );

      if (!mounted) return;
      if (confirmed != null) {
        // REST fallback returned the persisted message directly.
        _replacePending(clientId, confirmed);
      }
    } catch (e) {
      if (!mounted) return;
      final index = _messages.indexWhere((m) => m.matches(clientId));
      if (index != -1) {
        setState(() => _messages[index] =
            _messages[index].copyWith(status: MessageStatus.failed));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec de l'envoi du message")),
      );
    }
  }

  void _replacePending(String clientId, Message confirmed) {
    setState(() {
      final index = _messages.indexWhere((m) => m.matches(clientId));
      if (index != -1) {
        _messages[index] = confirmed;
      } else if (!_messages.any((m) => m.id == confirmed.id)) {
        _messages.add(confirmed);
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingClear?.cancel();
    _repository.setTyping(widget.conversationId, false);
    _repository.leaveConversation(widget.conversationId);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        bottom: _isConnected
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(26),
                child: Container(
                  width: double.infinity,
                  color: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: const Text(
                    'Connexion perdue, reconnexion en cours...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(currentUserId)),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages(int? currentUserId) {
    if (_isLoading) {
      return const LoadingState(message: 'Chargement des messages...');
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _loadMessages();
        },
      );
    }

    if (_messages.isEmpty && !_isOtherTyping) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Aucun message',
        message: 'Démarrez la conversation avec votre interlocuteur.',
      );
    }

    // Newest first because the ListView is reversed.
    final ordered = _messages.reversed.toList();

    int? lastOwnMessageId;
    for (final message in ordered) {
      if (message.senderId == currentUserId) {
        lastOwnMessageId = message.id;
        break;
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ordered.length + (_isOtherTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isOtherTyping && index == 0) {
          return const _TypingBubble();
        }

        final message = ordered[_isOtherTyping ? index - 1 : index];
        final isMe = message.senderId == currentUserId;

        return _MessageBubble(
          message: message,
          isMe: isMe,
          showReadReceipt: isMe && message.id == lastOwnMessageId,
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: _onComposerChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Votre message...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _sendMessage,
              mini: true,
              child: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
/// Chat bubble with sender name, timestamp and read/sent receipt.
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showReadReceipt;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showReadReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white : AppColors.text;
    final metaColor = isMe ? Colors.white70 : AppColors.textSecondary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                message.senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.message,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatChatTime(message.createdAt),
                  style: TextStyle(fontSize: 11, color: metaColor),
                ),
                if (isMe && showReadReceipt) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isFailed
                        ? Icons.error_outline_rounded
                        : message.isPending
                            ? Icons.schedule_rounded
                            : message.isRead
                                ? Icons.done_all_rounded
                                : Icons.check_rounded,
                    size: 14,
                    color: message.isFailed ? AppColors.error : metaColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Typing..." indicator shown while the other participant is composing.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'En train d\'écrire...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
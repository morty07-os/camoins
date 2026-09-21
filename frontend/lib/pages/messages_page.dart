import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/conversation.dart';
import '../providers/auth_provider.dart';
import '../services/chat_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_avatar.dart';
import '../widgets/notification_icon.dart';
import '../widgets/states.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getConversations();
});

class MessagesPage extends ConsumerStatefulWidget {
  final int? initialConversationId;

  const MessagesPage({super.key, this.initialConversationId});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  StreamSubscription<dynamic>? _messagesSubscription;
  StreamSubscription<dynamic>? _readSubscription;

  @override
  void initState() {
    super.initState();

    final repository = ref.read(chatRepositoryProvider);
    repository.connect();

    // Keep the list fresh while the user is on this screen.
    _messagesSubscription =
        repository.incomingMessages.listen((_) => _refresh());
    _readSubscription = repository.readReceipts.listen((_) => _refresh());

    if (widget.initialConversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push('/chat/${widget.initialConversationId}');
      });
    }
  }

  void _refresh() {
    if (mounted) ref.invalidate(conversationsProvider);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _readSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUserId = ref.watch(authProvider).currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          const NotificationIcon(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          await ref.read(conversationsProvider.future);
        },
        child: conversationsAsync.when(
          data: (conversations) {
            if (conversations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Aucune conversation',
                    message:
                        'Vos discussions apparaîtront ici après l\'acceptation d\'une demande.',
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return _ConversationTile(
                  conversation: conversation,
                  currentUserId: currentUserId,
                  onTap: () async {
                    await context.push('/chat/${conversation.id}');
                    _refresh();
                  },
                );
              },
            );
          },
          loading: () =>
              const LoadingState(message: 'Chargement des conversations...'),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              ErrorState(
                message: 'Impossible de charger les conversations',
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the conversation list with avatar, preview and unread badge.
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int? currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.hasUnread;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: hasUnread ? AppColors.primarySoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AppAvatar(name: conversation.otherUserName, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherUserName ?? 'Utilisateur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (conversation.lastMessageTime != null &&
                          conversation.lastMessageTime!.isNotEmpty)
                        Text(
                          formatChatTime(conversation.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? AppColors.text
                                : AppColors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (conversation.requestStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'REQUEST: ${conversation.requestStatus}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _preview() {
    final lastMessage = conversation.lastMessage;
    if (lastMessage == null || lastMessage.isEmpty) {
      return 'Aucun message pour le moment';
    }
    return conversation.isLastMessageMine(currentUserId)
        ? 'Vous : $lastMessage'
        : lastMessage;
  }
}

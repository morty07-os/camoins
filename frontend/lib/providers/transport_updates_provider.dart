import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../services/chat_repository.dart';
import 'auth_provider.dart';

// Re-fetch persisted state on delivery events, socket recovery and app resume.
final transportUpdatesProvider = StateProvider<int>((ref) {
  ref.watch(authProvider.select((state) => state.currentUser?.id));
  final repository = ref.watch(chatRepositoryProvider);
  void changed() => ref.controller.state++;
  final notifications = repository.notifications.listen((event) {
    if (event.type == 'delivery_confirmation_requested' ||
        event.type == 'delivery_confirmed') {
      changed();
    }
  });
  final messages = repository.incomingMessages.listen((event) {
    if (event.isSystem) changed();
  });
  final connection = repository.connectionState.listen((connected) {
    if (connected) changed();
  });
  final lifecycle = AppLifecycleListener(onResume: changed);
  ref.onDispose(() {
    notifications.cancel();
    messages.cancel();
    connection.cancel();
    lifecycle.dispose();
  });
  repository.connect();
  return 0;
});

final conversationDetailsProvider = FutureProvider.autoDispose
    .family<Conversation, int>((ref, id) {
  ref.watch(transportUpdatesProvider);
  return ref.watch(chatRepositoryProvider).getConversation(id);
});

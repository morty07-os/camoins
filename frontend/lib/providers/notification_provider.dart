import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:backhaul_frontend/models/notification.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/chat_repository.dart';
import 'transport_updates_provider.dart';

/// State for the notification provider
class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool hasMore;
  final int offset;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
    this.offset = 0,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? hasMore,
    int? offset,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
    );
  }
}

/// Notifier for managing notification state with real-time updates
class NotificationNotifier extends AutoDisposeAsyncNotifier<NotificationState> {
  static const int _limit = 20;
  late final ApiService _apiService;
  late final ChatRepository _chatRepository;
  // ignore: unused_field
  StreamSubscription<AppNotification>? _notificationSubscription;

  @override
  Future<NotificationState> build() async {
    _apiService = ref.read(apiServiceProvider);
    _chatRepository = ref.read(chatRepositoryProvider);

    // Listen to real-time notifications
    _listenToRealtimeNotifications();
    ref.onDispose(() => _notificationSubscription?.cancel());
    ref.listen(transportUpdatesProvider, (_, __) {
      // REST restores notifications missed while the socket/app was offline.
      refresh().catchError((Object _) {});
    });

    // Load initial notifications
    return _loadNotifications(refresh: true);
  }

  void _listenToRealtimeNotifications() {
    _notificationSubscription = _chatRepository.notifications.listen((notification) {
      _handleRealtimeNotification(notification);
    }, onError: (error) {
      if (kDebugMode) {
        debugPrint('[NotificationProvider] Realtime notification error: $error');
      }
    });
  }

  void _handleRealtimeNotification(AppNotification notification) {
    // Avoid duplicates - check if notification already exists in list
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final exists = currentState.notifications.any((n) => n.id == notification.id);
    if (exists) {
      return;
    }

    // Prepend new notification to the list
    state = AsyncValue.data(currentState.copyWith(
      notifications: [notification, ...currentState.notifications],
      unreadCount: currentState.unreadCount + 1,
    ));

    if (kDebugMode) {
      debugPrint('[NotificationProvider] Realtime notification received: ${notification.type}');
    }
  }

  Future<NotificationState> _loadNotifications({bool refresh = false}) async {
    final currentState = state.valueOrNull;
    final offset = refresh ? 0 : (currentState?.offset ?? 0);

    if (!refresh) {
      state = AsyncValue.loading();
    }

    try {
      final response = await _apiService.getNotifications(
        limit: _limit,
        offset: offset,
      );

      final newNotifications = response.notifications;
      final updatedNotifications = refresh
          ? newNotifications
          : <AppNotification>[
              ...(currentState?.notifications ?? []),
              ...newNotifications,
            ];

      final newState = NotificationState(
        notifications: updatedNotifications,
        unreadCount: response.unreadCount,
        hasMore: newNotifications.length >= _limit,
        offset: offset + _limit,
      );

      state = AsyncValue.data(newState);
      return newState;
    } catch (e, stackTrace) {
      if (refresh) {
        state = AsyncValue.error(e, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> loadMore() async {
    final currentState = state.valueOrNull;
    if (currentState == null || !currentState.hasMore) return;
    await _loadNotifications();
  }

  Future<void> refresh() async {
    await _loadNotifications(refresh: true);
  }

  Future<void> markAsRead(int notificationId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final index = currentState.notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1 || currentState.notifications[index].isRead) return;

    try {
      await _apiService.markNotificationAsRead(notificationId);

      final updatedNotifications = [...currentState.notifications];
      updatedNotifications[index] = AppNotification(
        id: updatedNotifications[index].id,
        userId: updatedNotifications[index].userId,
        title: updatedNotifications[index].title,
        body: updatedNotifications[index].body,
        type: updatedNotifications[index].type,
        relatedId: updatedNotifications[index].relatedId,
        conversationId: updatedNotifications[index].conversationId,
        tripId: updatedNotifications[index].tripId,
        requestId: updatedNotifications[index].requestId,
        isRead: true,
        createdAt: updatedNotifications[index].createdAt,
      );

      state = AsyncValue.data(currentState.copyWith(
        notifications: updatedNotifications,
        unreadCount: (currentState.unreadCount - 1).clamp(0, currentState.unreadCount),
      ));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationProvider] Failed to mark as read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.unreadCount == 0) return;

    try {
      await _apiService.markAllNotificationsAsRead();

      final updatedNotifications = currentState.notifications.map((n) => n.isRead
          ? n
          : AppNotification(
              id: n.id,
              userId: n.userId,
              title: n.title,
              body: n.body,
              type: n.type,
              relatedId: n.relatedId,
              conversationId: n.conversationId,
              tripId: n.tripId,
              requestId: n.requestId,
              isRead: true,
              createdAt: n.createdAt,
            )).toList();

      state = AsyncValue.data(currentState.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      ));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationProvider] Failed to mark all as read: $e');
      }
    }
  }
}

/// Provider for the API service
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Main notification provider
final notificationProvider = AutoDisposeAsyncNotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);

/// Convenience provider for just the unread count
final unreadNotificationCountProvider = Provider<int>((ref) {
  final asyncState = ref.watch(notificationProvider);
  return asyncState.when(
    data: (state) => state.unreadCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Convenience provider for the notification list
final notificationListProvider = Provider<List<AppNotification>>((ref) {
  final asyncState = ref.watch(notificationProvider);
  return asyncState.when(
    data: (state) => state.notifications,
    loading: () => [],
    error: (_, __) => [],
  );
});

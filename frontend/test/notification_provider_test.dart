import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';
import 'package:backhaul_frontend/models/notification.dart';
import 'package:backhaul_frontend/providers/notification_provider.dart';
import 'package:backhaul_frontend/providers/transport_updates_provider.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/chat_repository.dart';
import 'package:backhaul_frontend/services/chat_service.dart';

class MockApiService extends Mock implements ApiService {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockChatService extends Mock implements ChatService {}

void main() {
  group('NotificationProvider', () {
    late MockApiService mockApiService;
    late MockChatRepository mockChatRepository;
    late StreamController<AppNotification> notificationController;

    setUp(() {
      mockApiService = MockApiService();
      mockChatRepository = MockChatRepository();
      notificationController = StreamController<AppNotification>.broadcast();

      when(() => mockChatRepository.notifications).thenAnswer((_) => notificationController.stream);
      when(() => mockChatRepository.isConnected).thenReturn(true);
    });

    tearDown(() {
      notificationController.close();
    });

    test('initial state loads notifications from API', () async {
      final testNotifications = [
        AppNotification(
          id: 1,
          userId: 1,
          title: 'Test',
          body: 'Test body',
          type: 'new_message',
          isRead: false,
          createdAt: '2026-09-19T10:00:00.000Z',
        ),
      ];

      when(() => mockApiService.getNotifications(limit: 20, offset: 0))
          .thenAnswer((_) async => NotificationResponse(
                notifications: testNotifications,
                unreadCount: 1,
              ));

      final container = ProviderContainer(
        overrides: [
          transportUpdatesProvider.overrideWith((ref) => 0),
          apiServiceProvider.overrideWithValue(mockApiService),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      // Wait for initial load
      await container.read(notificationProvider.future);

      final state = container.read(notificationProvider);
      expect(state.value?.notifications.length, 1);
      expect(state.value?.unreadCount, 1);
      expect(state.value?.notifications.first.title, 'Test');
    });

    test('realtime notification adds to list and increments unread count', () async {
      final existingNotifications = [
        AppNotification(
          id: 1,
          userId: 1,
          title: 'Existing',
          body: 'Existing body',
          type: 'new_message',
          isRead: true,
          createdAt: '2026-09-19T09:00:00.000Z',
        ),
      ];

      when(() => mockApiService.getNotifications(limit: 20, offset: 0))
          .thenAnswer((_) async => NotificationResponse(
                notifications: existingNotifications,
                unreadCount: 0,
              ));

      final container = ProviderContainer(
        overrides: [
          transportUpdatesProvider.overrideWith((ref) => 0),
          apiServiceProvider.overrideWithValue(mockApiService),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await container.read(notificationProvider.future);
      
      // Keep a listener to prevent auto-dispose
      final _ = container.listen<AsyncValue<NotificationState>>(
        notificationProvider,
        (_, __) {},
        fireImmediately: true,
      );
      
      // Initial state
      expect(container.read(notificationProvider).value?.unreadCount, 0);
      expect(container.read(notificationProvider).value?.notifications.length, 1);

      // Add realtime notification
      final newNotification = AppNotification(
        id: 2,
        userId: 1,
        title: 'Realtime',
        body: 'Realtime body',
        type: 'new_message',
        isRead: false,
        createdAt: '2026-09-19T10:00:00.000Z',
      );

      notificationController.add(newNotification);

      // Wait for stream to process and state to update
      await Future.microtask(() {});
      await Future.delayed(const Duration(milliseconds: 10));


      final state = container.read(notificationProvider);
      expect(state.value?.notifications.length, 2);
      expect(state.value?.unreadCount, 1);
      expect(state.value?.notifications.first.id, 2); // New notification prepended
    });

    test('duplicate realtime notification is ignored', () async {
      final testNotifications = [
        AppNotification(
          id: 1,
          userId: 1,
          title: 'Test',
          body: 'Test body',
          type: 'new_message',
          isRead: false,
          createdAt: '2026-09-19T10:00:00.000Z',
        ),
      ];

      when(() => mockApiService.getNotifications(limit: 20, offset: 0))
          .thenAnswer((_) async => NotificationResponse(
                notifications: testNotifications,
                unreadCount: 1,
              ));

      final container = ProviderContainer(
        overrides: [
          transportUpdatesProvider.overrideWith((ref) => 0),
          apiServiceProvider.overrideWithValue(mockApiService),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await container.read(notificationProvider.future);
      
      // Keep a listener to prevent auto-dispose
      container.listen<AsyncValue<NotificationState>>(
        notificationProvider,
        (_, __) {},
        fireImmediately: true,
      );

      // Send duplicate notification
      notificationController.add(testNotifications.first);
      await Future.delayed(const Duration(milliseconds: 10));

      // Should not add duplicate
      expect(container.read(notificationProvider).value?.notifications.length, 1);
      expect(container.read(notificationProvider).value?.unreadCount, 1);
    });

    test('markAsRead updates notification and decrements unread count', () async {
      final testNotifications = [
        AppNotification(
          id: 1,
          userId: 1,
          title: 'Test',
          body: 'Test body',
          type: 'new_message',
          isRead: false,
          createdAt: '2026-09-19T10:00:00.000Z',
        ),
      ];

      when(() => mockApiService.getNotifications(limit: 20, offset: 0))
          .thenAnswer((_) async => NotificationResponse(
                notifications: testNotifications,
                unreadCount: 1,
              ));
      when(() => mockApiService.markNotificationAsRead(1))
          .thenAnswer((_) async => AppNotification(
                id: 1,
                userId: 1,
                title: 'Test',
                body: 'Test body',
                type: 'new_message',
                isRead: true,
                createdAt: '2026-09-19T10:00:00.000Z',
              ));

      final container = ProviderContainer(
        overrides: [
          transportUpdatesProvider.overrideWith((ref) => 0),
          apiServiceProvider.overrideWithValue(mockApiService),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await container.read(notificationProvider.future);

      // Mark as read
      await container.read(notificationProvider.notifier).markAsRead(1);

      final state = container.read(notificationProvider);
      expect(state.value?.notifications.first.isRead, true);
      expect(state.value?.unreadCount, 0);
    });

    test('markAllAsRead marks all notifications as read', () async {
      final testNotifications = [
        AppNotification(
          id: 1,
          userId: 1,
          title: 'Test 1',
          body: 'Body 1',
          type: 'new_message',
          isRead: false,
          createdAt: '2026-09-19T10:00:00.000Z',
        ),
        AppNotification(
          id: 2,
          userId: 1,
          title: 'Test 2',
          body: 'Body 2',
          type: 'new_request',
          isRead: false,
          createdAt: '2026-09-19T11:00:00.000Z',
        ),
      ];

      when(() => mockApiService.getNotifications(limit: 20, offset: 0))
          .thenAnswer((_) async => NotificationResponse(
                notifications: testNotifications,
                unreadCount: 2,
              ));
      when(() => mockApiService.markAllNotificationsAsRead())
          .thenAnswer((_) async => 2);

      final container = ProviderContainer(
        overrides: [
          transportUpdatesProvider.overrideWith((ref) => 0),
          apiServiceProvider.overrideWithValue(mockApiService),
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await container.read(notificationProvider.future);

      // Mark all as read
      await container.read(notificationProvider.notifier).markAllAsRead();

      final state = container.read(notificationProvider);
      expect(state.value?.unreadCount, 0);
      expect(state.value?.notifications.every((n) => n.isRead), true);
    });
  });

  group('AppNotification timestamp parsing', () {
    test('parses ISO 8601 UTC timestamp correctly', () {
      final notification = AppNotification(
        id: 1,
        userId: 1,
        title: 'Test',
        body: 'Body',
        type: 'new_message',
        isRead: false,
        createdAt: '2026-09-19T16:04:32.000Z',
      );

      final parsed = DateTime.parse(notification.createdAt);
      expect(parsed.isUtc, true);
      expect(parsed.toIso8601String(), '2026-09-19T16:04:32.000Z');
    });

    test('parses legacy SQLite timestamp as local time', () {
      // This simulates the old format without timezone
      final notification = AppNotification(
        id: 1,
        userId: 1,
        title: 'Test',
        body: 'Body',
        type: 'new_message',
        isRead: false,
        createdAt: '2026-09-19 16:04:32',
      );

      final parsed = DateTime.parse(notification.createdAt);
      // Dart parses non-UTC strings as local time
      expect(parsed.isUtc, false);
    });
  });
}
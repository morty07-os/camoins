import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:backhaul_frontend/models/conversation.dart';
import 'package:backhaul_frontend/models/notification.dart';
import 'package:backhaul_frontend/models/user.dart';
import 'package:backhaul_frontend/pages/chat_page.dart';
import 'package:backhaul_frontend/pages/customer_history_page.dart';
import 'package:backhaul_frontend/providers/auth_provider.dart';
import 'package:backhaul_frontend/providers/notification_provider.dart';
import 'package:backhaul_frontend/providers/transport_updates_provider.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/chat_repository.dart';
import 'package:backhaul_frontend/services/notification_navigation_service.dart';
import 'package:backhaul_frontend/services/storage_service.dart';

final clientUser = User(id: 2, email: 'client@test', role: 'CUSTOMER',
    profile: UserProfile(fullName: 'Client'));
class TestAuth extends AuthNotifier {
  TestAuth(this.user) : super(ApiService(), StorageService());
  final User user;
  @override
  Future<void> loadCurrentUser() async {
    state = AuthState(currentUser: user, isAuthenticated: true);
  }
}
class TestChat extends ChatRepository {
  String status = 'AWAITING_CUSTOMER_CONFIRMATION';
  int confirmations = 0;
  final joined = <int>[];
  final left = <int>[];
  @override
  Future<void> connect() async {}
  @override
  void joinConversation(int id) => joined.add(id);
  @override
  void leaveConversation(int id) => left.add(id);
  @override
  void setTyping(int id, bool typing) {}
  @override
  Future<List<Message>> getMessages(int id) async => [Message(
    id: id, conversationId: id, senderId: 1, senderName: 'Chauffeur',
    message: 'Demande $id', createdAt: '2026-09-23T10:00:00Z',
  )];
  @override
  Future<Conversation> getConversation(int id) async => Conversation(
    id: id, requestId: 9, driverId: 1, customerId: 2,
    createdAt: '2026-09-23 10:00:00', requestStatus: status);
  @override
  Future<void> confirmReceipt(int requestId) async {
    expect(requestId, 9);
    confirmations++;
    status = 'COMPLETED';
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('History authenticates, parses SQLite numeric values and preserves HTTP/parsing errors', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    final api = ApiService(client: MockClient((request) async {
      expect(request.url.path.endsWith('/trips/history'), isTrue);
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(jsonEncode({'success': true, 'history': [{
        'id': 4, 'trip_id': 1, 'request_id': 4, 'type': 'request',
        'origin': 'Alger', 'destination': 'Oran', 'date': '2030-01-01',
        'status': 'COMPLETED', 'otherParty': {
          'id': 1, 'name': 'Chauffeur', 'role': 'DRIVER', 'rating': 0, 'rating_count': 0,
        },
      }]}), 200);
    }));
    expect((await api.getTripHistory()).history.single.otherParty!.rating, 0.0);
    final denied = ApiService(client: MockClient((_) async =>
        http.Response('{"message":"Session expirée"}', 401)));
    await expectLater(denied.getTripHistory(), throwsA(predicate((e) => e.toString().contains('Session expirée'))));
    final broken = ApiService(client: MockClient((_) async => http.Response('invalid JSON', 200)));
    await expectLater(broken.getTripHistory(), throwsA(predicate((e) => e.toString().contains('Réponse du serveur invalide'))));
  });

  testWidgets('Persisted awaiting state offers confirmation only to the owning customer and refreshes', (tester) async {
    final repository = TestChat();
    Future<void> show(User user) async {
      await tester.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [
        authProvider.overrideWith((ref) => TestAuth(user)),
        chatRepositoryProvider.overrideWithValue(repository),
        unreadNotificationCountProvider.overrideWithValue(0),
      ], child: const MaterialApp(home: ChatPage(conversationId: 7))));
      await tester.pumpAndSettle();
    }
    await show(User(id: 1, email: 'driver@test', role: 'DRIVER', profile: UserProfile(fullName: 'Chauffeur')));
    expect(find.text('En attente de confirmation du client'), findsOneWidget);
    expect(find.text('Confirmer la réception'), findsNothing);
    await show(User(id: 3, email: 'other@test', role: 'CUSTOMER', profile: UserProfile(fullName: 'Autre')));
    expect(find.text('Confirmer la réception'), findsNothing);
    await show(clientUser);
    expect(find.text('Confirmer la réception'), findsOneWidget);
    await tester.tap(find.text('Confirmer la réception'));
    await tester.pumpAndSettle();
    expect(repository.confirmations, 1);
    expect(find.text('Réception confirmée'), findsOneWidget);
    expect(find.text('Confirmer la réception'), findsNothing);
    // Reopening uses persisted status rather than the earlier socket event.
    await show(clientUser);
    expect(find.text('Réception confirmée'), findsOneWidget);
  });

  testWidgets('Completion notification opens its explicit conversation', (tester) async {
    final notification = AppNotification(id: 1, userId: 2, title: 'Confirmation', body: '',
      type: 'delivery_confirmation_requested', relatedId: 9, requestId: 9, tripId: 3,
      conversationId: 7, isRead: true, createdAt: '2026-09-23');
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => TextButton(
        onPressed: () => NotificationNavigationService.handleNotificationTap(notification, context, clientUser),
        child: const Text('Ouvrir'))),
      GoRoute(path: '/chat/:id', builder: (_, state) => Text('Discussion ${state.pathParameters['id']}')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Discussion 7'), findsOneWidget);
  });

  testWidgets('Changing the open conversation clears the previous request messages', (tester) async {
    final repository = TestChat();
    final selected = ValueNotifier(7);
    addTearDown(selected.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => TestAuth(clientUser)),
      chatRepositoryProvider.overrideWithValue(repository),
      unreadNotificationCountProvider.overrideWithValue(0),
    ], child: MaterialApp(home: ValueListenableBuilder<int>(
      valueListenable: selected,
      builder: (_, id, __) => ChatPage(conversationId: id),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Demande 7'), findsOneWidget);
    selected.value = 8;
    await tester.pumpAndSettle();
    expect(find.text('Demande 7'), findsNothing);
    expect(find.text('Demande 8'), findsOneWidget);
    expect(repository.left, contains(7));
    expect(repository.joined.last, 8);
  });

  testWidgets('Mounted history refreshes after confirmation without restarting', (tester) async {
    bool completed = false;
    final api = ApiService(client: MockClient((_) async => http.Response(jsonEncode({
      'success': true, 'history': completed ? [{
        'id': 9, 'trip_id': 3, 'request_id': 9, 'type': 'request',
        'origin': 'Alger', 'destination': 'Oran', 'date': '2030-01-01', 'status': 'COMPLETED',
      }] : [],
    }), 200)));
    final container = ProviderContainer(overrides: [
      apiServiceProvider.overrideWithValue(api),
      transportUpdatesProvider.overrideWith((ref) => 0),
      unreadNotificationCountProvider.overrideWithValue(0),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: CustomerHistoryPage())));
    await tester.pumpAndSettle();
    expect(find.text('Alger'), findsNothing);
    completed = true;
    container.read(transportUpdatesProvider.notifier).state++;
    await tester.pumpAndSettle();
    expect(find.textContaining('Alger'), findsWidgets);
  });
}

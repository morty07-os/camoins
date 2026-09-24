import 'package:backhaul_frontend/main.dart';
import 'package:backhaul_frontend/models/conversation.dart';
import 'package:backhaul_frontend/models/notification.dart';
import 'package:backhaul_frontend/models/rating.dart' hide UserProfile;
import 'package:backhaul_frontend/models/user.dart';
import 'package:backhaul_frontend/pages/messages_page.dart';
import 'package:backhaul_frontend/providers/auth_provider.dart';
import 'package:backhaul_frontend/providers/notification_provider.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/notification_navigation_service.dart';
import 'package:backhaul_frontend/services/storage_service.dart';
import 'package:backhaul_frontend/widgets/notification_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CustomerAuthNotifier extends AuthNotifier {
  _CustomerAuthNotifier() : super(ApiService(), StorageService());

  @override
  Future<void> loadCurrentUser() async {
    state = AuthState(
      currentUser: User(
        id: 7,
        email: 'customer@test.com',
        role: 'CUSTOMER',
        profile: UserProfile(fullName: 'Test Customer'),
      ),
      isAuthenticated: true,
      isLoading: false,
    );
  }
}

class _FakeApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> searchTrips({
    String? originName,
    double? originLat,
    double? originLng,
    String? destinationName,
    double? destinationLat,
    double? destinationLng,
    String? date,
    double? requiredWeight,
    double? requiredVolume,
    String? truckType,
    int page = 1,
    int pageSize = 20,
  }) async =>
      {
        'success': true,
        'trips': const [],
        'count': 0,
        'page': page,
        'pageSize': pageSize,
        'totalPages': 0,
      };

  @override
  Future<NotificationResponse> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async =>
      NotificationResponse(notifications: const [], unreadCount: 0);

  @override
  Future<HistoryResponse> getTripHistory() async =>
      HistoryResponse(success: true, history: const []);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpCustomerApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _CustomerAuthNotifier()),
          unreadNotificationCountProvider.overrideWith((ref) => 0),
          conversationsProvider.overrideWith(
            (ref) async => <Conversation>[],
          ),
          apiServiceProvider.overrideWith((ref) => _FakeApiService()),
        ],
        child: const BackhaulApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  NavigationBar navigationBar(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar));

  testWidgets('customer can switch all five tabs with the correct selection',
      (tester) async {
    await pumpCustomerApp(tester);

    expect(navigationBar(tester).selectedIndex, 0);

    for (final entry in <String, int>{
      'Trajets': 1,
      'Messages': 2,
      'Historique': 3,
      'Profil': 4,
    }.entries) {
      await tester.tap(find.text(entry.key).last);
      await tester.pumpAndSettle();
      expect(navigationBar(tester).selectedIndex, entry.value);
    }
  });

  testWidgets('trip filters survive tab switches', (tester) async {
    await pumpCustomerApp(tester);

    await tester.tap(find.text('Trajets').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Poids min. (kg)'),
      '1250',
    );

    await tester.tap(find.text('Accueil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trajets').last);
    await tester.pumpAndSettle();

    expect(find.text('1250'), findsOneWidget);
    expect(navigationBar(tester).selectedIndex, 1);
  });

  testWidgets('notifications use a pushed route with working back navigation',
      (tester) async {
    await pumpCustomerApp(tester);

    await tester.tap(find.byType(NotificationIcon));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(navigationBar(tester).selectedIndex, 0);
  });

  testWidgets('customer notification links open conversation and trip details',
      (tester) async {
    final customer = User(
      id: 7,
      email: 'customer@test.com',
      role: 'CUSTOMER',
      profile: UserProfile(fullName: 'Test Customer'),
    );

    Future<void> verifyNotification({
      required AppNotification notification,
      required String expectedText,
    }) async {
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    NotificationNavigationService.handleNotificationTap(
                  notification,
                  context,
                  customer,
                ),
                child: const Text('Open notification'),
              ),
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) =>
                Text('Chat ${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/search-trip-details/:id',
            builder: (context, state) =>
                Text('Trip ${state.pathParameters['id']}'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open notification'));
      await tester.pumpAndSettle();
      expect(find.text(expectedText), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open notification'), findsOneWidget);
    }

    await verifyNotification(
      notification: AppNotification(
        id: 1,
        userId: 7,
        title: 'Message',
        body: 'Nouveau message',
        type: 'new_message',
        conversationId: 42,
        isRead: true,
        createdAt: '2026-09-24T12:00:00Z',
      ),
      expectedText: 'Chat 42',
    );

    await verifyNotification(
      notification: AppNotification(
        id: 2,
        userId: 7,
        title: 'Trajet',
        body: 'Demande mise à jour',
        type: 'new_request',
        tripId: 88,
        isRead: true,
        createdAt: '2026-09-24T12:00:00Z',
      ),
      expectedText: 'Trip 88',
    );
  });
}

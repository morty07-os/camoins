import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:backhaul_frontend/pages/driver_home_page.dart';
import 'package:backhaul_frontend/widgets/notification_icon.dart';
import 'package:backhaul_frontend/widgets/curved_transport_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backhaul_frontend/main.dart';
import 'package:backhaul_frontend/models/user.dart';
import 'package:backhaul_frontend/providers/auth_provider.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/storage_service.dart';

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier() : super(ApiService(), StorageService());

  @override
  Future<void> loadCurrentUser() async {
    state = AuthState(
      currentUser: User(
        id: 1,
        email: 'driver@test.com',
        role: 'DRIVER',
        profile: UserProfile(
          fullName: 'Test Driver',
          phone: '0555123456',
          city: 'Algiers',
          wilaya: 'Alger',
        ),
      ),
      isAuthenticated: true,
      isLoading: false,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier()),
        ],
        child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: BackhaulApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Driver lands on Dashboard and it is not blank', (tester) async {
    await pumpAuthenticatedApp(tester);

    expect(find.text('Tableau de bord'), findsWidgets);
    expect(find.textContaining('Test Driver'), findsOneWidget);
    expect(find.text('0555123456'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);
    expect(find.text('Camions'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('Driver can navigate to My Trucks tab', (tester) async {
    await pumpAuthenticatedApp(tester);

    await tester.tap(find.text('Camions'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un camion'), findsOneWidget);
  });

  testWidgets('Driver can navigate to Profil tab', (tester) async {
    await pumpAuthenticatedApp(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);
    expect(find.text('Test Driver'), findsOneWidget);
  });

  testWidgets('Driver can navigate to My Return Trips tab', (tester) async {
    await pumpAuthenticatedApp(tester);

    await tester.tap(find.text('Retours'));
    await tester.pumpAndSettle();

    expect(find.text('Publier le trajet'), findsOneWidget);
  });

  testWidgets('driver branches retain scroll and follow route changes and back',
      (tester) async {
    await pumpAuthenticatedApp(tester);
    final home = tester.element(find.byType(DriverHomePage));
    final router = GoRouter.of(home);
    final scroll = find.descendant(
        of: find.byType(DriverHomePage), matching: find.byType(Scrollable));
    await tester.drag(scroll, const Offset(0, -240));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scroll).position.pixels;
    for (final entry in <String, int>{
      '/driver-trucks': 1,
      '/driver-trips': 2,
      '/driver-history': 3,
      '/driver-messages': 4,
      '/driver-profile': 5,
    }.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<CurvedTransportBar>(find.byType(CurvedTransportBar))
              .selectedIndex,
          entry.value);
    }
    router.go('/driver-home');
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(DriverHomePage)), same(home));
    expect(tester.state<ScrollableState>(scroll).position.pixels, offset);
    await tester.tap(find.byType(NotificationIcon));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CurvedTransportBar>(find.byType(CurvedTransportBar))
            .selectedIndex,
        0);
  });

  testWidgets('driver mobile dashboard visual', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAuthenticatedApp(tester);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/driver_dashboard.png'));
  });
}

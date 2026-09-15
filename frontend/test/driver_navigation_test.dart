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
        child: const BackhaulApp(),
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
    expect(find.text('Mes camions'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('Driver can navigate to My Trucks tab', (tester) async {
    await pumpAuthenticatedApp(tester);

    await tester.tap(find.text('Mes camions'));
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

    await tester.tap(find.text('Mes trajets retour'));
    await tester.pumpAndSettle();

    expect(find.text('Publier le trajet'), findsOneWidget);
  });
}
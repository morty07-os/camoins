import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:backhaul_frontend/login_page.dart';
import 'package:backhaul_frontend/models/user.dart';
import 'package:backhaul_frontend/providers/auth_provider.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/storage_service.dart';

class MockApi extends Mock implements ApiService {}
class MockStorage extends Mock implements StorageService {}

void main() {
  late MockApi api;
  late MockStorage storage;
  final user = User(id: 1, email: 'user@example.com', role: 'CUSTOMER',
      profile: UserProfile(fullName: 'Customer'));

  setUp(() {
    api = MockApi();
    storage = MockStorage();
    when(() => storage.getToken()).thenAnswer((_) async => 'saved-token');
    when(() => storage.deleteToken()).thenAnswer((_) async {});
  });

  test('temporary failure preserves token and retry restores session', () async {
    when(() => api.getCurrentUser('saved-token')).thenAnswer((_) async =>
        {'success': false, 'message': 'Cannot connect to the server'});
    final notifier = AuthNotifier(api, storage);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.sessionRestoreFailed, isTrue);
    expect(notifier.state.isLoading, isFalse);
    verifyNever(() => storage.deleteToken());

    when(() => api.getCurrentUser('saved-token')).thenAnswer((_) async =>
        {'success': true, 'user': user});
    await notifier.loadCurrentUser();
    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.currentUser, user);
    expect(notifier.state.sessionRestoreFailed, isFalse);
    expect(notifier.state.error, isNull);
    verifyNever(() => storage.deleteToken());

    when(() => api.getCurrentUser('saved-token')).thenAnswer((_) async =>
        {'success': false, 'message': 'Server unavailable'});
    await notifier.loadCurrentUser();
    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.currentUser, user);
    verifyNever(() => storage.deleteToken());
  });

  test('invalid authentication clears token', () async {
    when(() => api.getCurrentUser('saved-token')).thenAnswer((_) async =>
        {'success': false, 'unauthorized': true});
    final notifier = AuthNotifier(api, storage);
    addTearDown(notifier.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.sessionRestoreFailed, isFalse);
    verify(() => storage.deleteToken()).called(1);
  });

  testWidgets('login offers retry after a temporary session failure', (tester) async {
    when(() => api.getCurrentUser('saved-token')).thenAnswer((_) async =>
        {'success': false});
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => AuthNotifier(api, storage))],
      child: const MaterialApp(home: LoginPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer ma session'), findsOneWidget);
    await tester.ensureVisible(find.text('Réessayer ma session'));
    await tester.tap(find.text('Réessayer ma session'));
    await tester.pumpAndSettle();
    verify(() => api.getCurrentUser('saved-token')).called(2);
    verifyNever(() => storage.deleteToken());
  });
}

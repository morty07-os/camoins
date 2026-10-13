import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:backhaul_frontend/config/app_config.dart';
import 'package:backhaul_frontend/models/search_result.dart';
import 'package:backhaul_frontend/services/api_service.dart';
import 'package:backhaul_frontend/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService().deleteToken();
  });

  test('bearer tokens never persist in shared preferences', () async {
    final storage = StorageService();
    await storage.saveToken('private-token');
    expect(await StorageService().getToken(), 'private-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('auth_token'), isFalse);
    if (!kIsWeb) {
      expect(await const FlutterSecureStorage().read(key: 'auth_token'), 'private-token');
    }
    await storage.deleteToken();
    expect(await storage.getToken(), isNull);
  });

  test('legacy plaintext tokens are discarded', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'legacy-token');
    expect(await StorageService().getToken(), isNull);
    expect(prefs.containsKey('auth_token'), isFalse);
  });

  test('public driver data no longer requires an email', () {
    final driver = DriverInfo.fromJson({ 'id': 1, 'full_name': 'Driver', 'rating': 0, 'rating_count': 0 });
    expect(driver.fullName, 'Driver');
    expect(driver.email, isEmpty);
  });

  test('logout distinguishes revocation, expiry, and network failure', () async {
    for (final status in [200, 401, 500]) {
      final api = ApiService(client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/logout');
        expect(request.headers['Authorization'], 'Bearer private-token');
        return http.Response('{}', status);
      }));
      expect(await api.logout('private-token'), status != 500);
    }
    final offline = ApiService(client: MockClient((_) async => throw http.ClientException('offline')));
    expect(await offline.logout('private-token'), isFalse);
  });

  test('backend configuration rejects unsafe or malformed URLs', () async {
    for (final url in ['javascript:alert(1)', 'file:///tmp/backend', 'https://user:password@example.com', 'https://example.com?token=x', 'https://example.com/#fragment']) {
      await expectLater(AppConfig.setBaseUrl(url), throwsArgumentError);
    }
    await AppConfig.setBaseUrl('https://example.com/');
    expect(AppConfig.baseUrl, 'https://example.com');
    await AppConfig.clearBaseUrlOverride();
  });
}

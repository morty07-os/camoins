import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for every backend URL used by the app.
///
/// The value can be provided at build time with
/// `--dart-define=API_BASE_URL=http://host:port` or overridden at runtime with
/// the `backend_url` shared preference (useful for testing on real devices).
class AppConfig {
  AppConfig._();

  static const String _defineBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _prefsBaseUrlKey = 'backend_url';

  static String? _overrideBaseUrl;

  /// Platform-aware default so emulators/simulators work without configuration.
  static String get defaultBaseUrl {
    if (_defineBaseUrl.isNotEmpty) {
      return _normalize(_defineBaseUrl);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulators reach the host machine through 10.0.2.2.
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  /// Base URL of the backend (no trailing slash), including any runtime override.
  static String get baseUrl => _overrideBaseUrl ?? defaultBaseUrl;

  /// Base URL of the REST API.
  static String get apiBaseUrl => '$baseUrl/api';

  /// Resolves the runtime override once, during app start-up.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsBaseUrlKey);
    if (stored != null && stored.trim().isNotEmpty) {
      _overrideBaseUrl = _normalize(stored);
    }
  }

  /// Overrides the base URL at runtime (persisted across launches).
  static Future<void> setBaseUrl(String value) async {
    final normalized = _normalize(value);
    _overrideBaseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsBaseUrlKey, normalized);
  }

  /// Clears the runtime override, falling back to the platform default.
  static Future<void> clearBaseUrlOverride() async {
    _overrideBaseUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsBaseUrlKey);
  }

  static String _normalize(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

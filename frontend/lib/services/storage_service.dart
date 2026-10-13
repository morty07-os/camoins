import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/notification.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage();
  // Browser tokens live only in this tab's memory, never localStorage.
  static String? _webToken;
  static const String _tokenKey = 'auth_token';
  static const String _pendingNotificationKey = 'pending_notification';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    if (kIsWeb) {
      _webToken = token;
    } else {
      await _secureStorage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    if (kIsWeb) return _webToken;
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _webToken = null;
    if (!kIsWeb) await _secureStorage.delete(key: _tokenKey);
  }

  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> savePendingNotification(AppNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingNotificationKey, jsonEncode(notification.toJson()));
  }

  Future<AppNotification?> getAndClearPendingNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingNotificationKey);
    if (jsonString != null) {
      await prefs.remove(_pendingNotificationKey);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppNotification.fromJson(jsonMap);
    }
    return null;
  }
}

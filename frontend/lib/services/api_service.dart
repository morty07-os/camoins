import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone': phone,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'user': User.fromJson(data['user']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get user',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String fullName,
    String? phone,
    String? city,
    String? wilaya,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'full_name': fullName,
          'phone': phone,
          'city': city,
          'wilaya': wilaya,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'profile': UserProfile.fromJson(data['profile']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }
}

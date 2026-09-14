import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/truck.dart';

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

  Future<Map<String, dynamic>> getMyTrucks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trucks/my'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'trucks': (data['trucks'] as List? ?? []).map((truck) => Truck.fromJson(truck)).toList(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get trucks',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> createTruck({
    required String truck_type,
    String brand = '',
    String model = '',
    required double max_weight,
    double? max_volume,
    String registration_number = '',
    String image_url = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trucks'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'truck_type': truck_type,
          'brand': brand,
          'model': model,
          'max_weight': max_weight,
          'max_volume': max_volume,
          'registration_number': registration_number,
          'image_url': image_url,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'truck': Truck.fromJson(data['truck']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create truck',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> updateTruck(
    int id, {
    required String truck_type,
    String brand = '',
    String model = '',
    required double max_weight,
    double? max_volume,
    String registration_number = '',
    String image_url = '',
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trucks/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'truck_type': truck_type,
          'brand': brand,
          'model': model,
          'max_weight': max_weight,
          'max_volume': max_volume,
          'registration_number': registration_number,
          'image_url': image_url,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'truck': Truck.fromJson(data['truck']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update truck',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> deleteTruck(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trucks/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete truck',
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
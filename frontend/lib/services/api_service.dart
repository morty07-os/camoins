import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/truck.dart';
import '../models/trip.dart';
import '../models/transport_request.dart';
import '../models/conversation.dart';
import 'storage_service.dart';

class ApiService {
  /// REST base URL resolved from [AppConfig] (no hardcoded hosts).
  static String get baseUrl => AppConfig.apiBaseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final token = await StorageService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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
        headers: await _authHeaders(),
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

  Future<Map<String, dynamic>> getTruck(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trucks/$id'),
        headers: await _authHeaders(),
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
          'message': data['message'] ?? 'Failed to get truck',
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
    required String truckType,
    String brand = '',
    String model = '',
    required double maxWeight,
    double? maxVolume,
    String registrationNumber = '',
    String imageUrl = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trucks'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'truck_type': truckType,
          'brand': brand,
          'model': model,
          'max_weight': maxWeight,
          'max_volume': maxVolume,
          'registration_number': registrationNumber,
          'image_url': imageUrl,
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
    required String truckType,
    String brand = '',
    String model = '',
    required double maxWeight,
    double? maxVolume,
    String registrationNumber = '',
    String imageUrl = '',
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trucks/$id'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'truck_type': truckType,
          'brand': brand,
          'model': model,
          'max_weight': maxWeight,
          'max_volume': maxVolume,
          'registration_number': registrationNumber,
          'image_url': imageUrl,
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
        headers: await _authHeaders(),
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

  Future<Map<String, dynamic>> getMyTrips() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/my'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'trips': (data['trips'] as List? ?? [])
              .map((trip) => Trip.fromJson(trip))
              .toList(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get trips',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> getTrip(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$id'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'trip': Trip.fromJson(data['trip']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get trip',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> createTrip({
    required int truckId,
    required String originName,
    double? originLat,
    double? originLng,
    required String destinationName,
    double? destinationLat,
    double? destinationLng,
    required String departureDate,
    required double availableWeight,
    double? availableVolume,
    String tripType = 'RETURN',
    String description = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'truck_id': truckId,
          'origin_name': originName,
          'origin_lat': originLat,
          'origin_lng': originLng,
          'destination_name': destinationName,
          'destination_lat': destinationLat,
          'destination_lng': destinationLng,
          'departure_date': departureDate,
          'available_weight': availableWeight,
          'available_volume': availableVolume,
          'trip_type': tripType,
          'description': description,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'trip': Trip.fromJson(data['trip']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create trip',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> updateTrip(
    int id, {
    required int truckId,
    required String originName,
    double? originLat,
    double? originLng,
    required String destinationName,
    double? destinationLat,
    double? destinationLng,
    required String departureDate,
    required double availableWeight,
    double? availableVolume,
    String description = '',
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$id'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'truck_id': truckId,
          'origin_name': originName,
          'origin_lat': originLat,
          'origin_lng': originLng,
          'destination_name': destinationName,
          'destination_lat': destinationLat,
          'destination_lng': destinationLng,
          'departure_date': departureDate,
          'available_weight': availableWeight,
          'available_volume': availableVolume,
          'description': description,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'trip': Trip.fromJson(data['trip']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update trip',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> deleteTrip(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$id'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete trip',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> _tripAction(int id, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$id/$action'),
        headers: await _authHeaders(),
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'trip': Trip.fromJson(data['trip']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Action failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> startTrip(int id) => _tripAction(id, 'start');

  Future<Map<String, dynamic>> completeTrip(int id) =>
      _tripAction(id, 'complete');

  Future<Map<String, dynamic>> cancelTrip(int id) =>
      _tripAction(id, 'cancel');

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

  Future<Map<String, dynamic>> searchTrips({
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    required String date,
    required double requiredWeight,
    double? requiredVolume,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/search/trips').replace(
        queryParameters: {
          if (originLat != null) 'origin_lat': originLat.toString(),
          if (originLng != null) 'origin_lng': originLng.toString(),
          if (destinationLat != null) 'destination_lat': destinationLat.toString(),
          if (destinationLng != null) 'destination_lng': destinationLng.toString(),
          'date': date,
          'required_weight': requiredWeight.toString(),
          if (requiredVolume != null) 'required_volume': requiredVolume.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'trips': data['trips'] as List? ?? [],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to search trips',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  // Transport Request APIs

  Future<Map<String, dynamic>> createRequest({
    required int tripId,
    required double requestedWeight,
    double? requestedVolume,
    String? cargoDescription,
    String? pickupLocation,
    String? deliveryLocation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'trip_id': tripId,
          'requested_weight': requestedWeight,
          if (requestedVolume != null) 'requested_volume': requestedVolume,
          if (cargoDescription != null) 'cargo_description': cargoDescription,
          if (pickupLocation != null) 'pickup_location': pickupLocation,
          if (deliveryLocation != null) 'delivery_location': deliveryLocation,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'request': TransportRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to create request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> getMyRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/my'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'requests': (data['requests'] as List? ?? [])
              .map((r) => TransportRequest.fromJson(r))
              .toList(),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get requests',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> getRequest(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/$id'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'request': TransportRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> acceptRequest(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$id/accept'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'request': TransportRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to accept request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> rejectRequest(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$id/reject'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'request': TransportRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reject request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> cancelRequest(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$id/cancel'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'request': TransportRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to cancel request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }

  Future<Map<String, dynamic>> completeRequest(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$id/complete'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'request': TransportRequest.fromJson(data['request']),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to complete request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to the server',
      };
    }
  }
// ---- Chat (conversations & messages) ----

  Future<List<Conversation>> getConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['conversations'] as List)
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(response.body, 'Failed to load conversations'));
  }

  Future<List<Message>> getMessages(int conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['messages'] as List)
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(response.body, 'Failed to load messages'));
  }

  /// Creates a message through REST.
  ///
  /// This is the fallback path used when the socket is unavailable. Callers
  /// should prefer the socket while connected so a message is never created
  /// twice (see `ChatRepository.sendMessage`).
  Future<Message> sendMessage(
    int conversationId,
    String message, {
    String? clientId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'message': message,
        if (clientId != null) 'client_id': clientId,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      return Message.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Failed to send message');
  }

  Future<void> markMessageAsRead(int messageId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/messages/$messageId/read'),
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        _errorMessage(response.body, 'Failed to mark message as read'),
      );
    }
  }

  String _errorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    } catch (_) {
      /* keep fallback */
    }
    return fallback;
  }
}
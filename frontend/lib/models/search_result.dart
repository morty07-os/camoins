import 'trip.dart';
import 'truck.dart';

class DriverInfo {
  final int id;
  final String email;
  final String fullName;
  final double rating;
  final int ratingCount;

  DriverInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.rating,
    required this.ratingCount,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      ratingCount: json['rating_count'] ?? 0,
    );
  }
}

class TripSearchResult {
  final Trip trip;
  final DriverInfo driver;
  final Truck truck;
  final int matchScore;

  TripSearchResult({
    required this.trip,
    required this.driver,
    required this.truck,
    required this.matchScore,
  });

  factory TripSearchResult.fromJson(Map<String, dynamic> json) {
    return TripSearchResult(
      trip: Trip.fromJson(json['trip']),
      driver: DriverInfo.fromJson(json['driver']),
      truck: Truck.fromJson(json['truck']),
      matchScore: json['matchScore'] ?? 0,
    );
  }

  String get routeLabel => '${trip.originName} → ${trip.destinationName}';

  String get capacityLabel =>
      '${_formatNumber(trip.availableWeight)} kg disponibles';

  String get driverRatingLabel =>
      '${driver.rating.toStringAsFixed(1)} ★ (${driver.ratingCount})';

  double get rating => driver.rating;

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

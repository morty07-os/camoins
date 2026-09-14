class Truck {
  final int id;
  final int driverId;
  final String truckType; // Internal: FLATBED, TARP, REFRIGERATED, VAN, SEMI_TRAILER, OTHER
  final String brand;
  final String model;
  final double maxWeight;
  final double? maxVolume;
  final String registrationNumber;
  final String? imageUrl;
  final String createdAt;
  final String updatedAt;

  Truck({
    required this.id,
    required this.driverId,
    required this.truckType,
    this.brand = '',
    this.model = '',
    required this.maxWeight,
    this.maxVolume,
    this.registrationNumber = '',
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json['id'],
      driverId: json['driver_id'],
      truckType: json['truck_type'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      maxWeight: (json['max_weight'] ?? 0).toDouble(),
      maxVolume: json['max_volume']?.toDouble(),
      registrationNumber: json['registration_number'] ?? '',
      imageUrl: json['image_url'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'truck_type': truckType,
      'brand': brand,
      'model': model,
      'max_weight': maxWeight,
      'max_volume': maxVolume,
      'registration_number': registrationNumber,
      'image_url': imageUrl,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // French display names for truck types
  static const Map<String, String> truckTypeDisplayNames = {
    'FLATBED': 'Plateau',
    'TARP': 'Camion bâché',
    'REFRIGERATED': 'Camion frigorifique',
    'VAN': 'Fourgon',
    'SEMI_TRAILER': 'Semi-remorque',
    'OTHER': 'Autre',
  };

  // Get French display name
  String get displayName => truckTypeDisplayNames[truckType] ?? truckType;
}
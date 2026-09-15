class Trip {
  final int id;
  final int driverId;
  final int truckId;
  final String originName;
  final double? originLat;
  final double? originLng;
  final String destinationName;
  final double? destinationLat;
  final double? destinationLng;
  final String departureDate; // ISO date string YYYY-MM-DD
  final double availableWeight;
  final double? availableVolume;
  final String tripType; // Internal: RETURN
  final String status; // Internal: PUBLISHED, IN_PROGRESS, COMPLETED, CANCELLED
  final String description;
  final String createdAt;
  final String updatedAt;

  Trip({
    required this.id,
    required this.driverId,
    required this.truckId,
    required this.originName,
    this.originLat,
    this.originLng,
    required this.destinationName,
    this.destinationLat,
    this.destinationLng,
    required this.departureDate,
    required this.availableWeight,
    this.availableVolume,
    this.tripType = 'RETURN',
    this.status = 'PUBLISHED',
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      driverId: json['driver_id'],
      truckId: json['truck_id'],
      originName: json['origin_name'] ?? '',
      originLat: json['origin_lat']?.toDouble(),
      originLng: json['origin_lng']?.toDouble(),
      destinationName: json['destination_name'] ?? '',
      destinationLat: json['destination_lat']?.toDouble(),
      destinationLng: json['destination_lng']?.toDouble(),
      departureDate: json['departure_date'] ?? '',
      availableWeight: (json['available_weight'] ?? 0).toDouble(),
      availableVolume: json['available_volume']?.toDouble(),
      tripType: json['trip_type'] ?? 'RETURN',
      status: json['status'] ?? 'PUBLISHED',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
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
      'status': status,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // French display names for trip types
  static const Map<String, String> tripTypeDisplayNames = {
    'RETURN': 'Trajet retour',
  };

  // French display names for statuses
  static const Map<String, String> statusDisplayNames = {
    'PUBLISHED': 'Publié',
    'IN_PROGRESS': 'En cours',
    'COMPLETED': 'Terminé',
    'CANCELLED': 'Annulé',
  };

  String get tripTypeDisplayName =>
      tripTypeDisplayNames[tripType] ?? tripType;

  String get statusDisplayName =>
      statusDisplayNames[status] ?? status;

  String get routeLabel => '$originName → $destinationName';

  String get capacityLabel =>
      '${_formatNumber(availableWeight)} kg disponibles';

  bool get isPublished => status == 'PUBLISHED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';

  static const List<String> _frenchMonths = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  // '2026-09-15' -> '15 septembre 2026'
  static String formatFrenchDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) {
      return isoDate;
    }
    final day = int.tryParse(parts[2]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[0]);
    if (day == null || month == null || year == null || month < 1 || month > 12) {
      return isoDate;
    }
    return '$day ${_frenchMonths[month - 1]} $year';
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
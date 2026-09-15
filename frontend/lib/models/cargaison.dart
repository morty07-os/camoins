class Cargaison {
  final int id;
  final int driverId;
  final int? tripId;
  final String originName;
  final String destinationName;
  final String cargoType;
  final double weight;
  final String? description;
  final String status; // AVAILABLE, ASSIGNED, IN_TRANSIT, DELIVERED, CANCELLED
  final String? customerName;
  final String? customerPhone;
  final String createdAt;
  final String updatedAt;

  Cargaison({
    required this.id,
    required this.driverId,
    this.tripId,
    required this.originName,
    required this.destinationName,
    required this.cargoType,
    required this.weight,
    this.description,
    required this.status,
    this.customerName,
    this.customerPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cargaison.fromJson(Map<String, dynamic> json) {
    return Cargaison(
      id: json['id'],
      driverId: json['driver_id'],
      tripId: json['trip_id'],
      originName: json['origin_name'] ?? '',
      destinationName: json['destination_name'] ?? '',
      cargoType: json['cargo_type'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      description: json['description'],
      status: json['status'] ?? 'AVAILABLE',
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'trip_id': tripId,
      'origin_name': originName,
      'destination_name': destinationName,
      'cargo_type': cargoType,
      'weight': weight,
      'description': description,
      'status': status,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // French display names for statuses
  static const Map<String, String> statusDisplayNames = {
    'AVAILABLE': 'Disponible',
    'ASSIGNED': 'Assignée au trajet',
    'IN_TRANSIT': 'En transit',
    'DELIVERED': 'Livrée',
    'CANCELLED': 'Annulée',
  };

  String get statusDisplayName =>
      statusDisplayNames[status] ?? status;

  bool get isAvailable => status == 'AVAILABLE';
  bool get isAssigned => status == 'ASSIGNED';
  bool get isInTransit => status == 'IN_TRANSIT';
  bool get isDelivered => status == 'DELIVERED';
  bool get isCancelled => status == 'CANCELLED';
}

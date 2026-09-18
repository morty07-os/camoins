class TransportRequest {
  final int id;
  final int tripId;
  final int customerId;
  final double requestedWeight;
  final double? requestedVolume;
  final String? cargoDescription;
  final String? pickupLocation;
  final String? deliveryLocation;
  final String agreedPrice;
  final String status; // PENDING, ACCEPTED, REJECTED, CANCELLED, COMPLETED
  final String createdAt;
  final String updatedAt;

  TransportRequest({
    required this.id,
    required this.tripId,
    required this.customerId,
    required this.requestedWeight,
    this.requestedVolume,
    this.cargoDescription,
    this.pickupLocation,
    this.deliveryLocation,
    required this.agreedPrice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransportRequest.fromJson(Map<String, dynamic> json) {
    return TransportRequest(
      id: json['id'],
      tripId: json['trip_id'],
      customerId: json['customer_id'],
      requestedWeight: (json['requested_weight'] ?? 0).toDouble(),
      requestedVolume: json['requested_volume']?.toDouble(),
      cargoDescription: json['cargo_description'],
      pickupLocation: json['pickup_location'],
      deliveryLocation: json['delivery_location'],
      agreedPrice: json['agreed_price'] ?? 'Prix à convenir',
      status: json['status'] ?? 'PENDING',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'customer_id': customerId,
      'requested_weight': requestedWeight,
      'requested_volume': requestedVolume,
      'cargo_description': cargoDescription,
      'pickup_location': pickupLocation,
      'delivery_location': deliveryLocation,
      'agreed_price': agreedPrice,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static const Map<String, String> statusDisplayNames = {
    'PENDING': 'En attente',
    'ACCEPTED': 'Acceptée',
    'REJECTED': 'Refusée',
    'CANCELLED': 'Annulée',
    'COMPLETED': 'Terminée',
  };

  String get statusDisplayName => statusDisplayNames[status] ?? status;

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isCompleted => status == 'COMPLETED';

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String get weightLabel => '${_formatNumber(requestedWeight)} kg';

  String get volumeLabel =>
      requestedVolume != null ? '${_formatNumber(requestedVolume!)} m³' : '—';
}

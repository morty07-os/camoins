class Rating {
  final int id;
  final int tripId;
  final int requestId;
  final int reviewerId;
  final int reviewedUserId;
  final int rating;
  final String? comment;
  final String createdAt;
  final UserProfile? reviewer;

  Rating({
    required this.id,
    required this.tripId,
    required this.requestId,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reviewer,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'],
      tripId: json['trip_id'],
      requestId: json['request_id'],
      reviewerId: json['reviewer_id'],
      reviewedUserId: json['reviewed_user_id'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: json['created_at'] ?? '',
      reviewer: json['reviewer_name'] != null
          ? UserProfile(
              fullName: json['reviewer_name'],
              profileImage: json['reviewer_image'],
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'request_id': requestId,
      'reviewer_id': reviewerId,
      'reviewed_user_id': reviewedUserId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt,
    };
  }
}

class UserProfile {
  final String fullName;
  final String? profileImage;

  UserProfile({
    required this.fullName,
    this.profileImage,
  });
}

class HistoryItem {
  final int id;
  final String type;
  final String origin;
  final String destination;
  final String date;
  final String status;
  final HistoryOtherParty? otherParty;
  final HistoryTruck? truck;
  final HistoryMyRating? myRating;

  HistoryItem({
    required this.id,
    required this.type,
    required this.origin,
    required this.destination,
    required this.date,
    required this.status,
    this.otherParty,
    this.truck,
    this.myRating,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      type: json['type'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? '',
      otherParty: json['otherParty'] != null ? HistoryOtherParty.fromJson(json['otherParty']) : null,
      truck: json['truck'] != null ? HistoryTruck.fromJson(json['truck']) : null,
      myRating: json['myRating'] != null ? HistoryMyRating.fromJson(json['myRating']) : null,
    );
  }
}

class HistoryOtherParty {
  final int id;
  final String name;
  final String role;
  final double rating;
  final int ratingCount;

  HistoryOtherParty({
    required this.id,
    required this.name,
    required this.role,
    required this.rating,
    required this.ratingCount,
  });

  factory HistoryOtherParty.fromJson(Map<String, dynamic> json) {
    return HistoryOtherParty(
      id: json['id'],
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      ratingCount: json['rating_count'] ?? 0,
    );
  }
}

class HistoryTruck {
  final String type;
  final String? brand;
  final String? model;

  HistoryTruck({
    required this.type,
    this.brand,
    this.model,
  });

  factory HistoryTruck.fromJson(Map<String, dynamic> json) {
    return HistoryTruck(
      type: json['type'] ?? '',
      brand: json['brand'],
      model: json['model'],
    );
  }
}

class HistoryMyRating {
  final int rating;
  final String? comment;

  HistoryMyRating({
    required this.rating,
    this.comment,
  });

  factory HistoryMyRating.fromJson(Map<String, dynamic> json) {
    return HistoryMyRating(
      rating: json['rating'],
      comment: json['comment'],
    );
  }
}

class HistoryResponse {
  final bool success;
  final List<HistoryItem> history;

  HistoryResponse({
    required this.success,
    required this.history,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    return HistoryResponse(
      success: json['success'] ?? false,
      history: (json['history'] as List? ?? [])
          .map((item) => HistoryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
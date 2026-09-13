class User {
  final int id;
  final String email;
  final String role;
  final UserProfile profile;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.profile,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      profile: UserProfile.fromJson(json['profile']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'profile': profile.toJson(),
    };
  }

  bool get isDriver => role == 'DRIVER';
  bool get isCustomer => role == 'CUSTOMER';
}

class UserProfile {
  final String fullName;
  final String? phone;
  final String? city;
  final String? wilaya;
  final String? profileImage;
  final double rating;
  final int ratingCount;

  UserProfile({
    required this.fullName,
    this.phone,
    this.city,
    this.wilaya,
    this.profileImage,
    this.rating = 0.0,
    this.ratingCount = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['full_name'],
      phone: json['phone'],
      city: json['city'],
      wilaya: json['wilaya'],
      profileImage: json['profile_image'],
      rating: (json['rating'] ?? 0).toDouble(),
      ratingCount: json['rating_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'wilaya': wilaya,
      'profile_image': profileImage,
      'rating': rating,
      'rating_count': ratingCount,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? city,
    String? wilaya,
    String? profileImage,
    double? rating,
    int? ratingCount,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      wilaya: wilaya ?? this.wilaya,
      profileImage: profileImage ?? this.profileImage,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }
}

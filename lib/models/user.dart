enum UserRole {
  client,
  delivery;

  String get displayName {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.delivery:
        return 'Livreur';
    }
  }
}

enum VehicleType {
  car,
  motorcycle,
  truck,
  van;

  String get displayName {
    switch (this) {
      case VehicleType.car:
        return 'Voiture';
      case VehicleType.motorcycle:
        return 'Moto';
      case VehicleType.truck:
        return 'Camion';
      case VehicleType.van:
        return 'Fourgonnette';
    }
  }
}

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profilePicture;
  final String? gender;
  final String? dateOfBirth;
  final String? country;
  final String? countryCode;

  // Livreur specific fields
  final VehicleType? vehicleType;
  final String? cinImage;
  final String? carteGriseImage;
  final String? permisImage;
  final bool isVerified;
  final bool isAvailable;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleType,
    this.cinImage,
    this.carteGriseImage,
    this.permisImage,
    this.isVerified = false,
    this.isAvailable = false,
    this.profilePicture,
    this.gender,
    this.dateOfBirth,
    this.country,
    this.countryCode,
  });

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    UserRole? role,
    String? avatar,
    DateTime? createdAt,
    DateTime? updatedAt,
    VehicleType? vehicleType,
    String? cinImage,
    String? carteGriseImage,
    String? permisImage,
    bool? isVerified,
    bool? isAvailable,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleType: vehicleType ?? this.vehicleType,
      cinImage: cinImage ?? this.cinImage,
      carteGriseImage: carteGriseImage ?? this.carteGriseImage,
      permisImage: permisImage ?? this.permisImage,
      isVerified: isVerified ?? this.isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatar': avatar,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'vehicleType': vehicleType?.name,
      'cinImage': cinImage,
      'carteGriseImage': carteGriseImage,
      'permisImage': permisImage,
      'isVerified': isVerified,
      'isAvailable': isAvailable,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      firstName: map['first_name'] ?? map['firstName'] ?? '',
      lastName: map['last_name'] ?? map['lastName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['user_type'] == 'external' ? UserRole.client : 
            map['user_type'] == 'delivery' ? UserRole.delivery :
            UserRole.values.firstWhere(
              (role) => role.name == map['role'],
              orElse: () => UserRole.client,
            ),
      avatar: map['avatar'],
      createdAt: DateTime.parse(map['created_at'] ?? map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? map['updatedAt'] ?? DateTime.now().toIso8601String()),
      profilePicture: map['profile_picture'],
      gender: map['gender'],
      dateOfBirth: map['date_of_birth'] ?? map['dateOfBirth'],
      country: map['country'],
      countryCode: map['country_code'] ?? map['countryCode'],
      vehicleType: map['vehicleType'] != null
          ? VehicleType.values.firstWhere(
              (type) => type.name == map['vehicleType'],
            )
          : null,
      cinImage: map['cinImage'],
      carteGriseImage: map['carteGriseImage'],
      permisImage: map['permisImage'],
      isVerified: map['isVerified'] ?? false,
      isAvailable: map['isAvailable'] ?? false,
    );
  }

  String get fullName => '$firstName $lastName';
}

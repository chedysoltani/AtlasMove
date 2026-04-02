import '../models/user.dart';

class LoginRequest {
  final String email;
  final String password;
  final UserRole role;

  LoginRequest({
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'role': role.name,
    };
  }
}

class SignupRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final UserRole role;

  // Livreur specific fields
  final VehicleType? vehicleType;
  final String? cinImage;
  final String? carteGriseImage;
  final String? permisImage;

  SignupRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    this.vehicleType,
    this.cinImage,
    this.carteGriseImage,
    this.permisImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role.name,
      if (vehicleType != null) 'vehicleType': vehicleType!.name,
      if (cinImage != null) 'cinImage': cinImage,
      if (carteGriseImage != null) 'carteGriseImage': carteGriseImage,
      if (permisImage != null) 'permisImage': permisImage,
    };
  }
}

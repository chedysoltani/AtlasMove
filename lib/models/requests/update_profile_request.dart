import 'package:easy_localization/easy_localization.dart';

/// Modèle de requête pour la mise à jour du profil utilisateur
class UpdateProfileRequest {
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? profilePicture;
  final String? gender;
  final String? dateOfBirth;
  final String? country;
  final String? countryCode;

  UpdateProfileRequest({
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.profilePicture,
    this.gender,
    this.dateOfBirth,
    this.country,
    this.countryCode,
  });

  /// Convertit l'instance en Map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    if (email != null) data['email'] = email;
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (phone != null) data['phone'] = phone;
    if (profilePicture != null) data['profile_picture'] = profilePicture;
    if (gender != null) data['gender'] = gender;
    if (dateOfBirth != null) data['date_of_birth'] = dateOfBirth;
    if (country != null) data['country'] = country;
    if (countryCode != null) data['country_code'] = countryCode;

    return data;
  }

  /// Validation des données
  String? validate() {
    // Validation de l'email
    if (email != null && email!.isNotEmpty) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email!)) {
        return 'auth.email_invalid'.tr();
      }
    }

    // Validation du prénom
    if (firstName != null && firstName!.isNotEmpty) {
      if (firstName!.length < 2) {
        return 'validation.first_name_min'.tr();
      }
      if (firstName!.length > 50) {
        return 'validation.first_name_max'.tr();
      }
    }

    // Validation du nom
    if (lastName != null && lastName!.isNotEmpty) {
      if (lastName!.length < 2) {
        return 'validation.last_name_min'.tr();
      }
      if (lastName!.length > 50) {
        return 'validation.last_name_max'.tr();
      }
    }

    // Validation du téléphone
    if (phone != null && phone!.isNotEmpty) {
      final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
      if (!phoneRegex.hasMatch(phone!)) {
        return 'validation.phone_invalid'.tr();
      }
    }

    // Validation du genre
    if (gender != null && gender!.isNotEmpty) {
      final validGenders = ['male', 'female', 'other'];
      if (!validGenders.contains(gender!.toLowerCase())) {
        return 'Genre invalide (male, female, other)';
      }
    }

    return null;
  }

  @override
  String toString() {
    return 'UpdateProfileRequest(email: $email, firstName: $firstName, lastName: $lastName)';
  }
}

import 'dart:io';

/// Requête d'inscription pour un livreur
class DriverRegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;
  final String vehicleType;
  final String cinNumber;
  final String drivingLicenseNumber;
  final String vehiclePlateNumber;
  final File? idCard;
  final File? drivingLicense;
  final File? vehicleRegistration;
  final String? referralCode;

  const DriverRegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirmPassword,
    required this.vehicleType,
    required this.cinNumber,
    required this.drivingLicenseNumber,
    required this.vehiclePlateNumber,
    this.idCard,
    this.drivingLicense,
    this.vehicleRegistration,
    this.referralCode,
  });

  /// Validation des données
  String? validate({bool skipFiles = false}) {
    // Validation du prénom
    if (firstName.trim().isEmpty) {
      return 'Le prénom est obligatoire';
    }
    if (firstName.length < 2) {
      return 'Le prénom doit contenir au moins 2 caractères';
    }
    if (firstName.length > 50) {
      return 'Le prénom ne doit pas dépasser 50 caractères';
    }

    // Validation du nom
    if (lastName.trim().isEmpty) {
      return 'Le nom est obligatoire';
    }
    if (lastName.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    if (lastName.length > 50) {
      return 'Le nom ne doit pas dépasser 50 caractères';
    }

    // Validation de l'email
    if (email.trim().isEmpty) {
      return 'L\'email est obligatoire';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Email invalide';
    }

    // Validation du téléphone
    if (phone.trim().isEmpty) {
      return 'Le téléphone est obligatoire';
    }
    final phoneRegex = RegExp(r'^\+[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Format téléphone invalide. Ex: +21698765432';
    }

    // Validation du mot de passe
    if (password.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(password)) {
      return 'Le mot de passe doit contenir au moins une minuscule';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(password)) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(password)) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    if (!RegExp(r'(?=.*[@\$!%*?&])').hasMatch(password)) {
      return 'Le mot de passe doit contenir au moins un caractère spécial (@\$!%*?&)';
    }

    // Validation de la confirmation du mot de passe
    if (password != confirmPassword) {
      return 'Les mots de passe ne correspondent pas';
    }

    // Validation du type de véhicule
    if (vehicleType.trim().isEmpty) {
      return 'Le type de véhicule est obligatoire';
    }

    // Validation CIN
    if (cinNumber.trim().isEmpty) {
      return 'Le numéro CIN est obligatoire';
    }
    if (!RegExp(r'^\d{8}$').hasMatch(cinNumber.trim())) {
      return 'Le CIN doit contenir exactement 8 chiffres';
    }

    // Validation numéro permis
    if (drivingLicenseNumber.trim().isEmpty) {
      return 'Le numéro de permis est obligatoire';
    }

    // Validation immatriculation
    if (vehiclePlateNumber.trim().isEmpty) {
      return 'Le numéro d\'immatriculation est obligatoire';
    }

    // Validation des fichiers (optionnelle en mode test)
    if (!skipFiles) {
      if (idCard == null) {
        return 'La carte d\'identité est obligatoire';
      }
      if (drivingLicense == null) {
        return 'Le permis de conduire est obligatoire';
      }
      if (vehicleRegistration == null) {
        return 'La carte grise est obligatoire';
      }
    }

    return null; // Pas d'erreur
  }

  /// Convertir en Map pour multipart
  Map<String, String> get textFields {
    final fields = {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'confirm_password': confirmPassword,
      'vehicle_type': vehicleType.trim(),
      'cin_number': cinNumber.trim(),
      'driving_license_number': drivingLicenseNumber.trim(),
      'vehicle_plate_number': vehiclePlateNumber.trim(),
    };
    if (referralCode != null && referralCode!.isNotEmpty) {
      fields['referral_code'] = referralCode!;
    }
    return fields;
  }

  /// Obtenir les fichiers pour multipart
  Map<String, File> get files {
    return {
      'id_card': idCard!,
      'driving_license': drivingLicense!,
      'vehicle_registration': vehicleRegistration!,
    };
  }
}

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';

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
  // Photos du véhicule (4 angles) et selfie de vérification — obligatoires
  final File? vehiclePhotoFront;
  final File? vehiclePhotoBack;
  final File? vehiclePhotoLeft;
  final File? vehiclePhotoRight;
  final File? selfie;
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
    this.vehiclePhotoFront,
    this.vehiclePhotoBack,
    this.vehiclePhotoLeft,
    this.vehiclePhotoRight,
    this.selfie,
    this.referralCode,
  });

  /// Validation des données
  String? validate({bool skipFiles = false}) {
    // Validation du prénom
    if (firstName.trim().isEmpty) {
      return 'signup.required_first_name'.tr();
    }
    if (firstName.length < 2) {
      return 'validation.first_name_min'.tr();
    }
    if (firstName.length > 50) {
      return 'validation.first_name_max'.tr();
    }

    // Validation du nom
    if (lastName.trim().isEmpty) {
      return 'signup.required_last_name'.tr();
    }
    if (lastName.length < 2) {
      return 'validation.last_name_min'.tr();
    }
    if (lastName.length > 50) {
      return 'validation.last_name_max'.tr();
    }

    // Validation de l'email
    if (email.trim().isEmpty) {
      return 'auth.email_required'.tr();
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'auth.email_invalid'.tr();
    }

    // Validation du téléphone
    if (phone.trim().isEmpty) {
      return 'signup.required_phone'.tr();
    }
    final phoneRegex = RegExp(r'^\+[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'validation.phone_format'.tr();
    }

    // Validation du mot de passe
    if (password.length < 8) {
      return 'auth.password_min8'.tr();
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(password)) {
      return 'driver_reg.pw_lower'.tr();
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(password)) {
      return 'driver_reg.pw_upper'.tr();
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(password)) {
      return 'driver_reg.pw_digit'.tr();
    }
    if (!RegExp(r'(?=.*[@\$!%*?&])').hasMatch(password)) {
      return 'driver_reg.pw_special'.tr();
    }

    // Validation de la confirmation du mot de passe
    if (password != confirmPassword) {
      return 'auth.passwords_mismatch'.tr();
    }

    // Validation du type de véhicule
    if (vehicleType.trim().isEmpty) {
      return 'driver_reg.select_vehicle'.tr();
    }

    // Validation CIN
    if (cinNumber.trim().isEmpty) {
      return 'validation.cin_required'.tr();
    }
    if (!RegExp(r'^\d{8}$').hasMatch(cinNumber.trim())) {
      return 'driver_reg.exactly_8'.tr();
    }

    // Validation numéro permis
    if (drivingLicenseNumber.trim().isEmpty) {
      return 'validation.license_required'.tr();
    }

    // Validation immatriculation
    if (vehiclePlateNumber.trim().isEmpty) {
      return 'validation.plate_required'.tr();
    }

    // Validation des fichiers (optionnelle en mode test)
    if (!skipFiles) {
      if (idCard == null) {
        return 'driver_reg.select_id'.tr();
      }
      if (drivingLicense == null) {
        return 'driver_reg.select_license'.tr();
      }
      if (vehicleRegistration == null) {
        return 'driver_reg.select_registration'.tr();
      }
      if (vehiclePhotoFront == null || vehiclePhotoBack == null ||
          vehiclePhotoLeft == null || vehiclePhotoRight == null) {
        return 'driver_reg.vehicle_photos_required'.tr();
      }
      if (selfie == null) {
        return 'driver_reg.selfie_required'.tr();
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
      if (vehiclePhotoFront != null) 'vehicle_photo_front': vehiclePhotoFront!,
      if (vehiclePhotoBack != null) 'vehicle_photo_back': vehiclePhotoBack!,
      if (vehiclePhotoLeft != null) 'vehicle_photo_left': vehiclePhotoLeft!,
      if (vehiclePhotoRight != null) 'vehicle_photo_right': vehiclePhotoRight!,
      if (selfie != null) 'selfie': selfie!,
    };
  }
}

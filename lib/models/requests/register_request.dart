/// Modèle de requête pour l'inscription client
class ClientRegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;

  ClientRegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirmPassword,
  });

  /// Crée une instance à partir d'un Map
  factory ClientRegisterRequest.fromJson(Map<String, dynamic> json) {
    return ClientRegisterRequest(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      password: json['password'] ?? '',
      confirmPassword: json['confirm_password'] ?? '',
    );
  }

  /// Convertit l'instance en Map
  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'password': password,
      'confirm_password': confirmPassword,
    };
  }

  /// Validation des données
  String? validate() {
    // Validation du prénom
    if (firstName.trim().isEmpty) {
      return 'Le prénom est requis';
    }
    if (firstName.trim().length < 2) {
      return 'Le prénom doit contenir au moins 2 caractères';
    }

    // Validation du nom
    if (lastName.trim().isEmpty) {
      return 'Le nom est requis';
    }
    if (lastName.trim().length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }

    // Validation de l'email
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Email invalide';
    }

    // Validation du téléphone
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    if (!phoneRegex.hasMatch(phone.trim())) {
      return 'Numéro de téléphone invalide';
    }

    // Validation du mot de passe
    if (password.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Le mot de passe doit contenir au moins une minuscule';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }

    // Validation de la confirmation du mot de passe
    if (password != confirmPassword) {
      return 'Les mots de passe ne correspondent pas';
    }

    return null; // Pas d'erreur
  }

  @override
  String toString() {
    return 'ClientRegisterRequest(firstName: $firstName, lastName: $lastName, email: $email, phone: $phone)';
  }
}

/// Modèle de requête pour l'inscription livreur
class DeliveryRegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;
  final String vehicleType;
  final String cinImage;
  final String carteGriseImage;
  final String permisImage;

  DeliveryRegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirmPassword,
    required this.vehicleType,
    required this.cinImage,
    required this.carteGriseImage,
    required this.permisImage,
  });

  factory DeliveryRegisterRequest.fromJson(Map<String, dynamic> json) {
    return DeliveryRegisterRequest(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      password: json['password'] ?? '',
      confirmPassword: json['confirm_password'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      cinImage: json['cin_image'] ?? '',
      carteGriseImage: json['carte_grise_image'] ?? '',
      permisImage: json['permis_image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'password': password,
      'confirm_password': confirmPassword,
      'vehicle_type': vehicleType,
      'cin_image': cinImage,
      'carte_grise_image': carteGriseImage,
      'permis_image': permisImage,
    };
  }

  String? validate() {
    // Réutiliser la validation du client
    final clientRequest = ClientRegisterRequest(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );
    
    final clientValidationError = clientRequest.validate();
    if (clientValidationError != null) {
      return clientValidationError;
    }

    // Validation spécifique au livreur
    if (vehicleType.trim().isEmpty) {
      return 'Le type de véhicule est requis';
    }

    if (cinImage.trim().isEmpty) {
      return 'L\'image CIN est requise';
    }

    if (carteGriseImage.trim().isEmpty) {
      return 'L\'image carte grise est requise';
    }

    if (permisImage.trim().isEmpty) {
      return 'L\'image permis est requise';
    }

    return null;
  }
}

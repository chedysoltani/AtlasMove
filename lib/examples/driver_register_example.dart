import 'dart:io';
import '../models/requests/driver_register_request.dart';
import '../services/auth_service.dart';

/// Exemple d'utilisation de l'inscription d'un livreur
class DriverRegisterExample {
  
  /// Exemple complet d'inscription d'un livreur
  static Future<void> registerDriverExample() async {
    print('🚚 Exemple d\'inscription d\'un livreur');
    print('=====================================');

    try {
      // Créer la requête avec les données de test
      final request = DriverRegisterRequest(
        firstName: 'amal',
        lastName: 'ghanmi',
        email: 'amal@example.com',
        phone: '+21698765432',
        password: 'SecureP@ss123',
        confirmPassword: 'SecureP@ss123',
        vehicleType: 'voiture',
        idCard: File('/path/to/id_card.jpg'), // Remplacer par un vrai fichier
        drivingLicense: File('/path/to/driving_license.jpg'), // Remplacer par un vrai fichier
        vehicleRegistration: File('/path/to/vehicle_registration.jpg'), // Remplacer par un vrai fichier
      );

      print('📋 Données envoyées:');
      print('  - Prénom: ${request.firstName}');
      print('  - Nom: ${request.lastName}');
      print('  - Email: ${request.email}');
      print('  - Téléphone: ${request.phone}');
      print('  - Type de véhicule: ${request.vehicleType}');
      print('  - Mot de passe: ${request.password.replaceAll(RegExp(r'.'), '*')}');

      // Valider la requête
      final validationError = request.validate();
      if (validationError != null) {
        print('❌ Erreur de validation: $validationError');
        return;
      }

      print('✅ Validation réussie');

      // Envoyer la requête
      print('📤 Envoi de la requête d\'inscription...');
      final response = await AuthService.registerDriver(request);

      print('🎉 Inscription réussie!');
      print('📄 Réponse:');
      print('  - Message: ${response.message}');
      print('  - User ID: ${response.user.id}');
      print('  - Email: ${response.user.email}');
      print('  - Nom complet: ${response.user.fullName}');
      print('  - Téléphone: ${response.user.phone}');
      print('  - Rôle: ${response.user.role}');
      print('  - Statut: ${response.user.role}');
      print('  - Status Code: ${response.statusCode}');
      print('  - Timestamp: ${response.timestamp}');

    } catch (e) {
      print('❌ Erreur lors de l\'inscription: $e');
    }
  }

  /// Exemple de réponse JSON attendue
  static void showExpectedResponse() {
    print('\n📄 Réponse JSON attendue:');
    print('========================');
    print('''
{
  "data": {
    "message": "Livreur registered successfully. Your documents are under review.",
    "user": {
      "id": "uuid",
      "email": "amal@example.com",
      "first_name": "amal",
      "last_name": "ghanmi",
      "phone": "+21698765432",
      "role": "livreur",
      "status": "active"
    }
  },
  "timestamp": "2026-05-04T13:24:05.236Z",
  "method": "POST",
  "statusCode": 201,
  "path": "/api/v1/auth/register/livreur"
}
''');
  }

  /// Détails de l'API
  static void showApiDetails() {
    print('\n🔧 Détails de l\'API:');
    print('==================');
    print('Endpoint: POST {{base_url}}/auth/register/livreur');
    print('Content-Type: multipart/form-data');
    print('');
    print('Champs texte:');
    print('  - first_name (string): amal');
    print('  - last_name (string): ghanmi');
    print('  - email (string): amal@example.com');
    print('  - phone (string): +21698765432');
    print('  - password (string): SecureP@ss123');
    print('  - confirm_password (string): SecureP@ss123');
    print('  - vehicle_type (string): voiture');
    print('');
    print('Fichiers:');
    print('  - id_card (file): Carte d\'identité');
    print('  - driving_license (file): Permis de conduire');
    print('  - vehicle_registration (file): Carte grise');
    print('');
    print('Validation:');
    print('  - Prénom: 2-50 caractères');
    print('  - Nom: 2-50 caractères');
    print('  - Email: format email valide');
    print('  - Téléphone: format international (+10-15 chiffres)');
    print('  - Mot de passe: 8+ caractères, 1 majuscule, 1 minuscule, 1 chiffre, 1 spécial');
    print('  - Type de véhicule: voiture, moto, camion, fourgonnette');
    print('  - Fichiers: tous obligatoires');
  }
}

/// Point d'entrée pour tester l'exemple
void main() {
  // Afficher les détails de l'API
  DriverRegisterExample.showApiDetails();
  
  // Afficher la réponse attendue
  DriverRegisterExample.showExpectedResponse();
  
  // Pour tester l'inscription réelle, décommentez la ligne suivante:
  // DriverRegisterExample.registerDriverExample();
}

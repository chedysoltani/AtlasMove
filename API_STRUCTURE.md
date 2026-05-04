# Structure API AtlasMove

## 📋 Vue d'ensemble

Cette documentation présente la structure mise en place pour consommer les API d'AtlasMove de manière propre et scalable.

## 🏗️ Architecture

### 1. **Core Network** (`lib/core/network/`)
- **`http_client.dart`** : Client HTTP centralisé avec gestion des erreurs
  - Base URL : `https://api.atla.business/api/v1`
  - Timeout : 30 secondes
  - Gestion automatique des erreurs HTTP
  - Support des requêtes GET, POST, PUT, DELETE
  - Logging des requêtes/réponses en mode debug

### 2. **Models** (`lib/models/`)
- **`user.dart`** : Modèle utilisateur existant
- **`requests/`** : Modèles de requêtes
  - **`register_request.dart`** : Requêtes d'inscription (client/livreur)
- **`responses/`** : Modèles de réponses
  - **`auth_response.dart`** : Réponses d'authentification

### 3. **Services** (`lib/services/`)
- **`auth_service.dart`** : Service d'authentification
  - Inscription client/livreur
  - Connexion/Déconnexion
  - Rafraîchissement de token
  - Réinitialisation de mot de passe

### 4. **Examples** (`lib/examples/`)
- **`auth_example.dart`** : Interface de test pour l'API d'inscription

## 🔌 API Endpoints

### Authentification

#### Inscription Client
```http
POST /auth/register/client
Content-Type: application/json

{
  "first_name": "chayma",
  "last_name": "mhatli",
  "email": "john.doe@example.com",
  "phone": "+21612345678",
  "password": "SecureP@ss123",
  "confirm_password": "SecureP@ss123"
}
```

#### Inscription Livreur
```http
POST /auth/register/delivery
Content-Type: application/json

{
  "first_name": "chauffeur",
  "last_name": "livreur",
  "email": "driver@example.com",
  "phone": "+21698765432",
  "password": "SecureP@ss123",
  "confirm_password": "SecureP@ss123",
  "vehicle_type": "car",
  "cin_image": "base64_image",
  "carte_grise_image": "base64_image",
  "permis_image": "base64_image"
}
```

#### Connexion
```http
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

## 🛠️ Utilisation

### 1. Inscription Client

```dart
import 'package:atlasmove/services/auth_service.dart';
import 'package:atlasmove/models/requests/register_request.dart';

// Création de la requête
final request = ClientRegisterRequest(
  firstName: 'Chayma',
  lastName: 'Mhatli',
  email: 'chayma@example.com',
  phone: '+21612345678',
  password: 'SecureP@ss123',
  confirmPassword: 'SecureP@ss123',
);

try {
  // Appel à l'API
  final response = await AuthService.registerClient(request);
  
  // Succès
  print('Inscription réussie: ${response.user.fullName}');
  print('Token: ${response.token}');
  
} catch (e) {
  // Gestion des erreurs
  print('Erreur: $e');
}
```

### 2. Gestion des Erreurs

```dart
try {
  final response = await AuthService.registerClient(request);
} on ValidationException catch (e) {
  // Erreur de validation des données
  print('Validation error: ${e.errors}');
} on AuthErrorResponse catch (e) {
  // Erreur retournée par l'API
  print('API error: ${e.message}');
} on NetworkException catch (e) {
  // Erreur réseau
  print('Network error: ${e.message}');
} catch (e) {
  // Erreur inattendue
  print('Unexpected error: $e');
}
```

## 🧪 Test de l'API

### Via l'interface de test

1. Lancez l'application
2. Naviguez vers `/test_auth`
3. Remplissez le formulaire d'inscription
4. Cliquez sur "S'inscrire"
5. Observez les logs dans la console

### Via Postman

```bash
# URL de base
https://api.atla.business/api/v1

# Endpoint d'inscription client
POST /auth/register/client
```

## 📝 Validation

### Validation Client
- **Prénom/Nom** : Minimum 2 caractères
- **Email** : Format email valide
- **Téléphone** : 8-15 chiffres, optionnellement avec +
- **Mot de passe** : 
  - Minimum 8 caractères
  - Au moins une majuscule
  - Au moins une minuscule
  - Au moins un chiffre
- **Confirmation** : Doit correspondre au mot de passe

## 🔧 Configuration

### Base URL
```dart
// Dans lib/core/network/http_client.dart
static const String _baseUrl = 'https://api.atla.business/api/v1';
```

### Timeout
```dart
static const Duration _timeout = Duration(seconds: 30);
static const Duration _receiveTimeout = Duration(seconds: 30);
```

## 🚀 Prochaines Étapes

1. **Intégration avec AuthProvider** : Connecter l'API au gestionnaire d'état
2. **Token Storage** : Sauvegarder les tokens de manière sécurisée
3. **Refresh Token** : Implémenter le rafraîchissement automatique
4. **API Livraison** : Créer les services pour les livraisons
5. **API Paiement** : Intégrer l'API de paiement
6. **Upload Images** : Gérer l'upload des images (CIN, permis, etc.)

## 🐛 Débogage

### Logs des requêtes
Les logs sont activés automatiquement en mode debug :

```dart
debugPrint('🌐 API Request: $method $uri');
debugPrint('📋 Headers: $finalHeaders');
debugPrint('📦 Body: ${jsonEncode(body)}');
debugPrint('📊 Response Status: ${response.statusCode}');
debugPrint('📄 Response Body: ${response.body}');
```

### Erreurs communes
- **NetworkException** : Problèmes de connexion
- **ValidationException** : Données invalides
- **AuthErrorResponse** : Erreurs de l'API
- **ServerException** : Erreurs serveur (5xx)

## 📱 Interface de Test

Accédez à l'interface de test via :
- Route : `/test_auth`
- Fonctionnalités :
  - Formulaire d'inscription complet
  - Validation en temps réel
  - Affichage des erreurs/succès
  - Logs de l'API

---

**Note** : Cette structure est conçue pour être extensible et maintenable. Chaque service peut être facilement ajouté en suivant le même pattern.

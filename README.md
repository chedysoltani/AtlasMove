# AtlasMove - Plateforme de Transport et Livraison

Une application mobile Flutter similaire à Uber, permettant aux clients de demander des courses/livraisons et aux livreurs de recevoir et accepter des missions.

## � Fonctionnalités

### 👤 Client
- Demander un taxi
- Demander une livraison (colis, meuble, etc.)
- Choisir type de véhicule (voiture, camion, moto…)
- Voir une carte (Google Maps) avec sa position actuelle
- Obtenir un prix estimé
- Être mis en relation avec le livreur le plus proche

### 🚚 Livreur
- Recevoir des demandes
- Accepter ou refuser une mission
- Voir la position du client sur la carte
- Suivre ses gains/statistiques

## 📱 Écrans Implémentés

### ✅ Terminé
- **Splash Screen**: Page d'ouverture avec animation AtlasMove
- **Login Screen**: Authentification avec choix de rôle
- **Signup Screen**: Inscription complète (Client + Livreur) avec upload d'images

### 🔄 En cours
- Dashboard Client
- Dashboard Livreur
- Carte avec Google Maps
- Système de paiement

## 🏗️ Architecture

### Structure des dossiers
```
lib/
├── main.dart                    # Point d'entrée
├── models/                      # Modèles de données
│   ├── user.dart               # Modèle User
│   └── auth_request.dart       # Request/Response
├── screens/                     # Écrans de l'application
│   ├── splash_screen.dart      # Splash screen animé
│   ├── login_screen.dart       # Écran de connexion
│   └── signup_screen.dart      # Écran d'inscription
├── widgets/                     # Widgets réutilisables
│   ├── custom_button.dart      # Bouton personnalisé
│   ├── custom_text_field.dart  # Champ de texte
│   ├── role_selector.dart      # Sélecteur de rôle
│   ├── vehicle_selector.dart   # Sélecteur de véhicule
│   └── image_upload_widget.dart # Upload d'images
├── providers/                   # State management (Provider)
│   └── auth_provider.dart      # Gestion de l'authentification
├── utils/                       # Utilitaires
│   └── app_theme.dart          # Thème AtlasMove
└── services/                    # Services (à implémenter)
```

### � Thème AtlasMove
- **Couleurs**: Noir, Blanc, Orange vibrant (#FF6B35)
- **Design**: Moderne inspiré d'Uber
- **Responsive**: Adapté à toutes les tailles d'écran
- **Animations**: Transitions fluides et micro-interactions

## 🛠️ Technologies Utilisées

- **Flutter**: Framework de développement mobile
- **Provider**: State management simple et efficace
- **Image Picker**: Upload d'images depuis caméra/galerie
- **Google Maps**: Carte et géolocalisation (prévu)
- **Shared Preferences**: Stockage local
- **Material Design 3**: UI moderne et intuitive

## 🚀 Démarrage

### Prérequis
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code avec extensions Flutter

### Installation
```bash
# Cloner le projet
git clone <repository-url>
cd atlasmove

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

### � Test sur mobile
```bash
# Lister les appareils disponibles
flutter devices

# Lancer sur un appareil spécifique
flutter run -d <device-id>
```

## 🧪 Tests

```bash
# Lancer tous les tests
flutter test

# Tests de couverture
flutter test --coverage
```

## 📋 Fonctionnalités d'Authentification

### 🔐 Login
- Email et mot de passe
- Sélection du rôle (Client/Livreur)
- Validation des champs
- Gestion des erreurs

### 📝 Signup (Client)
- Nom, Prénom, Email, Téléphone
- Mot de passe sécurisé
- Confirmation du mot de passe

### 📝 Signup (Livreur)
- Informations personnelles
- Type de véhicule (Voiture, Moto, Camion, Fourgonnette)
- Upload de documents obligatoires:
  - Carte d'identité (CIN)
  - Carte grise du véhicule
  - Permis de conduire

## 🎯 Prochaines Étapes

### Phase 1 (Backend)
- API REST avec Node.js/Express
- Base de données MongoDB/PostgreSQL
- Authentification JWT
- Système de paiement Stripe

### Phase 2 (Fonctionnalités avancées)
- Intégration Google Maps
- Géolocalisation en temps réel
- Notifications push
- Chat entre client et livreur
- Système de notation

### Phase 3 (Optimisation)
- Performance et optimisation
- Tests automatisés
- CI/CD pipeline
- Déploiement sur stores

## 🤝 Contribuer

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/amazing-feature`)
3. Commit les changements (`git commit -m 'Add amazing feature'`)
4. Push vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

---

**AtlasMove** - Transport & Livraison 🚚✨

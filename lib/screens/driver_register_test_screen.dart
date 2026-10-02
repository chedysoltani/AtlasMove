import 'dart:io';
import 'package:flutter/material.dart';
import '../models/requests/driver_register_request.dart';
import '../models/responses/driver_register_response.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Écran de test d'inscription pour les livreurs (sans fichiers)
class DriverRegisterTestScreen extends StatefulWidget {
  const DriverRegisterTestScreen({super.key});

  @override
  State<DriverRegisterTestScreen> createState() => _DriverRegisterTestScreenState();
}

class _DriverRegisterTestScreenState extends State<DriverRegisterTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController(text: 'amal');
  final _lastNameController = TextEditingController(text: 'ghanmi');
  final _emailController = TextEditingController(text: 'amal@example.com');
  final _phoneController = TextEditingController(text: '+21698765432');
  final _passwordController = TextEditingController(text: 'SecureP@ss123');
  final _confirmPasswordController = TextEditingController(text: 'SecureP@ss123');
  final _vehicleTypeController = TextEditingController(text: 'voiture');

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  /// Crée une image PNG minimale mais valide
  List<int> _createMinimalPng() {
    // En-tête PNG (Portable Network Graphics)
    final pngHeader = [
      // Signature PNG
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      // Chunk IHDR (Image Header)
      0x00, 0x00, 0x00, 0x0D, // Length (13 bytes)
      0x49, 0x48, 0x44, 0x52, // "IHDR"
      0x00, 0x00, 0x00, 0x01, // Width: 1 pixel
      0x00, 0x00, 0x00, 0x01, // Height: 1 pixel
      0x08, // Bit depth: 8 bits
      0x02, // Color type: 2 (RGB)
      0x00, 0x00, 0x00, 0x00, // Compression, filter, interlace
      0x9D, 0x3C, 0x78, // CRC32 for IHDR
      // Chunk IDAT (Image Data)
      0x00, 0x00, 0x00, 0x0A, // Length (10 bytes)
      0x49, 0x44, 0x41, 0x54, // "IDAT"
      // Données image compressées (1x1 pixel RGB)
      0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
      0x0D, 0x7A, 0x5D, 0x01, // CRC32 for IDAT
      // Chunk IEND (Image End)
      0x00, 0x00, 0x00, 0x00, // Length (0 bytes)
      0x49, 0x45, 0x4E, 0x44, // "IEND"
      0xAE, 0x42, 0x60, 0x82, // CRC32 for IEND
    ];
    return pngHeader;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    super.dispose();
  }

  Future<void> _testDriverRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      debugPrint('🚚 Test inscription livreur - Début');
      debugPrint('📋 Données:');
      debugPrint('  - Prénom: ${_firstNameController.text}');
      debugPrint('  - Nom: ${_lastNameController.text}');
      debugPrint('  - Email: ${_emailController.text}');
      debugPrint('  - Téléphone: ${_phoneController.text}');
      debugPrint('  - Véhicule: ${_vehicleTypeController.text}');

      // Créer des fichiers factices pour le test
      final tempDir = Directory.systemTemp;
      final idCardFile = File('${tempDir.path}/test_id_card.png');
      final licenseFile = File('${tempDir.path}/test_driving_license.png');
      final registrationFile = File('${tempDir.path}/test_vehicle_registration.png');
      
      // Créer de vraies images PNG factices (structure PNG simple)
      final pngBytes = _createMinimalPng();
      await idCardFile.writeAsBytes(pngBytes);
      await licenseFile.writeAsBytes(pngBytes);
      await registrationFile.writeAsBytes(pngBytes);

      debugPrint('📁 Fichiers temporaires créés:');
      debugPrint('  - ID Card: ${idCardFile.path}');
      debugPrint('  - License: ${licenseFile.path}');
      debugPrint('  - Registration: ${registrationFile.path}');

      // Créer une requête avec fichiers factices
      final request = DriverRegisterRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        vehicleType: _vehicleTypeController.text.trim(),
        cinNumber: '12345678',
        drivingLicenseNumber: 'TEST-LICENSE-001',
        vehiclePlateNumber: 'TN-TEST-001',
        idCard: idCardFile,
        drivingLicense: licenseFile,
        vehicleRegistration: registrationFile,
      );

      // Tester la validation locale (avec fichiers factices)
      final validationError = request.validate();
      if (validationError != null) {
        debugPrint('❌ Erreur de validation: $validationError');
        setState(() {
          _errorMessage = 'Validation: $validationError';
        });
        return;
      }

      debugPrint('✅ Validation locale réussie');

      // Tenter l'inscription (échouera à cause des fichiers manquants)
      final response = await AuthService.registerDriver(request);
      
      debugPrint('🎉 Inscription réussie!');
      debugPrint('📄 Réponse: ${response.message}');
      
      setState(() {
        _successMessage = response.message;
      });
      
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fillTestData() {
    setState(() {
      _firstNameController.text = 'amal';
      _lastNameController.text = 'ghanmi';
      _emailController.text = 'amal@example.com';
      _phoneController.text = '+21698765432';
      _passwordController.text = 'SecureP@ss123';
      _confirmPasswordController.text = 'SecureP@ss123';
      _vehicleTypeController.text = 'voiture';
      _errorMessage = null;
      _successMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Test Inscription Livreur',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: _fillTestData,
            tooltip: 'Remplir avec données de test',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message d'avertissement
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode TEST - Pas de fichiers requis. Teste la validation et la connexion API.',
                        style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Messages de retour
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Formulaire
              const Text(
                'Informations personnelles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _firstNameController,
                labelText: 'Prénom',
                prefixIcon: const Icon(Icons.person),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le prénom est obligatoire';
                  }
                  if (value.length < 2) {
                    return 'Le prénom doit contenir au moins 2 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _lastNameController,
                labelText: 'Nom',
                prefixIcon: const Icon(Icons.person),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est obligatoire';
                  }
                  if (value.length < 2) {
                    return 'Le nom doit contenir au moins 2 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'email est obligatoire';
                  }
                  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _phoneController,
                labelText: 'Téléphone',
                prefixIcon: const Icon(Icons.phone),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le téléphone est obligatoire';
                  }
                  final phoneRegex = RegExp(r'^\+[0-9]{10,15}$');
                  if (!phoneRegex.hasMatch(value)) {
                    return 'Format invalide. Ex: +21698765432';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _passwordController,
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le mot de passe est obligatoire';
                  }
                  if (value.length < 8) {
                    return 'Le mot de passe doit contenir au moins 8 caractères';
                  }
                  if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins une minuscule';
                  }
                  if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins une majuscule';
                  }
                  if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins un chiffre';
                  }
                  if (!RegExp(r'(?=.*[@\$!%*?&])').hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins un caractère spécial';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Confirmer le mot de passe',
                prefixIcon: const Icon(Icons.lock),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La confirmation du mot de passe est obligatoire';
                  }
                  if (value != _passwordController.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _vehicleTypeController,
                labelText: 'Type de véhicule',
                prefixIcon: const Icon(Icons.directions_car),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le type de véhicule est obligatoire';
                  }
                  final validVehicles = ['voiture', 'moto', 'camion', 'fourgonnette'];
                  if (!validVehicles.contains(value.toLowerCase())) {
                    return 'Type invalide (voiture, moto, camion, fourgonnette)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Remplir test',
                      onPressed: _fillTestData,
                      type: ButtonType.outline,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: _isLoading ? 'Test...' : 'Tester inscription',
                      onPressed: _isLoading ? null : _testDriverRegister,
                      isLoading: _isLoading,
                      type: ButtonType.primary,
                      height: 48,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Cliquez "Remplir test" pour charger les données\n'
                      '2. Modifiez si nécessaire\n'
                      '3. Cliquez "Tester inscription"\n'
                      '4. Vérifiez les messages de retour\n'
                      '5. Les erreurs de fichiers sont normales en mode test',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

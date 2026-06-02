import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/requests/driver_register_request.dart';
import '../models/responses/driver_register_response.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Écran d'inscription pour les livreurs
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _referralCodeController = TextEditingController();

  File? _idCard;
  File? _drivingLicense;
  File? _vehicleRegistration;

  bool _isLoading = false;
  String? _errorMessage;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickIdCard() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _idCard = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de la carte d\'identité: $e';
      });
    }
  }

  Future<void> _pickDrivingLicense() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _drivingLicense = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection du permis de conduire: $e';
      });
    }
  }

  Future<void> _pickVehicleRegistration() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _vehicleRegistration = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de la carte grise: $e';
      });
    }
  }

  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Vérifier que tous les fichiers sont sélectionnés
    if (_idCard == null) {
      setState(() {
        _errorMessage = 'Veuillez sélectionner votre carte d\'identité';
      });
      return;
    }

    if (_drivingLicense == null) {
      setState(() {
        _errorMessage = 'Veuillez sélectionner votre permis de conduire';
      });
      return;
    }

    if (_vehicleRegistration == null) {
      setState(() {
        _errorMessage = 'Veuillez sélectionner votre carte grise';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final referralCode = _referralCodeController.text.trim().toUpperCase();
      final request = DriverRegisterRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        vehicleType: _vehicleTypeController.text.trim(),
        idCard: _idCard,
        drivingLicense: _drivingLicense,
        vehicleRegistration: _vehicleRegistration,
        referralCode: referralCode.isNotEmpty ? referralCode : null,
      );

      final response = await AuthService.registerDriver(request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Rediriger vers l'écran de login
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          'Inscription Livreur',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Message d'erreur
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
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Informations personnelles
              const Text(
                'Informations personnelles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

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
              const SizedBox(height: 24),

              // Mot de passe
              const Text(
                'Mot de passe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

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
              const SizedBox(height: 24),

              // Documents
              const Text(
                'Documents requis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Carte d'identité
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Carte d\'identité',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _idCard != null ? Colors.green : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (_idCard != null)
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: _idCard != null ? 'Changer la carte d\'identité' : 'Sélectionner la carte d\'identité',
                      onPressed: _pickIdCard,
                      type: ButtonType.outline,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Permis de conduire
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Permis de conduire',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _drivingLicense != null ? Colors.green : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (_drivingLicense != null)
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: _drivingLicense != null ? 'Changer le permis' : 'Sélectionner le permis de conduire',
                      onPressed: _pickDrivingLicense,
                      type: ButtonType.outline,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Carte grise
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Carte grise',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _vehicleRegistration != null ? Colors.green : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (_vehicleRegistration != null)
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: _vehicleRegistration != null ? 'Changer la carte grise' : 'Sélectionner la carte grise',
                      onPressed: _pickVehicleRegistration,
                      type: ButtonType.outline,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Code de parrainage (optionnel)
              const Text(
                'Parrainage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous avez été recommandé par un ami ? Entrez son code pour lui offrir un bonus.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _referralCodeController,
                labelText: 'Code de parrainage (facultatif)',
                hintText: 'ATLAS-XXXXXX',
                prefixIcon: const Icon(Icons.card_giftcard_rounded),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (!RegExp(r'^ATLAS-[A-Z0-9]{6}$').hasMatch(value.trim().toUpperCase())) {
                      return 'Format invalide. Ex: ATLAS-J8K9F2';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Bouton d'inscription
              CustomButton(
                text: _isLoading ? 'Inscription...' : 'S\'inscrire',
                onPressed: _isLoading ? null : _registerDriver,
                isLoading: _isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

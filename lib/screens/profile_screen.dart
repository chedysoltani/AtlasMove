import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/profile_service.dart';
import '../models/requests/update_profile_request.dart';
import '../models/responses/auth_response.dart';
import '../core/network/http_client.dart';

/// Écran de profil utilisateur avec mise à jour des informations
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _profilePictureController = TextEditingController();
  final _genderController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _countryController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _profilePictureController.dispose();
    _genderController.dispose();
    _dateOfBirthController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      debugPrint('🔄 Chargement du profil utilisateur...');
      final response = await ProfileService.getCurrentProfile();
      
      debugPrint('👤 Données utilisateur reçues:');
      debugPrint('  - ID: ${response.user.id}');
      debugPrint('  - Prénom: ${response.user.firstName}');
      debugPrint('  - Nom: ${response.user.lastName}');
      debugPrint('  - Email: ${response.user.email}');
      debugPrint('  - Téléphone: ${response.user.phone}');
      debugPrint('  - Pays: ${response.user.country}');
      debugPrint('  - Genre: ${response.user.gender}');
      debugPrint('  - Date de naissance: ${response.user.dateOfBirth}');
      
      setState(() {
        _currentUser = response.user;
        _profilePictureUrl = _currentUser?.profilePicture;
        
        // Pré-remplir les champs avec les données actuelles
        _firstNameController.text = _currentUser?.firstName ?? '';
        _lastNameController.text = _currentUser?.lastName ?? '';
        _emailController.text = _currentUser?.email ?? '';
        _phoneController.text = _currentUser?.phone ?? '';
        _profilePictureController.text = _currentUser?.profilePicture ?? '';
        _genderController.text = _currentUser?.gender ?? '';
        _dateOfBirthController.text = _currentUser?.dateOfBirth ?? '';
        _countryController.text = _currentUser?.country ?? '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _profilePictureController.text = image.path;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de l\'image: $e';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = UpdateProfileRequest(
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        firstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        profilePicture: _profilePictureController.text.trim().isEmpty ? null : _profilePictureController.text.trim(),
        gender: _genderController.text.trim().isEmpty ? null : _genderController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim().isEmpty ? null : _dateOfBirthController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      );

      final response = await ProfileService.updateProfile(request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // Recharger les données du profil
        await _loadUserProfile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is ValidationException) {
      return error.toString();
    } else if (error is AuthErrorResponse) {
      return error.message;
    } else if (error is NetworkException) {
      return error.message;
    } else {
      return 'Une erreur inattendue est survenue: $error';
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
          'Mon Profil',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.primaryColor),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Photo de profil
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Photo de profil',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Affichage de la photo actuelle ou placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _profilePictureUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.person, size: 40);
                                },
                              ),
                            )
                          : const Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(height: 12),
                    
                    // Bouton pour choisir une image
                    CustomButton(
                      text: 'Choisir une photo',
                      onPressed: _pickImage,
                      type: ButtonType.text,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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

              // Champ Prénom
              CustomTextField(
                controller: _firstNameController,
                labelText: 'Prénom',
                prefixIcon: const Icon(Icons.person),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.length < 2) {
                      return 'Le prénom doit contenir au moins 2 caractères';
                    }
                    if (value.length > 50) {
                      return 'Le prénom ne doit pas dépasser 50 caractères';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Nom
              CustomTextField(
                controller: _lastNameController,
                labelText: 'Nom',
                prefixIcon: const Icon(Icons.person),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.length < 2) {
                      return 'Le nom doit contenir au moins 2 caractères';
                    }
                    if (value.length > 50) {
                      return 'Le nom ne doit pas dépasser 50 caractères';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Email
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Email invalide';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Téléphone
              CustomTextField(
                controller: _phoneController,
                labelText: 'Téléphone',
                prefixIcon: const Icon(Icons.phone),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    // Format plus strict pour l'API : commence par + et 10-15 chiffres
                    final phoneRegex = RegExp(r'^\+[0-9]{10,15}$');
                    if (!phoneRegex.hasMatch(value)) {
                      return 'Format requis: + suivi de 10-15 chiffres (ex: +33612345678)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Genre
              CustomTextField(
                controller: _genderController,
                labelText: 'Genre',
                prefixIcon: const Icon(Icons.person),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value!.isNotEmpty) {
                    final validGenders = ['male', 'female', 'other'];
                    if (!validGenders.contains(value!.toLowerCase())) {
                      return 'Genre invalide (male, female, other)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Date de naissance
              CustomTextField(
                controller: _dateOfBirthController,
                labelText: 'Date de naissance',
                prefixIcon: const Icon(Icons.calendar_today),
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value != null && value!.isNotEmpty) {
                    // Validation simple de la date
                    try {
                      final date = DateTime.parse(value);
                      // Vérifier que la date n'est pas dans le futur
                      if (date.isAfter(DateTime.now())) {
                        return 'La date de naissance ne peut pas être dans le futur';
                      }
                    } catch (e) {
                      return 'Format de date invalide (YYYY-MM-DD)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Champ Pays
              CustomTextField(
                controller: _countryController,
                labelText: 'Pays',
                prefixIcon: const Icon(Icons.flag),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != null && value!.length < 2) {
                    return 'Le pays doit contenir au moins 2 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Section de connexion rapide
             

              // Bouton de mise à jour
              CustomButton(
                text: _isLoading ? 'Mise à jour...' : 'Mettre à jour le profil',
                onPressed: _isLoading ? null : _updateProfile,
                isLoading: _isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 20),

              // Informations de l'API
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations de l\'API:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('Endpoint: PUT /users/profile'),
                    const Text('Base URL: ${HttpClient.baseUrl}'),
                    if (_currentUser != null) ...[
                      const SizedBox(height: 4),
                      Text('ID Utilisateur: ${_currentUser!.id}'),
                      Text('Email: ${_currentUser!.email}'),
                      Text('Rôle: ${_currentUser!.role}'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await ProfileService.logout();
      
      if (mounted) {
        // Rediriger vers la page de login
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

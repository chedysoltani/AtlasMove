import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/role_selector.dart';
import '../widgets/image_upload_widget.dart';
import '../widgets/vehicle_selector.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  UserRole _selectedRole = UserRole.client;
  VehicleType? _selectedVehicle;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  
  // Images pour livreur
  String? _cinImage;
  String? _carteGriseImage;
  String? _permisImage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isDeliveryRole => _selectedRole == UserRole.delivery;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isDeliveryRole && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un type de véhicule'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_isDeliveryRole && (_cinImage == null || _carteGriseImage == null || _permisImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez télécharger tous les documents obligatoires'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simuler un appel API
      await Future.delayed(const Duration(seconds: 3));
      
      // TODO: Implémenter la logique d'inscription
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inscription réussie en tant que ${_selectedRole.displayName}'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Retourner à l'écran de login
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'inscription: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Créer un compte',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rejoignez AtlasMove dès aujourd\'hui',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Role Selector
                    RoleSelector(
                      selectedRole: _selectedRole,
                      onRoleChanged: (role) {
                        setState(() {
                          _selectedRole = role;
                          // Reset vehicle selection when role changes
                          if (!_isDeliveryRole) {
                            _selectedVehicle = null;
                          }
                        });
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Name Fields
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _firstNameController,
                            labelText: 'Prénom',
                            hintText: 'Jean',
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre prénom';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            controller: _lastNameController,
                            labelText: 'Nom',
                            hintText: 'Dupont',
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre nom';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Email Field
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'exemple@email.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Phone Field
                    CustomTextField(
                      controller: _phoneController,
                      labelText: 'Téléphone',
                      hintText: '+33 6 12 34 56 78',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Password Fields
                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'Mot de passe',
                      hintText: '••••••••',
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: _togglePasswordVisibility,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un mot de passe';
                        }
                        if (value.length < 8) {
                          return 'Le mot de passe doit contenir au moins 8 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    CustomTextField(
                      controller: _confirmPasswordController,
                      labelText: 'Confirmer le mot de passe',
                      hintText: '••••••••',
                      obscureText: _obscureConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: _toggleConfirmPasswordVisibility,
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez confirmer votre mot de passe';
                        }
                        if (value != _passwordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    
                    // Delivery specific fields
                    if (_isDeliveryRole) ...[
                      const SizedBox(height: 32),
                      
                      // Vehicle Selector
                      VehicleSelector(
                        selectedVehicle: _selectedVehicle,
                        onVehicleChanged: (vehicle) {
                          setState(() {
                            _selectedVehicle = vehicle;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Document Uploads
                      Text(
                        'Documents obligatoires',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      ImageUploadWidget(
                        title: 'Carte d\'identité (CIN)',
                        imagePath: _cinImage,
                        onImageChanged: (path) {
                          setState(() {
                            _cinImage = path;
                          });
                        },
                        isRequired: true,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      ImageUploadWidget(
                        title: 'Carte grise du véhicule',
                        imagePath: _carteGriseImage,
                        onImageChanged: (path) {
                          setState(() {
                            _carteGriseImage = path;
                          });
                        },
                        isRequired: true,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      ImageUploadWidget(
                        title: 'Permis de conduire',
                        imagePath: _permisImage,
                        onImageChanged: (path) {
                          setState(() {
                            _permisImage = path;
                          });
                        },
                        isRequired: true,
                      ),
                    ],
                    
                    const SizedBox(height: 40),
                    
                    // Signup Button
                    CustomButton(
                      text: 'S\'inscrire',
                      onPressed: _handleSignup,
                      isLoading: _isLoading,
                      width: double.infinity,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Déjà un compte? ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        CustomButton(
                          text: 'Se connecter',
                          type: ButtonType.text,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

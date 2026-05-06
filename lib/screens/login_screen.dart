import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/role_selector.dart';
import '../services/auth_service.dart';
import '../models/responses/auth_response.dart';
import '../core/network/http_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  UserRole _selectedRole = UserRole.client;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Appel à l'API de login
      final response = await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Vérifier si une étape OTP est requise
      if (response.requiresOtp) {
        // Rediriger vers la page de vérification OTP
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/otp_verification',
            arguments: {
              'email': _emailController.text.trim(),
              'sessionToken': response.sessionToken ?? response.token,
            },
          );
        }
      } else if (response.isComplete) {
        // Connexion directe réussie
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connexion réussie! Bienvenue ${response.user.fullName}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // Mettre à jour l'AuthProvider avec le vrai token
        if (mounted) {
          print('DEBUG: response.user = ${response.user.toString()}');
          print('DEBUG: response.user.role = ${response.user.role}');
          print('DEBUG: response.user.firstName = ${response.user.firstName}');
          print('DEBUG: response.user.lastName = ${response.user.lastName}');
          print('DEBUG: response.user.fullName = ${response.user.fullName}');
          
          final authProvider = provider_pkg.Provider.of<AuthProvider>(context, listen: false);
          print('DEBUG: Avant setUser - AuthProvider.user = ${authProvider.currentUser?.fullName}');
          
          authProvider.setUser(response.user);
          authProvider.setToken(response.token);
          
          // Sauvegarder le token dans SharedPreferences pour les services Riverpod
          _saveTokenToPreferences(response.token);
          
          print('DEBUG: Après setUser - AuthProvider.user = ${authProvider.currentUser?.fullName}');
          print('DEBUG: AuthProvider.token = ${authProvider.token}');
        }

        // Rediriger selon le rôle de l'utilisateur
        if (mounted) {
          if (response.user.role == UserRole.client) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/client_dashboard',
              (route) => false,
            );
          } else if (response.user.role == UserRole.delivery) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/driver_main',
              (route) => false,
            );
          }
        }
      } else {
        throw Exception('Réponse de connexion invalide');
      }
    } catch (e) {
      String errorMessage = 'Erreur de connexion';
      
      // Gestion des erreurs spécifiques
      if (e is ServiceValidationException) {
        errorMessage = e.toString();
      } else if (e is ValidationException) {
        errorMessage = e.toString();
      } else if (e is AuthErrorResponse) {
        errorMessage = e.message;
      } else if (e is NetworkException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'Erreur de connexion: $e';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSignup() {
    Navigator.pushNamed(context, '/signup');
  }

  Future<void> _saveTokenToPreferences(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      print('DEBUG: Token sauvegardé dans SharedPreferences: $token');
    } catch (e) {
      print('DEBUG: Erreur sauvegarde token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceColor,
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connectez-vous à votre compte AtlasMove',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
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
                        });
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
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
                    
                    // Password Field
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        if (value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Login Button
                    CustomButton(
                      text: 'Se connecter',
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                      width: double.infinity,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Signup Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pas encore de compte? ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        CustomButton(
                          text: 'S\'inscrire',
                          type: ButtonType.text,
                          onPressed: _navigateToSignup,
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

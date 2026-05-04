import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/responses/auth_response.dart';
import '../models/user.dart';
import '../core/network/http_client.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Page de vérification OTP pour compléter la connexion
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String sessionToken;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.sessionToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _errorMessage;
  int _remainingSeconds = 300; // 5 minutes
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    
    // Validation des arguments
    if (widget.email.isEmpty || widget.sessionToken.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur: Paramètres de connexion manquants'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      });
      return;
    }
    
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds == 0) {
            _canResend = true;
          }
        });
        _startCountdown();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.verifyOtp(
        email: widget.email,
        otp: _otpController.text.trim(),
        sessionToken: widget.sessionToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connexion réussie! Bienvenue ${response.user.fullName}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // Rediriger vers le dashboard approprié
        if (response.user.role == UserRole.client) {
          Navigator.pushReplacementNamed(context, '/client_dashboard');
        } else if (response.user.role == UserRole.delivery) {
          Navigator.pushReplacementNamed(context, '/driver_dashboard');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.resendOtp(
        email: widget.email,
        sessionToken: widget.sessionToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // Redémarrer le countdown
        setState(() {
          _remainingSeconds = 300;
          _canResend = false;
        });
        _startCountdown();
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is ServiceValidationException) {
      return error.toString();
    } else if (error is ValidationException) {
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
          'Vérification OTP',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Icône et message
              Icon(
                Icons.security,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Vérification à deux facteurs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              Text(
                'Un code OTP a été envoyé à\n${widget.email}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

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

              // Champ OTP
              CustomTextField(
                controller: _otpController,
                labelText: 'Code OTP',
                hintText: 'Entrez le code à 6 chiffres',
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                prefixIcon: const Icon(Icons.security),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le code OTP est requis';
                  }
                  if (value.length != 6) {
                    return 'Le code OTP doit contenir 6 chiffres';
                  }
                  if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
                    return 'Le code OTP ne doit contenir que des chiffres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Countdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Code valide pour: ${_formatTime(_remainingSeconds)}',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bouton de vérification
              CustomButton(
                text: _isLoading ? 'Vérification...' : 'Vérifier le code',
                onPressed: _isLoading ? null : _verifyOtp,
                isLoading: _isLoading,
                width: double.infinity,
              ),
              const SizedBox(height: 16),

              // Bouton de renvoi
              CustomButton(
                text: _canResend ? 'Renvoyer le code' : 'Renvoyer (${_formatTime(_remainingSeconds)})',
                onPressed: (_canResend && !_isLoading) ? _resendOtp : null,
                type: ButtonType.text,
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
                    const Text('Endpoint: POST /m/auth/verify-otp'),
                    Text('Email: ${widget.email}'),
                    Text('Session Token: ${widget.sessionToken.length > 20 ? widget.sessionToken.substring(0, 20) : widget.sessionToken}...'),
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

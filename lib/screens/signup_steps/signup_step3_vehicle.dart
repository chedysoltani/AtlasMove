import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/vehicle_selector.dart';

class SignupStep3Vehicle extends StatefulWidget {
  const SignupStep3Vehicle({super.key});

  @override
  State<SignupStep3Vehicle> createState() => _SignupStep3VehicleState();
}

class _SignupStep3VehicleState extends State<SignupStep3Vehicle> {
  final _formKey = GlobalKey<FormState>();
  VehicleType? _selectedVehicle;

  @override
  void dispose() {
    super.dispose();
  }

  void _goToPreviousStep() {
    Navigator.of(context).pop();
  }

  void _completeSignup() {
    if (_formKey.currentState!.validate() && _selectedVehicle != null) {
      // TODO: Finaliser l'inscription
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inscription réussie ! Bienvenue chez AtlasMove.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Rediriger vers la page de login
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } else if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un type de véhicule'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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
          onPressed: _goToPreviousStep,
        ),
        title: const Text(
          'Étape 3/3',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Livreur',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Indicator
              Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  widthFactor: 1.0,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Type de véhicule',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Sélectionnez le type de véhicule que vous utilisez pour vos livraisons',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    VehicleSelector(
                      selectedVehicle: _selectedVehicle,
                      onVehicleChanged: (vehicle) {
                        setState(() {
                          _selectedVehicle = vehicle;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Additional Vehicle Info (conditional)
                    if (_selectedVehicle == VehicleType.car) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informations supplémentaires',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Véhicule particulier ou professionnel ?',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    text: 'Particulier',
                                    type: _selectedVehicle == VehicleType.car 
                                        ? ButtonType.primary 
                                        : ButtonType.outline,
                                    onPressed: () {
                                      // TODO: Gérer le type de véhicule
                                    },
                                    height: 48,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomButton(
                                    text: 'Professionnel',
                                    type: ButtonType.outline,
                                    onPressed: () {
                                      // TODO: Gérer le type de véhicule
                                    },
                                    height: 48,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 40),
                    
                    // Navigation Buttons
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Précédent',
                            onPressed: _goToPreviousStep,
                            type: ButtonType.outline,
                            height: 56,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Valider / S\'inscrire',
                            onPressed: _completeSignup,
                            height: 56,
                          ),
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

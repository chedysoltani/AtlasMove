import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/image_upload_widget.dart';

class SignupStep2Documents extends StatefulWidget {
  const SignupStep2Documents({super.key});

  @override
  State<SignupStep2Documents> createState() => _SignupStep2DocumentsState();
}

class _SignupStep2DocumentsState extends State<SignupStep2Documents> {
  String? _cinImage;
  String? _permisImage;
  String? _carteGriseImage;

  @override
  void dispose() {
    super.dispose();
  }

  void _goToNextStep() {
    // TODO: Valider que tous les documents sont uploadés
    Navigator.of(context).pushNamed('/signup_step3');
  }

  void _goToPreviousStep() {
    Navigator.of(context).pop();
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
          'Étape 2/3',
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
                  widthFactor: 0.66,
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
                'Documents',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Veuillez télécharger les documents requis pour devenir livreur',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Documents Upload
              Column(
                children: [
                  ImageUploadWidget(
                    title: 'Carte d\'identité',
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
                    title: 'Permis de conduire',
                    imagePath: _permisImage,
                    onImageChanged: (path) {
                      setState(() {
                        _permisImage = path;
                      });
                    },
                    isRequired: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  ImageUploadWidget(
                    title: 'Carte grise',
                    imagePath: _carteGriseImage,
                    onImageChanged: (path) {
                      setState(() {
                        _carteGriseImage = path;
                      });
                    },
                    isRequired: true,
                  ),
                ],
              ),
              
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
                      text: 'Suivant',
                      onPressed: _goToNextStep,
                      height: 56,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

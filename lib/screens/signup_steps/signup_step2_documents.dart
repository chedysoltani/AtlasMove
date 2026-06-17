import 'package:easy_localization/easy_localization.dart';
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
        title: Text(
          'signup.step2_title'.tr(),
          style: const TextStyle(
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
                'signup.driver_badge'.tr(),
                style: const TextStyle(
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

              Text(
                'signup.documents_title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'signup.documents_subtitle'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              Column(
                children: [
                  ImageUploadWidget(
                    title: 'signup.id_card'.tr(),
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
                    title: 'signup.driving_license'.tr(),
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
                    title: 'signup.vehicle_registration'.tr(),
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

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'common.previous'.tr(),
                      onPressed: _goToPreviousStep,
                      type: ButtonType.outline,
                      height: 56,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: 'common.next'.tr(),
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

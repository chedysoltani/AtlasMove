import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SignupStep1Personal extends StatefulWidget {
  const SignupStep1Personal({super.key});

  @override
  State<SignupStep1Personal> createState() => _SignupStep1PersonalState();
}

class _SignupStep1PersonalState extends State<SignupStep1Personal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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

  void _goToNextStep() {
    if (_formKey.currentState!.validate()) {
      // TODO: Stocker les données temporairement
      Navigator.of(context).pushNamed('/signup_step2');
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
        title: Text(
          'signup.step1_title'.tr(),
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
                  widthFactor: 0.33,
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
                'signup.personal_info_title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'signup.personal_info_subtitle'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _firstNameController,
                            labelText: 'auth.first_name'.tr(),
                            hintText: 'Jean',
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'signup.required_first_name'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            controller: _lastNameController,
                            labelText: 'auth.last_name'.tr(),
                            hintText: 'Dupont',
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'signup.required_last_name'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    CustomTextField(
                      controller: _emailController,
                      labelText: 'auth.email'.tr(),
                      hintText: 'auth.email_hint'.tr(),
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'auth.email_required'.tr();
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'auth.email_invalid'.tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    CustomTextField(
                      controller: _phoneController,
                      labelText: 'signup.phone_label'.tr(),
                      hintText: '+33 6 12 34 56 78',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'signup.required_phone'.tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'auth.password'.tr(),
                      hintText: '••••••••••',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'auth.password_required'.tr();
                        }
                        if (value.length < 8) {
                          return 'auth.password_min8'.tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    CustomTextField(
                      controller: _confirmPasswordController,
                      labelText: 'auth.confirm_password'.tr(),
                      hintText: '••••••••••',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'signup.required_confirm_password'.tr();
                        }
                        if (value != _passwordController.text) {
                          return 'auth.passwords_mismatch'.tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 40),

                    CustomButton(
                      text: 'common.next'.tr(),
                      onPressed: _goToNextStep,
                      width: double.infinity,
                      height: 56,
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

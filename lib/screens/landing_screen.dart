import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: AppTheme.textWhite,
                            size: 20,
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Hero Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: AppTheme.textWhite,
                        size: 60,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Title
                    const Text(
                      'AtlasMove',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                        letterSpacing: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Plateforme de Transport & Livraison',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Description
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
                      ),
                      child: const Text(
                        'La solution moderne pour vos besoins de transport et livraison. Rapide, fiable et accessible à tous.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Features Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.person,
                      title: 'Pour les Clients',
                      description: 'Demandez des courses et livraisons en quelques clics',
                      onTap: () => _navigateToAuth(context, 'client'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildFeatureCard(
                      context,
                      icon: Icons.local_shipping,
                      title: 'Pour les Livreurs',
                      description: 'Recevez des missions et gagnez de l\'argent',
                      onTap: () => _navigateToAuth(context, 'delivery'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildFeatureCard(
                      context,
                      icon: Icons.location_on,
                      title: 'GPS Intégré',
                      description: 'Suivi en temps réel sur carte interactive',
                      onTap: () {},
                      isDisabled: true,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // CTA Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    CustomButton(
                      text: 'Commencer maintenant',
                      onPressed: () => _navigateToAuth(context, 'client'),
                      type: ButtonType.primary,
                      height: 56,
                      width: double.infinity,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    CustomButton(
                      text: 'Devenir Livreur',
                      onPressed: () => Navigator.of(context).pushNamed('/driver_register'),
                      type: ButtonType.outline,
                      height: 56,
                      width: double.infinity,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Bouton de test pour débogage
                    CustomButton(
                      text: '🧪 Test Inscription',
                      onPressed: () => Navigator.of(context).pushNamed('/driver_register_test'),
                      type: ButtonType.secondary,
                      height: 40,
                      width: double.infinity,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Trust Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTrustItem(Icons.security, 'Sécurisé'),
                        _buildTrustItem(Icons.speed, 'Rapide'),
                        _buildTrustItem(Icons.star, 'Fiable'),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Divider(color: AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      '© 2024 AtlasMove. Tous droits réservés.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterLink('Mentions légales'),
                        const SizedBox(width: 16),
                        _buildFooterLink('Politique de confidentialité'),
                        const SizedBox(width: 16),
                        _buildFooterLink('Contact'),
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

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDisabled 
              ? AppTheme.textSecondary.withOpacity(0.2)
              : AppTheme.primaryColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDisabled 
                          ? AppTheme.textSecondary.withOpacity(0.2)
                          : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDisabled 
                          ? AppTheme.textSecondary
                          : AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDisabled 
                                ? AppTheme.textSecondary
                                : AppTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDisabled)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement footer navigation
      },
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _navigateToAuth(BuildContext context, String role) {
    if (role == 'delivery') {
      Navigator.of(context).pushNamed('/signup_step1');
    } else {
      Navigator.of(context).pushNamed('/login');
    }
  }
}

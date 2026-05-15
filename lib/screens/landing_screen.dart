import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import 'package:google_fonts/google_fonts.dart';
  Shader linearGradient = const LinearGradient(
  colors: <Color>[
    Color(0xffFF8C42),
    Color(0xffFF5E62),
  ],
).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0));


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
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/AtlasMove.png',
                        width: 180,
                        height: 180,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Title
                
Text(
  'AtlasMove',
  style: GoogleFonts.poppins(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    foreground: Paint()..shader = linearGradient,
    shadows: [
      Shadow(
        blurRadius: 10,
        color: Colors.black26,
        offset: Offset(2, 4),
      ),
    ],
  ),
),
                    
                    
                    
                    const Text(
                      'Plateforme de Transport & Livraison',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    
                   
                    
                    // Description
                   
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

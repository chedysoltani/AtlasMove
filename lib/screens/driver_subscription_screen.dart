import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/subscription_service.dart';
import '../utils/app_theme.dart';

class DriverSubscriptionScreen extends StatefulWidget {
  const DriverSubscriptionScreen({super.key});

  @override
  State<DriverSubscriptionScreen> createState() => _DriverSubscriptionScreenState();
}

class _DriverSubscriptionScreenState extends State<DriverSubscriptionScreen> {
  final SubscriptionService _subService = SubscriptionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mon Abonnement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _subService.resetSubscription(), // developer reset utility
          )
        ],
      ),
      body: AnimatedBuilder(
        animation: _subService,
        builder: (context, _) {
          final isValid = _subService.isSubscriptionValid;
          final isTrial = _subService.isTrialActive;
          final hasUsedTrial = _subService.hasUsedTrial;
          final expiry = _subService.expiryDate;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subscription Status Card
                  _buildStatusCard(isValid, isTrial, expiry),
                  const SizedBox(height: 24),

                  // The Premium Pricing Card
                  _buildPricingCard(hasUsedTrial),
                  const SizedBox(height: 30),

                  // Call to Action Buttons
                  if (_subService.isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                    )
                  else ...[
                    if (!hasUsedTrial) ...[
                      ElevatedButton(
                        onPressed: () => _activateFreeTrial(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 8,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Activer mon 1er mois GRATUIT',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/driver_crypto_select');
                      },
                      icon: const Icon(Icons.currency_exchange_rounded, size: 20),
                      label: Text(
                        hasUsedTrial ? 'S\'abonner en Crypto (90\$ / mois)' : 'Payer l\'abonnement en Crypto (90\$)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Paiements cryptographiques directs et anonymes via Binance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(bool isValid, bool isTrial, DateTime? expiry) {
    String title = "Aucun abonnement actif";
    String subtitle = "Abonnez-vous pour recevoir les demandes de courses";
    Color accentColor = AppTheme.errorColor;
    IconData icon = Icons.warning_amber_rounded;

    if (isValid) {
      accentColor = AppTheme.successColor;
      icon = Icons.verified_rounded;
      if (isTrial) {
        title = "Période d'essai active";
        subtitle = "Expire le : ${DateFormat('dd MMMM yyyy à HH:mm').format(expiry!)}";
      } else {
        title = "Abonnement Premium Actif";
        subtitle = "Prochain renouvellement : ${DateFormat('dd MMMM yyyy').format(expiry!)}";
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPricingCard(bool hasUsedTrial) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F2130),
            const Color(0xFF141622).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Stack(
        children: [
          // Orange glowing accent in the top corner
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    blurRadius: 40,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Plan Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 1),
                      ),
                      child: const Text(
                        'PREMIUM LIVREUR',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (!hasUsedTrial)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '1ER MOIS OFFERT',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Pricing Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '90\$',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ mois',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimisez vos revenus de transport sans aucune commission.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 20),

                // Features checklist
                _buildCheckRow("0% Commission sur les courses"),
                _buildCheckRow("Priorité absolue sur les courses à proximité"),
                _buildCheckRow("Accès aux zones rouges (Forte demande)"),
                _buildCheckRow("Historique des statistiques avancé"),
                _buildCheckRow("Support premium dédié WhatsApp & Clavardage"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFF1D2925),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppTheme.successColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFEEEEEE),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateFreeTrial(BuildContext context) async {
    final success = await _subService.activateFreeTrial();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.verified_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Félicitations ! Votre mois gratuit a été activé avec succès.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

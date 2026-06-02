import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/trip_service.dart';
import '../widgets/notification_sheet.dart';
import '../services/subscription_service.dart';
import '../models/driver_subscription_models.dart';
import 'driver_active_ride.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isOnline = false;
  final LocationTrackingService _locationTrackingService = LocationTrackingService();
  
  // Statistics
  final int _totalRides = 156;
  final double _totalEarnings = 12450.75;
  final double _todayEarnings = 325.50;
  final int _todayRides = 8;

  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationTracking();
      _resumeActiveRideIfAny();
      _subService.fetchStatus();
    });
    NotificationService().initialize();
  }

  @override
  void dispose() {
    _locationTrackingService.dispose();
    super.dispose();
  }

  /// If the driver had an active ride when they closed the app, re-enter it.
  Future<void> _resumeActiveRideIfAny() async {
    try {
      final activeTrip = await TripService.getActiveTrip();
      if (!mounted || activeTrip == null) return;
      const resumable = ['accepted', 'arriving', 'in_progress'];
      if (resumable.contains(activeTrip.status)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DriverActiveRideScreen(trip: activeTrip),
        ));
      }
    } catch (_) {}
  }

  /// Initialize location tracking with authentication token
  Future<void> _initializeLocationTracking() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      print('DEBUG: Token livreur = ${token}');
      print('DEBUG: User livreur = ${authProvider.currentUser?.fullName}');

      if (token == null || token.isEmpty) {
        print('DEBUG: No authentication token available');
        _showErrorSnackBar('Erreur: Token d\'authentification non disponible');
        return;
      }

      // Check if location service is available
      final isLocationAvailable = await _locationTrackingService.isLocationServiceAvailable();
      if (!isLocationAvailable) {
        print('DEBUG: Location service not available');
        _showErrorSnackBar('Veuillez activer les services de localisation');
        return;
      }

      // Send current location immediately
      final success = await _locationTrackingService.sendCurrentLocation(token);
      if (success) {
        print('DEBUG: Initial location sent successfully');
        _showSuccessSnackBar('Localisation envoyée avec succès');
      } else {
        print('DEBUG: Failed to send initial location');
        _showErrorSnackBar('Erreur lors de l\'envoi de la localisation');
      }

      // Start continuous tracking
      await _locationTrackingService.startLocationTracking(token);
      
    } catch (e) {
      print('DEBUG: Error initializing location tracking: $e');
      _showErrorSnackBar('Erreur d\'initialisation de la localisation: ${e.toString()}');
    }
  }

  /// Show success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dashboard Livreur',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedBuilder(
            animation: NotificationService(),
            builder: (context, _) {
              final unreadCount = NotificationService().unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () => NotificationSheet.show(context),
                    icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                           textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () async {
              // Deconnecter l'utilisateur
              NotificationService().disconnect();
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _subService,
        builder: (context, child) {
          final isPastDue = _subService.subscription?.isPastDue ?? false;
          return Column(
            children: [
              if (isPastDue) _buildPastDueBanner(context),
              Expanded(child: child!),
            ],
          );
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 16),

            // Subscription Banner
            _buildSubscriptionBanner(),
            
            const SizedBox(height: 16),
            
            // Statistics Grid
            _buildStatisticsGrid(),
            
            const SizedBox(height: 16),
            
            // Recent Activity
            _buildRecentActivity(),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            _buildQuickActions(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPastDueBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Abonnement impayé — Régularisez pour accéder aux courses',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isLocationTracking = _locationTrackingService.isTracking;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statut Actuel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOnline ? 'En ligne' : 'Hors ligne',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isOnline ? Colors.green : Colors.grey).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isOnline ? Icons.online_prediction : Icons.offline_bolt,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Location tracking status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isLocationTracking ? Icons.location_on : Icons.location_off,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isLocationTracking ? 'Localisation active' : 'Localisation inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          CustomButton(
            text: _isOnline ? 'Se déconnecter' : 'Se connecter',
            onPressed: () {
              setState(() {
                _isOnline = !_isOnline;
              });
              _showStatusChangeMessage();
            },
            height: 44,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    final subService = SubscriptionService();
    return AnimatedBuilder(
      animation: subService,
      builder: (context, _) {
        final isValid = subService.isSubscriptionValid;
        final isTrial = subService.isTrialActive;

        if (isValid) {
          return InkWell(
            onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161722),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successColor.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: AppTheme.successColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Abonnement Premium Actif ✨',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isTrial ? 'Mois gratuit (expire bientôt)' : 'Abonnement valide',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
                ],
              ),
            ),
          );
        } else {
          return InkWell(
            onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Activez votre Compte Livreur',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Votre abonnement est inactif. Activez dès maintenant votre 1er mois GRATUIT (puis 90\$/mois) pour commencer à recevoir des courses avec 0% de commission !',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Activer l\'abonnement',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Courses totales',
          _totalRides.toString(),
          Icons.local_taxi,
          Colors.blue,
        ),
        _buildStatCard(
          'Revenus totaux',
          '${_totalEarnings.toStringAsFixed(2)} MAD',
          Icons.attach_money,
          Colors.green,
        ),
        _buildStatCard(
          "Revenus d'aujourd'hui",
          '${_todayEarnings.toStringAsFixed(2)} MAD',
          Icons.today,
          Colors.orange,
        ),
        _buildStatCard(
          "Courses d'aujourd'hui",
          _todayRides.toString(),
          Icons.directions_car,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up,
                color: Colors.green,
                size: 14,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          
          const SizedBox(height: 2),
          
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activité récente',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Activity List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildActivityItem(
                'Course terminée',
                'Centre Commercial -> Rue Mohamed',
                '45.50 MAD',
                Icons.check_circle,
                Colors.green,
                'Il y a 2 heures',
              ),
              _buildDivider(),
              _buildActivityItem(
                'Course annulée',
                'Aéroport -> Hôtel',
                '0.00 MAD',
                Icons.cancel,
                Colors.red,
                'Il y a 4 heures',
              ),
              _buildDivider(),
              _buildActivityItem(
                'Course terminée',
                'Gare -> Quartier Nord',
                '32.00 MAD',
                Icons.check_circle,
                Colors.green,
                'Il y a 6 heures',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String route,
    String price,
    IconData icon,
    Color color,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          
          const SizedBox(width: 10),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  route,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey.shade200,
      indent: 68,
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions rapides',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Voir les courses',
                onPressed: () {
                  Navigator.pushNamed(context, '/driver_rides');
                },
                height: 44,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Revenus',
                onPressed: () {
                  Navigator.pushNamed(context, '/driver_earnings');
                },
                height: 44,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Services',
                onPressed: () {
                  Navigator.pushNamed(context, '/services_catalogue');
                },
                height: 44,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: 'Historique',
                onPressed: () {
                  Navigator.pushNamed(context, '/services_assignments');
                },
                height: 44,
                type: ButtonType.secondary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Location refresh button
        CustomButton(
          text: '🔄 Actualiser la localisation',
          onPressed: _refreshLocation,
          height: 44,
          type: ButtonType.secondary,
        ),

        const SizedBox(height: 12),

        // Partnership Offer Button
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade700,
                Colors.orange.shade400,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/driver_offer'),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Offre Partenariat & Progression',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Refresh location manually
  Future<void> _refreshLocation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token == null || token.isEmpty) {
        _showErrorSnackBar('Erreur: Token d\'authentification non disponible');
        return;
      }

      print('DEBUG: Manual location refresh requested');
      
      final success = await _locationTrackingService.sendCurrentLocation(token);
      if (success) {
        print('DEBUG: Manual location refresh successful');
        _showSuccessSnackBar('Localisation actualisée avec succès');
      } else {
        print('DEBUG: Manual location refresh failed');
        _showErrorSnackBar('Erreur lors de l\'actualisation de la localisation');
      }
    } catch (e) {
      print('DEBUG: Error in manual location refresh: $e');
      _showErrorSnackBar('Erreur: ${e.toString()}');
    }
  }

  void _showStatusChangeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'Vous êtes maintenant en ligne' : 'Vous êtes maintenant hors ligne'),
        backgroundColor: _isOnline ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

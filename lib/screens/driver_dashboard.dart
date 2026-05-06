import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../providers/auth_provider.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isOnline = false;
  
  // Statistics
  final int _totalRides = 156;
  final double _totalEarnings = 12450.75;
  final double _todayEarnings = 325.50;
  final int _todayRides = 8;

  @override
  void initState() {
    super.initState();
    // Debug: Vérifier le token du livreur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      print('DEBUG: Token livreur = ${authProvider.token}');
      print('DEBUG: User livreur = ${authProvider.currentUser?.fullName}');
    });
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
          IconButton(
            onPressed: () {
              // TODO: Notifications
            },
            icon: const Icon(Icons.notifications, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            
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
    );
  }

  Widget _buildStatusCard() {
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
                  Navigator.pushNamed(context, '/services');
                },
                height: 44,
              ),
            ),
          ],
        ),
      ],
    );
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

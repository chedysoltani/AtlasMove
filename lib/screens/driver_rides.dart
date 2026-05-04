import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

enum RideStatus { pending, accepted, rejected, completed, cancelled }

class DriverRidesScreen extends StatefulWidget {
  const DriverRidesScreen({super.key});

  @override
  State<DriverRidesScreen> createState() => _DriverRidesScreenState();
}

class _DriverRidesScreenState extends State<DriverRidesScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Courses disponibles',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'En ligne - Recherche de courses...',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '3 disponibles',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rides List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildRideCard(
                  id: 'RIDE-001',
                  customerName: 'Mohammed Ali',
                  pickup: 'Aéroport Mohammed V, Terminal 1',
                  destination: 'Hôtel Marrakech, Guéliz',
                  distance: 12.5,
                  price: 85.00,
                  type: 'Taxi',
                  status: RideStatus.pending,
                  urgency: 'Élevée',
                ),
                const SizedBox(height: 16),
                _buildRideCard(
                  id: 'RIDE-002',
                  customerName: 'Fatima Zahra',
                  pickup: 'Centre Commercial Al Maqam',
                  destination: 'Rue Agdal, Rabat',
                  distance: 8.3,
                  price: 45.50,
                  type: 'Livraison',
                  status: RideStatus.pending,
                  urgency: 'Moyenne',
                ),
                const SizedBox(height: 16),
                _buildRideCard(
                  id: 'RIDE-003',
                  customerName: 'Youssef Amine',
                  pickup: 'Gare Casa Port',
                  destination: 'Zone Industrielle Aïn Sebaâ',
                  distance: 15.7,
                  price: 120.00,
                  type: 'Camion',
                  status: RideStatus.pending,
                  urgency: 'Normale',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard({
    required String id,
    required String customerName,
    required String pickup,
    required String destination,
    required double distance,
    required double price,
    required String type,
    required RideStatus status,
    required String urgency,
  }) {
    final isUrgent = urgency == 'Élevée';
    final typeColor = _getTypeColor(type);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: status == RideStatus.pending ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUrgent ? Colors.red.withOpacity(0.3) : Colors.grey.shade200,
                width: isUrgent ? 2 : 1,
              ),
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
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.red.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Ride ID and Type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  id,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isUrgent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'URGENT',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Client: $customerName',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${price.toStringAsFixed(2)} MAD',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Route Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Pickup
                      _buildLocationRow(
                        Icons.location_on,
                        'Départ',
                        pickup,
                        Colors.green,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Destination
                      _buildLocationRow(
                        Icons.flag,
                        'Destination',
                        destination,
                        Colors.red,
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                if (status == RideStatus.pending)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Refuser',
                            onPressed: () => _handleRideAction(id, false),
                            height: 48,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Accepter',
                            onPressed: () => _handleRideAction(id, true),
                            height: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String location,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'taxi':
        return Colors.blue;
      case 'livraison':
        return Colors.orange;
      case 'camion':
        return Colors.purple;
      case 'moto':
        return Colors.green;
      case 'yacht':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  void _handleRideAction(String rideId, bool accepted) {
    setState(() {
      // TODO: Update ride status
    });

    if (accepted) {
      // Navigate to active ride screen
      Navigator.pushNamed(context, '/driver_active_ride');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course acceptée ! Navigation vers le trajet...'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course refusée'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Play sound effect
    HapticFeedback.lightImpact();
  }
}

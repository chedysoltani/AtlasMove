import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

enum RidePhase { arriving, started, completed }

class DriverActiveRideScreen extends StatefulWidget {
  const DriverActiveRideScreen({super.key});

  @override
  State<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen>
    with TickerProviderStateMixin {
  RidePhase _currentPhase = RidePhase.arriving;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // Ride data
  final String _customerName = 'Mohammed Ali';
  final String _pickup = 'Aéroport Mohammed V, Terminal 1';
  final String _destination = 'Hôtel Marrakech, Guéliz';
  final double _totalDistance = 12.5;
  final double _currentDistance = 8.2;
  final double _price = 85.00;
  final String _estimatedTime = '25 min';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: (_totalDistance - _currentDistance) / _totalDistance,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map Background
          _buildMapBackground(),
          
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
          
          // Bottom Sheet with ride info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildRideInfoSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Map Grid Pattern
          CustomPaint(
            size: Size.infinite,
            painter: RouteMapPainter(),
          ),
          
          // Route visualization
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Driver position
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor, width: 3),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Route line
                Container(
                  width: 4,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, Colors.green],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Customer position
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 3),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          
          // Map Controls
          Positioned(
            top: 120,
            right: 20,
            child: Column(
              children: [
                _buildMapControl(Icons.my_location, () {
                  // TODO: Center on current location
                }),
                const SizedBox(height: 8),
                _buildMapControl(Icons.navigation, () {
                  // TODO: Start navigation
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black, size: 24),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          Expanded(
            child: Text(
              'Course en cours',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Emergency call
            },
            icon: const Icon(Icons.phone, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildRideInfoSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Customer Info
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.8 (42 courses)',
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Route Progress
            _buildRouteProgress(),
            
            const SizedBox(height: 24),
            
            // Trip Info
            _buildTripInfo(),
            
            const SizedBox(height: 24),
            
            // Action Button
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteProgress() {
    final progress = (_totalDistance - _currentDistance) / _totalDistance;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progression du trajet',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Progress Bar
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_currentDistance.toStringAsFixed(1)} km restants',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _estimatedTime,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Départ', _pickup),
          const SizedBox(height: 12),
          _buildInfoRow('Destination', _destination),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Distance', '${_totalDistance.toStringAsFixed(1)} km'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow('Prix', '${_price.toStringAsFixed(2)} MAD'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
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
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    String buttonText;
    VoidCallback onPressed;

    switch (_currentPhase) {
      case RidePhase.arriving:
        buttonText = 'Je suis arrivé';
        onPressed = () => _updatePhase(RidePhase.started);
        break;
      case RidePhase.started:
        buttonText = 'Démarrer la course';
        onPressed = () => _updatePhase(RidePhase.completed);
        break;
      case RidePhase.completed:
        buttonText = 'Terminer la course';
        onPressed = () => _completeRide();
        break;
    }

    return CustomButton(
      text: buttonText,
      onPressed: onPressed,
      height: 56,
    );
  }

  void _updatePhase(RidePhase newPhase) {
    setState(() {
      _currentPhase = newPhase;
    });

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getPhaseMessage(newPhase)),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _completeRide() {
    // Navigate to ride completion screen
    Navigator.pushNamed(context, '/driver_ride_complete');
  }

  String _getPhaseMessage(RidePhase phase) {
    switch (phase) {
      case RidePhase.arriving:
        return 'En route vers le client...';
      case RidePhase.started:
        return 'Course en cours...';
      case RidePhase.completed:
        return 'Course terminée !';
    }
  }
}

class RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;

    // Draw grid
    const gridSize = 50.0;
    
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // Draw roads
    final roadPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 3;
    
    // Main road
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      roadPaint,
    );
    
    // Cross road
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.5, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

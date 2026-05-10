import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import 'driver_dashboard.dart';
import 'driver_rides.dart';
import 'driver_active_ride.dart';
import 'driver_earnings.dart';
import 'driver_profile.dart';
import '../services/trip_service.dart';
import '../models/trip_models.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isCheckingActiveTrip = false;
  bool _isActiveTripScreenOpen = false;
  
  final List<Widget> _pages = [
    const DriverDashboard(),
    const DriverRidesScreen(),
    const DriverEarningsScreen(),
    const DriverProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for active trip when screen is first loaded
    // TEMPORARILY DISABLED: uncomment to enable active trip checking on startup
    // _checkActiveTrip();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // TEMPORARILY DISABLED: uncomment to enable active trip checking on resume
      // _checkActiveTrip();
    }
  }

  Future<void> _checkActiveTrip() async {
    if (_isCheckingActiveTrip || _isActiveTripScreenOpen) return;
    
    setState(() => _isCheckingActiveTrip = true);
    
    try {
      final AvailableTrip? activeTrip = await TripService.getActiveTrip();
      
      if (activeTrip != null && mounted) {
        _isActiveTripScreenOpen = true;
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverActiveRideScreen(trip: activeTrip),
          ),
        );
        
        // When we return from the active ride screen, reset the flag
        if (mounted) {
          _isActiveTripScreenOpen = false;
        }
      }
    } catch (e) {
      debugPrint('Failed to check active trip: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingActiveTrip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          if (_isCheckingActiveTrip)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.local_taxi,
                label: 'Courses',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.attach_money,
                label: 'Revenus',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person,
                label: 'Profil',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

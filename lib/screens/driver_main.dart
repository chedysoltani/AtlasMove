import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/app_theme.dart';
import 'driver_dashboard.dart';
import 'driver_rides.dart';
import 'driver_active_ride.dart';
import 'driver_profile.dart';
import 'driver_rendezvous_screen.dart';
import 'services_screen.dart';
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
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DriverDashboard(),
      DriverRidesScreen(
        onBackToDashboard: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const DriverRendezvousScreen(),
      const ServicesScreen(),
      const DriverProfileScreen(),
    ];
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.dashboard_rounded,
                  label: 'nav.dashboard'.tr(), index: 0),
              _buildNavItem(icon: Icons.local_taxi_rounded,
                  label: 'nav.rides'.tr(), index: 1),
              _buildNavItem(icon: Icons.calendar_month_rounded,
                  label: 'nav.rdv'.tr(), index: 2),
              _buildNavItem(icon: Icons.work_outline_rounded,
                  label: 'nav.services'.tr(), index: 3),
              _buildNavItem(icon: Icons.person_rounded,
                  label: 'nav.profile'.tr(), index: 4),
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
    const orange = Color(0xFFFF6B35);

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 14 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? orange.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: isSelected ? orange : const Color(0xFF9BA3B4),
              size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: isSelected ? orange : const Color(0xFF9BA3B4),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }
}

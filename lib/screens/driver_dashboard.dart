import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/trip_service.dart';
import '../services/subscription_service.dart';
import '../widgets/notification_sheet.dart';
import 'driver_active_ride.dart';

// Style de carte propre style inDrive — routes visibles, design épuré
const String _mapStyle = '''[
  {"featureType":"all","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#f0ede8"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#e8e4de"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#d4cfc9"},{"weight":"1"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry.stroke","stylers":[{"color":"#c8c3bc"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffe082"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#f5c518"},{"weight":"1"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.local","elementType":"geometry.stroke","stylers":[{"color":"#ddd8d0"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#666666"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"},{"weight":"3"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#aed6f1"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#5b8fa8"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#333333"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#777777"}]},
  {"featureType":"building","elementType":"geometry.fill","stylers":[{"color":"#e4ddd5"}]},
  {"featureType":"building","elementType":"geometry.stroke","stylers":[{"color":"#d4ccc4"}]}
]''';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with TickerProviderStateMixin {
  // Map
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  final Set<Marker> _markers = {};

  // State
  bool _isOnline = false;

  // Services
  final LocationTrackingService _locationTrackingService =
      LocationTrackingService();
  final SubscriptionService _subService = SubscriptionService();

  // Animation
  late AnimationController _onlineAnimController;

  // Stats (static for now)
  final double _todayEarnings = 325.50;
  final int _todayRides = 8;
  final double _rating = 4.8;

  @override
  void initState() {
    super.initState();
    _onlineAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _initializeLocationTracking();
      _resumeActiveRideIfAny();
      _subService.fetchStatus();
    });
    NotificationService().initialize();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionSub?.cancel();
    _locationTrackingService.dispose();
    _onlineAnimController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latLng = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = latLng;
      _markers.clear();
      _markers.add(_buildDriverMarker(latLng));
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15.5),
      ),
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final updated = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPosition = updated;
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(_buildDriverMarker(updated));
      });
      if (_isOnline) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(updated));
      }
    });
  }

  Marker _buildDriverMarker(LatLng position) {
    return Marker(
      markerId: const MarkerId('driver'),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        _isOnline ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
      ),
      anchor: const Offset(0.5, 0.5),
    );
  }

  Future<void> _initializeLocationTracking() async {
    try {
      final token =
          Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) return;
      await _locationTrackingService.sendCurrentLocation(token);
      await _locationTrackingService.startLocationTracking(token);
    } catch (_) {}
  }

  Future<void> _resumeActiveRideIfAny() async {
    try {
      final activeTrip = await TripService.getActiveTrip();
      if (!mounted || activeTrip == null) return;
      const resumable = ['accepted', 'livreur_en_route', 'in_progress'];
      if (resumable.contains(activeTrip.status)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DriverActiveRideScreen(trip: activeTrip),
        ));
      }
    } catch (_) {}
  }

  void _toggleOnline() {
    setState(() {
      _isOnline = !_isOnline;
      // Rebuild marker with new color
      if (_currentPosition != null) {
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(_buildDriverMarker(_currentPosition!));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOnline ? 'Vous êtes maintenant en ligne' : 'Vous êtes hors ligne',
        ),
        backgroundColor: _isOnline ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
  }

  void _centerOnMe() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15.5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // â”€â”€â”€ FULL SCREEN MAP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildMap(),

          // â”€â”€â”€ TOP BAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // â”€â”€â”€ PAST DUE BANNER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _subService,
              builder: (_, __) {
                if (_subService.subscription?.isPastDue != true) {
                  return const SizedBox.shrink();
                }
                return _buildPastDueBanner();
              },
            ),
          ),

          // â”€â”€â”€ CENTER ON ME BUTTON â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            right: 16,
            bottom: 240,
            child: _buildMapButton(
              icon: Icons.my_location_rounded,
              onTap: _centerOnMe,
            ),
          ),

          // â”€â”€â”€ BOTTOM PANEL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // MAP
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentPosition ?? const LatLng(36.8065, 10.1815),
        zoom: 15.5,
      ),
      style: _mapStyle,
      onMapCreated: (controller) {
        _mapController = controller;
        if (_currentPosition != null) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _currentPosition!, zoom: 15.5),
            ),
          );
        }
      },
      markers: _markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: false,
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // TOP BAR
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Logo / App name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOnline ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isOnline ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Notification button
            AnimatedBuilder(
              animation: NotificationService(),
              builder: (_, __) {
                final count = NotificationService().unreadCount;
                return _buildTopIconButton(
                  icon: Icons.notifications_outlined,
                  badge: count,
                  onTap: () => NotificationSheet.show(context),
                );
              },
            ),

            const SizedBox(width: 8),

            // Menu button
            _buildTopIconButton(
              icon: Icons.menu_rounded,
              onTap: _showMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            if (badge > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // MAP FAB BUTTON
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildMapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BOTTOM PANEL
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                // Stats row
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.attach_money_rounded,
                      value: '${_todayEarnings.toStringAsFixed(0)} TND',
                      label: "Aujourd'hui",
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    _buildStatChip(
                      icon: Icons.directions_car_rounded,
                      value: '$_todayRides',
                      label: 'Courses',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _buildStatChip(
                      icon: Icons.star_rounded,
                      value: '$_rating',
                      label: 'Note',
                      color: Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Online / Offline toggle button
                GestureDetector(
                  onTap: _toggleOnline,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isOnline
                            ? [
                                const Color(0xFF1DB954),
                                const Color(0xFF17A345),
                              ]
                            : [
                                AppTheme.primaryColor,
                                const Color(0xFFE55A2B),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline ? Colors.green : AppTheme.primaryColor)
                              .withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _isOnline
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            key: ValueKey(_isOnline),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isOnline
                                ? 'Passer hors ligne'
                                : 'Démarrer — Aller en ligne',
                            key: ValueKey(_isOnline),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Quick action row
                Row(
                  children: [
                    _buildQuickAction(
                      icon: Icons.history_rounded,
                      label: 'Historique',
                      onTap: () => Navigator.pushNamed(context, '/services_assignments'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.person_rounded,
                      label: 'Profil',
                      onTap: () => Navigator.pushNamed(context, '/driver_profile'),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.card_membership_rounded,
                      label: 'Abonnement',
                      onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
                      highlight: !(_subService.isSubscriptionValid),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickAction(
                      icon: Icons.star_rounded,
                      label: 'Offre',
                      onTap: () => Navigator.pushNamed(context, '/driver_offer'),
                      highlightColor: Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
    Color? highlightColor,
  }) {
    final color = highlightColor ??
        (highlight ? AppTheme.primaryColor : Colors.grey.shade700);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: highlight || highlightColor != null
                ? color.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight || highlightColor != null
                  ? color.withValues(alpha: 0.25)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // PAST DUE BANNER
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildPastDueBanner() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Abonnement impayé — Régularisez pour accéder aux courses',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // MENU
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _buildMenuSheet(),
    );
  }

  Widget _buildMenuSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuTile(Icons.person_rounded, 'Mon Profil', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver_profile');
            }),
            _buildMenuTile(Icons.card_membership_rounded, 'Abonnement', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver_subscription');
            }),
            _buildMenuTile(Icons.star_rounded, 'Offre Partenariat', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver_offer');
            }),
            _buildMenuTile(Icons.refresh_rounded, 'Actualiser localisation', () {
              Navigator.pop(context);
              _refreshLocation();
            }),
            const Divider(height: 24),
            _buildMenuTile(
              Icons.logout_rounded,
              'Déconnexion',
              () async {
                Navigator.pop(context);
                NotificationService().disconnect();
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (mounted) Navigator.of(context).pushReplacementNamed('/login');
              },
              color: Colors.red,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? Colors.black87;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: c,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }

  Future<void> _refreshLocation() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) return;
      await _locationTrackingService.sendCurrentLocation(token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Localisation actualisée'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }
}

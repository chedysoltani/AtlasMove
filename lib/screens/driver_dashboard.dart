import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../utils/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/location_tracking_service.dart';
import '../services/location_foreground_service.dart';
import '../services/notification_service.dart';
import '../services/call_service.dart';
import '../services/trip_service.dart';
import '../services/subscription_service.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/service_api.dart';
import '../models/service_models.dart';
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
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
  bool _isTogglingOnline = false;

  bool get _isOnline => DriverService.isOnline;

  // Services
  final LocationTrackingService _locationTrackingService =
      LocationTrackingService();
  final SubscriptionService _subService = SubscriptionService();

  // Animation
  late AnimationController _onlineAnimController;

  // Stats — loaded from API
  double _todayEarnings = 0.0;
  int _todayRides = 0;
  String _statsCurrency = 'TND';
  bool _statsLoading = false;

  // Driver service type (null = loading)
  String? _driverTransportType;

  @override
  void initState() {
    super.initState();
    _onlineAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    DriverService.isOnlineNotifier.addListener(_onAvailabilityChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _initializeLocationTracking();
      _resumeActiveRideIfAny();
      _subService.fetchStatus();
      DriverService.loadAvailability();
      _loadDriverServiceType();
      _loadDailyStats();
    });
    NotificationService().initialize();
    CallService().connectSocket();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    DriverService.isOnlineNotifier.removeListener(_onAvailabilityChanged);
    _mapController?.dispose();
    _positionSub?.cancel();
    _onlineAnimController.dispose();
    super.dispose();
  }

  void _onAvailabilityChanged() {
    if (mounted) setState(() {});
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
      await LocationForegroundService.start();
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

  bool get _canGoOnline {
    final sub = _subService.subscription;
    if (sub == null) return false;
    return sub.isValid;
  }

  Future<void> _toggleOnline() async {
    if (_isTogglingOnline) return;
    HapticFeedback.mediumImpact();

    final newStatus = !_isOnline;

    // Block going online if subscription is not valid
    if (newStatus && !_canGoOnline) {
      Navigator.pushNamed(context, '/driver_subscription');
      return;
    }

    setState(() => _isTogglingOnline = true);
    try {
      await DriverService.setAvailability(newStatus);
      // Rebuild map marker with new color
      if (_currentPosition != null && mounted) {
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'driver');
          _markers.add(_buildDriverMarker(_currentPosition!));
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'driver.status_online'.tr() : 'driver.status_offline'.tr()),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          ),
        );
      }
    } on ForbiddenException {
      // Safety net: subscription expired between the local check and the API call.
      await _subService.fetchStatus();
      if (mounted) Navigator.pushNamed(context, '/driver_subscription');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: impossible de changer le statut'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingOnline = false);
    }
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
                final sub = _subService.subscription;
                if (sub == null) return const SizedBox.shrink();
                if (sub.isPastDue) return _buildPastDueBanner();
                if (sub.isCanceled || (!sub.isValid && !sub.isPastDue)) return _buildInactiveBanner();
                if (sub.isTrial) return _buildTrialBanner();
                return const SizedBox.shrink();
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
                    _isOnline ? 'driver.status_online'.tr() : 'driver.status_offline'.tr(),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E6EF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section label ─────────────────────────────────────
                Row(
                  children: [
                    Text(
                      'driver.dashboard_title'.tr(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9BA3B4),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _statsLoading ? null : _loadDailyStats,
                      child: _statsLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Color(0xFF9BA3B4),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: Color(0xFF9BA3B4),
                            ),
                    ),
                    const Spacer(),
                    Text(
                      _isOnline ? '● ${'driver.status_online'.tr()}' : '● ${'driver.status_offline'.tr()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isOnline
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF9BA3B4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Stats row ─────────────────────────────────────────
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.account_balance_wallet_rounded,
                      value: '${_todayEarnings.toStringAsFixed(2)} $_statsCurrency',
                      label: 'nav.earnings'.tr(),
                      color: const Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 10),
                    _buildStatChip(
                      icon: Icons.directions_car_rounded,
                      value: '$_todayRides',
                      label: 'nav.rides'.tr(),
                      color: const Color(0xFF3B82F6),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Online / Offline button ───────────────────────────
                GestureDetector(
                  onTap: _isTogglingOnline ? null : _toggleOnline,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isOnline
                            ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                            : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF0F172A))
                              .withValues(alpha: 0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _isTogglingOnline
                        ? const Center(
                            child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  _isOnline
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey(_isOnline),
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _isOnline
                                      ? 'driver.status_offline'.tr()
                                      : 'driver.status_online'.tr(),
                                  key: ValueKey(_isOnline),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
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
                fontSize: 9,
                fontWeight: FontWeight.w500,
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
        (highlight ? AppTheme.primaryColor : const Color(0xFF475569));
    final isAccented = highlight || highlightColor != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isAccented ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAccented
                  ? color.withValues(alpha: 0.22)
                  : const Color(0xFFE2E6EF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isAccented
                      ? color.withValues(alpha: 0.12)
                      : const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 6),
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
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Abonnement impayé — Régularisez pour accéder aux courses',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialBanner() {
    final sub = _subService.subscription;
    if (sub == null || !sub.isTrial) return const SizedBox.shrink();
    final days = sub.daysRemaining;
    final isUrgent = days <= 7;
    final bg = isUrgent ? const Color(0xFFEA580C) : const Color(0xFF1E40AF);
    final icon = isUrgent ? Icons.timer_rounded : Icons.card_membership_rounded;
    final message = days == 0
        ? 'Période d\'essai expirée — Abonnez-vous pour continuer'
        : isUrgent
            ? 'Période d\'essai : encore $days jour${days > 1 ? 's' : ''} — Abonnez-vous'
            : 'Essai gratuit actif · encore $days jours restants';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveBanner() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/driver_subscription'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Compte inactif — Abonnez-vous pour recevoir des courses',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 12),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // MENU
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadDailyStats() async {
    if (!mounted) return;
    setState(() => _statsLoading = true);
    double? lat, lng;
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}
    final stats = await DriverService.fetchDailyStats(latitude: lat, longitude: lng);
    if (mounted) {
      setState(() {
        _statsLoading = false;
        if (stats != null) {
          _todayEarnings = stats['today_earnings'] as double;
          _todayRides = stats['today_rides'] as int;
          _statsCurrency = stats['currency'] as String;
        }
      });
    }
  }

  Future<void> _loadDriverServiceType() async {
    try {
      final token = await TokenStorage.getAccessToken() ?? '';
      final assignment = await ServiceApi.getCurrentAssignment(token: token);
      if (mounted && assignment != null) {
        setState(() => _driverTransportType = assignment.transportType);
      }
    } catch (_) {}
  }

  bool get _isTaxiDriver =>
      _driverTransportType != null &&
      TransportTypeConstants.taxiSlugs.contains(_driverTransportType);

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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E6EF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // Header label
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Menu', style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 16),

            _buildMenuTile(Icons.person_rounded, 'driver.profile_title'.tr(),
                'driver.profile_subtitle'.tr(), () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver_profile');
            }),
            if (_isTaxiDriver)
              _buildMenuTile(Icons.card_membership_rounded, 'driver.subscription_menu'.tr(),
                  'driver.subscription_subtitle'.tr(), () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver_subscription');
              })
            else
              _buildMenuTile(Icons.percent_rounded, 'Commission 10%',
                  'Payable chaque mois — compte désactivé sinon', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/driver_earnings');
              }),
            _buildMenuTile(Icons.star_rounded, 'driver.offers_menu'.tr(),
                'driver.offers_subtitle'.tr(), () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/driver_offer');
            }),
            _buildMenuTile(Icons.my_location_rounded, 'driver.refresh_location'.tr(),
                'driver.refresh_location_subtitle'.tr(), () {
              Navigator.pop(context);
              _refreshLocation();
            }),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFF1F3F7), height: 1),
            ),

            _buildMenuTile(Icons.logout_rounded, 'auth.logout'.tr(),
                'driver.logout_subtitle'.tr(), () async {
              Navigator.pop(context);
              NotificationService().disconnect();
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            }, isDestructive: true),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String label, String subtitle,
      VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : const Color(0xFF0F172A);
    final bgColor = isDestructive
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF8F9FB);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFECACA)
                : const Color(0xFFE2E6EF),
          ),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              Text(subtitle, style: const TextStyle(
                fontSize: 11, color: Color(0xFF9BA3B4))),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, size: 13,
              color: color.withValues(alpha: 0.35)),
        ]),
      ),
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
            content: Text('driver.location_refreshed'.tr()),
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

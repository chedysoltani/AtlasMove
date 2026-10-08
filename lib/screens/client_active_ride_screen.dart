import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip_models.dart';
import '../providers/ride_state_provider.dart';
import '../services/trip_service.dart';
import '../services/route_service.dart';
import '../services/call_service.dart';
import '../screens/active_call_screen.dart';
import '../utils/app_theme.dart';
import '../map/driver_marker_controller.dart';
import '../map/map_camera.dart';
import '../map/map_markers.dart';
import '../map/map_widgets.dart';
import '../map/route_overlay.dart';

// ─── Local palette ────────────────────────────────────────────────────────────
class _C {
  static const primary     = Color(0xFFFF6600);
  static const green       = Color(0xFF22C55E);
  static const red         = Color(0xFFEF4444);
  static const amber       = Color(0xFFF59E0B);
  static const gray900     = Color(0xFF0F172A);
  static const gray800     = Color(0xFF1E293B);
  static const gray600     = Color(0xFF475569);
  static const gray400     = Color(0xFF94A3B8);
  static const gray100     = Color(0xFFF1F5F9);
  static const white       = Colors.white;
  static const accentLight = Color(0xFFFFF7ED);
}

class ClientActiveRideScreen extends ConsumerStatefulWidget {
  final String tripId;
  final double lockedFare;
  final String currency;
  final String driverName;
  final String? driverPhone;
  final String? driverPhoto;
  final double driverRating;
  final String driverVehicle;
  final String destination;
  // Optional — pass for live map; screen degrades gracefully if absent
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const ClientActiveRideScreen({
    super.key,
    required this.tripId,
    required this.lockedFare,
    required this.currency,
    required this.driverName,
    this.driverPhone,
    this.driverPhoto,
    required this.driverRating,
    required this.driverVehicle,
    required this.destination,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  @override
  ConsumerState<ClientActiveRideScreen> createState() =>
      _ClientActiveRideScreenState();
}

class _ClientActiveRideScreenState extends ConsumerState<ClientActiveRideScreen>
    with TickerProviderStateMixin {
  // ── Animation ───────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  // ── Map ─────────────────────────────────────────────────────────────────────
  // UN SEUL marqueur chauffeur (id constant `driver_marker`), déplacé par
  // interpolation ; la carte seule est reconstruite pendant l'animation.
  late final DriverMarkerController _driverMarker;
  late final RouteOverlay _route;
  final FollowCamera _follow = FollowCamera();
  final ValueNotifier<double> _cameraBearing = ValueNotifier<double>(0);
  CameraPosition? _cameraPos;
  bool _isMapReady = false;
  DateTime?  _lastRouteFetch;
  bool       _fetchingRoute = false;
  Set<Marker> _staticMarkers = const <Marker>{};
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;
  bool _iconsRequested = false;

  // ── Cancellation / navigation ────────────────────────────────────────────────
  bool _isCancelling = false;
  bool _hasNavigated = false;

  // ── Helpers ─────────────────────────────────────────────────────────────────
  bool get _hasPickupCoords =>
      widget.pickupLatitude != null && widget.pickupLongitude != null;

  LatLng? get _pickupLatLng => _hasPickupCoords
      ? LatLng(widget.pickupLatitude!, widget.pickupLongitude!)
      : null;

  LatLng? get _destinationLatLng =>
      widget.destinationLatitude != null && widget.destinationLongitude != null
          ? LatLng(widget.destinationLatitude!, widget.destinationLongitude!)
          : null;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _driverMarker = DriverMarkerController(vsync: this);
    _route = RouteOverlay(vsync: this);
    // Le tracé suit le marqueur affiché : la partie parcourue passe en gris.
    _driverMarker.marker.addListener(_onDriverMarkerFrame);
    _rebuildStaticMarkers();

    // Start WebSocket + fallback polling via provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeRideProvider.notifier)
          .startForTrip(widget.tripId, 'accepted');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iconsRequested) {
      _iconsRequested = true;
      _loadIcons(MediaQuery.devicePixelRatioOf(context));
    }
  }

  @override
  void dispose() {
    _driverMarker.marker.removeListener(_onDriverMarkerFrame);
    ref.read(activeRideProvider.notifier).stopTracking();
    _driverMarker.dispose();
    _route.dispose();
    _follow.dispose();
    _cameraBearing.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onDriverMarkerFrame() {
    final p = _driverMarker.position;
    if (p != null) _route.updateProgress(p);
  }

  // ── Icônes (générées une fois par densité, cache dans la fabrique) ──────────
  Future<void> _loadIcons(double dpr) async {
    final factory = MapMarkerFactory.instance;
    try {
      final icons = await Future.wait([
        factory.vehicle(VehicleCategory.fromLabel(widget.driverVehicle), dpr),
        factory.pickupPin(dpr),
        factory.destinationPin(dpr),
      ]);
      if (!mounted) return;
      _driverMarker.setIcon(icons[0]);
      _pickupIcon = icons[1];
      _destinationIcon = icons[2];
      setState(_rebuildStaticMarkers);
    } catch (e) {
      debugPrint('ClientActiveRide: rendu des icônes impossible: $e');
      if (mounted) _driverMarker.setIcon(fallbackDriverIcon());
    }
  }

  void _rebuildStaticMarkers() {
    final pickup = _pickupLatLng;
    final dest = _destinationLatLng;
    _staticMarkers = {
      if (pickup != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: InfoWindow(title: 'booking_extra.your_position'.tr()),
          icon: _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: MapMarkerFactory.pinAnchor,
          zIndexInt: 2,
        ),
      if (dest != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: dest,
          infoWindow: InfoWindow(title: widget.destination),
          icon: _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: MapMarkerFactory.pinAnchor,
          zIndexInt: 3,
        ),
    };
  }

  /// Cadre départ + destination pour la course en cours.
  void _drawRideRoute() {
    final pickup = _pickupLatLng;
    final dest = _destinationLatLng;
    if (pickup == null || dest == null || !mounted) return;
    _route.clear();
    _fetchRoute(pickup, dest);
    if (_isMapReady) {
      MapCamera.fitBounds(_follow.controller, [pickup, dest], padding: 80);
    }
  }

  // ── Driver position update ───────────────────────────────────────────────────
  void _onNewDriverLocation(DriverLocation loc) {
    final accepted = _driverMarker.update(DriverFix(
      position: loc.position,
      heading: loc.heading,
      speedMps: loc.speed,
      accuracyM: loc.accuracy,
      timestamp: loc.updatedAt,
    ));
    if (!accepted) return; // position aberrante ou sans mouvement réel

    final newPos = loc.position;
    final status = ref.read(activeRideProvider).status;
    final target = _routeTarget(status);

    // Follow camera: frame driver + destination (inProgress) or driver + pickup (arriving)
    if (_isMapReady && _follow.isFollowing.value) {
      MapCamera.fitBounds(
        _follow.controller,
        [newPos, if (target != null) target],
        padding: 100,
      );
    }

    // Throttle route re-fetch to once every 10 seconds (4 s si hors tracé)
    final minGap = _route.isOffRoute ? 4 : 10;
    final now = DateTime.now();
    if (!_fetchingRoute &&
        target != null &&
        (_lastRouteFetch == null ||
            now.difference(_lastRouteFetch!).inSeconds >= minGap)) {
      _fetchRoute(newPos, target);
    }
  }

  LatLng? _routeTarget(RideStatus status) =>
      (status == RideStatus.inProgress && _destinationLatLng != null)
          ? _destinationLatLng
          : _pickupLatLng;

  /// Caméra sur le chauffeur (+ départ) au chargement de la carte.
  void _frameInitial(LatLng driverPos) {
    final pickup = _pickupLatLng;
    if (pickup == null) {
      _follow.controller?.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: driverPos, zoom: 16)));
      return;
    }
    MapCamera.fitBounds(_follow.controller, [driverPos, pickup], padding: 100);
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    _fetchingRoute = true;
    try {
      final result = await RouteService.getRoute(from, to);
      if (!mounted) return;
      if (result != null) {
        _route.setRoute(
          result.points,
          durationSeconds: result.durationSeconds.toDouble(),
          head: _driverMarker.position,
        );
      } else {
        _route.setRoute([from, to], head: _driverMarker.position, animate: false);
      }
      _lastRouteFetch = DateTime.now();
      if (mounted) setState(() {}); // ETA / distance
    } finally {
      _fetchingRoute = false;
    }
  }

  // ── Boutons carte ────────────────────────────────────────────────────────────
  void _recenter() {
    final pos = _driverMarker.position;
    _follow.isFollowing.value = true;
    if (pos != null) _frameInitial(pos);
  }

  void _fitWholeTrip() {
    final pos = _driverMarker.position;
    _follow.isFollowing.value = false;
    MapCamera.fitBounds(
      _follow.controller,
      [if (pos != null) pos, if (_pickupLatLng != null) _pickupLatLng!, if (_destinationLatLng != null) _destinationLatLng!],
      padding: 110,
    );
  }

  void _resetNorth() {
    final cam = _cameraPos;
    if (cam == null) return;
    _follow.controller?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: cam.target, zoom: cam.zoom, bearing: 0, tilt: 0),
    ));
  }

  // ── Status helpers ───────────────────────────────────────────────────────────
  static Color _statusColor(RideStatus s) {
    switch (s) {
      case RideStatus.accepted:   return _C.primary;
      case RideStatus.arriving:   return _C.amber;
      case RideStatus.arrived:    return _C.amber;
      case RideStatus.inProgress: return _C.green;
      case RideStatus.completed:  return _C.green;
      case RideStatus.cancelled:  return _C.red;
      default:                    return _C.gray400;
    }
  }

  static String _statusLabel(RideStatus s) {
    switch (s) {
      case RideStatus.accepted:   return 'booking.ride_confirmed'.tr();
      case RideStatus.arriving:   return 'booking.driver_en_route'.tr();
      case RideStatus.arrived:    return 'booking.driver_arrived'.tr();
      case RideStatus.inProgress: return 'booking.ride_in_progress'.tr();
      case RideStatus.completed:  return 'booking.ride_completed'.tr();
      case RideStatus.cancelled:  return 'booking.ride_cancelled'.tr();
      default:                    return 'common.pending'.tr();
    }
  }

  static IconData _statusIcon(RideStatus s) {
    switch (s) {
      case RideStatus.accepted:   return Icons.check_circle_rounded;
      case RideStatus.arriving:   return Icons.directions_car_rounded;
      case RideStatus.arrived:    return Icons.place_rounded;
      case RideStatus.inProgress: return Icons.navigation_rounded;
      case RideStatus.completed:  return Icons.flag_rounded;
      case RideStatus.cancelled:  return Icons.cancel_rounded;
      default:                    return Icons.hourglass_top_rounded;
    }
  }

  // ── Cancel ride ─────────────────────────────────────────────────────────────
  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('booking.cancel_ride'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('booking.cancel_confirm_body'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.no'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: Text('booking.cancel_ride_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await TripService.cancelClientTrip(widget.tripId, 'Annulé par le client');
      if (mounted) Navigator.pushReplacementNamed(context, '/client_dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('common.unknown_error'.tr()), backgroundColor: _C.red));
        setState(() => _isCancelling = false);
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(activeRideProvider);

    // React to driver position changes
    ref.listen<ActiveRideState>(activeRideProvider, (prev, next) {
      final nextLoc = next.driverLocation;
      if (nextLoc != null &&
          nextLoc.updatedAt != prev?.driverLocation?.updatedAt) {
        _onNewDriverLocation(nextLoc);
      }

      // When ride starts (inProgress), draw route pickup → destination
      if (next.status == RideStatus.inProgress &&
          prev?.status != RideStatus.inProgress) {
        _drawRideRoute();
      }

      // Auto-navigate when ride ends (guard against multiple calls)
      if (next.status == RideStatus.completed && mounted && !_hasNavigated) {
        _hasNavigated = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/client_trip_history');
        });
      } else if (next.status == RideStatus.cancelled && mounted && !_hasNavigated) {
        _hasNavigated = true;
        _showCancelledByDriverDialog();
      }
    });

    return Scaffold(
      backgroundColor: _C.gray100,
      body: _hasPickupCoords
          ? _buildMapLayout(rideState)
          : _buildCardLayout(rideState),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MAP LAYOUT (when pickup coords are available)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMapLayout(ActiveRideState rideState) {
    return Stack(
      children: [
        _buildGoogleMap(rideState),

        // Top header overlay
        Positioned(
          top: 0, left: 0, right: 0,
          child: _buildMapHeader(rideState),
        ),

        // Boussole / itinéraire complet / recentrage
        if (_isMapReady)
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            right: 16,
            child: _buildMapControls(),
          ),

        // Stale location warning
        if (rideState.driverLocation?.isStale == true)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16, right: 72,
            child: _buildStaleWarning(),
          ),

        // Bottom info sheet
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildBottomSheet(rideState),
        ),
      ],
    );
  }

  Widget _buildGoogleMap(ActiveRideState rideState) {
    final initialTarget = _pickupLatLng!;
    return BrandedGoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
      onMapCreated: (ctrl) {
        _follow.attach(ctrl);
        setState(() => _isMapReady = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // La position a pu arriver avant la carte : on la rejoue une fois.
          final driverLoc = ref.read(activeRideProvider).driverLocation;
          if (driverLoc != null) {
            if (!_driverMarker.hasPosition) _onNewDriverLocation(driverLoc);
            _frameInitial(driverLoc.position);
          }
        });
      },
      staticMarkers: _staticMarkers,
      driverMarker: _driverMarker.marker,
      routePolylines: _route.polylines,
      onUserGesture: _follow.onUserGesture,
      onCameraMove: (pos) {
        _cameraPos = pos;
        _cameraBearing.value = pos.bearing;
      },
      trafficEnabled: true,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        bottom: 340,
      ),
    );
  }

  Widget _buildMapHeader(ActiveRideState rideState) {
    final color = _statusColor(rideState.status);
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 12, right: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusLabel(rideState.status),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          _buildLiveDot(),
        ],
      ),
    );
  }

  /// Boutons flottants : boussole, itinéraire complet, recentrage (reprise du suivi).
  Widget _buildMapControls() {
    return ValueListenableBuilder<bool>(
      valueListenable: _follow.isFollowing,
      builder: (context, following, _) => Column(
        children: [
          MapCompassButton(bearing: _cameraBearing, onTap: _resetNorth),
          const SizedBox(height: 10),
          MapRoundButton(
            icon: Icons.route_rounded,
            onTap: _fitWholeTrip,
            tooltip: 'active_ride.full_route'.tr(),
          ),
          const SizedBox(height: 10),
          MapRoundButton(
            icon: following ? Icons.gps_fixed : Icons.gps_not_fixed,
            active: following,
            onTap: _recenter,
            tooltip: 'booking_extra.follow_driver'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.amber.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.signal_wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'booking_extra.location_pending'.tr(),
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(ActiveRideState rideState) {
    final isCancelable = rideState.status == RideStatus.accepted ||
        rideState.status == RideStatus.arriving ||
        rideState.status == RideStatus.arrived;
    final isFinished = rideState.status == RideStatus.completed ||
        rideState.status == RideStatus.cancelled;

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 3,
                  decoration: BoxDecoration(
                    color: _C.gray400.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Timeline ────────────────────────────────────────────
              _buildRideTimeline(rideState),
              const SizedBox(height: 14),

              // ── ETA (uniquement quand le driver est en route) ───────
              if (rideState.status == RideStatus.arriving &&
                  rideState.driverLocation != null &&
                  _pickupLatLng != null)
                _buildEtaRow(rideState.driverLocation!),

              // ── Driver info ─────────────────────────────────────────
              _buildDriverRow(),

              if (!isFinished) ...[
                const SizedBox(height: 10),
                _buildFareRow(),
              ],
              const SizedBox(height: 14),
              if (isFinished)
                _buildFinishedActions(rideState.status == RideStatus.completed)
              else if (isCancelable)
                _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Timeline horizontale 4 étapes
  Widget _buildRideTimeline(ActiveRideState rideState) {
    final steps = [
      (label: 'rdv.confirmed'.tr(),  done: true),
      (label: 'booking_extra.step_en_route'.tr(),  done: rideState.status == RideStatus.arriving ||
          rideState.status == RideStatus.arrived ||
          rideState.status == RideStatus.inProgress ||
          rideState.status == RideStatus.completed),
      (label: 'booking_extra.step_arrived'.tr(),   done: rideState.status == RideStatus.arrived ||
          rideState.status == RideStatus.inProgress ||
          rideState.status == RideStatus.completed),
      (label: 'rdv.completed'.tr(),  done: rideState.status == RideStatus.completed),
    ];
    final activeIndex = steps.lastIndexWhere((s) => s.done);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Ligne de connexion
          final lineActive = (i ~/ 2) < activeIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: lineActive ? _C.primary : _C.gray100,
            ),
          );
        }
        final idx = i ~/ 2;
        final step = steps[idx];
        final isActive = idx == activeIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: isActive ? 14 : 10,
              height: isActive ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.done ? _C.primary : _C.gray100,
                border: Border.all(
                  color: step.done ? _C.primary : _C.gray400.withOpacity(0.4),
                  width: isActive ? 2.5 : 1.5,
                ),
                boxShadow: isActive ? [
                  BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 8, spreadRadius: 1),
                ] : [],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: step.done ? FontWeight.w700 : FontWeight.w400,
                color: step.done ? _C.gray900 : _C.gray400,
              ),
            ),
          ],
        );
      }),
    );
  }

  /// ETA / distance du livreur jusqu'au point de pickup.
  /// Utilise l'itinéraire routier (OSRM) réduit au fil de la progression ;
  /// repli sur la distance à vol d'oiseau tant qu'aucun tracé n'est chargé.
  Widget _buildEtaRow(DriverLocation driverLoc) {
    final double distM;
    final int etaMin;
    if (_route.hasRoute && _route.remainingSeconds != null) {
      distM = _route.remainingMeters;
      etaMin = math.max(1, (_route.remainingSeconds! / 60).ceil());
    } else {
      distM = _haversineMeters(driverLoc.position, _pickupLatLng!);
      etaMin = (distM / 500).ceil(); // vitesse moyenne 30 km/h ≈ 500 m/min
    }
    final distLabel = distM < 1000
        ? '${distM.round()} m'
        : '${(distM / 1000).toStringAsFixed(1)} km';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: _C.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'booking_extra.arriving_in'.tr(namedArgs: {'min': '$etaMin'}),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _C.primary),
            ),
            const Spacer(),
            Text(
              distLabel,
              style: const TextStyle(fontSize: 12, color: _C.gray600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// Haversine distance en mètres entre deux points
  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sin1 = math.sin(dLat / 2);
    final sin2 = math.sin(dLng / 2);
    final x = sin1 * sin1 + math.cos(lat1) * math.cos(lat2) * sin2 * sin2;
    return 2 * r * math.asin(math.sqrt(x));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CARD LAYOUT (fallback when no pickup coords)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCardLayout(ActiveRideState rideState) {
    final isCancelable = rideState.status == RideStatus.accepted ||
        rideState.status == RideStatus.arriving ||
        rideState.status == RideStatus.arrived;
    final isFinished = rideState.status == RideStatus.completed ||
        rideState.status == RideStatus.cancelled;

    return SafeArea(
      child: Column(
        children: [
          _buildCardHeader(rideState),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildStatusCard(rideState),
                  const SizedBox(height: 16),
                  _buildFareCard(),
                  const SizedBox(height: 16),
                  _buildDriverCard(),
                  const SizedBox(height: 16),
                  _buildStepperCard(rideState),
                  const SizedBox(height: 24),
                  if (isFinished)
                    _buildFinishedActions(rideState.status == RideStatus.completed)
                  else if (isCancelable)
                    _buildCancelButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(ActiveRideState rideState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.gray900, _C.gray800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _C.primary.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: _C.primary, width: 1.5),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _C.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('booking.active_ride_title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('booking.real_time_tracking'.tr(),
                    style: const TextStyle(color: _C.primary, fontSize: 12)),
              ],
            ),
          ),
          _buildLiveDot(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Shared sub-widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildLiveDot() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _C.green.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.green.withAlpha(100)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('booking_extra.live'.tr(),
                  style: TextStyle(color: _C.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverRow() {
    return Row(
      children: [
        // Avatar
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_C.primary, Color(0xFFFF8C00)]),
            boxShadow: [BoxShadow(color: _C.primary.withAlpha(60), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: widget.driverPhoto != null
              ? ClipOval(child: Image.network(widget.driverPhoto!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarInitial()))
              : _avatarInitial(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.driverName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _C.gray900)),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 3),
                  Text(widget.driverRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.gray600)),
                  const SizedBox(width: 6),
                  Container(width: 3, height: 3,
                      decoration: const BoxDecoration(color: _C.gray400, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(widget.driverVehicle,
                      style: const TextStyle(fontSize: 11, color: _C.gray400)),
                ],
              ),
              if (widget.driverPhone != null && widget.driverPhone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _copyDriverPhone(widget.driverPhone!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 12, color: _C.gray400),
                      const SizedBox(width: 4),
                      Text(widget.driverPhone!,
                          style: const TextStyle(fontSize: 12, color: _C.gray600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 13, color: _C.primary),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Call button
        GestureDetector(
          onTap: _startCallToDriver,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _C.green.withAlpha(20), shape: BoxShape.circle,
              border: Border.all(color: _C.green.withAlpha(80)),
            ),
            child: const Icon(Icons.phone_rounded, color: _C.green, size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _startCallToDriver() async {
    final session = await CallService().initiateCall(widget.tripId);
    if (session == null) {
      if (mounted) {
        final err = CallService().lastError ?? 'active_ride.unknown_error'.tr();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('active_ride.call_failed'.tr()),
            content: SelectableText(err),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(session: session, isOutgoing: true),
        ),
      );
    }
  }

  void _copyDriverPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('booking_extra.number_copied'.tr()),
        backgroundColor: _C.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _avatarInitial() {
    final initial = widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : 'C';
    return Center(
        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)));
  }

  Widget _buildFareRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.accentLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.handshake_rounded, color: _C.primary, size: 20),
          const SizedBox(width: 10),
          Text('booking.fare_locked'.tr(),
              style: const TextStyle(fontSize: 13, color: _C.gray600, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            '${widget.lockedFare.toStringAsFixed(2)} ${widget.currency}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _C.primary),
          ),
        ],
      ),
    );
  }

  // Card layout variants of status/fare/driver/stepper cards
  Widget _buildStatusCard(ActiveRideState rideState) {
    final color = _statusColor(rideState.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withAlpha(20), shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(_statusIcon(rideState.status), color: color, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusLabel(rideState.status),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(widget.destination,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _C.gray600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _C.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('booking_extra.fare_locked_negotiated'.tr(),
                  style: TextStyle(fontSize: 12, color: _C.gray600, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(widget.lockedFare.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _C.primary)),
                  const SizedBox(width: 4),
                  Text(widget.currency,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.primary)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _C.accentLight, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.handshake_rounded, color: _C.primary, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('booking.your_driver'.tr(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.gray400, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          _buildDriverRow(),
        ],
      ),
    );
  }

  Widget _buildStepperCard(ActiveRideState rideState) {
    final steps = [
      ('booking.ride_confirmed'.tr(),        RideStatus.accepted),
      ('booking.driver_en_route_short'.tr(), RideStatus.arriving),
      ('booking.driver_arrived'.tr(),        RideStatus.arrived),
      ('booking.ride_in_progress'.tr(),      RideStatus.inProgress),
      ('booking.ride_completed'.tr(),        RideStatus.completed),
    ];
    final currentIdx = steps.indexWhere((s) => s.$2 == rideState.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('booking.ride_steps'.tr(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.gray400, letterSpacing: 0.8)),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final isDone    = i < currentIdx;
            final isCurrent = i == currentIdx;
            final color     = _statusColor(rideState.status);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? _C.green : isCurrent ? color.withAlpha(20) : _C.gray100,
                      border: Border.all(
                          color: isDone ? _C.green : isCurrent ? color : _C.gray400,
                          width: isCurrent ? 2 : 1),
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : Icons.circle,
                      size: isDone ? 16 : (isCurrent ? 10 : 8),
                      color: isDone ? Colors.white : isCurrent ? color : _C.gray400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(steps[i].$1,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? color : isDone ? _C.gray600 : _C.gray400)),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCancelledByDriverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.amber.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded, color: _C.amber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('booking.ride_cancelled'.tr(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'booking_extra.driver_unable'.tr(),
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/client_dashboard');
            },
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: _C.gray400)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/create_ride');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('booking_extra.new_ride'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCancelling ? null : _cancelRide,
        icon: _isCancelling
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.red))
            : const Icon(Icons.close_rounded, size: 18),
        label: Text(_isCancelling ? 'booking.cancelling'.tr() : 'booking.cancel_ride'.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.red,
          side: const BorderSide(color: _C.red, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFinishedActions(bool isCompleted) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (isCompleted ? _C.green : _C.red).withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isCompleted ? _C.green : _C.red).withAlpha(60)),
          ),
          child: Column(
            children: [
              Icon(isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCompleted ? _C.green : _C.red, size: 48),
              const SizedBox(height: 10),
              Text(isCompleted ? 'booking.ride_completed_success'.tr() : 'booking.ride_cancelled'.tr(),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: isCompleted ? _C.green : _C.red)),
              if (isCompleted) ...[
                const SizedBox(height: 6),
                Text('booking.amount_paid'.tr(namedArgs: {'amount': widget.lockedFare.toStringAsFixed(2), 'currency': widget.currency}),
                    style: const TextStyle(fontSize: 14, color: _C.gray600)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/client_trip_history'),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: Text('nav.history'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

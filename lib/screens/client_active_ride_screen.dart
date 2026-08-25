import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
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

  // Smooth marker animation
  late final AnimationController _markerCtrl;
  LatLng? _markerFrom;
  LatLng? _markerTo;

  // ── Map ─────────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  bool _isMapReady    = false;
  bool _followCamera  = true;
  Set<Polyline> _polylines = {};
  DateTime?  _lastRouteFetch;
  bool       _fetchingRoute = false;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

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

  // Current interpolated driver position (used for marker + camera)
  LatLng? get _smoothDriverPos {
    if (_markerFrom == null || _markerTo == null) return _markerTo;
    final t = _easeOut(_markerCtrl.value);
    return LatLng(
      _markerFrom!.latitude  + (_markerTo!.latitude  - _markerFrom!.latitude)  * t,
      _markerFrom!.longitude + (_markerTo!.longitude - _markerFrom!.longitude) * t,
    );
  }

  static double _easeOut(double t) => 1 - (1 - t) * (1 - t);

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

    _markerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() { if (mounted) setState(() {}); });

    _loadIcons();

    // Start WebSocket + fallback polling via provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeRideProvider.notifier)
          .startForTrip(widget.tripId, 'accepted');
    });
  }

  @override
  void dispose() {
    ref.read(activeRideProvider.notifier).stopTracking();
    _pulseCtrl.dispose();
    _markerCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Custom icons ─────────────────────────────────────────────────────────────
  Future<void> _loadIcons() async {
    _driverIcon = await _buildCarIcon();
    _pickupIcon = await _buildPickupIcon();
    _destinationIcon = await _buildDestinationIcon();
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _buildDestinationIcon() async {
    const double dp = 44.0, px = 3.0, size = dp * px;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, size, size));
    final cx = size / 2, cy = size * 0.42, r = size * 0.30;
    // Shadow
    canvas.drawCircle(Offset(cx, cy + 4), r + 6,
        Paint()..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Red fill circle
    canvas.drawCircle(Offset(cx, cy), r + 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), r + 3, Paint()..color = const Color(0xFFEF4444));
    // White inner dot
    canvas.drawCircle(Offset(cx, cy), r * 0.4, Paint()..color = Colors.white);
    // Pin tail
    final path = Path()
      ..moveTo(cx - r * 0.5, cy + r * 0.9)
      ..lineTo(cx, cy + r * 2.4)
      ..lineTo(cx + r * 0.5, cy + r * 0.9)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFEF4444));
    final pic = rec.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List(), size: const Size(dp, dp));
  }

  void _drawRideRoute() {
    final pickup = _pickupLatLng;
    final dest = _destinationLatLng;
    if (pickup == null || dest == null || !mounted) return;
    _fetchRoute(pickup, dest);
    if (_isMapReady && _mapController != null) {
      const pad = 0.003;
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(pickup.latitude, dest.latitude) - pad,
          math.min(pickup.longitude, dest.longitude) - pad,
        ),
        northeast: LatLng(
          math.max(pickup.latitude, dest.latitude) + pad,
          math.max(pickup.longitude, dest.longitude) + pad,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  Future<BitmapDescriptor> _buildCarIcon() async {
    const double dp = 60.0, px = 3.0, size = dp * px;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, size, size));
    final cx = size / 2, cy = size / 2;
    final r = size * 0.44;

    // Soft drop shadow
    canvas.drawCircle(
      Offset(cx, cy + 5),
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Orange brand disc
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFFF97316));

    // Subtle highlight ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 2.0,
    );

    // ── Car body ─────────────────────────────────────────────────────────
    final bodyW = size * 0.38, bodyH = size * 0.58;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH),
        Radius.circular(bodyW * 0.30),
      ),
      Paint()..color = Colors.white,
    );

    // Windshield + rear window — light blue-gray glass
    final glassW = bodyW * 0.68, glassH = bodyH * 0.20;
    final glassPaint = Paint()..color = const Color(0xFFB8D4F0).withOpacity(0.90);
    // Front windshield (top of car)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - bodyH * 0.20), width: glassW, height: glassH),
        Radius.circular(size * 0.03),
      ),
      glassPaint,
    );
    // Rear window (bottom of car)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + bodyH * 0.20), width: glassW, height: glassH * 0.80),
        Radius.circular(size * 0.03),
      ),
      glassPaint,
    );

    // Headlights strip (front = top)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - bodyH * 0.455), width: bodyW * 0.65, height: size * 0.045),
        Radius.circular(size * 0.02),
      ),
      Paint()..color = Colors.white.withOpacity(0.95),
    );

    // Tail lights strip (rear = bottom) — red
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + bodyH * 0.455), width: bodyW * 0.65, height: size * 0.038),
        Radius.circular(size * 0.015),
      ),
      Paint()..color = const Color(0xFFFF3B3B).withOpacity(0.90),
    );

    // ── Wheels — circular with rim ────────────────────────────────────────
    final wheelR = size * 0.076;
    final xOff = bodyW * 0.62, yOff = bodyH * 0.30;
    for (final pos in [
      Offset(cx - xOff, cy - yOff),
      Offset(cx + xOff, cy - yOff),
      Offset(cx - xOff, cy + yOff),
      Offset(cx + xOff, cy + yOff),
    ]) {
      canvas.drawCircle(pos, wheelR, Paint()..color = const Color(0xFF1A1A2E));
      canvas.drawCircle(pos, wheelR * 0.52, Paint()..color = const Color(0xFF4A4A6A));
      canvas.drawCircle(pos, wheelR * 0.22, Paint()..color = Colors.white.withOpacity(0.55));
    }

    final pic = rec.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List(), size: const Size(dp, dp));
  }

  Future<BitmapDescriptor> _buildPickupIcon() async {
    const double dp = 44.0, px = 3.0, size = dp * px;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, size, size));
    final cx = size / 2, cy = size / 2, r = size * 0.38;
    // Shadow
    canvas.drawCircle(Offset(cx, cy + 2), r + 4,
        Paint()..color = Colors.black.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Outer ring white
    canvas.drawCircle(Offset(cx, cy), r + 5, Paint()..color = Colors.white);
    // Green fill
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF22C55E));
    // White inner dot
    canvas.drawCircle(Offset(cx, cy), r * 0.35, Paint()..color = Colors.white);
    final pic = rec.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List(), size: const Size(dp, dp));
  }

  // Clean map style — no POI, no transit, beige roads
  static const String _mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"administrative","stylers":[{"visibility":"simplified"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f0e8"}]},
    {"featureType":"water","stylers":[{"color":"#a8d4f5"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#f5f1eb"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e8e0d0"}]}
  ]''';

  // ── Driver position update ───────────────────────────────────────────────────
  void _onNewDriverPosition(LatLng newPos) {
    // Start smooth animation from current interpolated position
    _markerFrom = _smoothDriverPos ?? newPos;
    _markerTo   = newPos;
    _markerCtrl.forward(from: 0.0);

    // Follow camera: frame driver + destination (inProgress) or driver + pickup (arriving)
    if (_followCamera && _isMapReady && _mapController != null) {
      final status = ref.read(activeRideProvider).status;
      final target = (status == RideStatus.inProgress && _destinationLatLng != null)
          ? _destinationLatLng!
          : (_pickupLatLng ?? newPos);
      _frameBothPoints2(newPos, target);
    }

    // Throttle route re-fetch to once every 10 seconds
    final now = DateTime.now();
    if (!_fetchingRoute &&
        (_lastRouteFetch == null ||
            now.difference(_lastRouteFetch!).inSeconds >= 10)) {
      final status = ref.read(activeRideProvider).status;
      if (status == RideStatus.inProgress && _destinationLatLng != null) {
        _fetchRoute(newPos, _destinationLatLng!);
      } else if (_pickupLatLng != null) {
        _fetchRoute(newPos, _pickupLatLng!);
      }
    }
  }

  void _frameBothPoints(LatLng driverPos) {
    final pickup = _pickupLatLng;
    if (pickup == null) {
      _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(target: driverPos, zoom: 16)));
      return;
    }
    _frameBothPoints2(driverPos, pickup);
  }

  void _frameBothPoints2(LatLng a, LatLng b) {
    const pad = 0.002;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(a.latitude,  b.latitude)  - pad,
        math.min(a.longitude, b.longitude) - pad,
      ),
      northeast: LatLng(
        math.max(a.latitude,  b.latitude)  + pad,
        math.max(a.longitude, b.longitude) + pad,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    _fetchingRoute = true;
    try {
      final result = await RouteService.getRoute(from, to);
      if (!mounted) return;
      final points = result?.points ?? [from, to];
      setState(() {
        _polylines = {
          // Outline (darker blue)
          Polyline(
            polylineId: const PolylineId('driver_route_outline'),
            points: points,
            color: const Color(0xFF0D47A1),
            width: 13,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
          // Main route (blue)
          Polyline(
            polylineId: const PolylineId('driver_route'),
            points: points,
            color: const Color(0xFF1A73E8),
            width: 9,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
        _lastRouteFetch = DateTime.now();
      });
    } finally {
      _fetchingRoute = false;
    }
  }

  // ── Status helpers ───────────────────────────────────────────────────────────
  static Color _statusColor(RideStatus s) {
    switch (s) {
      case RideStatus.accepted:   return _C.primary;
      case RideStatus.arriving:   return _C.amber;
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
      final prevPos = prev?.driverLocation?.position;
      final nextPos = next.driverLocation?.position;
      if (nextPos != null && nextPos != prevPos) {
        _onNewDriverPosition(nextPos);
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

        // Follow-camera toggle
        if (_isMapReady)
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            right: 16,
            child: _buildFollowButton(),
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
    final markers = <Marker>{};

    // Pickup marker — custom green circle
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _pickupLatLng!,
      infoWindow: const InfoWindow(title: 'Votre position'),
      icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      anchor: const Offset(0.5, 0.5),
      zIndex: 1,
    ));

    // Driver marker — car icon, flat, rotating
    final driverPos = _smoothDriverPos;
    if (driverPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        rotation: rideState.driverLocation?.heading ?? 0,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        zIndex: 2,
      ));
    }

    // Destination marker — shown when ride is in progress
    final destLatLng = _destinationLatLng;
    if (destLatLng != null && rideState.status == RideStatus.inProgress) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destLatLng,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
        infoWindow: InfoWindow(title: widget.destination),
        zIndex: 3,
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        setState(() => _isMapReady = true);
        // Defer setMapStyle: calling it inside onMapCreated on iOS blocks tile
        // rendering, showing a blue background instead of map tiles.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // No custom style: default Google Maps shows roads/network clearly.
          final driverLoc = ref.read(activeRideProvider).driverLocation;
          if (driverLoc != null) _frameBothPoints(driverLoc.position);
        });
      },
      markers: markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      buildingsEnabled: false,
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

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _followCamera = !_followCamera);
        if (_followCamera) {
          final pos = _smoothDriverPos;
          if (pos != null) _frameBothPoints(pos);
        }
      },
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(
          _followCamera ? Icons.gps_fixed : Icons.gps_not_fixed,
          color: _followCamera ? _C.primary : _C.gray400,
          size: 22,
        ),
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
      child: const Row(
        children: [
          Icon(Icons.signal_wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Localisation en attente…',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(ActiveRideState rideState) {
    final isCancelable = rideState.status == RideStatus.accepted ||
        rideState.status == RideStatus.arriving;
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
      (label: 'Confirmé',  done: true),
      (label: 'En route',  done: rideState.status == RideStatus.arriving ||
          rideState.status == RideStatus.inProgress ||
          rideState.status == RideStatus.completed),
      (label: 'Arrivé',   done: rideState.status == RideStatus.inProgress ||
          rideState.status == RideStatus.completed),
      (label: 'Terminé',  done: rideState.status == RideStatus.completed),
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

  /// ETA du livreur jusqu'au point de pickup
  Widget _buildEtaRow(DriverLocation driverLoc) {
    final distM = _haversineMeters(driverLoc.position, _pickupLatLng!);
    final etaMin = (distM / 500).ceil(); // vitesse moyenne 30 km/h ≈ 500 m/min
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
              'Arrivée dans ~$etaMin min',
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
        rideState.status == RideStatus.arriving;
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
              const Text('LIVE',
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
        final err = CallService().lastError ?? 'Erreur inconnue';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Impossible de démarrer l\'appel'),
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
        content: const Text('Numéro copié'),
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
              const Text('Tarif négocié et verrouillé 🔒',
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
            const Expanded(
              child: Text('Course annulée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'Le livreur n\'a pas pu prendre en charge votre course.\n\n'
          'Vous pouvez créer une nouvelle demande — d\'autres livreurs sont disponibles.',
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
            child: const Text('Nouvelle course'),
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

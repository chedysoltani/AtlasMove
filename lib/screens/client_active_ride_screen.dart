import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip_models.dart';
import '../providers/ride_state_provider.dart';
import '../services/trip_service.dart';
import '../services/route_service.dart';
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
  final String? driverPhoto;
  final double driverRating;
  final String driverVehicle;
  final String destination;
  // Optional — pass for live map; screen degrades gracefully if absent
  final double? pickupLatitude;
  final double? pickupLongitude;

  const ClientActiveRideScreen({
    super.key,
    required this.tripId,
    required this.lockedFare,
    required this.currency,
    required this.driverName,
    this.driverPhoto,
    required this.driverRating,
    required this.driverVehicle,
    required this.destination,
    this.pickupLatitude,
    this.pickupLongitude,
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

  // ── Cancellation ────────────────────────────────────────────────────────────
  bool _isCancelling = false;

  // ── Helpers ─────────────────────────────────────────────────────────────────
  bool get _hasPickupCoords =>
      widget.pickupLatitude != null && widget.pickupLongitude != null;

  LatLng? get _pickupLatLng => _hasPickupCoords
      ? LatLng(widget.pickupLatitude!, widget.pickupLongitude!)
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
    )..addListener(() => setState(() {}));

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

  // ── Driver position update ───────────────────────────────────────────────────
  void _onNewDriverPosition(LatLng newPos) {
    // Start smooth animation from current interpolated position
    _markerFrom = _smoothDriverPos ?? newPos;
    _markerTo   = newPos;
    _markerCtrl.forward(from: 0.0);

    // Follow camera: frame driver + pickup
    if (_followCamera && _isMapReady && _mapController != null) {
      _frameBothPoints(newPos);
    }

    // Throttle route re-fetch to once every 10 seconds
    final now = DateTime.now();
    if (!_fetchingRoute &&
        _pickupLatLng != null &&
        (_lastRouteFetch == null ||
            now.difference(_lastRouteFetch!).inSeconds >= 10)) {
      _fetchRoute(newPos, _pickupLatLng!);
    }
  }

  void _frameBothPoints(LatLng driverPos) {
    final pickup = _pickupLatLng;
    if (pickup == null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(driverPos));
      return;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(driverPos.latitude,  pickup.latitude),
        math.min(driverPos.longitude, pickup.longitude),
      ),
      northeast: LatLng(
        math.max(driverPos.latitude,  pickup.latitude),
        math.max(driverPos.longitude, pickup.longitude),
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    _fetchingRoute = true;
    try {
      final result = await RouteService.getRoute(from, to);
      if (!mounted) return;
      final points = result?.points ?? [from, to];
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('driver_route'),
            points: points,
            color: _C.primary,
            width: 4,
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
      case RideStatus.accepted:   return 'Course confirmée';
      case RideStatus.arriving:   return 'Chauffeur en route vers vous';
      case RideStatus.inProgress: return 'Course en cours';
      case RideStatus.completed:  return 'Course terminée';
      case RideStatus.cancelled:  return 'Course annulée';
      default:                    return 'En attente…';
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
        title: const Text('Annuler la course ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Êtes-vous sûr de vouloir annuler ? Des frais peuvent s\'appliquer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: const Text('Oui, annuler'),
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
            .showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.red));
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

      // Auto-navigate when ride ends
      if (next.status == RideStatus.completed && mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/client_trip_history');
        });
      } else if (next.status == RideStatus.cancelled && mounted) {
        Navigator.pushReplacementNamed(context, '/client_dashboard');
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

    // Pickup marker (client position — static green)
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _pickupLatLng!,
      infoWindow: const InfoWindow(title: 'Votre position'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));

    // Driver marker (animated orange)
    final driverPos = _smoothDriverPos;
    if (driverPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        infoWindow: InfoWindow(title: widget.driverName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        rotation: rideState.driverLocation?.heading ?? 0,
        flat: true,
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        setState(() => _isMapReady = true);
        // If driver position already known, frame it immediately
        final driverLoc = ref.read(activeRideProvider).driverLocation;
        if (driverLoc != null) _frameBothPoints(driverLoc.position);
      },
      markers: markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        bottom: 260,
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
    final color = _statusColor(rideState.status);
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
              const SizedBox(height: 14),
              _buildDriverRow(),
              const SizedBox(height: 14),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon(rideState.status), color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusLabel(rideState.status),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    if (!isFinished)
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      ),
                  ],
                ),
              ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Course Active',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Suivi en temps réel',
                    style: TextStyle(color: _C.primary, fontSize: 12)),
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
            ],
          ),
        ),
        // Call button placeholder
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _C.green.withAlpha(20), shape: BoxShape.circle,
            border: Border.all(color: _C.green.withAlpha(80)),
          ),
          child: const Icon(Icons.phone_rounded, color: _C.green, size: 18),
        ),
      ],
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
          const Text('Tarif verrouillé',
              style: TextStyle(fontSize: 13, color: _C.gray600, fontWeight: FontWeight.w600)),
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
          const Text('Votre chauffeur',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.gray400, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          _buildDriverRow(),
        ],
      ),
    );
  }

  Widget _buildStepperCard(ActiveRideState rideState) {
    const steps = [
      ('Course confirmée',       RideStatus.accepted),
      ('Chauffeur en route',     RideStatus.arriving),
      ('Course en cours',        RideStatus.inProgress),
      ('Course terminée',        RideStatus.completed),
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
          const Text('Étapes du trajet',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.gray400, letterSpacing: 0.8)),
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

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCancelling ? null : _cancelRide,
        icon: _isCancelling
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.red))
            : const Icon(Icons.close_rounded, size: 18),
        label: Text(_isCancelling ? 'Annulation…' : 'Annuler la course'),
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
              Text(isCompleted ? 'Course terminée ! 🎉' : 'Course annulée',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: isCompleted ? _C.green : _C.red)),
              if (isCompleted) ...[
                const SizedBox(height: 6),
                Text('Montant payé : ${widget.lockedFare.toStringAsFixed(2)} ${widget.currency}',
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
            label: const Text('Voir l\'historique'),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../models/trip_models.dart';
import '../providers/map_provider.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../services/route_service.dart';
import '../services/call_service.dart';
import '../screens/active_call_screen.dart';
import 'driver_main.dart';
import '../services/location_tracking_service.dart';
import '../map/driver_marker_controller.dart';
import '../map/map_camera.dart';
import '../map/map_markers.dart';
import '../map/map_widgets.dart';
import '../map/route_overlay.dart';

enum RidePhase { arriving, started, completed }

class DriverActiveRideScreen extends ConsumerStatefulWidget {
  final AvailableTrip trip;

  const DriverActiveRideScreen({super.key, required this.trip});

  @override
  ConsumerState<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends ConsumerState<DriverActiveRideScreen>
    with TickerProviderStateMixin {
  late RidePhase _currentPhase;
  bool _showHandle = true;

  bool _isMapReady = false;
  double _currentDistance = 0.0;
  String _estimatedTime = 'Calcul...';
  bool _isFetchingRoute = false;
  DateTime? _lastRouteFetchTime;

  // ── Carte ──────────────────────────────────────────────────────────────────
  // UN SEUL marqueur chauffeur (id constant `driver_marker`) déplacé par
  // interpolation ; tracé, caméra et boussole sont pilotés localement.
  late final DriverMarkerController _driverMarker;
  late final RouteOverlay _route;
  final FollowCamera _follow = FollowCamera();
  final ValueNotifier<double> _cameraBearing = ValueNotifier<double>(0);
  CameraPosition? _cameraPos;
  Set<Marker> _staticMarkers = const <Marker>{};
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;
  bool _iconsRequested = false;

  LatLng get _pickupLatLng =>
      LatLng(widget.trip.pickupLatitude, widget.trip.pickupLongitude);
  LatLng get _destinationLatLng =>
      LatLng(widget.trip.destinationLatitude, widget.trip.destinationLongitude);

  @override
  void initState() {
    super.initState();
    // Initialize phase based on existing trip status
    if (widget.trip.status == 'in_progress') {
      _currentPhase = RidePhase.started;
    } else if (widget.trip.status == 'completed') {
      _currentPhase = RidePhase.completed;
    } else {
      _currentPhase = RidePhase.arriving;
    }
    if (widget.trip.status == 'livreur_en_route') {
      _currentPhase = RidePhase.started;
    }

    // Course en cours : la position du chauffeur part vers le client (POST /trips/location, ~5 s)
    if (widget.trip.status != 'completed' && !widget.trip.status.startsWith('cancelled')) {
      unawaited(LocationTrackingService().setActiveTrip(widget.trip.id));
    }

    _driverMarker = DriverMarkerController(vsync: this);
    _route = RouteOverlay(vsync: this);
    // Le tracé suit le marqueur affiché (pas la position brute) : la partie
    // parcourue disparaît au fil de l'animation.
    _driverMarker.marker.addListener(_onDriverMarkerFrame);
    _rebuildStaticMarkers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pas de marqueur bleu 'current_position' (ce sont deux marqueurs pour un
      // même chauffeur) et pas d'auto-follow du notifier : la caméra est gérée ici.
      ref
          .read(mapProvider.notifier)
          .initializeMap(showUserMarker: false, autoFollowCamera: false);
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

  /// Les bitmaps sont générés une seule fois par densité (cache de la fabrique).
  Future<void> _loadIcons(double dpr) async {
    final factory = MapMarkerFactory.instance;
    try {
      final icons = await Future.wait([
        factory.vehicle(VehicleCategory.fromLabel(widget.trip.serviceName), dpr),
        factory.pickupPin(dpr),
        factory.destinationPin(dpr),
      ]);
      if (!mounted) return;
      _driverMarker.setIcon(icons[0]);
      _pickupIcon = icons[1];
      _destIcon = icons[2];
      setState(_rebuildStaticMarkers);
    } catch (e) {
      debugPrint('DriverActiveRide: rendu des icônes impossible: $e');
      if (mounted) _driverMarker.setIcon(fallbackDriverIcon());
    }
  }

  void _rebuildStaticMarkers() {
    _staticMarkers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng,
        icon: _pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        anchor: MapMarkerFactory.pinAnchor,
        zIndexInt: 2,
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng,
        icon: _destIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: MapMarkerFactory.pinAnchor,
        zIndexInt: 3,
      ),
    };
  }

  @override
  void dispose() {
    _driverMarker.marker.removeListener(_onDriverMarkerFrame);
    // Le provider carte est global : sans ceci le flux GPS haute précision
    // continue à tourner après la sortie de l'écran.
    ref.read(mapProvider.notifier).stopTracking();
    _driverMarker.dispose();
    _route.dispose();
    _follow.dispose();
    _cameraBearing.dispose();
    super.dispose();
  }

  void _onDriverMarkerFrame() {
    final p = _driverMarker.position;
    if (p != null) _route.updateProgress(p);
  }

  // Décale le point cible de la caméra vers l'avant du driver
  // pour que le driver apparaisse en bas de l'écran
  LatLng _cameraAheadTarget(LatLng pos, double bearing, double offsetKm) {
    const earthRadius = 6371.0;
    final bearingRad = bearing * math.pi / 180;
    final latRad = pos.latitude * math.pi / 180;
    final lngRad = pos.longitude * math.pi / 180;
    final angularDist = offsetKm / earthRadius;
    final newLat = math.asin(math.sin(latRad) * math.cos(angularDist) +
        math.cos(latRad) * math.sin(angularDist) * math.cos(bearingRad));
    final newLng = lngRad +
        math.atan2(
            math.sin(bearingRad) * math.sin(angularDist) * math.cos(latRad),
            math.cos(angularDist) - math.sin(latRad) * math.sin(newLat));
    return LatLng(newLat * 180 / math.pi, newLng * 180 / math.pi);
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371;
    final double lat1Rad = start.latitude * (math.pi / 180);
    final double lon1Rad = start.longitude * (math.pi / 180);
    final double lat2Rad = end.latitude * (math.pi / 180);
    final double lon2Rad = end.longitude * (math.pi / 180);
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;
    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.pow(math.sin(dLon / 2), 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  String _estimateDuration(double distanceKm) {
    final minutes = (distanceKm / 30 * 60).round();
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '${hours}h ${remaining}min';
  }

  String _formatDuration(int minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}min';
  }

  // ── Position du chauffeur ───────────────────────────────────────────────────

  /// Point d'entrée de chaque position GPS locale (via MapState).
  void _onDriverPosition(LatLng pos) {
    final gps = ref.read(mapProvider.notifier).lastPosition;
    final accepted = _driverMarker.update(DriverFix(
      position: pos,
      heading: gps?.heading,
      // Geolocator renvoie 0.0 quand la vitesse est inconnue : on laisse le
      // contrôleur la déduire du déplacement dans ce cas.
      speedMps: (gps != null && gps.speed > 0) ? gps.speed : null,
      accuracyM: gps?.accuracy,
      timestamp: gps?.timestamp ?? DateTime.now(),
    ));
    if (!accepted) return; // position aberrante ou sans mouvement réel

    _followDriverCamera(pos);
    _updateRouteDetails(pos);
  }

  /// Le tracé est ré-évalué chaque seconde environ ; distance/ETA restantes
  /// sont déduites du tracé entre deux requêtes OSRM.
  void _refreshEtaFromRoute() {
    if (!_route.hasRoute) return;
    final remainingKm = _route.remainingMeters / 1000.0;
    final secs = _route.remainingSeconds;
    _currentDistance = remainingKm;
    if (secs != null) _estimatedTime = _formatDuration((secs / 60).ceil());
  }

  Future<void> _updateRouteDetails(LatLng currentPos, {bool force = false}) async {
    // arriving → pickup, started/completed → destination
    final targetLatLng =
        _currentPhase == RidePhase.arriving ? _pickupLatLng : _destinationLatLng;

    // Requêtes OSRM espacées (10 s, 4 s si le chauffeur a quitté le tracé)
    final now = DateTime.now();
    final minGap = _route.isOffRoute ? 4 : 10;
    if (_isFetchingRoute ||
        (!force &&
            _lastRouteFetchTime != null &&
            now.difference(_lastRouteFetchTime!).inSeconds < minGap)) {
      if (mounted && _route.hasRoute) setState(_refreshEtaFromRoute);
      return;
    }

    if (!mounted) return;
    setState(() => _isFetchingRoute = true);

    try {
      final routeResult = await RouteService.getRoute(currentPos, targetLatLng);
      if (!mounted) return;

      double distance = _calculateDistance(currentPos, targetLatLng);
      String durationStr = _estimateDuration(distance);

      if (routeResult != null) {
        distance = routeResult.distanceKm;
        durationStr = _formatDuration((routeResult.durationSeconds / 60).round());
        _route.setRoute(
          routeResult.points,
          durationSeconds: routeResult.durationSeconds.toDouble(),
          head: _driverMarker.position ?? currentPos,
        );
      } else {
        // Repli : ligne droite, sans animation
        _route.setRoute(
          [currentPos, targetLatLng],
          head: currentPos,
          animate: false,
        );
      }

      setState(() {
        _currentDistance = distance;
        _estimatedTime = durationStr;
        _lastRouteFetchTime = now;
      });
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  bool mapStateReady(MapState state) => state.status == MapStatus.ready;

  // ── Caméra ──────────────────────────────────────────────────────────────────

  /// Caméra « navigation » : le chauffeur en bas d'écran, orienté selon son cap lissé.
  CameraUpdate _navigationCamera(LatLng pos) {
    final ahead = _cameraAheadTarget(pos, _driverMarker.bearing, 0.20);
    return CameraUpdate.newCameraPosition(CameraPosition(
      target: ahead,
      zoom: 17.0,
      tilt: 45.0,
      bearing: _driverMarker.bearing,
    ));
  }

  void _followDriverCamera(LatLng pos) {
    if (!_isMapReady || !_follow.isFollowing.value) return;
    if (_currentPhase == RidePhase.arriving) {
      // Montrer driver + client dans le même cadre
      MapCamera.fitBounds(_follow.controller, [pos, _pickupLatLng], padding: 100);
    } else {
      _follow.follow(_navigationCamera(pos));
    }
  }

  /// Bouton « ma position » : réactive le suivi.
  void _recenter() {
    final pos = _driverMarker.position ?? ref.read(mapProvider).currentPosition;
    if (pos == null) return;
    if (_currentPhase == RidePhase.arriving) {
      _follow.isFollowing.value = true;
      MapCamera.fitBounds(_follow.controller, [pos, _pickupLatLng], padding: 100);
    } else {
      _follow.recenter(_navigationCamera(pos));
    }
  }

  /// Bouton « itinéraire complet » : chauffeur + prise en charge + destination.
  void _fitWholeTrip() {
    final pos = _driverMarker.position ?? ref.read(mapProvider).currentPosition;
    _follow.isFollowing.value = false;
    MapCamera.fitBounds(
      _follow.controller,
      [if (pos != null) pos, _pickupLatLng, _destinationLatLng],
      padding: 110,
    );
  }

  void _resetNorth() {
    final cam = _cameraPos;
    if (cam == null) return;
    _follow.isFollowing.value = false;
    _follow.controller?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: cam.target, zoom: cam.zoom, bearing: 0, tilt: 0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    // Le marqueur reçoit toutes les positions (même carte pas encore prête) ;
    // seule la caméra dépend de _isMapReady.
    ref.listen<MapState>(mapProvider, (previous, next) {
      final pos = next.currentPosition;
      if (pos == null) return;
      if (previous?.currentPosition != pos) {
        _onDriverPosition(pos);
      } else if (previous?.status != next.status) {
        _updateRouteDetails(pos);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map Background
          _buildGoogleMap(mapState),

          if (mapState.status == MapStatus.loading) const MapLoadingWidget(),

          if (mapState.status == MapStatus.error ||
              mapState.status == MapStatus.permissionDenied ||
              mapState.status == MapStatus.locationDisabled)
            _buildErrorWidget(mapState),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),

          // Map Controls
          if (_isMapReady)
            _buildMapControls(mapState),

          // Bottom Sheet with ride info
          if (_isMapReady)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRideInfoSheet(mapState),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap(MapState mapState) {
    final startTarget = mapState.currentPosition ?? _pickupLatLng;
    final aheadStart = _cameraAheadTarget(startTarget, _driverMarker.bearing, 0.25);
    return BrandedGoogleMap(
      initialCameraPosition: CameraPosition(
        target: aheadStart,
        zoom: 17.0,
        tilt: 45.0,
        bearing: _driverMarker.bearing,
      ),
      onMapCreated: (GoogleMapController controller) {
        ref.read(mapProvider.notifier).setMapController(controller);
        _follow.attach(controller);
        setState(() => _isMapReady = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final pos = _driverMarker.position ??
              ref.read(mapProvider).currentPosition;
          if (pos != null) {
            _followDriverCamera(pos);
            _updateRouteDetails(pos, force: true);
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
      // Padding minimal → map plein écran comme inDrive
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 90,
        bottom: 140,
      ),
    );
  }

  Widget _buildMapControls(MapState mapState) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      right: 16,
      child: ValueListenableBuilder<bool>(
        valueListenable: _follow.isFollowing,
        builder: (context, following, _) => Column(
          children: [
            MapCompassButton(bearing: _cameraBearing, onTap: _resetNorth),
            const SizedBox(height: 10),
            MapRoundButton(
              icon: Icons.route_rounded,
              onTap: _fitWholeTrip,
              tooltip: 'Itinéraire complet',
            ),
            const SizedBox(height: 10),
            MapRoundButton(
              icon: following ? Icons.gps_fixed : Icons.gps_not_fixed,
              active: following,
              onTap: _recenter,
              tooltip: 'Ma position',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isArriving = _currentPhase == RidePhase.arriving;
    final navColor = isArriving
        ? const Color(0xFF1B5E20)   // vert foncé → vers client
        : const Color(0xFF0D47A1);  // bleu foncé → vers destination
    final directionLabel = isArriving ? 'driver.active_ride'.tr() : 'driver.rides_title'.tr();

    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 12,
        right: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: navColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Flèche de direction
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          // Label + distance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(directionLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(
                  _currentDistance > 0
                      ? '${_currentDistance.toStringAsFixed(1)} km · $_estimatedTime'
                      : _estimatedTime,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          // Boutons action
          if (widget.trip.clientPhone != null)
            _navIconBtn(Icons.phone_rounded, Colors.white, _startCallToClient),
          const SizedBox(width: 6),
          _navIconBtn(Icons.close_rounded, Colors.red.shade300,
              () => _showCancelDialog()),
        ],
      ),
    );
  }

  Future<void> _startCallToClient() async {
    final session = await CallService().initiateCall(widget.trip.id);
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

  Widget _navIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('common.cancelled'.tr()),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'driver.cancellation_reason'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.back'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;

                Navigator.pop(context); // Close dialog

                try {
                  await TripService.cancelTrip(widget.trip.id, reasonController.text);
                  // Course finie : cadence « sans course » (le chauffeur reste joignable pour de nouvelles courses)
                  await LocationTrackingService().clearActiveTrip();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('common.cancelled'.tr()), backgroundColor: Colors.orange),
                    );
                    Navigator.pop(context); // Go back to dashboard
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('common.server_error'.tr()), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text('common.confirm'.tr(), style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Panel flottant compact style inDrive — map visible au maximum
  Widget _buildRideInfoSheet(MapState mapState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Client + prix sur une ligne compacte
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.trip.clientName ?? 'Client',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(widget.trip.serviceName,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 11)),
                        if (widget.trip.clientPhone != null &&
                            widget.trip.clientPhone!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.trip.clientPhone!,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Prix + distance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(widget.trip.offeredFare ?? widget.trip.estimatedFare).toStringAsFixed(2)} ${widget.trip.currency}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1B5E20)),
                      ),
                      Text(
                        _currentDistance > 0
                            ? '${_currentDistance.toStringAsFixed(1)} km · $_estimatedTime'
                            : widget.trip.estimatedDistanceKm
                                .toStringAsFixed(1) +
                                ' km',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bouton action pleine largeur
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildActionButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _currentPhase == RidePhase.arriving ? 'driver.active_ride'.tr() : 'driver.rides_title'.tr(),
            // arriving→pickup  |  started/completed→destination
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_isFetchingRoute)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_currentDistance.toStringAsFixed(1)} km restants',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _estimatedTime,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow('Point de départ', widget.trip.pickupAddress),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          _buildInfoRow('Destination', widget.trip.destinationAddress),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow('Distance totale', '${widget.trip.estimatedDistanceKm.toStringAsFixed(1)} km'),
              ),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow('Prix convenu', '${(widget.trip.offeredFare ?? widget.trip.estimatedFare).toStringAsFixed(2)} ${widget.trip.currency}'),
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
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    String buttonText;
    VoidCallback onPressed;

    switch (_currentPhase) {
      case RidePhase.arriving:
        buttonText = 'driver.active_ride'.tr();
        onPressed = () {
          _updatePhase(RidePhase.started, 'livreur_en_route');
        };
        break;
      case RidePhase.started:
        buttonText = 'driver.ride_started'.tr();
        onPressed = () {
          _updatePhase(RidePhase.completed, 'in_progress');
        };
        break;
      case RidePhase.completed:
        buttonText = 'driver.ride_completed'.tr();
        onPressed = () => _completeRide();
        break;
    }

    return CustomButton(
      key: ValueKey(_currentPhase),
      text: buttonText,
      onPressed: onPressed,
      height: 56,
    );
  }

  void _refreshRouteForPhaseChange() {
    _route.clear();
    final pos = _driverMarker.position ?? ref.read(mapProvider).currentPosition;
    if (pos != null) _updateRouteDetails(pos, force: true);
  }

  Future<void> _updatePhase(RidePhase newPhase, String apiStatus) async {
    final oldPhase = _currentPhase;
    
    // Optimistic Update
    setState(() {
      _currentPhase = newPhase;
    });
    
    HapticFeedback.mediumImpact();

    // Nouvelle phase = nouvelle cible (pickup → destination) : on repart d'un
    // tracé vierge et on force le recalcul sans attendre le throttle de 10 s.
    _refreshRouteForPhaseChange();

    try {
      await TripService.updateTripStatus(widget.trip.id, apiStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getPhaseMessage(newPhase)),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _currentPhase = oldPhase;
        });
        
        _refreshRouteForPhaseChange();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.network_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRide() async {
    try {
      await TripService.updateTripStatus(widget.trip.id, 'completed');
      // Course finie : cadence « sans course » (le chauffeur reste joignable pour de nouvelles courses)
                  await LocationTrackingService().clearActiveTrip();
      if (!mounted) return;
      _showCompletionSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('common.server_error'.tr()), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showCompletionSummary() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.green, size: 32),
            ),
            const SizedBox(height: 16),
            Text('driver.ride_completed'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.trip.destinationAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _summaryTile('Distance', '${widget.trip.estimatedDistanceKm.toStringAsFixed(1)} km'),
                _summaryTile('Durée', _estimatedTime),
                _summaryTile('nav.earnings'.tr(), '${(widget.trip.offeredFare ?? widget.trip.estimatedFare).toStringAsFixed(2)} ${widget.trip.currency}'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Retour au Dashboard — recrée DriverMainScreen (index 0 = Dashboard)
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const DriverMainScreen()),
                    (route) => false,
                  );
                },
                child: Text('driver.dashboard_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  String _getPhaseMessage(RidePhase phase) {
    switch (phase) {
      case RidePhase.arriving:
        return 'driver.active_ride'.tr();
      case RidePhase.started:
        return 'driver.active_ride'.tr();
      case RidePhase.completed:
        return 'driver.ride_completed'.tr();
    }
  }

  Widget _buildErrorWidget(MapState mapState) {
    return LocationErrorWidget(
      message: mapState.errorMessage ?? 'Une erreur est survenue',
      status: mapState.status,
      onRetry: () => ref.read(mapProvider.notifier).retry(),
      onOpenSettings: () {
        if (mapState.status == MapStatus.permissionDenied) {
          LocationService().openAppSettings();
        } else if (mapState.status == MapStatus.locationDisabled) {
          LocationService().openLocationSettings();
        }
      },
    );
  }
}

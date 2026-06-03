import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

enum RidePhase { arriving, started, completed }

// Style carte navigation — routes claires, pas de POI ni buildings
const String _navMapStyle = '''[
  {"featureType":"all","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#f2efe9"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#ece8e1"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#d5d0c8"},{"weight":"1"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#fdd663"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#e8c84b"},{"weight":"1"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#555555"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"},{"weight":"3"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#aee0f4"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
]''';

class DriverActiveRideScreen extends ConsumerStatefulWidget {
  final AvailableTrip trip;

  const DriverActiveRideScreen({super.key, required this.trip});

  @override
  ConsumerState<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends ConsumerState<DriverActiveRideScreen> {
  late RidePhase _currentPhase;
  bool _showHandle = true;

  bool _isMapReady = false;
  double _currentDistance = 0.0;
  String _estimatedTime = 'Calcul...';
  bool _isFetchingRoute = false;
  DateTime? _lastRouteFetchTime;
  double _currentBearing = 0.0;
  BitmapDescriptor? _carIcon;
  
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).initializeMap();
    });
    _initCarIcon();
  }

  Future<void> _initCarIcon() async {
    _carIcon = await _createCarIcon();
    if (!mounted) return;
    setState(() {});
    // Force refresh pour appliquer l'icône voiture immédiatement
    final mapState = ref.read(mapProvider);
    if (mapState.currentPosition != null) {
      _lastRouteFetchTime = null; // reset throttle
      _updateRouteDetails(mapState.currentPosition!);
    }
  }

  // Voiture vue 3/4 avant — effet 3D réaliste
  Future<BitmapDescriptor> _createCarIcon() async {
    // Canvas 3× la taille logique pour haute résolution
    const double lw = 64.0;  // largeur logique dp
    const double lh = 90.0;  // hauteur logique dp
    const double px = 3.0;   // facteur pixel
    const double w = lw * px;
    const double h = lh * px;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    // Ombre au sol
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w/2, h*0.88), width: w*0.7, height: h*0.07),
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Côté gauche (face latérale visible) ──
    final sideLeft = Path()
      ..moveTo(w*0.08, h*0.52)
      ..lineTo(w*0.08, h*0.74)
      ..lineTo(w*0.42, h*0.80)
      ..lineTo(w*0.42, h*0.58)
      ..close();
    canvas.drawPath(sideLeft, Paint()..color = const Color(0xFFBBDEFB));

    // ── Toit (vue de dessus légèrement inclinée) ──
    final roof = Path()
      ..moveTo(w*0.08, h*0.38)
      ..lineTo(w*0.42, h*0.30)
      ..lineTo(w*0.92, h*0.35)
      ..lineTo(w*0.92, h*0.52)
      ..lineTo(w*0.42, h*0.58)
      ..lineTo(w*0.08, h*0.52)
      ..close();
    canvas.drawPath(roof, Paint()..color = Colors.white);

    // ── Face avant (la plus visible) ──
    final front = Path()
      ..moveTo(w*0.42, h*0.30)
      ..lineTo(w*0.92, h*0.35)
      ..lineTo(w*0.92, h*0.75)
      ..lineTo(w*0.42, h*0.80)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFFE3F2FD));

    // Contour général
    final outline = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(front, outline);
    canvas.drawPath(roof, outline);
    canvas.drawPath(sideLeft, outline);

    // Pare-brise avant
    final windshield = Path()
      ..moveTo(w*0.46, h*0.32)
      ..lineTo(w*0.88, h*0.37)
      ..lineTo(w*0.88, h*0.51)
      ..lineTo(w*0.46, h*0.50)
      ..close();
    canvas.drawPath(windshield,
        Paint()..color = const Color(0xFF90CAF9).withOpacity(0.55));

    // Vitres latérales
    final sideWindows = Path()
      ..moveTo(w*0.10, h*0.40)
      ..lineTo(w*0.40, h*0.33)
      ..lineTo(w*0.40, h*0.50)
      ..lineTo(w*0.10, h*0.52)
      ..close();
    canvas.drawPath(sideWindows,
        Paint()..color = const Color(0xFF90CAF9).withOpacity(0.40));

    // Phares avant (jaune)
    final hl = Paint()..color = const Color(0xFFFFF176);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w*0.44, h*0.70, w*0.12, h*0.04), const Radius.circular(3)),
        hl);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w*0.74, h*0.70, w*0.14, h*0.04), const Radius.circular(3)),
        hl);

    // Roues
    final wheelD = Paint()..color = const Color(0xFF212121);
    for (final r in [
      Rect.fromLTWH(w*0.04, h*0.60, w*0.16, h*0.20),
      Rect.fromLTWH(w*0.36, h*0.64, w*0.14, h*0.18),
      Rect.fromLTWH(w*0.58, h*0.64, w*0.16, h*0.20),
      Rect.fromLTWH(w*0.80, h*0.63, w*0.14, h*0.18),
    ]) {
      canvas.drawOval(r, wheelD);
      canvas.drawOval(r.deflate(3), Paint()..color = const Color(0xFF78909C));
    }

    // Flèche direction (haut = devant du véhicule dans la vue inDrive)
    final arrow = Path()
      ..moveTo(w*0.50, h*0.02)
      ..lineTo(w*0.38, h*0.16)
      ..lineTo(w*0.62, h*0.16)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF1565C0));
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(
      data!.buffer.asUint8List(),
      size: const Size(lw, lh),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLon = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
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

  Future<void> _updateRouteDetails(LatLng currentPos) async {
    // arriving → pickup, started/completed → destination
    final targetLatLng = _currentPhase == RidePhase.arriving
        ? LatLng(widget.trip.pickupLatitude, widget.trip.pickupLongitude)
        : LatLng(widget.trip.destinationLatitude, widget.trip.destinationLongitude);

    // Throttle route fetching to once every 10 seconds to avoid API spam
    final now = DateTime.now();
    if (_isFetchingRoute || 
        (_lastRouteFetchTime != null && now.difference(_lastRouteFetchTime!).inSeconds < 10)) {
      return;
    }

    setState(() => _isFetchingRoute = true);

    try {
      final routeResult = await RouteService.getRoute(currentPos, targetLatLng);
      
      if (!mounted) return;

      final mapNotifier = ref.read(mapProvider.notifier);
      
      final targetMarker = Marker(
        markerId: const MarkerId('target'),
        position: targetLatLng,
        infoWindow: InfoWindow(title: _currentPhase == RidePhase.arriving ? 'Client' : 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _currentPhase == RidePhase.arriving ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed
        ),
      );

      List<LatLng> points = [currentPos, targetLatLng];
      double distance = _calculateDistance(currentPos, targetLatLng);
      String durationStr = _estimateDuration(distance);

      if (routeResult != null) {
        points = routeResult.points;
        distance = routeResult.distanceKm;
        
        final durationMin = (routeResult.durationSeconds / 60).round();
        if (durationMin < 1) durationStr = '< 1 min';
        else if (durationMin < 60) durationStr = '$durationMin min';
        else {
          final h = durationMin ~/ 60;
          final m = durationMin % 60;
          durationStr = '${h}h ${m}min';
        }
      }

      // Route bleue épaisse style navigation
      final routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF1A73E8),
        width: 9,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        patterns: [],
      );

      // Outline sous la route (effet Google Maps)
      final routeOutline = Polyline(
        polylineId: const PolylineId('route_outline'),
        points: points,
        color: const Color(0xFF0D47A1),
        width: 13,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      );

      // Calcul du bearing driver → target pour orienter la caméra
      final bearing = _calculateBearing(currentPos, targetLatLng);
      setState(() => _currentBearing = bearing);

      mapNotifier.clearPolylines();
      mapNotifier.addMarker(targetMarker);

      // Remplace le marker bleu par défaut ('current_position') par l'icône voiture
      if (_carIcon != null) {
        mapNotifier.removeMarker('current_position');
        mapNotifier.addMarker(Marker(
          markerId: const MarkerId('driver_car'),
          position: currentPos,
          icon: _carIcon!,
          flat: true,
          rotation: 0,
          anchor: const Offset(0.5, 0.75),
          zIndex: 2,
        ));
      }

      mapNotifier.addPolyline(routeOutline);
      mapNotifier.addPolyline(routePolyline);

      // Caméra style navigation GPS :
      // Zoom 19, tilt 70°, voiture en bas → 250m devant en cible
      final mapState = ref.read(mapProvider);
      if (mapStateReady(mapState) && mapState.isFollowingUser) {
        final aheadTarget = _cameraAheadTarget(currentPos, bearing, 0.25);
        mapState.mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: aheadTarget,
              zoom: 19.0,
              tilt: 70.0,
              bearing: bearing,
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    // Reactively update route if driver moves
    ref.listen<MapState>(mapProvider, (previous, next) {
      if (next.currentPosition != null && _isMapReady) {
        if (previous?.currentPosition != next.currentPosition || previous?.status != next.status) {
          _updateRouteDetails(next.currentPosition!);
        }
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
          if (_isMapReady && mapState.status == MapStatus.ready)
            _buildMapControls(mapState),
            
          // Bottom Sheet with ride info
          if (_isMapReady && mapState.status == MapStatus.ready)
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
    final startTarget = mapState.currentPosition ??
        LatLng(widget.trip.pickupLatitude, widget.trip.pickupLongitude);
    final aheadStart = _cameraAheadTarget(startTarget, _currentBearing, 0.25);
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: aheadStart,
        zoom: 19.0,
        tilt: 70.0,
        bearing: _currentBearing,
      ),
      onMapCreated: (GoogleMapController controller) async {
        ref.read(mapProvider.notifier).setMapController(controller);
        await controller.setMapStyle(_navMapStyle);
        setState(() => _isMapReady = true);

        // Forcer immédiatement la caméra navigation (tilt 70°, zoom 19)
        final pos = ref.read(mapProvider).currentPosition ?? startTarget;
        final ahead = _cameraAheadTarget(pos, _currentBearing, 0.25);
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(CameraPosition(
            target: ahead,
            zoom: 19.0,
            tilt: 70.0,
            bearing: _currentBearing,
          )),
        );

        if (ref.read(mapProvider).currentPosition != null) {
          _lastRouteFetchTime = null;
          _updateRouteDetails(ref.read(mapProvider).currentPosition!);
        }
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      markers: mapState.markers,
      polylines: mapState.polylines,
      trafficEnabled: true,
      buildingsEnabled: false,
      // Padding minimal → map plein écran comme inDrive
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 90,
        bottom: 140,
      ),
    );
  }

  Widget _buildMapControls(MapState mapState) {
    return Positioned(
      top: 160,
      right: 16,
      child: Column(
        children: [
          _buildMapControl(
            Icons.my_location, 
            () => ref.read(mapProvider.notifier).centerOnCurrentPosition(),
            color: mapState.isFollowingUser ? AppTheme.primaryColor : Colors.black,
          ),
          const SizedBox(height: 8),
          _buildMapControl(
            mapState.isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
            () {
               ref.read(mapProvider.notifier).toggleFollowingUser();
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(mapState.isFollowingUser ? 'Suivi GPS désactivé' : 'Suivi GPS activé'))
               );
            },
            color: mapState.isFollowingUser ? AppTheme.primaryColor : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onPressed, {Color color = Colors.black}) {
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
        icon: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildHeader() {
    final isArriving = _currentPhase == RidePhase.arriving;
    final navColor = isArriving
        ? const Color(0xFF1B5E20)   // vert foncé → vers client
        : const Color(0xFF0D47A1);  // bleu foncé → vers destination
    final directionLabel = isArriving ? 'Vers le client' : 'Vers la destination';

    return Column(
      children: [
        // Barre navigation principale
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          color: navColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Flèche de direction
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              // Label + distance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(directionLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(
                      _currentDistance > 0
                          ? '${_currentDistance.toStringAsFixed(1)} km · $_estimatedTime'
                          : _estimatedTime,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Boutons action
              if (widget.trip.clientPhone != null)
                _navIconBtn(Icons.phone_rounded, Colors.white, () {}),
              const SizedBox(width: 6),
              _navIconBtn(Icons.close_rounded, Colors.red.shade300,
                  () => _showCancelDialog()),
            ],
          ),
        ),
      ],
    );
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
          title: const Text('Annuler la course'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Raison de l\'annulation',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;
                
                Navigator.pop(context); // Close dialog
                
                try {
                  await TripService.cancelTrip(widget.trip.id, reasonController.text);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Course annulée.'), backgroundColor: Colors.orange),
                    );
                    Navigator.pop(context); // Go back to dashboard
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
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
                      ],
                    ),
                  ),
                  // Prix + distance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.trip.estimatedFare.toStringAsFixed(2)} ${widget.trip.currency}',
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
              _currentPhase == RidePhase.arriving ? 'Vers le client' : 'Vers la destination',
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
                child: _buildInfoRow('Prix estimé', '${widget.trip.estimatedFare.toStringAsFixed(2)} ${widget.trip.currency}'),
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
        buttonText = 'Arrivé chez le client';
        onPressed = () {
          _updatePhase(RidePhase.started, 'livreur_en_route');
        };
        break;
      case RidePhase.started:
        buttonText = 'Démarrer la course';
        onPressed = () {
          _updatePhase(RidePhase.completed, 'in_progress');
        };
        break;
      case RidePhase.completed:
        buttonText = 'Terminer la course';
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

  Future<void> _updatePhase(RidePhase newPhase, String apiStatus) async {
    final oldPhase = _currentPhase;
    
    // Optimistic Update
    setState(() {
      _currentPhase = newPhase;
    });
    
    HapticFeedback.mediumImpact();

    // Optimistically update map if moving to next phase
    if (newPhase == RidePhase.completed) {
       final mapState = ref.read(mapProvider);
       if (mapState.currentPosition != null) {
          _updateRouteDetails(mapState.currentPosition!);
       }
    }

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
        
        // Revert map if needed
        if (oldPhase == RidePhase.started) {
           final mapState = ref.read(mapProvider);
           if (mapState.currentPosition != null) {
              _updateRouteDetails(mapState.currentPosition!);
           }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur réseau. Action annulée.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeRide() async {
    try {
      await TripService.updateTripStatus(widget.trip.id, 'completed');
      if (!mounted) return;
      _showCompletionSummary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Erreur: impossible de terminer.'), backgroundColor: Colors.red)
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
            const Text('Course terminée !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                _summaryTile('Gain', '${widget.trip.estimatedFare.toStringAsFixed(2)} ${widget.trip.currency}'),
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
                  // Retour au Dashboard en supprimant tout le stack
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Retour au tableau de bord',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        return 'En route vers le client...';
      case RidePhase.started:
        return 'Arrivé chez le client. Démarrez la course !';
      case RidePhase.completed:
        return 'Course en cours — en route vers la destination !';
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

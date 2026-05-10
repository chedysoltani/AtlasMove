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

class DriverActiveRideScreen extends ConsumerStatefulWidget {
  final AvailableTrip trip;

  const DriverActiveRideScreen({super.key, required this.trip});

  @override
  ConsumerState<DriverActiveRideScreen> createState() => _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends ConsumerState<DriverActiveRideScreen> {
  late RidePhase _currentPhase;
  bool _isMapReady = false;
  double _currentDistance = 0.0;
  String _estimatedTime = 'Calcul...';
  bool _isFetchingRoute = false;
  DateTime? _lastRouteFetchTime;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).initializeMap();
    });
  }

  @override
  void dispose() {
    super.dispose();
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
    final targetLatLng = _currentPhase == RidePhase.completed
        ? LatLng(widget.trip.destinationLatitude, widget.trip.destinationLongitude)
        : LatLng(widget.trip.pickupLatitude, widget.trip.pickupLongitude);

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
        infoWindow: InfoWindow(title: _currentPhase == RidePhase.completed ? 'Destination' : 'Client'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _currentPhase == RidePhase.completed ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen
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

      final routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppTheme.primaryColor,
        width: 5,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      );

      mapNotifier.clearPolylines();
      mapNotifier.addMarker(targetMarker);
      mapNotifier.addPolyline(routePolyline);

      // Frame bounds to include driver and target
      if (points.isNotEmpty && mapStateReady(ref.read(mapProvider))) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            math.min(currentPos.latitude, targetLatLng.latitude),
            math.min(currentPos.longitude, targetLatLng.longitude),
          ),
          northeast: LatLng(
            math.max(currentPos.latitude, targetLatLng.latitude),
            math.max(currentPos.longitude, targetLatLng.longitude),
          ),
        );
        ref.read(mapProvider).mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100), // padding
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
    return GoogleMap(
      initialCameraPosition: mapState.cameraPosition ??
          CameraPosition(
            target: LatLng(widget.trip.pickupLatitude, widget.trip.pickupLongitude), 
            zoom: 14
          ),
      onMapCreated: (GoogleMapController controller) {
        ref.read(mapProvider.notifier).setMapController(controller);
        setState(() => _isMapReady = true);
        if (mapState.currentPosition != null) {
           _updateRouteDetails(mapState.currentPosition!);
        }
      },
      myLocationEnabled: false, // We use custom marker
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      markers: mapState.markers,
      polylines: mapState.polylines,
      trafficEnabled: false,
      buildingsEnabled: true,
      padding: EdgeInsets.only(top: 100, bottom: MediaQuery.of(context).size.height * 0.45),
    );
  }

  Widget _buildMapControls(MapState mapState) {
    return Positioned(
      top: 120,
      right: 20,
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
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  splashRadius: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Course Active',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.trip.clientPhone != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: Call intent
                    },
                    icon: Icon(Icons.phone, color: Colors.green.shade700),
                    splashRadius: 24,
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _showCancelDialog(),
                  icon: Icon(Icons.close_rounded, color: Colors.red.shade700),
                  splashRadius: 24,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildRideInfoSheet(MapState mapState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Customer Info Profile
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.trip.clientName ?? "Client Inconnu",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.trip.serviceName,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Route Progress
              _buildRouteProgress(),
              
              const SizedBox(height: 20),
              
              // Trip Info
              _buildTripInfo(),
              
              const SizedBox(height: 24),
              
              // Action Button with AnimatedSwitcher for smooth phase changes
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
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
      padding: const EdgeInsets.all(16),
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
        buttonText = 'Je suis en route';
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
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Course terminée avec succès !'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Erreur: impossible de terminer.'), backgroundColor: Colors.red)
        );
      }
    }
  }

  String _getPhaseMessage(RidePhase phase) {
    switch (phase) {
      case RidePhase.arriving:
        return 'En attente de départ...';
      case RidePhase.started:
        return 'Vous êtes en route vers le point de collecte !';
      case RidePhase.completed:
        return 'Course démarrée, en route vers la destination !';
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

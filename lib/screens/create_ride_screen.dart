import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import '../providers/map_provider.dart';
import '../providers/services_provider.dart';
import '../models/service_models.dart';
import '../models/trip_models.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../services/trip_service.dart';
import '../providers/cards_provider.dart';
import '../models/card_models.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _AppColors {
  static const primary = Color(0xFFFF6B35); // Orange vibrant de la marque
  static const accent = Color(0xFFFF6B35); 
  static const accentLight = Color(0xFFFFF1EB); // Orange très clair
  static const accentMid = Color(0xFFE85A2A);   // Orange plus sombre
  static const accentShadow = Color(0x59FF6B35);

  static const green = Color(0xFF22C55E);
  static const greenLight = Color(0xFFDCFCE7);
  static const red = Color(0xFFEF4444);

  static const gray50 = Color(0xFFF8F9FB);
  static const gray100 = Color(0xFFF1F3F7);
  static const gray200 = Color(0xFFE2E6EF);
  static const gray300 = Color(0xFFCDD3E0);
  static const gray400 = Color(0xFF9BA3B4);
  static const gray600 = Color(0xFF5C6475);
  static const gray900 = Color(0xFF0F172A); // Noir/Bleu très sombre (Brand Black)

  static const white = Colors.white;
}

class _AppTextStyles {
  static const sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: _AppColors.gray400,
    letterSpacing: 0.7,
  );

  static const chipLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: _AppColors.gray600,
    height: 1,
  );

  static const chipLabelActive = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: _AppColors.white,
    height: 1,
  );

  static const serviceNameStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _AppColors.gray900,
  );

  static const serviceDescStyle = TextStyle(
    fontSize: 11,
    color: _AppColors.gray400,
    height: 1.3,
  );

  static const servicePriceStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _AppColors.gray900,
  );

  static const servicePriceActiveStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: _AppColors.accentMid,
  );

  static const statValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: _AppColors.gray900,
  );

  static const statLabel = TextStyle(
    fontSize: 10,
    color: _AppColors.gray400,
    height: 1.4,
  );

  static const headerTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: _AppColors.gray900,
    height: 1.2,
  );

  static const headerSubtitle = TextStyle(
    fontSize: 12,
    color: _AppColors.gray400,
  );

  static const ctaLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: _AppColors.white,
  );

  static const ctaLabelDisabled = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: _AppColors.gray400,
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CreateRideScreen extends ConsumerStatefulWidget {
  const CreateRideScreen({super.key});

  @override
  ConsumerState<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends ConsumerState<CreateRideScreen> {
  bool _isMapReady = false;
  ServiceCategoryWithServices? _selectedCategory;
  Service? _selectedService;
  bool _servicesExpanded = false;
  bool _serviceSectionExpanded = false;
  bool _isCreatingTrip = false;
  TripResponse? _tripResponse;
  String? _tripError;
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  LatLng? _destinationCoordinates;
  List<String> _addressSuggestions = [];
  bool _isSearching = false;
  double? _estimatedDistance;
  String? _estimatedDuration;
  bool _showRouteInfo = false;
  Timer? _debounceTimer;
  bool _showRouteEstimation = false;
  double _sheetHeight = 0.35;
  String _paymentType = 'cash'; // 'card' | 'cash'

  bool _isDestinationFocused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).initializeMap();
      ref.read(catalogueProvider.notifier).fetchCatalogue();
      ref.read(cardsProvider.notifier).loadCards();
    });
    _destinationController.addListener(_onDestinationChanged);
    _destinationFocusNode.addListener(() {
      setState(() {
        _isDestinationFocused = _destinationFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _destinationController.removeListener(_onDestinationChanged);
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  // ── Business logic (unchanged) ─────────────────────────────────────────────
  void _onDestinationChanged() {
    final query = _destinationController.text;
    _debounceTimer?.cancel();
    if (query.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _searchAddresses(query);
      });
    } else {
      setState(() {
        _addressSuggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _searchAddresses(String query) async {
    setState(() {
      _isSearching = true;
      _addressSuggestions = [];
    });
    try {
      final mapState = ref.read(mapProvider);
      final suggestions = await GeocodingService.searchAddressSuggestions(
        query,
        userLocation: mapState.currentPosition,
        radiusKm: 100,
      );
      if (mounted) {
        setState(() {
          _addressSuggestions = suggestions;
          _isSearching = false;
        });
        // Show feedback if no results found
        if (suggestions.isEmpty && query.length >= 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aucun résultat trouvé. Essayez une autre recherche.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la recherche. Veuillez réessayer.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _selectDestination(String address) async {
    setState(() {
      _isSearching = true;
      _addressSuggestions = [];
    });
    _destinationController.text = address;
    _destinationFocusNode.unfocus();
    try {
      final coordinates = await GeocodingService.getAddressCoordinates(address);
      if (coordinates != null && mounted) {
        final latLng = LatLng(coordinates.latitude, coordinates.longitude);
        setState(() {
          _destinationCoordinates = latLng;
          _isSearching = false;
        });
        final mapState = ref.read(mapProvider);
        if (mapState.mapController != null) {
          mapState.mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 15),
            ),
          );
        }
        if (mapState.currentPosition != null) {
          await _calculateRoute(mapState.currentPosition!, latLng);
        }
      } else if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse non trouvée')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la recherche de l\'adresse')),
        );
      }
    }
  }

  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    try {
      final distanceKm = _calculateDistance(start, end);
      final duration = _estimateDuration(distanceKm);
      if (mounted) {
        setState(() {
          _estimatedDistance = distanceKm;
          _estimatedDuration = duration;
          _showRouteInfo = true;
          _showRouteEstimation = true;
        });
      }
      _addRouteElements(start, end);
      await _fitMapToBounds(start, end);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du calcul de l\'itinéraire')),
        );
      }
    }
  }

  Future<void> _fitMapToBounds(LatLng start, LatLng end) async {
    final mapState = ref.read(mapProvider);
    if (mapState.mapController == null) return;
    final minLat = math.min(start.latitude, end.latitude);
    final maxLat = math.max(start.latitude, end.latitude);
    final minLng = math.min(start.longitude, end.longitude);
    final maxLng = math.max(start.longitude, end.longitude);
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
    await mapState.mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
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
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return '${hours}h ${remaining}min';
  }

  void _addRouteElements(LatLng start, LatLng end) {
    final mapNotifier = ref.read(mapProvider.notifier);
    final pickupMarker = Marker(
      markerId: const MarkerId('pickup'),
      position: start,
      infoWindow: const InfoWindow(title: 'Point de départ'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );
    final destinationMarker = Marker(
      markerId: const MarkerId('destination'),
      position: end,
      infoWindow: const InfoWindow(title: 'Destination'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    final routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: [start, end],
      color: _AppColors.accent,
      width: 4,
    );
    mapNotifier.clearPolylines();
    mapNotifier.addMarker(pickupMarker);
    mapNotifier.addMarker(destinationMarker);
    mapNotifier.addPolyline(routePolyline);
  }

  void _createRide() async {
    if (_isCreatingTrip) return;

    setState(() {
      _isCreatingTrip = true;
      _tripError = null;
    });

    debugPrint('=== _createRide() START ===');
    
    try {
      // 1. Validation du Service
      if (_selectedService == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner un service'), backgroundColor: _AppColors.red),
          );
        }
        return;
      }
      
      // 2. Validation de la Destination
      if (_destinationCoordinates == null || _estimatedDistance == null || _estimatedDuration == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner une destination'), backgroundColor: _AppColors.red),
          );
        }
        return;
      }

      // 3. Validation de la Position
      final mapState = ref.read(mapProvider);
      if (mapState.currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Position actuelle non disponible'), backgroundColor: _AppColors.red),
          );
        }
        return;
      }

      // 4. Validation de la Carte (si paiement par carte)
      if (_paymentType == 'card') {
        final cardsState = ref.read(cardsProvider);
        if (cardsState.cards.isEmpty) {
          if (mounted) _showNoCardDialog();
          return;
        }
      }

      // 5. Appel API
      final response = await TripService.createTrip(
        serviceId: _selectedService!.id,
        pickupAddress: 'Position actuelle',
        pickupLatitude: mapState.currentPosition!.latitude,
        pickupLongitude: mapState.currentPosition!.longitude,
        destinationAddress: _destinationController.text,
        destinationLatitude: _destinationCoordinates!.latitude,
        destinationLongitude: _destinationCoordinates!.longitude,
        estimatedDistanceKm: _estimatedDistance!,
        estimatedDurationMin: _parseDurationToMinutes(_estimatedDuration!),
        paymentType: _paymentType,
      );

      if (mounted) {
        setState(() => _tripResponse = response);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: _AppColors.green),
        );
      }
    } catch (e) {
      debugPrint('ERREUR lors de la création de course: $e');
      if (mounted) {
        setState(() => _tripError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: _AppColors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingTrip = false);
      }
      debugPrint('=== _createRide() END ===');
    }
  }

  int _parseDurationToMinutes(String duration) {
    if (duration.contains('h')) {
      final parts = duration.split('h');
      final hours = int.parse(parts[0].trim());
      final minutes = parts.length > 1 ? int.parse(parts[1].replaceAll('min', '').trim()) : 0;
      return hours * 60 + minutes;
    } else {
      return int.parse(duration.replaceAll('min', '').trim());
    }
  }

  void _onServiceSelected() {
    if (_destinationCoordinates != null && _selectedService != null) {
      setState(() {
        _serviceSectionExpanded = true;
        _sheetHeight = 0.65;
      });
    }
  }

  void _collapseServiceSection() {
    setState(() {
      _serviceSectionExpanded = false;
      _sheetHeight = 0.35;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: _AppColors.white,
      body: Stack(
        children: [
          _buildGoogleMap(mapState),
          _buildHeader(),
          if (_showRouteEstimation &&
              _estimatedDistance != null &&
              _estimatedDuration != null)
            _buildRouteEstimationCard(),
          if (mapState.status == MapStatus.loading) const MapLoadingWidget(),
          if (mapState.status == MapStatus.error ||
              mapState.status == MapStatus.permissionDenied ||
              mapState.status == MapStatus.locationDisabled)
            _buildErrorWidget(mapState),
          if (_isMapReady && mapState.status == MapStatus.ready)
            _buildFloatingButtons(mapState),
          if (_isMapReady && mapState.status == MapStatus.ready)
            _buildBottomSheet(),
        ],
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildGoogleMap(MapState mapState) {
    return GoogleMap(
      initialCameraPosition: mapState.cameraPosition ??
          const CameraPosition(target: LatLng(33.5731, -7.5898), zoom: 12),
      onMapCreated: (GoogleMapController controller) {
        ref.read(mapProvider.notifier).setMapController(controller);
        setState(() => _isMapReady = true);
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      markers: mapState.markers,
      polylines: mapState.polylines,
      trafficEnabled: false,
      buildingsEnabled: true,
      indoorViewEnabled: false,
      mapType: MapType.normal,
      padding: const EdgeInsets.only(top: 120, bottom: 200),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Back button
              _CircleButton(
                color: _AppColors.gray100,
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: _AppColors.gray600,
                ),
              ),
              const SizedBox(width: 14),
              // Title
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Créer une course', style: _AppTextStyles.headerTitle),
                    SizedBox(height: 2),
                    Text(
                      'Sélectionnez votre destination',
                      style: _AppTextStyles.headerSubtitle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Route Estimation Card ──────────────────────────────────────────────────
  Widget _buildRouteEstimationCard() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: _GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card header
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _AppColors.accentLight,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: _AppColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Estimation du trajet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _AppColors.gray900,
                    ),
                  ),
                  const Spacer(),
                  _CircleButton(
                    size: 26,
                    color: _AppColors.gray100,
                    onTap: () {
                      setState(() {
                        _showRouteEstimation = false;
                        _estimatedDistance = null;
                        _estimatedDuration = null;
                        _destinationCoordinates = null;
                        _destinationController.clear();
                      });
                      final n = ref.read(mapProvider.notifier);
                      n.clearPolylines();
                      n.removeMarker('pickup');
                      n.removeMarker('destination');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: _AppColors.gray400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row
              Container(
                decoration: BoxDecoration(
                  color: _AppColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        icon: Icons.straighten_rounded,
                        value: '${_estimatedDistance!.toStringAsFixed(1)} km',
                        label: 'Distance',
                      ),
                    ),
                    Container(width: 1, height: 40, color: _AppColors.gray200),
                    Expanded(
                      child: _StatCell(
                        icon: Icons.access_time_rounded,
                        value: _estimatedDuration!,
                        label: 'Durée estimée',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB Buttons ────────────────────────────────────────────────────────────
  Widget _buildFloatingButtons(MapState mapState) {
    final topOffset = _showRouteEstimation
        ? MediaQuery.of(context).padding.top + 220.0
        : MediaQuery.of(context).padding.top + 100.0;

    return Positioned(
      right: 16,
      top: topOffset,
      child: Column(
        children: [
          _FabButton(
            heroTag: 'center_location',
            onTap: () {
              if (mapState.currentPosition != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Position centrée')),
                );
              }
            },
            child: Icon(
              Icons.my_location_rounded,
              size: 18,
              color: mapState.isFollowingUser
                  ? _AppColors.accent
                  : _AppColors.gray400,
            ),
          ),
          const SizedBox(height: 10),
          _FabButton(
            heroTag: 'toggle_following',
            onTap: () {
              ref.read(mapProvider.notifier).toggleFollowingUser();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(mapState.isFollowingUser
                      ? 'Suivi GPS désactivé'
                      : 'Suivi GPS activé'),
                ),
              );
            },
            child: Icon(
              mapState.isFollowingUser
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              size: 18,
              color: mapState.isFollowingUser
                  ? _AppColors.accent
                  : _AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
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

  // ── Bottom Sheet ───────────────────────────────────────────────────────────
  Widget _buildBottomSheet() {
    if (_tripResponse?.data != null) {
      return _buildTripWaitingCard();
    }
    
    final catalogueAsync = ref.watch(catalogueProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calcul de la hauteur cible en fonction de l'état
    double targetHeight;
    if (_destinationCoordinates == null) {
      // Augmentation de la hauteur initiale (0.32 au lieu de 0.22)
      targetHeight = _isDestinationFocused ? screenHeight * 0.65 : screenHeight * 0.32;
    } else {
      targetHeight = _serviceSectionExpanded ? screenHeight * 0.75 : screenHeight * 0.48;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (_destinationCoordinates != null) {
            if (details.primaryDelta! < -10 && !_serviceSectionExpanded) {
              setState(() {
                _serviceSectionExpanded = true;
                _sheetHeight = 0.75;
              });
            } else if (details.primaryDelta! > 10 && _serviceSectionExpanded) {
              _collapseServiceSection();
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
          height: targetHeight,
          decoration: BoxDecoration(
            color: _AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle minimaliste
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _AppColors.gray200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Expanded(
                child: _buildMainContent(catalogueAsync),
              ),

              // Bouton CTA fixé en bas
              _buildCtaButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(AsyncValue<ServiceCatalogue> catalogueAsync) {
    // Si la destination n'est pas choisie, on se concentre sur l'input
    if (_destinationCoordinates == null) {
      return SingleChildScrollView(
        key: const ValueKey('destination_step'),
        padding: EdgeInsets.fromLTRB(20, _isDestinationFocused ? 10 : 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isDestinationFocused) ...[
              const Text(
                'Où allons-nous aujourd\'hui ?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _AppColors.gray900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildDestinationInput(),
          ],
        ),
      );
    }

    // Si la destination est choisie, on affiche les services et le paiement
    return SingleChildScrollView(
      key: const ValueKey('service_step'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Récapitulatif destination compact
          _buildDestinationSummary(),
          
          if (_showRouteInfo && _estimatedDistance != null)
            _buildRouteInlineBadge(),

          const SizedBox(height: 24),
          
          // Sélection du service
          _buildServiceSelection(catalogueAsync),

          const SizedBox(height: 24),
          
          // Sélection du paiement
          _buildPaymentSelection(),
          
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDestinationSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.gray100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _AppColors.accentLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, size: 18, color: _AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destination',
                  style: TextStyle(fontSize: 11, color: _AppColors.gray400, fontWeight: FontWeight.w600),
                ),
                Text(
                  _destinationController.text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _AppColors.gray900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _destinationCoordinates = null;
                _showRouteInfo = false;
                _showRouteEstimation = false;
                _destinationController.clear();
                _selectedService = null;
                _selectedCategory = null;
                _serviceSectionExpanded = false;
              });
              final n = ref.read(mapProvider.notifier);
              n.clearPolylines();
              n.removeMarker('pickup');
              n.removeMarker('destination');
            },
            icon: const Icon(Icons.edit_outlined, size: 18, color: _AppColors.accent),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── Trip Waiting Card ─────────────────────────────────────────────────────
  Widget _buildTripWaitingCard() {
    final tripData = _tripResponse!.data!;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: _AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: _AppColors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: _AppColors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Course créée avec succès',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'En attente d\'un livreur',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Trip details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fare section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _AppColors.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Tarif estimé',
                          style: TextStyle(
                            fontSize: 12,
                            color: _AppColors.gray600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${tripData.estimatedFare.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _AppColors.accentMid,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tripData.currency,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _AppColors.accentMid,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Trip info
                  Row(
                    children: [
                      Expanded(
                        child: _buildTripInfoItem(
                          icon: Icons.route_rounded,
                          label: 'Distance',
                          value: '${_estimatedDistance?.toStringAsFixed(1)} km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTripInfoItem(
                          icon: Icons.access_time_rounded,
                          label: 'Durée',
                          value: _estimatedDuration ?? '-',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTripInfoItem(
                          icon: _paymentType == 'card' ? Icons.credit_card_rounded : Icons.payments_rounded,
                          label: 'Paiement',
                          value: _paymentType == 'card' ? 'Carte' : 'Espèces',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(tripData.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getStatusColor(tripData.status),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(tripData.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(tripData.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(tripData.status),
                          ),
                        ),
                        const Spacer(),
                        if (tripData.estimatedArrivalMinutes != null)
                          Text(
                            '~${tripData.estimatedArrivalMinutes} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _AppColors.gray600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: Implement cancel trip
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Annulation en cours...')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: _AppColors.gray300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _AppColors.gray600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Implement contact driver
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Contact en cours...')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Suivre',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                )],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTripInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: _AppColors.accent,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _AppColors.gray400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _AppColors.gray900,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _AppColors.gray400;
      case 'searching':
        return _AppColors.accent;
      case 'accepted':
        return _AppColors.green;
      case 'arriving':
        return Colors.orange;
      case 'in_progress':
        return _AppColors.accentMid;
      case 'completed':
        return _AppColors.green;
      case 'cancelled':
        return _AppColors.red;
      default:
        return _AppColors.gray400;
    }
  }
  
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'searching':
        return 'Recherche de livreur';
      case 'accepted':
        return 'Course acceptée';
      case 'arriving':
        return 'Livreur en route';
      case 'in_progress':
        return 'Course en cours';
      case 'completed':
        return 'Course terminée';
      case 'cancelled':
        return 'Course annulée';
      default:
        return 'En attente';
    }
  }
  Widget _buildDestinationInput() {
    return Column(
      children: [
        // Input field
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: _isDestinationFocused ? _AppColors.white : _AppColors.gray50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDestinationFocused ? _AppColors.primary : _AppColors.gray200,
              width: _isDestinationFocused ? 2 : 1,
            ),
            boxShadow: _isDestinationFocused ? [
              BoxShadow(
                color: _AppColors.primary.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: TextField(
            controller: _destinationController,
            focusNode: _destinationFocusNode,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _AppColors.gray900,
            ),
            decoration: InputDecoration(
              hintText: 'Saisissez votre destination...',
              hintStyle: const TextStyle(
                fontSize: 15,
                color: _AppColors.gray400,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_AppColors.primary),
                        ),
                      )
                    : Icon(
                        Icons.search_rounded,
                        color: _isDestinationFocused ? _AppColors.primary : _AppColors.gray400,
                        size: 22,
                      ),
              ),
              suffixIcon: _destinationController.text.isNotEmpty ? IconButton(
                icon: const Icon(Icons.cancel_rounded, color: _AppColors.gray300, size: 20),
                onPressed: () => _destinationController.clear(),
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
            ),
          ),
        ),

        // Address suggestions
        if (_addressSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 350), // Augmenté pour voir encore plus de résultats
            decoration: BoxDecoration(
              color: _AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _AppColors.gray200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _addressSuggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _AppColors.gray100),
              itemBuilder: (context, index) {
                final suggestion = _addressSuggestions[index];
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _AppColors.accentLight,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: _AppColors.accent,
                    ),
                  ),
                  title: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _AppColors.gray900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text(
                    'Appuyer pour sélectionner',
                    style: TextStyle(fontSize: 11, color: _AppColors.gray400),
                  ),
                  onTap: () => _selectDestination(suggestion),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Route Inline Badge ─────────────────────────────────────────────────────
  Widget _buildRouteInlineBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _AppColors.accentLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_rounded, size: 15, color: _AppColors.accentMid),
          const SizedBox(width: 8),
          Text(
            '${_estimatedDistance!.toStringAsFixed(1)} km',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _AppColors.accentMid,
            ),
          ),
          if (_estimatedDuration != null) ...[
            Text(
              '  ·  $_estimatedDuration',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _AppColors.accentMid,
              ),
            ),
          ],
          const Spacer(),
          const Text(
            'Trajet calculé',
            style: TextStyle(fontSize: 11, color: _AppColors.accentMid),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSelection(AsyncValue<ServiceCatalogue> catalogueAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('SERVICES DISPONIBLES', style: _AppTextStyles.sectionLabel),
            const Spacer(),
            if (_selectedService != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _AppColors.greenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Sélectionné',
                  style: TextStyle(fontSize: 10, color: _AppColors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        catalogueAsync.when(
          loading: () => const SizedBox(
            height: 90,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(_AppColors.accent),
              ),
            ),
          ),
          error: (error, stack) => SizedBox(
            height: 90,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: _AppColors.gray300, size: 28),
                  const SizedBox(height: 6),
                  const Text(
                    'Erreur de chargement',
                    style: TextStyle(fontSize: 12, color: _AppColors.gray400),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(catalogueProvider.notifier).fetchCatalogue(),
                    child: const Text('Réessayer',
                        style: TextStyle(fontSize: 12, color: _AppColors.accent)),
                  ),
                ],
              ),
            ),
          ),
          data: (catalogue) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoriesList(catalogue),
              if (_servicesExpanded && _selectedCategory != null) ...[
                const SizedBox(height: 16),
                _buildServicesList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesList(ServiceCatalogue catalogue) {
    final categories = catalogue.data;

    if (categories.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.category_outlined,
                  color: _AppColors.gray200, size: 28),
              const SizedBox(height: 6),
              Text(
                'Aucun service disponible',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory?.id == category.id;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedCategory = null;
                  _selectedService = null;
                  _servicesExpanded = false;
                } else {
                  _selectedCategory = category;
                  _selectedService = null;
                  _servicesExpanded = true;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _AppColors.accent : _AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _AppColors.accent : _AppColors.gray200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : _AppColors.gray100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category.name),
                      size: 17,
                      color: isSelected ? _AppColors.white : _AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    style: isSelected
                        ? _AppTextStyles.chipLabelActive
                        : _AppTextStyles.chipLabel,
                  ),
                  if (category.services.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${category.services.length}',
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected
                            ? Colors.white.withOpacity(0.65)
                            : _AppColors.gray400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesLabel() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: _AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Services disponibles',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _AppColors.gray900,
          ),
        ),
      ],
    );
  }

  Widget _buildServicesList() {
    if (_selectedCategory == null) return const SizedBox.shrink();
    final services = _selectedCategory!.services;

    return Column(
      children: services.map((service) => _buildServiceItem(service)).toList(),
    );
  }

  Widget _buildPaymentSelection() {
    final cardsState = ref.watch(cardsProvider);
    final defaultCard = cardsState.cards.isNotEmpty 
        ? cardsState.cards.firstWhere((c) => c.isDefault, orElse: () => cardsState.cards.first)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MODE DE PAIEMENT', style: _AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildCompactPaymentItem(
              id: 'cash',
              label: 'Espèces',
              icon: Icons.payments_rounded,
              isSelected: _paymentType == 'cash',
            ),
            const SizedBox(width: 12),
            _buildCompactPaymentItem(
              id: 'card',
              label: defaultCard != null ? 'Carte' : 'Ajouter une carte',
              subLabel: defaultCard?.maskedLabel,
              icon: Icons.credit_card_rounded,
              isSelected: _paymentType == 'card',
              onTap: () {
                if (defaultCard == null) {
                  _showNoCardDialog();
                } else if (_paymentType == 'card') {
                  Navigator.pushNamed(context, '/cards');
                } else {
                  setState(() => _paymentType = 'card');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactPaymentItem({
    required String id,
    required String label,
    String? subLabel,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => setState(() => _paymentType = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? _AppColors.accent : _AppColors.gray50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? [
              BoxShadow(
                color: _AppColors.accent.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? _AppColors.white : _AppColors.gray400,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? _AppColors.white : _AppColors.gray900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subLabel != null)
                      Text(
                        subLabel,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? _AppColors.white.withOpacity(0.7) : _AppColors.gray400,
                        ),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTypeItem({
    required String id,
    required String label,
    String? subLabel,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _paymentType = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _AppColors.accentLight : _AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _AppColors.accent : _AppColors.gray200,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? _AppColors.accent : _AppColors.gray400,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? _AppColors.accentMid : _AppColors.gray600,
              ),
            ),
            if (subLabel != null)
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? _AppColors.accentMid.withOpacity(0.7) : _AppColors.gray400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNoCardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aucune carte enregistrée'),
        content: const Text(
          'Vous devez enregistrer une carte bancaire pour utiliser ce mode de paiement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/cards');
            },
            child: const Text('Ajouter une carte'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(Service service) {
    final isSelected = _selectedService?.id == service.id;

    return GestureDetector(
      onTap: service.isActive
          ? () {
              setState(() => _selectedService = service);
              if (!_serviceSectionExpanded) {
                setState(() {
                  _serviceSectionExpanded = true;
                  _sheetHeight = 0.75;
                });
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _AppColors.accentLight : _AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _AppColors.accent : _AppColors.gray100,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _AppColors.accent.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            // Service Icon background
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? _AppColors.white : _AppColors.gray50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(_selectedCategory?.name ?? ''),
                size: 22,
                color: isSelected ? _AppColors.accent : _AppColors.gray400,
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: service.isActive ? _AppColors.gray900 : _AppColors.gray400,
                    ),
                  ),
                  if (service.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      service.description!,
                      style: _AppTextStyles.serviceDescStyle.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Price
            if (service.basePrice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${service.basePrice!.toStringAsFixed(2)} ${service.currency}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? _AppColors.accentMid : _AppColors.gray900,
                    ),
                  ),
                  const Text(
                    'estimé',
                    style: TextStyle(fontSize: 10, color: _AppColors.gray400),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── CTA Button ─────────────────────────────────────────────────────────────
  Widget _buildCtaButton() {
    final hasService = _selectedService != null;
    final canCreate = hasService && 
        _destinationCoordinates != null && 
        _estimatedDistance != null && 
        _estimatedDuration != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, MediaQuery.of(context).padding.bottom + 16),
      child: GestureDetector(
        onTap: canCreate && !_isCreatingTrip ? _createRide : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 56,
          decoration: BoxDecoration(
            gradient: (canCreate && !_isCreatingTrip)
                ? const LinearGradient(
                    colors: [_AppColors.accent, _AppColors.accentMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: (canCreate && !_isCreatingTrip) ? null : _AppColors.gray100,
            borderRadius: BorderRadius.circular(18),
            boxShadow: (canCreate && !_isCreatingTrip)
                ? [
                    BoxShadow(
                      color: _AppColors.accent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: _isCreatingTrip ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: canCreate ? _AppColors.white : _AppColors.gray400,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      canCreate
                          ? 'Confirmer la course'
                          : 'Choisir une option',
                      style: (canCreate && !_isCreatingTrip)
                          ? _AppTextStyles.ctaLabel.copyWith(fontSize: 16)
                          : _AppTextStyles.ctaLabelDisabled.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (_isCreatingTrip)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(_AppColors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('taxi') || name.contains('transport'))
      return Icons.local_taxi_rounded;
    if (name.contains('livraison') || name.contains('delivery'))
      return Icons.delivery_dining_rounded;
    if (name.contains('moto')) return Icons.motorcycle_rounded;
    if (name.contains('van') || name.contains('camion'))
      return Icons.local_shipping_rounded;
    if (name.contains('course') || name.contains('ride'))
      return Icons.directions_car_rounded;
    if (name.contains('urgence') || name.contains('emergency'))
      return Icons.emergency_rounded;
    if (name.contains('premium') || name.contains('luxury'))
      return Icons.star_rounded;
    return Icons.category_rounded;
  }
}

// ─── Reusable UI Components ────────────────────────────────────────────────────

/// Frosted glass card with subtle shadow
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Circular icon button
class _CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  const _CircleButton({
    required this.child,
    required this.color,
    this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

/// Floating action button (map overlay)
class _FabButton extends StatelessWidget {
  final Widget child;
  final String heroTag;
  final VoidCallback onTap;

  const _FabButton({
    required this.child,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onTap,
        backgroundColor: _AppColors.white,
        mini: true,
        elevation: 0,
        child: child,
      ),
    );
  }
}

/// Stat cell for route estimation
class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _AppColors.accent),
          const SizedBox(height: 5),
          Text(value, style: _AppTextStyles.statValue),
          const SizedBox(height: 2),
          Text(label, style: _AppTextStyles.statLabel),
        ],
      ),
    );
  }
}

/// Simple horizontal divider
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _AppColors.gray100);
  }
}
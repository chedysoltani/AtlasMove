import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import '../providers/map_provider.dart';
import '../providers/services_provider.dart';
import '../models/service_models.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _AppColors {
  static const accent = Color(0xFF4F8EF7);
  static const accentLight = Color(0xFFEBF2FF);
  static const accentMid = Color(0xFF3B74D9);
  static const accentShadow = Color(0x594F8EF7);

  static const green = Color(0xFF22C55E);
  static const greenLight = Color(0xFFDCFCE7);
  static const red = Color(0xFFEF4444);

  static const gray50 = Color(0xFFF8F9FB);
  static const gray100 = Color(0xFFF1F3F7);
  static const gray200 = Color(0xFFE2E6EF);
  static const gray300 = Color(0xFFCDD3E0);
  static const gray400 = Color(0xFF9BA3B4);
  static const gray600 = Color(0xFF5C6475);
  static const gray900 = Color(0xFF0F172A);

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).initializeMap();
      ref.read(catalogueProvider.notifier).fetchCatalogue();
    });
    _destinationController.addListener(_onDestinationChanged);
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
    if (query.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 800), () {
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
      final suggestions = await GeocodingService.searchAddressSuggestions(query);
      if (mounted) {
        setState(() {
          _addressSuggestions = suggestions;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
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

  void _createRide() {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un service'),
          backgroundColor: _AppColors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Course créée avec le service: ${_selectedService!.name}'),
        backgroundColor: _AppColors.green,
      ),
    );
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
    final catalogueAsync = ref.watch(catalogueProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = screenHeight * (_serviceSectionExpanded ? _sheetHeight : 0.35);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (_destinationCoordinates != null && _selectedService != null) {
            if (details.primaryDelta! < -10) {
              _onServiceSelected();
            } else if (details.primaryDelta! > 10 && _serviceSectionExpanded) {
              _collapseServiceSection();
            }
          }
        },
        onVerticalDragEnd: (details) {
          if (_destinationCoordinates != null && _selectedService != null) {
            if (details.velocity.pixelsPerSecond.dy < -500) {
              _onServiceSelected();
            } else if (details.velocity.pixelsPerSecond.dy > 500 && _serviceSectionExpanded) {
              _collapseServiceSection();
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: targetHeight,
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
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 0),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _serviceSectionExpanded ? _AppColors.accent : _AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (_serviceSectionExpanded && _destinationCoordinates != null && _selectedService != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Glissez vers le bas pour voir le trajet',
                  style: TextStyle(
                    fontSize: 11,
                    color: _AppColors.gray400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Destination input ──────────────────────────────────
                      _buildDestinationInput(),

                      // ── Route info inline (after destination selected) ─────
                      if (_showRouteInfo && _estimatedDistance != null)
                        _buildRouteInlineBadge(),

                      const SizedBox(height: 14),
                      const _Divider(),
                      const SizedBox(height: 14),

                      // ── Service selection ──────────────────────────────────
                      _buildServiceSelection(catalogueAsync),

                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // ── CTA Button ─────────────────────────────────────────────────
              _buildCtaButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Destination Input ──────────────────────────────────────────────────────
  Widget _buildDestinationInput() {
    return Column(
      children: [
        // Input field
        Container(
          decoration: BoxDecoration(
            color: _AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _AppColors.gray200),
          ),
          child: TextField(
            controller: _destinationController,
            focusNode: _destinationFocusNode,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _AppColors.gray900,
            ),
            decoration: InputDecoration(
              hintText: 'Où allez-vous ?',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: _AppColors.gray400,
              ),
              prefixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_AppColors.accent),
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.search_rounded,
                      color: _AppColors.gray400,
                      size: 20,
                    ),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _AppColors.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: _AppColors.white,
                    size: 17,
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
        ),

        // Address suggestions
        if (_addressSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: _AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AppColors.gray200),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
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

  // ── Service Selection ──────────────────────────────────────────────────────
  Widget _buildServiceSelection(AsyncValue<ServiceCatalogue> catalogueAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CHOISIR UN SERVICE', style: _AppTextStyles.sectionLabel),
        const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                _buildServicesLabel(),
                const SizedBox(height: 8),
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

  Widget _buildServiceItem(Service service) {
    final isSelected = _selectedService?.id == service.id;

    return GestureDetector(
      onTap: service.isActive
          ? () {
              setState(() => _selectedService = service);
              _onServiceSelected();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? _AppColors.accentLight : _AppColors.gray50,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected ? _AppColors.accent : _AppColors.gray200,
          ),
        ),
        child: Row(
          children: [
            // Color dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _AppColors.accent : _AppColors.gray300,
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: service.isActive
                        ? _AppTextStyles.serviceNameStyle
                        : _AppTextStyles.serviceNameStyle.copyWith(
                            color: _AppColors.gray400),
                  ),
                  if (service.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      service.description!,
                      style: _AppTextStyles.serviceDescStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Price + check
            if (service.basePrice != null)
              Text(
                '${service.basePrice!.toStringAsFixed(2)} ${service.currency}',
                style: isSelected
                    ? _AppTextStyles.servicePriceActiveStyle
                    : _AppTextStyles.servicePriceStyle,
              ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _AppColors.accent : _AppColors.gray300,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: _AppColors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── CTA Button ─────────────────────────────────────────────────────────────
  Widget _buildCtaButton() {
    final hasService = _selectedService != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 16),
      child: GestureDetector(
        onTap: hasService ? _createRide : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: hasService ? _AppColors.accent : _AppColors.gray100,
            borderRadius: BorderRadius.circular(13),
            boxShadow: hasService
                ? const [
                    BoxShadow(
                      color: _AppColors.accentShadow,
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_car_rounded,
                size: 18,
                color: hasService ? _AppColors.white : _AppColors.gray400,
              ),
              const SizedBox(width: 9),
              Text(
                hasService
                    ? 'Créer la course — ${_selectedService!.name}'
                    : 'Sélectionnez un service',
                style: hasService
                    ? _AppTextStyles.ctaLabel
                    : _AppTextStyles.ctaLabelDisabled,
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
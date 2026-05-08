import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../providers/map_provider.dart';
import '../providers/services_provider.dart';
import '../models/service_models.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';

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
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  LatLng? _destinationCoordinates;
  List<String> _addressSuggestions = [];
  bool _isSearching = false;
  double? _estimatedDistance;
  String? _estimatedDuration;
  bool _showRouteInfo = false;

  @override
  void initState() {
    super.initState();
    // Initialiser la carte au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).initializeMap();
      // Charger le catalogue des services
      ref.read(catalogueProvider.notifier).fetchCatalogue();
    });
    
    _destinationController.addListener(_onDestinationChanged);
  }
  
  @override
  void dispose() {
    _destinationController.removeListener(_onDestinationChanged);
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }
  
  void _onDestinationChanged() {
    final query = _destinationController.text;
    if (query.length >= 3) {
      _searchAddresses(query);
    } else {
      setState(() {
        _addressSuggestions = [];
      });
    }
  }
  
  Future<void> _searchAddresses(String query) async {
    print('DEBUG: Searching addresses for query: "$query"');
    setState(() {
      _isSearching = true;
      _addressSuggestions = []; // Clear previous suggestions
    });
    
    try {
      final suggestions = await GeocodingService.searchAddressSuggestions(query);
      print('DEBUG: Found ${suggestions.length} suggestions');
      for (var suggestion in suggestions) {
        print('DEBUG: Suggestion: $suggestion');
      }
      
      if (mounted) {
        setState(() {
          _addressSuggestions = suggestions;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error searching addresses: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
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
        
        // Centrer la carte sur la destination
        final mapState = ref.read(mapProvider);
        if (mapState.mapController != null) {
          mapState.mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 15),
            ),
          );
        }
        
        // Calculer l'itinéraire si on a la position actuelle
        if (mapState.currentPosition != null) {
          await _calculateRoute(mapState.currentPosition!, latLng);
        }
      } else if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse non trouvée')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la recherche de l\'adresse')),
        );
      }
    }
  }
  
  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    // Pour l'instant, calcul simple de distance
    final distance = _calculateDistance(start, end);
    final duration = _estimateDuration(distance);
    
    if (mounted) {
      setState(() {
        _estimatedDistance = distance;
        _estimatedDuration = duration;
        _showRouteInfo = true;
      });
    }
    
    // Ajouter les marqueurs et la polyline
    _addRouteElements(start, end);
  }
  
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // en kilomètres
    
    final double lat1Rad = start.latitude * (math.pi / 180);
    final double lon1Rad = start.longitude * (math.pi / 180);
    final double lat2Rad = end.latitude * (math.pi / 180);
    final double lon2Rad = end.longitude * (math.pi / 180);
    
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;
    
    final double a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.pow(math.sin(dLon / 2), 2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }
  
  String _estimateDuration(double distanceKm) {
    // Estimation simple: 30 km/h en ville
    final minutes = (distanceKm / 30 * 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }
  
  void _addRouteElements(LatLng start, LatLng end) {
    final mapNotifier = ref.read(mapProvider.notifier);
    final mapState = ref.read(mapProvider);
    
    // Effacer les marqueurs précédents sauf la position actuelle
    final currentMarkers = mapState.markers.where(
      (m) => m.markerId.value == 'current_position'
    ).toSet();
    
    // Marqueur de départ (pickup)
    final pickupMarker = Marker(
      markerId: const MarkerId('pickup'),
      position: start,
      infoWindow: const InfoWindow(title: 'Point de départ'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );
    
    // Marqueur de destination
    final destinationMarker = Marker(
      markerId: const MarkerId('destination'),
      position: end,
      infoWindow: const InfoWindow(title: 'Destination'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    
    // Polyline simple (ligne droite entre les points)
    final routePolyline = Polyline(
      polylineId: const PolylineId('route'),
      points: [start, end],
      color: Theme.of(context).primaryColor,
      width: 4,
    );
    
    // Mettre à jour les marqueurs et polylines
    mapNotifier.state = mapState.copyWith(
      markers: {...currentMarkers, pickupMarker, destinationMarker},
      polylines: {routePolyline},
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Google Maps
          _buildGoogleMap(mapState),

          // Header avec bouton retour
          _buildHeader(),

          // Loading overlay
          if (mapState.status == MapStatus.loading)
            const MapLoadingWidget(),

          // Error overlay
          if (mapState.status == MapStatus.error || 
              mapState.status == MapStatus.permissionDenied ||
              mapState.status == MapStatus.locationDisabled)
            _buildErrorWidget(mapState),

          // Bouton flottant pour recentrer
          if (_isMapReady && mapState.status == MapStatus.ready)
            _buildFloatingButtons(mapState),

          // Bottom sheet pour créer une course
          if (_isMapReady && mapState.status == MapStatus.ready)
            _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildGoogleMap(MapState mapState) {
    return GoogleMap(
      initialCameraPosition: mapState.cameraPosition ?? 
          const CameraPosition(target: LatLng(33.5731, -7.5898), zoom: 12),
      onMapCreated: (GoogleMapController controller) {
        ref.read(mapProvider.notifier).setMapController(controller);
        setState(() {
          _isMapReady = true;
        });
      },
      myLocationEnabled: false, // Temporairement désactivé pour éviter les erreurs
      myLocationButtonEnabled: false, // On utilise notre propre bouton
      zoomControlsEnabled: false, // On utilise nos propres contrôles
      compassEnabled: true,
      mapToolbarEnabled: false,
      markers: mapState.markers,
      polylines: mapState.polylines,
      trafficEnabled: false,
      buildingsEnabled: true,
      indoorViewEnabled: false,
      mapType: MapType.normal,
      padding: const EdgeInsets.only(
        top: 120, // Espace pour le header
        bottom: 200, // Espace pour le bottom sheet
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Bouton retour
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Créer une course',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Où allez-vous ?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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

  Widget _buildFloatingButtons(MapState mapState) {
    return Positioned(
      right: 16,
      top: 130, // Juste en dessous du header
      child: Column(
        children: [
          // Bouton pour recentrer sur la position
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: "center_location",
              onPressed: () {
                ref.read(mapProvider.notifier).centerOnCurrentPosition();
              },
              backgroundColor: Colors.white,
              mini: true,
              child: Icon(
                Icons.my_location,
                color: mapState.isFollowingUser 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey[600],
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Bouton pour activer/désactiver le suivi
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: "toggle_following",
              onPressed: () {
                ref.read(mapProvider.notifier).toggleFollowingUser();
              },
              backgroundColor: Colors.white,
              mini: true,
              child: Icon(
                mapState.isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: mapState.isFollowingUser 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey[600],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(MapState mapState) {
    return LocationErrorWidget(
      message: mapState.errorMessage ?? 'Une erreur est survenue',
      status: mapState.status,
      onRetry: () {
        ref.read(mapProvider.notifier).retry();
      },
      onOpenSettings: () {
        if (mapState.status == MapStatus.permissionDenied) {
          // Ouvrir les paramètres de l'application
          LocationService().openAppSettings();
        } else if (mapState.status == MapStatus.locationDisabled) {
          // Ouvrir les paramètres de localisation
          LocationService().openLocationSettings();
        }
      },
    );
  }

  Widget _buildBottomSheet() {
    final catalogueAsync = ref.watch(catalogueProvider);
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Indicateur de drag
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Service Selection Section
              _buildServiceSelection(catalogueAsync),
              
              const SizedBox(height: 16),
              
              // Destination input with suggestions
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _destinationController,
                      focusNode: _destinationFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Où allez-vous ?',
                        prefixIcon: _isSearching 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  
                  // Address suggestions
                  if (_addressSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _addressSuggestions.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200]!,
                        ),
                        itemBuilder: (context, index) {
                          final suggestion = _addressSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.location_on, 
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            title: Text(
                              suggestion,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Appuyer pour sélectionner',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            onTap: () => _selectDestination(suggestion),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  // Route information
                  if (_showRouteInfo && _estimatedDistance != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_estimatedDistance!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_estimatedDuration != null)
                                  Text(
                                    _estimatedDuration!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Test button for debugging
             
              
              const SizedBox(height: 8),
              
              // Bouton créer course
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedService != null ? _createRide : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedService != null 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedService != null 
                            ? 'Créer une course - ${_selectedService!.name}'
                            : 'Sélectionnez un service',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildServiceSelection(AsyncValue<ServiceCatalogue> catalogueAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sélectionner un service',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        catalogueAsync.when(
          loading: () => Container(
            height: 120,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Container(
            height: 120,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () => ref.read(catalogueProvider.notifier).fetchCatalogue(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
          data: (catalogue) => Column(
            children: [
              _buildCategoriesList(catalogue),
              if (_servicesExpanded) _buildServicesList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesList(ServiceCatalogue catalogue) {
    final categories = catalogue.data;
    
    if (categories.isEmpty) {
      return Container(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(
                'Aucun service disponible',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory?.id == category.id;
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getCategoryIcon(category.name),
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (category.services.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${category.services.length}',
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesList() {
    if (_selectedCategory == null || !_servicesExpanded) {
      return const SizedBox.shrink();
    }

    final services = _selectedCategory!.services;
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services disponibles',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ...services.map((service) => _buildServiceItem(service)),
        ],
      ),
    );
  }

  Widget _buildServiceItem(Service service) {
    final isSelected = _selectedService?.id == service.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: service.isActive ? () {
          setState(() {
            _selectedService = service;
          });
        } : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: service.isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                    if (service.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        service.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  if (service.basePrice != null) ...[
                    Text(
                      '${service.basePrice!.toStringAsFixed(2)} ${service.currency}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    
    if (name.contains('taxi') || name.contains('transport')) {
      return Icons.local_taxi;
    } else if (name.contains('livraison') || name.contains('delivery')) {
      return Icons.delivery_dining;
    } else if (name.contains('moto')) {
      return Icons.motorcycle;
    } else if (name.contains('van') || name.contains('camion')) {
      return Icons.local_shipping;
    } else if (name.contains('course') || name.contains('ride')) {
      return Icons.directions_car;
    } else if (name.contains('urgence') || name.contains('emergency')) {
      return Icons.emergency;
    } else if (name.contains('premium') || name.contains('luxury')) {
      return Icons.star;
    } else {
      return Icons.category;
    }
  }

  void _createRide() {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un service'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Implémenter la logique de création de course
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Course créée avec le service: ${_selectedService!.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

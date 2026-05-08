import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../providers/map_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../services/location_service.dart';

class CreateRideOSMScreen extends ConsumerStatefulWidget {
  const CreateRideOSMScreen({super.key});

  @override
  ConsumerState<CreateRideOSMScreen> createState() => _CreateRideOSMScreenState();
}

class _CreateRideOSMScreenState extends ConsumerState<CreateRideOSMScreen> {
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    // Initialiser la carte au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapProvider.notifier).initializeMap();
      // Set map as ready after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isMapReady = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // OpenStreetMap
          _buildOpenStreetMap(mapState),

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

  Widget _buildOpenStreetMap(MapState mapState) {
    return FlutterMap(
      options: MapOptions(
        center: mapState.currentPosition != null 
            ? LatLng(mapState.currentPosition!.latitude, mapState.currentPosition!.longitude)
            : const LatLng(33.5731, -7.5898), // Casablanca par défaut
        zoom: 15.0,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactiveFlags: InteractiveFlag.all,
      ),
      children: [
        // Tile layer OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.atlasmove',
          maxZoom: 19,
        ),
        
        // Markers
        if (mapState.currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(mapState.currentPosition!.latitude, mapState.currentPosition!.longitude),
                width: 40,
                height: 40,
                builder: (context) => const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ],
          ),
      ],
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
                    const SizedBox(height: 4),
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
                if (mapState.currentPosition != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Position centrée')),
                  );
                }
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mapState.isFollowingUser 
                        ? 'Suivi GPS désactivé' 
                        : 'Suivi GPS activé'),
                  ),
                );
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
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
              
              // Destination input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Où allez-vous ?',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
              
              const SizedBox(height: 16),
              
              // Bouton créer course
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implémenter la logique de création de course
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fonctionnalité de création de course bientôt disponible!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Créer une course',
                        style: TextStyle(
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
    );
  }
}

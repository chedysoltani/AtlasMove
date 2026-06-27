import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../services/driver_service.dart';
import '../core/network/http_client.dart';
import '../models/trip_models.dart';
import 'driver_active_ride.dart';

class DriverRidesScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  
  const DriverRidesScreen({super.key, this.onBackToDashboard});

  @override
  State<DriverRidesScreen> createState() => _DriverRidesScreenState();
}

class _DriverRidesScreenState extends State<DriverRidesScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _isLoading = true;
  String? _error;
  String? _acceptingTripId;
  List<AvailableTrip> _trips = [];
  final LocationService _locationService = LocationService();
  final Map<String, double?> _submittedBids = {};
  final Map<String, double> _bidInputs = {};
  final Map<String, bool> _isBiddingExpanded = {};
  final Map<String, Timer> _bidPollingTimers = {};
  Timer? _autoRefreshTimer;
  final Set<String> _refusedTripIds = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    DriverService.isOnlineNotifier.addListener(_onOnlineStatusChanged);
    if (DriverService.isOnline) {
      _fetchAvailableTrips();
      _startAutoRefresh();
    } else {
      _isLoading = false;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _submittedBids.isEmpty && DriverService.isOnline) {
        _fetchAvailableTrips();
      }
    });
  }

  void _onOnlineStatusChanged() {
    if (!mounted) return;
    if (DriverService.isOnline) {
      setState(() { _isLoading = true; _error = null; _trips = []; });
      _fetchAvailableTrips();
      _startAutoRefresh();
    } else {
      _autoRefreshTimer?.cancel();
      setState(() { _isLoading = false; _trips = []; _error = null; });
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    DriverService.isOnlineNotifier.removeListener(_onOnlineStatusChanged);
    _autoRefreshTimer?.cancel();
    for (final t in _bidPollingTimers.values) {
      t.cancel();
    }
    _pulseController.dispose();
    super.dispose();
  }
  
  /// Polls the offer status every 4s. When accepted by the client, redirects to Active Ride.
  void _startBidAcceptancePolling(AvailableTrip trip, double bidAmount) {
    // Don't start duplicate polling for the same trip
    _bidPollingTimers[trip.id]?.cancel();
    _bidPollingTimers[trip.id] = Timer.periodic(
      const Duration(seconds: 4),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          final activeTrip = await TripService.getActiveTrip();
          if (activeTrip != null && activeTrip.id == trip.id && mounted) {
            timer.cancel();
            _bidPollingTimers.remove(trip.id);
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Votre offre a été acceptée ! Course en cours.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverActiveRideScreen(trip: activeTrip),
              ),
            );
          }
        } catch (_) {
          // Keep polling silently on error
        }
      },
    );
  }

  Future<void> _fetchAvailableTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Fetching driver location for trips search...');
      
      // Check permissions and get location
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Le service de localisation est désactivé. Veuillez l\'activer pour rechercher des courses.');
      }

      final permission = await _locationService.requestLocationPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('La permission de localisation est requise pour trouver des courses à proximité.');
      }

      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Impossible d\'obtenir votre position actuelle.');
      }

      debugPrint('Driver location found: ${position.latitude}, ${position.longitude}');
      
      final trips = await TripService.getAvailableTrips(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: 20,
      );

      if (mounted) {
        setState(() {
          // Filtrer les courses refusées localement
          _trips = trips.where((t) => !_refusedTripIds.contains(t.id)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.onBackToDashboard != null
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new, 
                  color: Colors.black,
                  size: 24,
                ),
                onPressed: widget.onBackToDashboard,
              )
            : null,
        title: Text(
          'driver.available_rides'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _isLoading ? null : _fetchAvailableTrips,
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: DriverService.isOnlineNotifier,
        builder: (_, isOnline, __) {
          if (!isOnline) return _buildOfflineScreen();
          return Column(
            children: [
              // Header with status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.orange : (_error != null ? Colors.red : Colors.green),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLoading ? 'common.loading'.tr() : (_error != null ? 'common.error'.tr() : 'driver.status_online'.tr()),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (!_isLoading && _error == null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_trips.length} disponibles',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildBodyContent()),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildOfflineScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFF0F172A), size: 38),
            ),
            const SizedBox(height: 20),
            const Text('Vous êtes hors ligne',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            const Text(
              'Passez en ligne depuis le tableau de bord pour voir et accepter des courses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9BA3B4),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                'common.unknown_error'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!.replaceAll('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'common.retry'.tr(),
                onPressed: _fetchAvailableTrips,
              ),
            ],
          ),
        ),
      );
    }
    
    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.grey.shade300, size: 80),
            const SizedBox(height: 16),
            Text(
              'driver.no_rides'.tr(),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nous vous notifierons dès qu\'une\ncourse sera disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return _buildRideCard(trip);
        },
      ),
    );
  }

  Widget _buildRideCard(AvailableTrip trip) {
    // Determine urgency mock or logic (for demo, if distance < 2km we say urgent)
    final distanceToPickup = trip.distanceToPickupKm ?? 0.0;
    final isUrgent = distanceToPickup < 2.0 && distanceToPickup > 0;
    final typeColor = _getTypeColor(trip.serviceName);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUrgent ? Colors.red.withOpacity(0.3) : Colors.grey.shade200,
                width: isUrgent ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.red.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Ride ID and Type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  trip.id.substring(0, 8).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    trip.serviceName,
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isUrgent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PROCHE',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Client: ${trip.clientName ?? "Inconnu"}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (trip.clientPhone != null && trip.clientPhone!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      trip.clientPhone!,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(trip.offeredFare ?? trip.estimatedFare).toStringAsFixed(2)} ${trip.currency}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            trip.distanceToPickupKm != null 
                                ? 'à ${trip.distanceToPickupKm!.toStringAsFixed(1)} km'
                                : '${trip.estimatedDistanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          if (trip.isNegotiable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Négociable 🤝',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Route Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Pickup
                      _buildLocationRow(
                        Icons.location_on,
                        'Départ',
                        trip.pickupAddress,
                        Colors.green,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Destination
                      _buildLocationRow(
                        Icons.flag,
                        'Destination',
                        trip.destinationAddress,
                        Colors.red,
                      ),
                    ],
                  ),
                ),

                // Action Buttons & Bidding Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bid status if already submitted
                      if (_submittedBids[trip.id] != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'driver_rides.offer_submitted'.tr(namedArgs: {'amount': _submittedBids[trip.id]!.toStringAsFixed(2), 'currency': trip.currency}),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Default actions row
                        Row(
                          children: [
                            // Refuser
                            Expanded(
                              flex: 3,
                              child: OutlinedButton(
                                onPressed: () => _handleRideAction(trip, false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  'driver.refuse'.tr(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Proposer offre
                            if (trip.isNegotiable && _submittedBids[trip.id] == null) ...[
                              Expanded(
                                flex: 4,
                                child: ElevatedButton(
                                  onPressed: () => _showOfferBottomSheet(trip),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Offre',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            
                            // Accepter
                            Expanded(
                              flex: 5,
                              child: _acceptingTripId == trip.id 
                                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()))
                                : CustomButton(
                                    text: _submittedBids[trip.id] != null ? 'driver.accept'.tr() : 'driver.accept'.tr(),
                                    onPressed: () => _handleRideAction(trip, true),
                                    height: 48,
                                  ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOfferBottomSheet(AvailableTrip trip) {
    double bid = (trip.offeredFare ?? trip.estimatedFare) + 1.0;
    final clientFare = trip.offeredFare ?? trip.estimatedFare;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Proposer votre tarif',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (bid > clientFare) {
                            setModal(() => bid = double.parse((bid - 0.5).toStringAsFixed(2)));
                          }
                        },
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.remove, size: 20),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF97316), width: 1.5),
                        ),
                        child: Text(
                          '${bid.toStringAsFixed(2)} ${trip.currency}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setModal(() => bid = double.parse((bid + 0.5).toStringAsFixed(2)));
                        },
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await TripService.submitDriverOffer(trip.id, bid);
                          setState(() => _submittedBids[trip.id] = bid);
                          _startBidAcceptancePolling(trip, bid);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('driver.offer_submitted_short'.tr(namedArgs: {'amount': bid.toStringAsFixed(2), 'currency': trip.currency})),
                            backgroundColor: Colors.green,
                          ));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('common.unknown_error'.tr()),
                            backgroundColor: Colors.red,
                          ));
                        }
                      },
                      child: const Text(
                        'Envoyer l\'offre',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBiddingPanel(AvailableTrip trip) {
    final currentBid = _bidInputs[trip.id] ?? (trip.offeredFare ?? trip.estimatedFare);
    final clientFare = trip.offeredFare ?? trip.estimatedFare;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proposer votre contre-tarif :',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (currentBid > clientFare) {
                    setState(() {
                      _bidInputs[trip.id] = double.parse((currentBid - 0.5).toStringAsFixed(2));
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.remove, color: Colors.black, size: 16),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  '${currentBid.toStringAsFixed(2)} ${trip.currency}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _bidInputs[trip.id] = double.parse((currentBid + 0.5).toStringAsFixed(2));
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                try {
                  await TripService.submitDriverOffer(trip.id, currentBid);
                  setState(() {
                    _submittedBids[trip.id] = currentBid;
                    _isBiddingExpanded[trip.id] = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('driver.offer_submitted_short'.tr(namedArgs: {'amount': currentBid.toStringAsFixed(2), 'currency': trip.currency})),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Start polling until client accepts or rejects
                  _startBidAcceptancePolling(trip, currentBid);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('common.unknown_error'.tr()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'Envoyer l\'offre',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String location,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleRideAction(AvailableTrip trip, bool accept) async {
    if (accept) {
      setState(() {
        _acceptingTripId = trip.id;
      });
      
      try {
        await TripService.acceptTrip(trip.id);
        
        if (mounted) {
          // Remove from list
          setState(() {
            _trips.removeWhere((t) => t.id == trip.id);
            _acceptingTripId = null;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('driver.active_ride'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to active ride
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverActiveRideScreen(trip: trip),
            ),
          );
        }
      } on ForbiddenException {
        if (mounted) {
          setState(() => _acceptingTripId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Abonnement requis pour accepter des courses'),
              backgroundColor: const Color(0xFFEA580C),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'S\'abonner',
                textColor: Colors.white,
                onPressed: () => Navigator.pushNamed(context, '/driver_subscription'),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _acceptingTripId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('common.server_error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Retirer localement immédiatement
      setState(() {
        _refusedTripIds.add(trip.id);
        _trips.removeWhere((t) => t.id == trip.id);
      });
      // Informer le backend — le backend NE doit PAS annuler le trip,
      // il doit seulement marquer ce livreur comme ayant refusé et
      // garder le trip disponible pour les autres livreurs.
      TripService.refuseTrip(trip.id);
    }
  }

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    // Passenger
    if (t.contains('taxi') || t.contains('vtc') || t.contains('voiture')) {
      return Colors.blue;
    }
    // Light delivery
    if (t.contains('coursier') || t.contains('livraison') ||
        t.contains('delivery') || t.contains('colis') ||
        t.contains('camionnette') || t.contains('velo')) {
      return Colors.orange;
    }
    // Heavy transport
    if (t.contains('camion') || t.contains('truck') || t.contains('semi') ||
        t.contains('remorque') || t.contains('tracteur') ||
        t.contains('benne') || t.contains('grue') || t.contains('frigo')) {
      return Colors.purple;
    }
    // Moto
    if (t.contains('moto') || t.contains('motorcycle')) {
      return Colors.green;
    }
    // Maritime
    if (t.contains('yacht') || t.contains('vedette') ||
        t.contains('ferry') || t.contains('nautique')) {
      return Colors.cyan;
    }
    // Bus / collectif
    if (t.contains('bus') || t.contains('minibus') || t.contains('collectif')) {
      return Colors.indigo;
    }
    // Ambulance / urgent
    if (t.contains('ambulance') || t.contains('urgence')) {
      return Colors.red;
    }
    // Agricultural / industrial
    if (t.contains('agricol') || t.contains('tracteur') ||
        t.contains('chariot') || t.contains('engin')) {
      return Colors.brown;
    }
    return AppTheme.primaryColor;
  }
}

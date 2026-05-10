import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip_models.dart';
import '../services/trip_service.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class ClientTripHistoryScreen extends StatefulWidget {
  const ClientTripHistoryScreen({super.key});

  @override
  State<ClientTripHistoryScreen> createState() => _ClientTripHistoryScreenState();
}

class _ClientTripHistoryScreenState extends State<ClientTripHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<TripHistoryItem> _trips = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMore &&
        _error == null) {
      _loadMore();
    }
  }

  Future<void> _loadHistory() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _trips.clear();
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      debugPrint('🔍 TripHistory: Initial load starting...');
      final response = await TripService.getClientTripHistory(page: _currentPage, limit: _limit);
      
      debugPrint('📊 TripHistory API Response: ${response.trips.length} trips found out of ${response.total}');
      
      if (mounted) {
        setState(() {
          _trips.addAll(response.trips);
          _isLoading = false;
          _hasMore = _trips.length < response.total;
        });
      }
    } catch (e) {
      debugPrint('❌ TripHistory Error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      debugPrint('🔄 TripHistory: Loading page $nextPage...');
      final response = await TripService.getClientTripHistory(page: nextPage, limit: _limit);
      
      if (mounted) {
        setState(() {
          _trips.addAll(response.trips);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMore = _trips.length < response.total;
        });
        debugPrint('✅ TripHistory: Page $nextPage loaded. Total items: ${_trips.length}');
      }
    } catch (e) {
      debugPrint('❌ TripHistory Pagination Error: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // We don't set global error for pagination failure to not hide existing items
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors du chargement: $e')),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Historique des trajets',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null && _trips.isEmpty) {
      return _buildErrorState();
    }

    if (_trips.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _trips.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _trips.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TripHistoryCard(trip: _trips[index]),
          );
        } else {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SkeletonCard(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Aucun trajet trouvé',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vos futurs trajets apparaîtront ici.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Recharger',
            onPressed: _loadHistory,
            width: 150,
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Réessayer',
              onPressed: _loadHistory,
              width: 150,
            ),
          ],
        ),
      ),
    );
  }
}

class TripHistoryCard extends StatelessWidget {
  final TripHistoryItem trip;

  const TripHistoryCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final priceFormat = NumberFormat.currency(symbol: trip.currency, decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Top Section: Status & Date
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(status: trip.status),
                  Text(
                    dateFormat.format(trip.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Middle Section: Addresses
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Timeline indicator
                  Column(
                    children: [
                      const Icon(Icons.circle, size: 12, color: AppTheme.primaryColor),
                      Container(
                        width: 2,
                        height: 30,
                        color: Colors.grey.shade200,
                      ),
                      const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Address texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.pickupAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          trip.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // Bottom Section: Fare & Service
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.serviceName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trip.estimatedDistanceKm.toStringAsFixed(1)} km • ${trip.estimatedDurationMin} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    priceFormat.format(trip.estimatedFare),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        label = 'Terminé';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Annulé';
        break;
      case 'accepted':
        color = Colors.blue;
        label = 'Accepté';
        break;
      case 'started':
      case 'in_progress':
        color = Colors.orange;
        label = 'En cours';
        break;
      case 'pending':
        color = Colors.grey;
        label = 'En attente';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: 80,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey.shade50,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey.shade50,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

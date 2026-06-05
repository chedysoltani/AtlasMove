import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/trip_models.dart';
import '../services/trip_service.dart';
import '../utils/app_theme.dart';

class ClientTripHistoryScreen extends StatefulWidget {
  const ClientTripHistoryScreen({super.key});

  @override
  State<ClientTripHistoryScreen> createState() =>
      _ClientTripHistoryScreenState();
}

class _ClientTripHistoryScreenState extends State<ClientTripHistoryScreen> {
  static const _orange = Color(0xFFFF6B35);
  static const _dark = Color(0xFF0F172A);

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
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
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
      final response = await TripService.getClientTripHistory(
          page: _currentPage, limit: _limit);
      if (mounted) {
        setState(() {
          _trips.addAll(response.trips);
          _isLoading = false;
          _hasMore = _trips.length < response.total;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final response = await TripService.getClientTripHistory(
          page: nextPage, limit: _limit);
      if (mounted) {
        setState(() {
          _trips.addAll(response.trips);
          _currentPage = nextPage;
          _isLoadingMore = false;
          _hasMore = _trips.length < response.total;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                color: _orange,
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1A2744)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(top: -20, right: -20,
                child: _ring(140, _orange.withOpacity(0.07))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Historique',
                          style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                        Text('${_trips.length} trajet${_trips.length > 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                  // Refresh button
                  GestureDetector(
                    onTap: _loadHistory,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
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

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) return _buildSkeletons();
    if (_error != null && _trips.isEmpty) return _buildError();
    if (_trips.isEmpty) return _buildEmpty();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      itemCount: _trips.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _trips.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TripHistoryCard(
              trip: _trips[index],
              onCancel: () => _cancelTripDialog(_trips[index]),
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B35)))),
        );
      },
    );
  }

  Widget _buildSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _SkeletonCard(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.history_rounded,
                color: Color(0xFF9BA3B4), size: 36),
          ),
          const SizedBox(height: 14),
          Text('Aucun trajet trouvé',
            style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: _dark)),
          const SizedBox(height: 4),
          Text('Vos futurs trajets apparaîtront ici',
            style: GoogleFonts.poppins(
              fontSize: 12, color: const Color(0xFF9BA3B4))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _orange.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Text('Actualiser',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 14),
            Text('Erreur de chargement',
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12, color: const Color(0xFF9BA3B4))),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: _loadHistory,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('Réessayer',
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cancel dialog ─────────────────────────────────────────────────────────

  Future<void> _cancelTripDialog(TripHistoryItem trip) async {
    final reasons = [
      "Temps d'attente trop long",
      "Changement de programme",
      "Erreur lors de la commande",
      "Chauffeur trop éloigné",
      "Autre",
    ];
    String selectedReason = reasons[0];
    final customCtrl = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E6EF),
                    borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 18),

                // Header
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.cancel_rounded,
                        color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Annuler la course',
                    style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: _dark)),
                ]),
                const SizedBox(height: 6),
                Text('Indiquez le motif de l\'annulation',
                  style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF9BA3B4))),
                const SizedBox(height: 16),

                // Reason chips
                ...reasons.map((r) {
                  final sel = selectedReason == r;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedReason = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: sel
                            ? _orange.withOpacity(0.06)
                            : const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? _orange.withOpacity(0.4)
                              : const Color(0xFFE2E6EF),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? _orange : const Color(0xFFCDD3E0),
                              width: 1.5),
                            color: sel
                                ? _orange.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          child: sel
                              ? Center(child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _orange)))
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(r, style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? _orange : _dark)),
                      ]),
                    ),
                  );
                }),

                if (selectedReason == 'Autre') ...[
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: customCtrl,
                    maxLines: 2,
                    style: GoogleFonts.poppins(fontSize: 13, color: _dark),
                    decoration: InputDecoration(
                      hintText: 'Précisez la raison...',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: const Color(0xFFCDD3E0)),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FB),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFE2E6EF))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFE2E6EF))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _orange, width: 1.5)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFE2E6EF))),
                        child: Center(child: Text('Retour',
                          style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569)))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: isSubmitting ? null : () async {
                        final reason = selectedReason == 'Autre'
                            ? customCtrl.text.trim()
                            : selectedReason;
                        if (selectedReason == 'Autre' && reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Veuillez préciser la raison.')));
                          return;
                        }
                        setModal(() => isSubmitting = true);
                        try {
                          await TripService.cancelClientTrip(trip.id, reason);
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Course annulée.'),
                                  backgroundColor: AppTheme.successColor));
                            _loadHistory();
                          }
                        } catch (e) {
                          if (mounted) {
                            setModal(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'),
                                  backgroundColor: AppTheme.errorColor));
                          }
                        }
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.3),
                            blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Center(child: isSubmitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : Text('Confirmer',
                              style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: Colors.white))),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: c, width: 1)));
}

// ── Trip card ─────────────────────────────────────────────────────────────

class TripHistoryCard extends StatelessWidget {
  final TripHistoryItem trip;
  final VoidCallback? onCancel;

  static const _orange = Color(0xFFFF6B35);
  static const _dark = Color(0xFF0F172A);

  const TripHistoryCard({
    super.key,
    required this.trip,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm');
    final status = trip.status.toLowerCase();
    final isCancelable = ['pending', 'searching', 'accepted',
        'arriving', 'livreur_en_route'].contains(status);
    final isMatching = status == 'pending' || status == 'searching';
    final statusData = _statusInfo(status);

    return GestureDetector(
      onTap: isMatching
          ? () => Navigator.pushNamed(context, '/create_ride',
              arguments: {'tripId': trip.id})
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E6EF)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            // ── Top: status + date ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusData.$2.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusData.$1,
                      style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: statusData.$2)),
                  ),
                  const Spacer(),
                  Text(dateFormat.format(trip.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: const Color(0xFF9BA3B4),
                      fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F3F7)),

            // ── Middle: route ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Timeline
                  Column(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _orange, width: 2),
                          color: Colors.white,
                        ),
                      ),
                      Container(
                          width: 1.5, height: 28,
                          color: const Color(0xFFE2E6EF)),
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Addresses
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.pickupAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: _dark)),
                        const SizedBox(height: 14),
                        Text(trip.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: _dark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F3F7)),

            // ── Bottom: service + fare ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.local_taxi_rounded,
                        color: _orange, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.serviceName,
                          style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _dark)),
                        Text('${trip.estimatedDistanceKm.toStringAsFixed(1)} km'
                            ' • ${trip.estimatedDurationMin} min',
                          style: GoogleFonts.poppins(
                            fontSize: 11, color: const Color(0xFF9BA3B4))),
                      ],
                    ),
                  ),
                  Text(
                    '${trip.estimatedFare.toStringAsFixed(2)} ${trip.currency}',
                    style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: _orange)),
                ],
              ),
            ),

            // ── Cancel button ──────────────────────────────────────
            if (isCancelable && onCancel != null) ...[
              const Divider(height: 1, color: Color(0xFFF1F3F7)),
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_rounded,
                          color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 6),
                      Text('Annuler cette course',
                        style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, Color) _statusInfo(String s) {
    switch (s) {
      case 'completed': return ('Terminé', const Color(0xFF22C55E));
      case 'cancelled': return ('Annulé', const Color(0xFFEF4444));
      case 'accepted': return ('Accepté', const Color(0xFF3B82F6));
      case 'started':
      case 'in_progress': return ('En cours', _orange);
      case 'pending':
      case 'searching': return ('En attente', const Color(0xFF9BA3B4));
      default: return (s, const Color(0xFF9BA3B4));
    }
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E6EF)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _skel(70, 22, radius: 8),
            const Spacer(),
            _skel(80, 14, radius: 6),
          ]),
          const SizedBox(height: 14),
          _skel(double.infinity, 14, radius: 6),
          const SizedBox(height: 10),
          _skel(200, 14, radius: 6),
          const SizedBox(height: 14),
          Row(children: [
            _skel(100, 14, radius: 6),
            const Spacer(),
            _skel(60, 18, radius: 6),
          ]),
        ],
      ),
    );
  }

  Widget _skel(double w, double h, {double radius = 4}) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F7),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

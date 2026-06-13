import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/trip_service.dart';
import '../models/trip_models.dart';
import '../services/notification_service.dart';
import '../services/call_service.dart';
import '../services/profile_service.dart';
import '../widgets/notification_sheet.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard>
    with TickerProviderStateMixin {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);

  // ── State ─────────────────────────────────────────────────────────────────
  int _currentIndex = 0;
  List<TripHistoryItem> _recentTrips = [];
  bool _isLoadingRecent = false;
  bool _isLoadingStats = true;
  String _statsTripsCount = '--';
  String _statsTotalAmount = '--';
  String _statsCurrency = 'TND';
  int _statsUpcomingRdv = 0;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadDashboardData();
    NotificationService().initialize();
    CallService().connectSocket();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingRecent = true;
      _isLoadingStats = true;
    });

    // Charger les stats et les trajets récents en parallèle
    await Future.wait([
      _loadStats(),
      _loadRecentTrips(),
    ]);
  }

  Future<void> _loadStats() async {
    try {
      final stats = await TripService.getClientDashboardStats();
      if (mounted) {
        setState(() {
          _statsTripsCount = stats.totalTrips.toString();
          _statsTotalAmount =
              '${stats.totalSpent.toStringAsFixed(2)} ${stats.currency}';
          _statsCurrency = stats.currency;
          _statsUpcomingRdv = stats.upcomingRendezvous;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadRecentTrips() async {
    try {
      final response = await TripService.getClientTripHistory(page: 1, limit: 3);
      if (mounted) {
        setState(() {
          _recentTrips = response.trips;
          _isLoadingRecent = false;
        });
      }
    } catch (e) {
      debugPrint('Recent trips error: $e');
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  void _navigateToHistory() {
    Navigator.pushNamed(context, '/client_trip_history')
        .then((_) => _loadDashboardData());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: _buildBody(),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 1:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, '/create_ride');
          setState(() => _currentIndex = 0);
        });
        return const SizedBox.shrink();
      case 2:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, '/client_rewards');
          setState(() => _currentIndex = 0);
        });
        return const SizedBox.shrink();
      case 3:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, '/cards');
          setState(() => _currentIndex = 0);
        });
        return const SizedBox.shrink();
      case 4:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, '/profile');
          setState(() => _currentIndex = 0);
        });
        return const SizedBox.shrink();
      default:
        return _buildDashboardContent();
    }
  }

  // ── Dashboard content ─────────────────────────────────────────────────────

  Widget _buildDashboardContent() {
    return Column(
      children: [
        // ── Dark hero header ──────────────────────────────────────────
        _buildHeader(),

        // ── Scrollable white content ──────────────────────────────────
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CTA principal
                    _buildMainCta(),
                    const SizedBox(height: 22),

                    // Stats
                    _buildSectionTitle('client.summary'.tr(), Icons.bar_chart_rounded,
                        onRefresh: _loadDashboardData),
                    const SizedBox(height: 12),
                    _buildStatsRow(),
                    const SizedBox(height: 22),

                    // Rendez-vous card
                    _buildRendezvousCard(),
                    const SizedBox(height: 22),

                    // Activité récente
                    _buildSectionTitle('client.recent_activity'.tr(),
                        Icons.history_rounded, onSeeAll: _navigateToHistory),
                    const SizedBox(height: 12),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
            // Decorative rings
            Positioned(top: -30, right: -30,
                child: _ring(160, _orange.withOpacity(0.07))),
            Positioned(bottom: 0, left: -40,
                child: _ring(120, Colors.white.withOpacity(0.03))),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_orange, _orangeLight]),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('client.welcome'.tr(namedArgs: {'name': '👋'}),
                          style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white54)),
                        Text('client.dashboard_title'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                      ],
                    ),
                  ),
                  // Notification bell
                  AnimatedBuilder(
                    animation: NotificationService(),
                    builder: (_, __) {
                      final count = NotificationService().unreadCount;
                      return GestureDetector(
                        onTap: () => NotificationSheet.show(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.notifications_rounded,
                                  color: Colors.white, size: 20),
                              if (count > 0)
                                Positioned(
                                  right: 8, top: 8,
                                  child: Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(
                                        color: _orange,
                                        shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Logout
                  GestureDetector(
                    onTap: () async {
                      NotificationService().disconnect();
                      await ProfileService.logout();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/login', (_) => false);
                      }
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.logout_rounded,
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

  // ── CTA ───────────────────────────────────────────────────────────────────

  Widget _buildMainCta() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/create_ride'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_dark, Color(0xFF1A2744)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: _dark.withOpacity(0.25),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_orange, _orangeLight]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _orange.withOpacity(0.4),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('client.create_ride'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('client.driver_search_hint'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final loading = _isLoadingStats;
    return Row(
      children: [
        _statChip(
          icon: Icons.route_rounded,
          value: loading ? '...' : _statsTripsCount,
          label: 'client.trips'.tr(),
          color: const Color(0xFF3B82F6),
          onTap: _navigateToHistory,
        ),
        const SizedBox(width: 10),
        _statChip(
          icon: Icons.account_balance_wallet_rounded,
          value: loading ? '...' : _statsTotalAmount,
          label: 'client.spent'.tr(),
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(width: 10),
        _statChip(
          icon: Icons.event_available_rounded,
          value: loading ? '...' : (_statsUpcomingRdv > 0 ? '$_statsUpcomingRdv RDV' : '0 RDV'),
          label: 'rdv.upcoming'.tr(),
          color: _orange,
          onTap: () => Navigator.pushNamed(context, '/client_rendezvous_history'),
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(height: 8),
              Text(value,
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                style: GoogleFonts.poppins(
                  fontSize: 10, color: const Color(0xFF9BA3B4),
                  fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Rendez-vous ───────────────────────────────────────────────────────────

  Widget _buildRendezvousCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/client_rendezvous_history'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('rdv.title'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                  Text('client.book_scheduled'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.white60)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, '/client_rendezvous_booking'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('rdv.reserve'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent trips ──────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    if (_isLoadingRecent) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_orange)),
        ),
      );
    }
    if (_recentTrips.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E6EF)),
        ),
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.history_rounded,
                  color: Color(0xFF9BA3B4), size: 26),
            ),
            const SizedBox(height: 10),
            Text('client.no_trips'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: const Color(0xFF475569))),
            Text('client.trips_hint'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 11, color: const Color(0xFF9BA3B4))),
          ],
        ),
      );
    }
    return Column(
      children: _recentTrips
          .take(3)
          .map((trip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTripCard(trip),
              ))
          .toList(),
    );
  }

  Widget _buildTripCard(TripHistoryItem trip) {
    final dateFormat = DateFormat('dd MMM - HH:mm');
    final statusData = _statusInfo(trip.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E6EF)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_taxi_rounded,
                color: _orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vers ${trip.destinationAddress.split(',').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _dark)),
                const SizedBox(height: 3),
                Row(children: [
                  Text(dateFormat.format(trip.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: const Color(0xFF9BA3B4))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text('·',
                      style: TextStyle(color: Color(0xFFCDD3E0))),
                  ),
                  Text(
                    '${trip.estimatedDistanceKm.toStringAsFixed(1)} km',
                    style: GoogleFonts.poppins(
                      fontSize: 11, color: const Color(0xFF9BA3B4))),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${trip.estimatedFare.toStringAsFixed(2)} ${trip.currency}',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _dark)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusData.$2.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusData.$1,
                  style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: statusData.$2)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return ('common.completed'.tr(), const Color(0xFF22C55E));
      case 'cancelled': return ('common.cancelled'.tr(), const Color(0xFFEF4444));
      case 'accepted': return ('common.accepted'.tr(), const Color(0xFF3B82F6));
      case 'in_progress':
      case 'started': return ('common.in_progress'.tr(), _orange);
      default: return (status, const Color(0xFF9BA3B4));
    }
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'nav.home'.tr(), 0),
              _navItem(Icons.directions_car_rounded, 'client.create_ride'.tr(), 1),
              _navItem(Icons.card_giftcard_rounded, 'nav.loyalty'.tr(), 2),
              _navItem(Icons.credit_card_rounded, 'nav.cards'.tr(), 3),
              _navItem(Icons.person_rounded, 'nav.profile'.tr(), 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 14 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: isSelected ? _orange : const Color(0xFF9BA3B4),
              size: 22),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 10,
              color: isSelected ? _orange : const Color(0xFF9BA3B4),
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon,
      {VoidCallback? onRefresh, VoidCallback? onSeeAll}) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _orange, size: 15),
        ),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
        const Spacer(),
        if (onRefresh != null)
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh_rounded,
                color: _orange, size: 18)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text('nav.history'.tr(), style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600, color: _orange))),
      ],
    );
  }

  Widget _ring(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: c, width: 1)));
}

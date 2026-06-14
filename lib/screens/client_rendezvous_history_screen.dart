import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';
import 'client_rendezvous_booking_screen.dart';
import 'rendezvous_negotiation_screen.dart';

class ClientRendezvousHistoryScreen extends StatefulWidget {
  const ClientRendezvousHistoryScreen({super.key});

  @override
  State<ClientRendezvousHistoryScreen> createState() =>
      _ClientRendezvousHistoryScreenState();
}

class _ClientRendezvousHistoryScreenState
    extends State<ClientRendezvousHistoryScreen>
    with SingleTickerProviderStateMixin {
  // ─── Colors ──────────────────────────────────────────────────────
  static const _navy = Color(0xFF0F172A);
  static const _navyLight = Color(0xFF1E293B);
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);
  static const _bg = Color(0xFFF8F9FB);
  static const _border = Color(0xFFE8ECF0);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);

  // ─── State ───────────────────────────────────────────────────────
  int _selectedTab = 0; // 0 = À venir, 1 = Passés

  final List<Rendezvous> _upcoming = [];
  final List<Rendezvous> _past = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  final int _limit = 10;
  int _total = 0;

  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadHistory();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent * 0.85 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadHistory({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _upcoming.clear();
        _past.clear();
        _currentPage = 1;
        _hasMore = true;
      }
    });

    try {
      final resp = await RendezvousService.getClientHistory(
        page: _currentPage,
        limit: _limit,
      );
      _total = resp.total;
      _distributeItems(resp.items);
      if (mounted) {
        setState(() {
          _hasMore = (_upcoming.length + _past.length) < _total;
          _isLoading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
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
    setState(() => _isLoadingMore = true);
    _currentPage++;
    try {
      final resp = await RendezvousService.getClientHistory(
        page: _currentPage,
        limit: _limit,
      );
      _distributeItems(resp.items);
      if (mounted) {
        setState(() {
          _hasMore = (_upcoming.length + _past.length) < _total;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      _currentPage--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _distributeItems(List<Rendezvous> items) {
    for (final rdv in items) {
      if (rdv.isUpcoming) {
        _upcoming.add(rdv);
      } else {
        _past.add(rdv);
      }
    }
    _upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    _past.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  Future<void> _cancelRendezvous(Rendezvous rdv) async {
    final confirmed = await _showCancelDialog(rdv);
    if (confirmed != true) return;

    try {
      await RendezvousService.cancelRendezvous(rdv.id);
      if (mounted) {
        _showSnack('rdv.cancelled'.tr(), success: true);
        _loadHistory(refresh: true);
      }
    } catch (e) {
      if (mounted) _showSnack('${'common.error'.tr()} : $e', success: false);
    }
  }

  Future<bool?> _showCancelDialog(Rendezvous rdv) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_busy_rounded,
                    color: Color(0xFFEF4444), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'rdv.cancelled'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy à HH:mm', 'fr').format(rdv.scheduledAt),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'common.back'.tr(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'common.cancel'.tr(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      floatingActionButton: _buildFAB(),
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  _buildTabBar(),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────

  Widget _buildHero() {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 145,
        child: Stack(
          children: [
            Positioned(
              right: -25,
              top: -15,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 26,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -25,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                    width: 18,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _loadHistory(refresh: true),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_orange, _orangeLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'rdv.my_rdv'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'rdv.total'.tr(namedArgs: {'count': '${_upcoming.length + _past.length}'}),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.55),
                            ),
                          ),
                        ],
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
  }

  // ─── Tab bar ──────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _tabItem(0, Icons.upcoming_rounded, 'rdv.available'.tr(), _upcoming.length), // TODO: add translation key for "À venir"
            _tabItem(1, Icons.history_rounded, 'rdv.history'.tr(), _past.length), // TODO: add translation key for "Passés"
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label, int count) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? _orange : _textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _textPrimary : _textSecondary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? _orange : _textSecondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Content ──────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_isLoading) return _buildLoader();
    if (_error != null) return _buildError();

    final items = _selectedTab == 0 ? _upcoming : _past;
    final isUpcoming = _selectedTab == 0;

    if (items.isEmpty) return _buildEmpty(isUpcoming);

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: () => _loadHistory(refresh: true),
        color: _orange,
        child: ListView.builder(
          controller: _selectedTab == 0 ? _scrollCtrl : null,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: items.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: _orange, strokeWidth: 2),
                ),
              );
            }
            return _RdvCard(
              rdv: items[i],
              onCancel: items[i].isCancellable ? () => _cancelRendezvous(items[i]) : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: _orange,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'common.loading'.tr(),
            style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFEF4444), size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'common.error'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _orangeButton('common.retry'.tr(), () => _loadHistory(refresh: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isUpcoming) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _textSecondary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpcoming ? Icons.event_available_rounded : Icons.history_rounded,
                color: _textSecondary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'rdv.no_rdv'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              isUpcoming
                  ? 'rdv.book'.tr()
                  : 'rdv.history'.tr(), // TODO: add translation key for "Vos rendez-vous passés apparaîtront ici"
              style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _orangeButton(String label, VoidCallback onTap) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_orange, _orangeLight]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const ClientRendezvousBookingScreen()),
        );
        _loadHistory(refresh: true);
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      label: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_orange, _orangeLight]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _orange.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'rdv.book'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── RDV Card ─────────────────────────────────────────────────────────────────

class _RdvCard extends StatelessWidget {
  final Rendezvous rdv;
  final VoidCallback? onCancel;

  static const _navy = Color(0xFF0F172A);
  static const _orange = Color(0xFFFF6B35);
  static const _border = Color(0xFFE8ECF0);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);

  const _RdvCard({required this.rdv, this.onCancel});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF22C55E);
      case 'completed':
        return const Color(0xFF3B82F6);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'rdv.pending'.tr();
      case 'accepted':
        return 'rdv.confirmed'.tr();
      case 'completed':
        return 'rdv.completed'.tr();
      case 'cancelled':
        return 'rdv.cancelled'.tr();
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(rdv.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top: date + status badge ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon(rdv.status), color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE dd MMMM', 'fr').format(rdv.scheduledAt),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm', 'fr').format(rdv.scheduledAt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(rdv.status),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: _border, height: 1, thickness: 1),

          // ── Middle: service + address + duration ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                _infoRow(Icons.local_taxi_rounded, rdv.serviceName, bold: true),
                const SizedBox(height: 8),
                _infoRow(Icons.location_on_rounded, rdv.address),
                const SizedBox(height: 8),
                _infoRow(Icons.timer_rounded, '${rdv.durationMinutes} minutes'),
                if (rdv.livreurName != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.person_rounded, rdv.livreurName!),
                ],
                if (rdv.details != null && rdv.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.notes_rounded, rdv.details!),
                ],
              ],
            ),
          ),

          // ── Bottom: negotiate button (pending RDV) ────────────
          if (rdv.status == 'pending') ...[
            Divider(color: _border, height: 1, thickness: 1),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RendezvousNegotiationScreen(
                    rdv: rdv,
                    isDriver: false,
                  ),
                ),
              ),
              borderRadius: onCancel != null
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.06),
                  borderRadius: onCancel != null
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🤝', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      'Voir les négociations',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Bottom: cancel button ──────────────────────────────
          if (onCancel != null) ...[
            Divider(color: _border, height: 1, thickness: 1),
            InkWell(
              onTap: onCancel,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.05),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy_rounded,
                        size: 15, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Text(
                      'rdv.cancelled'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: _orange),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: bold ? _textPrimary : _textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';
import '../utils/fare_calculator.dart';
import 'rendezvous_negotiation_screen.dart';

class DriverRendezvousScreen extends StatefulWidget {
  const DriverRendezvousScreen({super.key});

  @override
  State<DriverRendezvousScreen> createState() => _DriverRendezvousScreenState();
}

class _DriverRendezvousScreenState extends State<DriverRendezvousScreen>
    with SingleTickerProviderStateMixin {
  // ─── Colors ──────────────────────────────────────────────────────
  static const _navy = Color(0xFF0F172A);
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);

  int _selectedTab = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  final _planningKey = GlobalKey<_PlanningTabState>();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_selectedTab == index) return;
    HapticFeedback.selectionClick();
    _animCtrl.forward(from: 0);
    setState(() => _selectedTab = index);
  }

  void _onBookingAccepted() {
    _planningKey.currentState?._load();
    _switchTab(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: IndexedStack(
                        index: _selectedTab,
                        children: [
                          _AvailableTab(onAccepted: _onBookingAccepted),
                          _PlanningTab(key: _planningKey),
                          const _HistoryTab(),
                        ],
                      ),
                    ),
                  ),
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
        height: 120,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
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
                          Icons.event_available_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'rdv.title'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'rdv.my_rdv'.tr(), // TODO: add translation key for "Gérez vos courses planifiées"
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
            _tabItem(0, Icons.search_rounded, 'rdv.available'.tr()),
            _tabItem(1, Icons.calendar_month_rounded, 'rdv.my_rdv'.tr()), // TODO: add translation key for "Planning"
            _tabItem(2, Icons.history_rounded, 'rdv.history'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? _orange : const Color(0xFF9BA3B4),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? const Color(0xFF1A1F36) : const Color(0xFF9BA3B4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

const _navy = Color(0xFF0F172A);
const _orange = Color(0xFFFF6B35);
const _orangeLight = Color(0xFFFF8C5A);
const _bg = Color(0xFFF8F9FB);
const _border = Color(0xFFE8ECF0);
const _textPrimary = Color(0xFF1A1F36);
const _textSecondary = Color(0xFF9BA3B4);
const _indigo = Color(0xFF6366F1);

Widget _infoRow(IconData icon, String text,
    {bool bold = false, Color? iconColor}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (iconColor ?? _orange).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: iconColor ?? _orange),
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

void _showSnack(BuildContext context, String msg, {bool success = true}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.poppins()),
    backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

// ─── Tab 1: Available bookings ────────────────────────────────────────────────

class _AvailableTab extends StatefulWidget {
  final VoidCallback? onAccepted;
  const _AvailableTab({this.onAccepted});

  @override
  State<_AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends State<_AvailableTab>
    with AutomaticKeepAliveClientMixin {
  final List<Rendezvous> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  int _total = 0;
  final int _limit = 10;
  Timer? _refreshTimer;
  final Set<String> _acceptingIds = {};
  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) { if (mounted && _acceptingIds.isEmpty && !_isLoading) _refresh(); },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent * 0.85
        && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) { _items.clear(); _page = 1; _hasMore = true; }
    });
    try {
      final resp = await RendezvousService.getAvailableBookings(page: _page, limit: _limit);
      _total = resp.total;
      if (mounted) setState(() {
        _items.addAll(resp.items);
        _hasMore = _items.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _refresh() async {
    if (_isLoading) return;
    setState(() { _items.clear(); _page = 1; _hasMore = true; _isLoading = true; _error = null; });
    try {
      final resp = await RendezvousService.getAvailableBookings(page: 1, limit: _limit);
      _total = resp.total;
      if (mounted) setState(() {
        _items.addAll(resp.items);
        _hasMore = _items.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final resp = await RendezvousService.getAvailableBookings(page: _page, limit: _limit);
      if (mounted) setState(() {
        _items.addAll(resp.items);
        _hasMore = _items.length < _total;
        _isLoadingMore = false;
      });
    } catch (e) {
      _page--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _accept(Rendezvous rdv) async {
    HapticFeedback.lightImpact();
    setState(() => _acceptingIds.add(rdv.id));
    try {
      await RendezvousService.acceptBooking(
        rdv.id,
        finalFare: rdv.estimatedFare,
        currency: rdv.currency ?? 'TND',
      );
      if (mounted) {
        _showSnack(context,
            '${'rdv.accept'.tr()} ${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(rdv.scheduledAt)}');
        _refresh();
        widget.onAccepted?.call();
      }
    } catch (e) {
      if (mounted) _showSnack(context, '${'common.error'.tr()} : $e', success: false);
    } finally {
      if (mounted) setState(() => _acceptingIds.remove(rdv.id));
    }
  }

  Future<void> _propose(Rendezvous rdv) async {
    final currency = rdv.currency ?? 'TND';
    final decimals = const {'EUR', 'GBP', 'USD'}.contains(currency) ? 2 : 3;
    final ctrl = TextEditingController(
      text: rdv.estimatedFare != null
          ? rdv.estimatedFare!.toStringAsFixed(decimals)
          : '',
    );
    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Text('💬', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('Proposer un prix',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rdv.estimatedFare != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Prix client : ${FareCalculator.formatFare(rdv.estimatedFare!, currency)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Votre prix ($currency)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: Text('Envoyer',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == null || !mounted) return;
    try {
      await RendezvousService.proposeOffer(rdv.id, confirmed, currency: currency);
      if (mounted) {
        _showSnack(context,
            'Offre de ${FareCalculator.formatFare(confirmed, currency)} envoyée');
      }
    } catch (e) {
      if (mounted) _showSnack(context, '${'common.error'.tr()} : $e', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return _loader();
    if (_error != null) return _errorView();
    if (_items.isEmpty) return _emptyView();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: _orange,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _orange, strokeWidth: 2),
              ),
            );
          }
          final rdv = _items[i];
          return _AvailableCard(
            rdv: rdv,
            isAccepting: _acceptingIds.contains(rdv.id),
            onAccept: () => _accept(rdv),
            onPropose: () => _propose(rdv),
          );
        },
      ),
    );
  }

  Widget _loader() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: _orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('common.loading'.tr(),
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary)),
        ]),
      );

  Widget _emptyView() => RefreshIndicator(
        onRefresh: _refresh,
        color: _orange,
        child: ListView(children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.search_off_rounded,
                    color: _textSecondary, size: 32),
              ),
              const SizedBox(height: 16),
              Text('rdv.no_rdv'.tr(),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
              const SizedBox(height: 6),
              Text('common.no_data'.tr(), // TODO: add translation key for "Tirez vers le bas pour actualiser"
                  style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary)),
            ]),
          )
        ]),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFEF4444), size: 30),
            ),
            const SizedBox(height: 16),
            Text('common.error'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 6),
            Text(_error!,
                style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _OrangeBtn('common.retry'.tr(), _refresh),
          ]),
        ),
      );
}

class _AvailableCard extends StatelessWidget {
  final Rendezvous rdv;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onPropose;

  const _AvailableCard({
    required this.rdv,
    required this.isAccepting,
    required this.onAccept,
    required this.onPropose,
  });

  static const _green = Color(0xFF22C55E);
  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);
  static const _blue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final hasDestination = rdv.destinationAddress != null && rdv.destinationAddress!.isNotEmpty;
    final hasFare = rdv.estimatedFare != null;
    final currency = rdv.currency ?? 'TND';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [

          // ── Header: date + badges ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_available_rounded,
                      color: _orange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE dd MMM yyyy', 'fr').format(rdv.scheduledAt),
                        style: GoogleFonts.poppins(
                            color: _orange, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        DateFormat('HH:mm', 'fr').format(rdv.scheduledAt),
                        style: GoogleFonts.poppins(
                            color: _orange.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (rdv.isNegotiable)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _indigo.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.handshake_rounded, color: _indigo, size: 12),
                        const SizedBox(width: 4),
                        Text('Négociable',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _indigo)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'rdv.pending'.tr(),
                    style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _amber),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Service ──────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _navy.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        rdv.isDelivery
                            ? Icons.local_shipping_rounded
                            : Icons.local_taxi_rounded,
                        color: _navy,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rdv.serviceName,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: _border, height: 1, thickness: 1),
                const SizedBox(height: 12),

                // ── Route ────────────────────────────────────────────
                _sectionLabel('Trajet', Icons.route_rounded),
                const SizedBox(height: 10),

                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: _orange, shape: BoxShape.circle),
                        ),
                        if (hasDestination) ...[
                          Container(
                              width: 2, height: 28, color: _border),
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                                color: _green, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rdv.address,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                                height: 1.3),
                          ),
                          if (hasDestination) ...[
                            const SizedBox(height: 22),
                            Text(
                              rdv.destinationAddress!,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                  height: 1.3),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Quick chips: distance, duration, weight
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (rdv.estimatedDistanceKm != null)
                      _chip(Icons.route_rounded,
                          '${rdv.estimatedDistanceKm!.toStringAsFixed(1)} km',
                          const Color(0xFF6366F1)),
                    _chip(Icons.timer_rounded,
                        '${rdv.durationMinutes} min', _textSecondary),
                    if (rdv.cargoWeightKg != null)
                      _chip(Icons.scale_rounded,
                          '${rdv.cargoWeightKg!.toStringAsFixed(0)} kg',
                          _textSecondary),
                    if (rdv.cargoSize != null && rdv.cargoSize!.isNotEmpty)
                      _chip(Icons.category_rounded,
                          _cargoSizeLabel(rdv.cargoSize!), _textSecondary),
                    if (rdv.isFragile == true)
                      _chip(Icons.warning_amber_rounded, 'FRAGILE', _red),
                  ],
                ),

                // ── Cargo details ─────────────────────────────────────
                if (rdv.cargoDescription != null &&
                    rdv.cargoDescription!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: _border, height: 1, thickness: 1),
                  const SizedBox(height: 10),
                  _sectionLabel('Marchandise', Icons.inventory_2_rounded),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      rdv.cargoDescription!,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _textPrimary,
                          height: 1.4),
                    ),
                  ),
                ],

                // ── Client info ────────────────────────────────────────
                if (rdv.clientName != null || rdv.clientPhone != null) ...[
                  const SizedBox(height: 12),
                  Divider(color: _border, height: 1, thickness: 1),
                  const SizedBox(height: 10),
                  _sectionLabel('Client', Icons.person_rounded),
                  const SizedBox(height: 8),
                  if (rdv.clientName != null)
                    _infoRow(Icons.person_outline_rounded,
                        rdv.clientName!, bold: true),
                  if (rdv.clientPhone != null) ...[
                    const SizedBox(height: 6),
                    _infoRow(Icons.phone_rounded, rdv.clientPhone!,
                        iconColor: _blue),
                  ],
                ],

                // ── Notes ─────────────────────────────────────────────
                if (rdv.details != null && rdv.details!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: _border, height: 1, thickness: 1),
                  const SizedBox(height: 10),
                  _sectionLabel('Notes', Icons.notes_rounded),
                  const SizedBox(height: 8),
                  Text(
                    rdv.details!,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _textSecondary,
                        height: 1.5),
                  ),
                ],

                // ── Tarif estimé ──────────────────────────────────────
                if (hasFare) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_rounded,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tarif estimé',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white54),
                          ),
                        ),
                        Text(
                          FareCalculator.formatFare(
                              rdv.estimatedFare!, currency),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Action buttons ────────────────────────────────────
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isAccepting ? null : onPropose,
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: _indigo),
                        label: Text('Proposer',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _indigo)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: _indigo),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: isAccepting
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFF4ADE80)]),
                          color: isAccepting ? _border : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isAccepting
                              ? []
                              : [
                                  BoxShadow(
                                    color: _green.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: isAccepting ? null : onAccept,
                          icon: isAccepting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _textSecondary))
                              : const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 18),
                          label: Text(
                            isAccepting
                                ? 'common.loading'.tr()
                                : 'rdv.accept'.tr(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isAccepting
                                  ? _textSecondary
                                  : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _textSecondary),
        const SizedBox(width: 5),
        Text(label.toUpperCase(),
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
                letterSpacing: 0.8)),
      ],
    );
  }

  String _cargoSizeLabel(String size) {
    switch (size) {
      case 'small': return 'Petit';
      case 'medium': return 'Moyen';
      case 'large': return 'Grand';
      case 'extra_large': return 'Très grand';
      default: return size;
    }
  }
}

// ─── Tab 2: Driver Planning ───────────────────────────────────────────────────

class _PlanningTab extends StatefulWidget {
  const _PlanningTab({super.key});

  @override
  State<_PlanningTab> createState() => _PlanningTabState();
}

class _PlanningTabState extends State<_PlanningTab>
    with AutomaticKeepAliveClientMixin {
  List<Rendezvous> _items = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _releasingIds = {};
  final Set<String> _completingIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final items = await RendezvousService.getDriverSchedule();
      if (mounted) setState(() {
        _items = items..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _release(Rendezvous rdv) async {
    final confirmed = await _confirmDialog(
      context,
      icon: Icons.undo_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'rdv.refuse'.tr(), // TODO: add translation key for "Libérer ce rendez-vous ?"
      subtitle:
          '${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(rdv.scheduledAt)}',
      confirmLabel: 'rdv.refuse'.tr(),
      confirmColor: const Color(0xFFF59E0B),
    );
    if (confirmed != true) return;

    HapticFeedback.lightImpact();
    setState(() => _releasingIds.add(rdv.id));
    try {
      await RendezvousService.rejectBooking(rdv.id);
      if (mounted) {
        _showSnack(context, 'rdv.cancelled'.tr());
        _load();
      }
    } catch (e) {
      if (mounted) _showSnack(context, '${'common.error'.tr()} : $e', success: false);
    } finally {
      if (mounted) setState(() => _releasingIds.remove(rdv.id));
    }
  }

  Future<void> _complete(Rendezvous rdv) async {
    final confirmed = await _confirmDialog(
      context,
      icon: Icons.task_alt_rounded,
      iconColor: const Color(0xFF22C55E),
      title: 'Terminer le rendez-vous',
      subtitle: DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(rdv.scheduledAt),
      confirmLabel: 'Terminer',
      confirmColor: const Color(0xFF22C55E),
    );
    if (confirmed != true) return;

    HapticFeedback.lightImpact();
    setState(() => _completingIds.add(rdv.id));
    try {
      await RendezvousService.completeRendezvous(rdv.id);
      if (mounted) {
        _showSnack(context, 'Rendez-vous terminé');
        _load();
      }
    } catch (e) {
      if (mounted) _showSnack(context, '${'common.error'.tr()} : $e', success: false);
    } finally {
      if (mounted) setState(() => _completingIds.remove(rdv.id));
    }
  }

  void _copyCoords(Rendezvous rdv) {
    Clipboard.setData(ClipboardData(text: '${rdv.latitude}, ${rdv.longitude}'));
    _showSnack(context, 'rdv.address'.tr()); // TODO: add translation key for "Coordonnées copiées"
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return _loader();
    if (_error != null) return _errorView();
    if (_items.isEmpty) return _emptyView();

    return RefreshIndicator(
      onRefresh: _load,
      color: _orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final rdv = _items[i];
          final showDay = i == 0 ||
              !_sameDay(_items[i - 1].scheduledAt, rdv.scheduledAt);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDay) _dayHeader(rdv.scheduledAt),
              _PlanningCard(
                rdv: rdv,
                isReleasing: _releasingIds.contains(rdv.id),
                isCompleting: _completingIds.contains(rdv.id),
                onRelease: () => _release(rdv),
                onComplete: () => _complete(rdv),
                onNavigate: () => _copyCoords(rdv),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayHeader(DateTime date) {
    final isToday = _sameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isToday ? _navy : _textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isToday ? 'rdv.today'.tr() : DateFormat('EEEE dd MMMM', 'fr').format(date),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isToday ? Colors.white : _textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: _border, thickness: 1)),
      ]),
    );
  }

  Widget _loader() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: _orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('common.loading'.tr(),
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary)),
        ]),
      );

  Widget _emptyView() => RefreshIndicator(
        onRefresh: _load,
        color: _orange,
        child: ListView(children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.calendar_month_outlined,
                    color: _textSecondary, size: 32),
              ),
              const SizedBox(height: 16),
              Text('rdv.no_rdv'.tr(),
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
              const SizedBox(height: 6),
              Text('rdv.available'.tr(), // TODO: add translation key for "Acceptez des RDV dans l'onglet Disponibles"
                  style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary)),
            ]),
          )
        ]),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFEF4444), size: 30),
            ),
            const SizedBox(height: 16),
            Text('common.error'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 6),
            Text(_error!,
                style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _OrangeBtn('common.retry'.tr(), _load),
          ]),
        ),
      );
}

class _PlanningCard extends StatelessWidget {
  final Rendezvous rdv;
  final bool isReleasing;
  final bool isCompleting;
  final VoidCallback onRelease;
  final VoidCallback onComplete;
  final VoidCallback onNavigate;

  const _PlanningCard({
    required this.rdv,
    required this.isReleasing,
    required this.isCompleting,
    required this.onRelease,
    required this.onComplete,
    required this.onNavigate,
  });

  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Time banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.access_time_rounded, color: _green, size: 16),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  DateFormat('HH:mm', 'fr').format(rdv.scheduledAt),
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _green),
                ),
                Text(
                  '${rdv.durationMinutes} min',
                  style: GoogleFonts.poppins(fontSize: 11, color: _green.withOpacity(0.7)),
                ),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'rdv.confirmed'.tr(),
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _green),
                ),
              ),
            ]),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(children: [
              _infoRow(
                rdv.isDelivery
                    ? Icons.local_shipping_rounded
                    : Icons.local_taxi_rounded,
                rdv.serviceName,
                bold: true,
              ),
              const SizedBox(height: 8),
              _infoRow(Icons.location_on_rounded, rdv.address,
                  iconColor: rdv.isDelivery ? _orange : null),
              if (rdv.isDelivery && rdv.destinationAddress != null) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.flag_rounded, rdv.destinationAddress!,
                    iconColor: _green),
              ],
              if (rdv.estimatedDistanceKm != null) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.route_rounded,
                    '${rdv.estimatedDistanceKm!.toStringAsFixed(1)} km estimés'),
              ],
              if (rdv.cargoDescription != null &&
                  rdv.cargoDescription!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.inventory_2_rounded, rdv.cargoDescription!),
              ],
              if (rdv.isFragile == true) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.warning_amber_rounded, 'Colis FRAGILE',
                    iconColor: const Color(0xFFEF4444)),
              ],
              if (!rdv.isDelivery) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.timer_rounded, '${rdv.durationMinutes} min'),
              ],
              if (rdv.clientName != null) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.person_rounded, 'rdv.client_name'.tr(namedArgs: {'name': rdv.clientName!})),
              ],
              if (rdv.clientPhone != null) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.phone_rounded, rdv.clientPhone!),
              ],
              if (rdv.details != null && rdv.details!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.notes_rounded, rdv.details!),
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_rounded, size: 16, color: _navy),
                    label: Text('Naviguer',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, color: _navy, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: _navy),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isReleasing ? null : onRelease,
                    icon: isReleasing
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFF59E0B)))
                        : const Icon(Icons.undo_rounded,
                            size: 16, color: Color(0xFFF59E0B)),
                    label: Text(
                      isReleasing ? 'common.loading'.tr() : 'rdv.refuse'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                          fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isCompleting ? null : onComplete,
                  icon: isCompleting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.task_alt_rounded,
                          size: 16, color: Colors.white),
                  label: Text(
                    isCompleting ? 'common.loading'.tr() : 'Terminer',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RendezvousNegotiationScreen(
                        rdv: rdv,
                        isDriver: true,
                      ),
                    ),
                  ),
                  icon: const Text('🤝', style: TextStyle(fontSize: 15)),
                  label: Text('Voir les négociations',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _indigo,
                          fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: _indigo),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3: Driver History ────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final List<Rendezvous> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  int _total = 0;
  final int _limit = 10;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent * 0.85
        && !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) { _items.clear(); _page = 1; _hasMore = true; }
    });
    try {
      final resp = await RendezvousService.getDriverHistory(page: _page, limit: _limit);
      _total = resp.total;
      if (mounted) setState(() {
        _items.addAll(resp.items);
        _hasMore = _items.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final resp = await RendezvousService.getDriverHistory(page: _page, limit: _limit);
      if (mounted) setState(() {
        _items.addAll(resp.items);
        _hasMore = _items.length < _total;
        _isLoadingMore = false;
      });
    } catch (e) {
      _page--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) return _loader();
    if (_error != null) return _errorView();
    if (_items.isEmpty) return _emptyView();

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: _orange,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _orange, strokeWidth: 2),
              ),
            );
          }
          return _HistoryCard(rdv: _items[i]);
        },
      ),
    );
  }

  Widget _loader() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: _orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('common.loading'.tr(),
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary)),
        ]),
      );

  Widget _emptyView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: _textSecondary.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, color: _textSecondary, size: 32),
          ),
          const SizedBox(height: 16),
          Text('rdv.no_rdv'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
          const SizedBox(height: 6),
          Text('rdv.history'.tr(), // TODO: add translation key for "Vos courses passées apparaîtront ici"
              style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary)),
        ]),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 30),
            ),
            const SizedBox(height: 16),
            Text('common.error'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 6),
            Text(_error!,
                style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _OrangeBtn('common.retry'.tr(), () => _load(refresh: true)),
          ]),
        ),
      );
}

class _HistoryCard extends StatelessWidget {
  final Rendezvous rdv;

  const _HistoryCard({required this.rdv});

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return const Color(0xFF3B82F6);
      case 'cancelled': return const Color(0xFFEF4444);
      case 'accepted':  return const Color(0xFF22C55E);
      default:          return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed': return 'rdv.completed'.tr();
      case 'cancelled': return 'rdv.cancelled'.tr();
      case 'accepted':  return 'rdv.confirmed'.tr();
      default:          return 'rdv.pending'.tr();
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'completed': return Icons.task_alt_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'accepted':  return Icons.check_circle_rounded;
      default:          return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(rdv.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_statusIcon(rdv.status), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    DateFormat('EEEE dd MMMM', 'fr').format(rdv.scheduledAt),
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
                  ),
                  Text(
                    DateFormat('HH:mm', 'fr').format(rdv.scheduledAt),
                    style: GoogleFonts.poppins(fontSize: 12, color: _textSecondary),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _statusLabel(rdv.status),
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ]),
          ),
          Divider(color: _border, height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(children: [
              _infoRow(Icons.local_taxi_rounded, rdv.serviceName, bold: true),
              const SizedBox(height: 8),
              _infoRow(Icons.location_on_rounded, rdv.address),
              const SizedBox(height: 8),
              _infoRow(Icons.timer_rounded, '${rdv.durationMinutes} minutes'),
              if (rdv.clientName != null) ...[
                const SizedBox(height: 8),
                _infoRow(Icons.person_rounded, 'rdv.client_name'.tr(namedArgs: {'name': rdv.clientName!})),
              ],
              if (rdv.finalFare != null) ...[
                const SizedBox(height: 8),
                _infoRow(
                  Icons.payments_rounded,
                  'Montant final : ${FareCalculator.formatFare(rdv.finalFare!, rdv.currency ?? 'TND')}',
                  bold: true,
                ),
              ] else if (rdv.estimatedFare != null) ...[
                const SizedBox(height: 8),
                _infoRow(
                  Icons.payments_rounded,
                  'Tarif estimé : ${FareCalculator.formatFare(rdv.estimatedFare!, rdv.currency ?? 'TND')}',
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _OrangeBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OrangeBtn(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
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
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDialog(
  BuildContext context, {
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required String confirmLabel,
  required Color confirmColor,
}) {
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
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('common.cancel'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: _textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(confirmLabel,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

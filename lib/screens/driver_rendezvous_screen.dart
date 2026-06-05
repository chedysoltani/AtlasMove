import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';
import '../utils/app_theme.dart';

class DriverRendezvousScreen extends StatefulWidget {
  const DriverRendezvousScreen({super.key});

  @override
  State<DriverRendezvousScreen> createState() => _DriverRendezvousScreenState();
}

class _DriverRendezvousScreenState extends State<DriverRendezvousScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rendez-vous'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Disponibles'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Mon Planning'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AvailableBookingsTab(),
          _ScheduleTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Available Bookings ────────────────────────────────────────────────

class _AvailableBookingsTab extends StatefulWidget {
  const _AvailableBookingsTab();

  @override
  State<_AvailableBookingsTab> createState() => _AvailableBookingsTabState();
}

class _AvailableBookingsTabState extends State<_AvailableBookingsTab> {
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
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted && _acceptingIds.isEmpty) _refresh();
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

  Future<void> _load({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _items.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final resp =
          await RendezvousService.getAvailableBookings(page: _page, limit: _limit);
      _total = resp.total;
      if (mounted) {
        setState(() {
          _items.addAll(resp.items);
          _hasMore = _items.length < _total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_isLoading) return;
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _isLoading = true;
      _error = null;
    });
    try {
      final resp =
          await RendezvousService.getAvailableBookings(page: 1, limit: _limit);
      _total = resp.total;
      if (mounted) {
        setState(() {
          _items.addAll(resp.items);
          _hasMore = _items.length < _total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    try {
      final resp =
          await RendezvousService.getAvailableBookings(page: _page, limit: _limit);
      if (mounted) {
        setState(() {
          _items.addAll(resp.items);
          _hasMore = _items.length < _total;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      _page--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _accept(Rendezvous rdv) async {
    HapticFeedback.lightImpact();
    setState(() => _acceptingIds.add(rdv.id));
    try {
      await RendezvousService.acceptBooking(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rendez-vous du ${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(rdv.scheduledAt)} accepté !',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingIds.remove(rdv.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _errorView();
    }
    if (_items.isEmpty) {
      return _emptyView();
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ));
          }
          final rdv = _items[i];
          return _AvailableCard(
            rdv: rdv,
            isAccepting: _acceptingIds.contains(rdv.id),
            onAccept: () => _accept(rdv),
          );
        },
      ),
    );
  }

  Widget _emptyView() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'Aucun rendez-vous disponible',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tirez vers le bas pour actualiser',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  final Rendezvous rdv;
  final bool isAccepting;
  final VoidCallback onAccept;

  const _AvailableCard({
    required this.rdv,
    required this.isAccepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available,
                    color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE dd MMMM yyyy • HH:mm', 'fr')
                      .format(rdv.scheduledAt),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.local_shipping, rdv.serviceName,
                    bold: true, fontSize: 14),
                const SizedBox(height: 8),
                _row(Icons.location_on, rdv.address),
                const SizedBox(height: 6),
                _row(Icons.timer, '${rdv.durationMinutes} minutes'),
                if (rdv.clientName != null) ...[
                  const SizedBox(height: 6),
                  _row(Icons.person_outline, rdv.clientName!),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isAccepting ? null : onAccept,
                    icon: isAccepting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                        isAccepting ? 'Acceptation…' : 'Accepter le RDV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text,
      {bool bold = false, double fontSize = 13}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab 2: Driver Schedule ───────────────────────────────────────────────────

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  List<Rendezvous> _items = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _releasingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await RendezvousService.getDriverSchedule();
      if (mounted) {
        setState(() {
          _items = items;
          _items.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _release(Rendezvous rdv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Libérer ce rendez-vous ?'),
        content: Text(
          'Le rendez-vous du ${DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(rdv.scheduledAt)} sera remis dans le pool disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Libérer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.lightImpact();
    setState(() => _releasingIds.add(rdv.id));
    try {
      await RendezvousService.rejectBooking(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rendez-vous libéré avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _releasingIds.remove(rdv.id));
    }
  }

  void _copyCoords(Rendezvous rdv) {
    final coords = '${rdv.latitude}, ${rdv.longitude}';
    Clipboard.setData(ClipboardData(text: coords));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordonnées copiées : $coords'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryColor,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucun rendez-vous accepté ce mois-ci',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final rdv = _items[i];
          final showDayHeader = i == 0 ||
              !_sameDay(_items[i - 1].scheduledAt, rdv.scheduledAt);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDayHeader) _dayHeader(rdv.scheduledAt),
              _ScheduleCard(
                rdv: rdv,
                isReleasing: _releasingIds.contains(rdv.id),
                onRelease: () => _release(rdv),
                onCopyCoords: () => _copyCoords(rdv),
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
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isToday
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isToday
                  ? "Aujourd'hui"
                  : DateFormat('EEEE dd MMMM', 'fr').format(date),
              style: TextStyle(
                color: isToday ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Rendezvous rdv;
  final bool isReleasing;
  final VoidCallback onRelease;
  final VoidCallback onCopyCoords;

  const _ScheduleCard({
    required this.rdv,
    required this.isReleasing,
    required this.onRelease,
    required this.onCopyCoords,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successColor.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Time banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    color: AppTheme.successColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm', 'fr').format(rdv.scheduledAt),
                  style: const TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.timer,
                    color: AppTheme.successColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${rdv.durationMinutes} min',
                  style: const TextStyle(
                    color: AppTheme.successColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Confirmé',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.local_shipping, rdv.serviceName,
                    bold: true, fontSize: 14),
                const SizedBox(height: 8),
                _row(Icons.location_on, rdv.address),
                if (rdv.clientName != null) ...[
                  const SizedBox(height: 6),
                  _row(Icons.person, 'Client : ${rdv.clientName}'),
                ],
                if (rdv.clientPhone != null) ...[
                  const SizedBox(height: 6),
                  _row(Icons.phone, rdv.clientPhone!),
                ],
                if (rdv.details != null && rdv.details!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _row(Icons.notes, rdv.details!),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Copy/navigate button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCopyCoords,
                        icon: const Icon(Icons.navigation,
                            size: 16, color: AppTheme.primaryColor),
                        label: const Text(
                          'Naviguer',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Release button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isReleasing ? null : onRelease,
                        icon: isReleasing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.warningColor),
                              )
                            : const Icon(Icons.undo,
                                size: 16, color: AppTheme.warningColor),
                        label: Text(
                          isReleasing ? 'Libération…' : 'Libérer',
                          style: const TextStyle(
                              color: AppTheme.warningColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppTheme.warningColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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

  Widget _row(IconData icon, String text,
      {bool bold = false, double fontSize = 13}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

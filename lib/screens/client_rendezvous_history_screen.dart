import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';
import '../utils/app_theme.dart';
import 'client_rendezvous_booking_screen.dart';

class ClientRendezvousHistoryScreen extends StatefulWidget {
  const ClientRendezvousHistoryScreen({super.key});

  @override
  State<ClientRendezvousHistoryScreen> createState() =>
      _ClientRendezvousHistoryScreenState();
}

class _ClientRendezvousHistoryScreenState
    extends State<ClientRendezvousHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    if (_isLoading && !refresh) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler le rendez-vous ?'),
        content: Text(
          'Voulez-vous annuler le rendez-vous du ${DateFormat('dd MMM yyyy à HH:mm', 'fr').format(rdv.scheduledAt)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Annuler RDV'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await RendezvousService.cancelRendezvous(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rendez-vous annulé'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadHistory(refresh: true);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mes Rendez-vous'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'À venir (${_upcoming.length})'),
            Tab(text: 'Passés (${_past.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadHistory(refresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientRendezvousBookingScreen(),
            ),
          );
          _loadHistory(refresh: true);
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouveau RDV',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_upcoming, isUpcoming: true),
                    _buildList(_past, isUpcoming: false),
                  ],
                ),
    );
  }

  Widget _buildError() {
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
            onPressed: () => _loadHistory(refresh: true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Rendezvous> items, {required bool isUpcoming}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUpcoming ? Icons.calendar_today : Icons.history,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming
                  ? 'Aucun rendez-vous à venir'
                  : 'Aucun historique',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(refresh: true),
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: isUpcoming ? _scrollCtrl : null,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == items.length) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ));
          }
          return _RendezvousCard(
            rdv: items[i],
            onCancel:
                items[i].isCancellable ? () => _cancelRendezvous(items[i]) : null,
          );
        },
      ),
    );
  }
}

class _RendezvousCard extends StatelessWidget {
  final Rendezvous rdv;
  final VoidCallback? onCancel;

  const _RendezvousCard({required this.rdv, this.onCancel});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.successColor;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Confirmé';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(rdv.status);
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
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.event, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('EEEE dd MMMM yyyy • HH:mm', 'fr')
                        .format(rdv.scheduledAt),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(rdv.status),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.local_shipping, rdv.serviceName),
                const SizedBox(height: 8),
                _infoRow(Icons.location_on, rdv.address),
                const SizedBox(height: 8),
                _infoRow(Icons.timer, '${rdv.durationMinutes} minutes'),
                if (rdv.livreurName != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.person, 'Livreur : ${rdv.livreurName}'),
                ],
                if (rdv.details != null && rdv.details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.notes, rdv.details!),
                ],
                if (onCancel != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.cancel_outlined,
                              size: 16, color: AppTheme.errorColor),
                          label: const Text(
                            'Annuler',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (rdv.livreurPhone != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('Contacter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }
}

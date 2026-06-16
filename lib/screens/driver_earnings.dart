import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/commission_models.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_stats_service.dart';
import '../services/rendezvous_service.dart';
import '../services/location_service.dart';
import 'driver_commission_payment_screen.dart';

const _orange = Color(0xFFFF6B35);
const _orangeLight = Color(0xFFFF8C42);
const _navy = Color(0xFF1E293B);
const _surface = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF64748B);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final _statsService = RendezvousStatsService();

  DateTime _selectedMonth = DateTime.now();
  DriverCommissionStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _monthParam =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      double? lat;
      double? lng;
      final pos = await LocationService().getCurrentPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
      final stats = await _statsService.fetchCommissionStats(
        _monthParam,
        latitude: lat,
        longitude: lng,
      );
      if (stats != null) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
        return;
      }
      // Fallback: build from local rendezvous list
      final rdvList = await _fetchCompletedRdv();
      final localStats = _statsService.buildFromLocal(rdvList, _monthParam, 'TND');
      setState(() {
        _stats = localStats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<Rendezvous>> _fetchCompletedRdv() async {
    try {
      final resp = await RendezvousService.getDriverHistory(limit: 100);
      return resp.items.where((r) {
        return r.status == 'completed' &&
            r.scheduledAt.year == _selectedMonth.year &&
            r.scheduledAt.month == _selectedMonth.month;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
      return;
    }
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _load();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'driver.earnings_title'.tr(),
          style: GoogleFonts.poppins(
            color: _navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _navy, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _navy, size: 22),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _orange,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMonthSelector(),
                        const SizedBox(height: 16),
                        _buildRevenueCard(),
                        const SizedBox(height: 16),
                        _buildCommissionCard(),
                        const SizedBox(height: 16),
                        _buildBreakdownSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
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
            const Icon(Icons.error_outline_rounded, color: _red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: _orange),
              label: Text('Réessayer',
                  style: GoogleFonts.poppins(color: _orange, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final label = _stats?.formattedPeriod ?? _monthParam;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: _navy),
            onPressed: _prevMonth,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16, color: _navy),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded,
                color: _isCurrentMonth ? _border : _navy),
            onPressed: _isCurrentMonth ? null : _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    final stats = _stats;
    final revenue = stats?.totalRevenue ?? 0.0;
    final currency = stats?.currency ?? 'TND';
    final count = stats?.completedCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_orange, _orangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Chiffre d\'affaires',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${revenue.toStringAsFixed(2)} $currency',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      '$count rendez-vous terminés',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionCard() {
    final stats = _stats;
    final commission = stats?.commissionDue ?? 0.0;
    final currency = stats?.currency ?? 'TND';
    final rate = ((stats?.commissionRate ?? 0.10) * 100).toStringAsFixed(0);
    final isPaid = stats?.commissionPaid ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? _green.withOpacity(0.3) : _amber.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _indigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.percent_rounded, color: _indigo, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commission AtlasMove ($rate%)',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15, color: _navy),
                  ),
                  Text(
                    'Applicable aux services de livraison uniquement',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montant dû',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${commission.toStringAsFixed(2)} $currency',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isPaid ? _green : _amber,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (isPaid ? _green : _amber).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (isPaid ? _green : _amber).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      color: isPaid ? _green : _amber,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPaid ? 'Payée' : 'En attente',
                      style: GoogleFonts.poppins(
                        color: isPaid ? _green : _amber,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isPaid && commission > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _amber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'À régler avant la fin du mois pour maintenir l\'accès à vos services.',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommissionPaymentScreen(
                        month: _monthParam,
                        commissionDue: commission,
                        currency: currency,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_rounded,
                    size: 18, color: Colors.white),
                label: Text(
                  'Payer maintenant — ${commission.toStringAsFixed(2)} $currency',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownSection() {
    final items = _stats?.breakdown ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Détail par service',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 16, color: _navy),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _buildEmptyBreakdown()
        else
          ...items.map((item) => _buildBreakdownItem(item)),
      ],
    );
  }

  Widget _buildEmptyBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_rounded, color: _border, size: 44),
            const SizedBox(height: 10),
            Text(
              'Aucun rendez-vous terminé ce mois-ci',
              style: GoogleFonts.poppins(
                  color: _textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(CommissionBreakdownItem item) {
    final isTaxi = item.isTaxiType;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isTaxi
                      ? Icons.local_taxi_rounded
                      : Icons.delivery_dining_rounded,
                  color: _orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.serviceName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _navy),
                    ),
                    Text(
                      '${item.completedCount} mission${item.completedCount > 1 ? 's' : ''} terminée${item.completedCount > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _textSecondary),
                    ),
                  ],
                ),
              ),
              if (isTaxi)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Exempté',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statPill(
                    'CA',
                    '${item.revenue.toStringAsFixed(2)} ${item.currency}',
                    _navy),
                if (!isTaxi)
                  _statPill(
                      'Commission (10%)',
                      '${item.commission.toStringAsFixed(2)} ${item.currency}',
                      _indigo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: _textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

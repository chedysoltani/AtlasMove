import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/commission_models.dart';
import '../models/service_models.dart';
import '../services/location_service.dart';
import '../services/rendezvous_stats_service.dart';
import '../utils/app_theme.dart';

/// Pendant de [DriverSubscriptionScreen] pour les chauffeurs à commission
/// (tous les services sauf Taxi Économique) : pas d'abonnement 90 USD, mais
/// 10 % du chiffre d'affaires, payable chaque mois.
class DriverCommissionScreen extends StatefulWidget {
  const DriverCommissionScreen({super.key});

  @override
  State<DriverCommissionScreen> createState() => _DriverCommissionScreenState();
}

class _DriverCommissionScreenState extends State<DriverCommissionScreen> {
  static const _amber = Color(0xFFF59E0B);

  final _statsService = RendezvousStatsService();
  DriverCommissionStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    DriverCommissionStats? stats;
    try {
      // Devise résolue par zone GPS côté backend, comme dans « Mes gains »
      final pos = await LocationService().getCurrentPosition() ?? LocationService().currentPosition;
      stats = await _statsService.fetchCommissionStats(
        month,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'commission.title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMonthCard(),
                const SizedBox(height: 20),
                _buildPricingCard(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/driver_earnings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 8,
                    shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'commission.see_earnings'.tr(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Commission du mois en cours : montant dû et statut de paiement.
  Widget _buildMonthCard() {
    if (_loading && _stats == null) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF161722),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final stats = _stats;
    final due = stats?.commissionDue ?? 0;
    final currency = stats?.currency ?? 'TND';
    final isPaid = stats?.commissionPaid ?? false;

    final String status;
    final Color accentColor;
    final IconData icon;
    if (stats == null) {
      status = 'commission.unavailable'.tr();
      accentColor = Colors.grey;
      icon = Icons.cloud_off_rounded;
    } else if (isPaid) {
      status = 'driver_earnings.paid'.tr();
      accentColor = AppTheme.successColor;
      icon = Icons.verified_rounded;
    } else if (due > 0) {
      status = 'driver_earnings.pay_before'.tr();
      accentColor = _amber;
      icon = Icons.schedule_rounded;
    } else {
      status = 'commission.nothing_due'.tr();
      accentColor = AppTheme.successColor;
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'commission.this_month'.tr(namedArgs: {'month': stats?.formattedPeriod ?? ''}),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  stats == null ? '—' : '${due.toStringAsFixed(2)} $currency',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (stats != null)
                  Text(
                    'commission.on_revenue'.tr(namedArgs: {
                      'amount': '${stats.totalRevenue.toStringAsFixed(2)} $currency',
                    }),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: TextStyle(color: accentColor, fontSize: 12, height: 1.3, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    final rate = '${(BillingRule.commissionRate * 100).toStringAsFixed(0)}%';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F2130),
            const Color(0xFF141622).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    blurRadius: 40,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      'commission.badge'.tr(),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      rate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'commission.of_revenue'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'commission.tagline'.tr(),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 20),
                _buildCheckRow('commission.feature_no_subscription'.tr()),
                _buildCheckRow('commission.feature_auto'.tr(namedArgs: {'rate': rate})),
                _buildCheckRow('commission.feature_monthly'.tr()),
                _buildCheckRow('commission.feature_details'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Color(0xFF1D2925), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppTheme.successColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFEEEEEE),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

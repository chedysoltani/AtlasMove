import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/driver_subscription_models.dart';
import '../services/subscription_service.dart';

class DriverOfferScreen extends StatefulWidget {
  const DriverOfferScreen({super.key});

  @override
  State<DriverOfferScreen> createState() => _DriverOfferScreenState();
}

class _DriverOfferScreenState extends State<DriverOfferScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0F172A);
  static const _orange = Color(0xFFFF6B35);
  static const _bg = Color(0xFFF8F9FB);

  PrivilegeDashboard? _data;
  bool _loading = true;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await PrivilegeService.getDashboard();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── VIP color helpers ──────────────────────────────────────────────────────

  Color _vipColor(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return const Color(0xFFF59E0B);
      case 'platinum':
        return const Color(0xFF8B5CF6);
      case 'silver':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF92400E);
    }
  }

  String _vipLabel(String level) {
    switch (level.toLowerCase()) {
      case 'gold':
        return 'privilege.vip_gold'.tr();
      case 'platinum':
        return 'privilege.vip_platinum'.tr();
      case 'silver':
        return 'privilege.vip_silver'.tr();
      default:
        return 'privilege.vip_bronze'.tr();
    }
  }

  // Taxi = has subscription spending; logistics = commission only
  bool get _isTaxiProfile =>
      (_data?.financials.totalSpentSubscriptions ?? 0) > 0;

  String _commissionRateLabel(double rate) =>
      '${(rate * 100).toStringAsFixed(0)}%';

  IconData _rewardIcon(String type) =>
      type == 'travel' ? Icons.flight_rounded : Icons.account_balance_wallet_rounded;

  Color _rewardColor(String type) =>
      type == 'travel' ? _orange : const Color(0xFF10B981);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHero(),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    final vipLevel = _data?.vipLevel ?? 'silver';
    final streakMonths = _data?.streakMonths ?? 0;
    final currentLevel = _data?.stats.currentLevel ?? vipLevel;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _navy,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
          ),
          onPressed: _load,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: _navy,
          child: Stack(
            children: [
              // decorative circles
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: 20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _orange.withOpacity(0.08),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          // VIP badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _vipColor(vipLevel).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _vipColor(vipLevel).withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded,
                                    color: _vipColor(vipLevel), size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  _vipLabel(vipLevel),
                                  style: TextStyle(
                                    color: _vipColor(vipLevel),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_data != null) ...[
                            // Commission rate badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.pie_chart_rounded,
                                      color: Colors.white70, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    _commissionRateLabel(_data!.financials.commissionRate),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Score chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _orange.withOpacity(0.4)),
                              ),
                              child: Text(
                                'privilege.score'.tr(namedArgs: {'score': _data!.score.toString()}),
                                style: const TextStyle(
                                  color: _orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'privilege.title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'privilege.subtitle'.tr(namedArgs: {'level': currentLevel, 'months': streakMonths.toString()}),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) return _buildError();
    if (_data == null) return const SizedBox();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatChips(_data!),
                const SizedBox(height: 24),
                _buildMonthlyObjective(_data!.monthlyObjective),
                const SizedBox(height: 24),
                _buildRewardsSection(_data!.rewards),
                const SizedBox(height: 24),
                _buildFinancials(_data!.financials),
                const SizedBox(height: 24),
                _buildAnnualRevenueSection(_data!.financials),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stat chips ─────────────────────────────────────────────────────────────

  Widget _buildStatChips(PrivilegeDashboard data) {
    return Row(
      children: [
        Expanded(
          child: _statChip(
            icon: Icons.directions_car_rounded,
            label: 'privilege.this_month'.tr(),
            value: '${data.stats.completedTripsThisMonth}',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statChip(
            icon: Icons.local_fire_department_rounded,
            label: 'privilege.regularity'.tr(),
            value: 'privilege.months_streak'.tr(namedArgs: {'count': data.stats.monthlyConsecutiveMonths.toString()}),
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statChip(
            icon: Icons.workspace_premium_rounded,
            label: 'privilege.level'.tr(),
            value: data.stats.currentLevel.toUpperCase(),
            color: _vipColor(data.vipLevel),
          ),
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF0)),
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
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _navy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9BA3B4), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Monthly Objective ──────────────────────────────────────────────────────

  Widget _buildMonthlyObjective(PrivilegeMonthlyObjective obj) {
    final pct = (obj.completionPercentage / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('privilege.monthly_obj'.tr()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${obj.completedTrips} / ${obj.targetTrips}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'privilege.trips_done'.tr(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Circular progress indicator
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(_orange),
                          strokeWidth: 5,
                        ),
                        Center(
                          child: Text(
                            '${(pct * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Orange progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(_orange),
                ),
              ),
              if (obj.helperMessage.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: _orange, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        obj.helperMessage,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Hours sub-row — taxi only
              if (_isTaxiProfile && obj.targetHours > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: _orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'privilege.hours_active'.tr(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${obj.completedHours}h / ${obj.targetHours}h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'privilege.hours_remaining'.tr(namedArgs: {'h': obj.remainingHours.toString()}),
                        style: const TextStyle(
                          color: _orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Rewards ────────────────────────────────────────────────────────────────

  Widget _buildRewardsSection(List<PrivilegeReward> rewards) {
    final driverRewards = rewards
        .where((r) => r.id != 'cashback_100_usd_mock' && r.type != 'travel')
        .toList();
    if (driverRewards.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('privilege.rewards'.tr()),
        const SizedBox(height: 12),
        ...driverRewards.map(_buildRewardCard),
      ],
    );
  }

  Widget _buildRewardCard(PrivilegeReward r) {
    final color = _rewardColor(r.type);
    final pct = (r.completionPercentage / 100).clamp(0.0, 1.0);
    final isCompleted = r.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_rewardIcon(r.type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        r.title,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Text(
                          'privilege.reward_obtained'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'privilege.reward_months_left'.tr(namedArgs: {'months': r.remainingMonths.toString()}),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  r.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9BA3B4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE8ECF0),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.completedMonths} / ${r.targetMonths} mois',
                  style: const TextStyle(
                    color: Color(0xFF9BA3B4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Financials ─────────────────────────────────────────────────────────────

  Widget _buildFinancials(PrivilegeFinancials f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('privilege.financial_summary'.tr()),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _finRow(
                icon: Icons.trending_up_rounded,
                label: 'privilege.total_earnings'.tr(),
                value: '${f.totalDriverEarnings.toStringAsFixed(2)} ${f.currency}',
                color: const Color(0xFF10B981),
              ),
              const Divider(height: 20, indent: 44),
              _finRow(
                icon: Icons.pie_chart_rounded,
                label: 'privilege.commission_paid'.tr(namedArgs: {'rate': _commissionRateLabel(f.commissionRate)}),
                value: '${f.totalCommissionPaid.toStringAsFixed(2)} ${f.currency}',
                color: _orange,
              ),
              if (_isTaxiProfile) ...[
                const Divider(height: 20, indent: 44),
                _finRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'privilege.subscriptions_paid'.tr(),
                  value: '${f.totalSpentSubscriptions.toStringAsFixed(2)} ${f.currency}',
                  color: const Color(0xFF3B82F6),
                ),
              ],
              const Divider(height: 20, indent: 44),
              _finRow(
                icon: Icons.local_taxi_rounded,
                label: 'privilege.total_trips'.tr(),
                value: '${f.totalTripsCompleted}',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _finRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Annual Revenue Share ───────────────────────────────────────────────────

  Widget _buildAnnualRevenueSection(PrivilegeFinancials f) {
    final annualShare = f.totalDriverEarnings * 0.03;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('3% Chiffre d\'Affaires Annuel'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF065F46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3% de votre CA annuel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Calculé sur vos courses complétées',
                          style: TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Text(
                      'Annuel',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chiffre d\'affaires',
                            style: TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${f.totalDriverEarnings.toStringAsFixed(2)} ${f.currency}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '× 3%',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Part annuelle',
                            style: TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${annualShare.toStringAsFixed(2)} ${f.currency}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFA7F3D0), size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ce montant est calculé sur votre chiffre d\'affaires annuel total et versé une fois par an.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat chips skeleton
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  height: 88,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _shimmer(borderRadius: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _skeletonBlock(height: 180),
          const SizedBox(height: 24),
          _skeletonBlock(height: 120),
          const SizedBox(height: 12),
          _skeletonBlock(height: 120),
        ],
      ),
    );
  }

  Widget _skeletonBlock({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: _shimmer(borderRadius: 18),
    );
  }

  Widget _shimmer({double borderRadius = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: const _ShimmerBox(),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'privilege.load_error'.tr(),
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: const TextStyle(color: Color(0xFF9BA3B4), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('common.retry'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _navy,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ── Shimmer animation ─────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _anim.value * 3, 0),
            end: Alignment(-0.5 + _anim.value * 3, 0),
            colors: const [
              Color(0xFFF1F5F9),
              Color(0xFFE2E8F0),
              Color(0xFFF1F5F9),
            ],
          ),
        ),
      ),
    );
  }
}

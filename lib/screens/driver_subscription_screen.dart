import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/driver_subscription_models.dart';
import '../services/subscription_service.dart';
import '../utils/app_theme.dart';

class DriverSubscriptionScreen extends StatefulWidget {
  const DriverSubscriptionScreen({super.key});

  @override
  State<DriverSubscriptionScreen> createState() => _DriverSubscriptionScreenState();
}

class _DriverSubscriptionScreenState extends State<DriverSubscriptionScreen> {
  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subService.fetchStatus());
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
          'sub.title'.tr(),
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
            onPressed: () => _subService.fetchStatus(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
        animation: _subService,
        builder: (context, _) {
          if (_subService.isLoading && _subService.status == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          final sub = _subService.subscription;
          final loyalty = _subService.loyaltyProgram;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Blocking banner for past_due
                  if (sub?.isPastDue == true) _buildPastDueBanner(),

                  // Status card
                  _buildStatusCard(sub),
                  const SizedBox(height: 20),

                  // Trial badge if trial
                  if (sub?.isTrial == true) _buildTrialBadge(sub!),

                  // Loyalty program card
                  if (loyalty != null) ...[
                    _buildLoyaltyCard(loyalty),
                    const SizedBox(height: 20),
                  ],

                  // Pricing card
                  _buildPricingCard(sub),
                  const SizedBox(height: 24),

                  // Action buttons
                  if (_subService.isLoading)
                    const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  else
                    _buildActionButtons(sub),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildPastDueBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade700, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'sub.past_due'.tr(),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'sub.past_due_desc'.tr(),
                  style: TextStyle(color: Colors.red.shade300, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(DriverSubscription? sub) {
    String title;
    String subtitle;
    Color accentColor;
    IconData icon;

    if (sub == null || sub.isCanceled) {
      title = 'sub.inactive'.tr();
      subtitle = 'sub.inactive_desc'.tr();
      accentColor = AppTheme.errorColor;
      icon = Icons.warning_amber_rounded;
    } else if (sub.isPastDue) {
      title = 'sub.past_due'.tr();
      subtitle = 'sub.expires_on'.tr(namedArgs: {'date': DateFormat('dd MMM yyyy').format(sub.expiresAt)});
      accentColor = Colors.redAccent;
      icon = Icons.credit_card_off_rounded;
    } else if (sub.isTrial) {
      title = 'sub.trial'.tr();
      subtitle = 'sub.expires_on'.tr(namedArgs: {'date': DateFormat('dd MMMM yyyy').format(sub.expiresAt)});
      accentColor = const Color(0xFF4FC3F7);
      icon = Icons.hourglass_top_rounded;
    } else {
      title = 'sub.active'.tr();
      subtitle = sub.cancelAtPeriodEnd
          ? 'sub.until_date'.tr(namedArgs: {'date': DateFormat('dd MMM yyyy').format(sub.expiresAt)})
          : 'sub.next_renewal'.tr(namedArgs: {'date': DateFormat('dd MMM yyyy').format(sub.expiresAt)});
      accentColor = AppTheme.successColor;
      icon = Icons.verified_rounded;
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBadge(DriverSubscription sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4FC3F7).withOpacity(0.15),
            const Color(0xFF0288D1).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: Color(0xFF4FC3F7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'sub.trial_days'.tr(namedArgs: {'days': sub.daysRemaining.toString()}),
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyCard(LoyaltyProgram loyalty) {
    final cashback = loyalty.cashbackAmount;
    final progress = loyalty.progressPercent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'sub.loyalty_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (loyalty.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'sub.loyalty_completed'.tr(),
                    style: const TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Cashback row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'sub.loyalty_cashback'.tr(),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              Text(
                '\$${cashback.toStringAsFixed(2)} / \$${LoyaltyProgram.targetCashback.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.07),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 8),

          // Trips count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'sub.loyalty_trips'.tr(namedArgs: {'count': loyalty.completedTripsCount.toString()}),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(DriverSubscription? sub) {
    final showTrialOffer = sub == null || sub.isCanceled;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        'sub.badge'.tr(),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (showTrialOffer)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'sub.trial_offer'.tr(),
                          style: const TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '90\$',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'sub.per_month'.tr(),
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'sub.tagline'.tr(),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 20),
                _buildCheckRow('sub.feature_commission'.tr()),
                _buildCheckRow('sub.feature_priority'.tr()),
                _buildCheckRow('sub.feature_zones'.tr()),
                _buildCheckRow('sub.feature_stats'.tr()),
                _buildCheckRow('sub.feature_support'.tr()),
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

  Widget _buildActionButtons(DriverSubscription? sub) {
    final noSub = sub == null || sub.isCanceled;
    final isPastDue = sub?.isPastDue ?? false;
    final isActive = sub?.isActive ?? false;
    final cancelRequested = sub?.cancelAtPeriodEnd ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Subscribe / Pay button (shown when no active sub or past_due)
        if (noSub || isPastDue) ...[
          ElevatedButton(
            onPressed: () => _subscribe(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 8,
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              isPastDue ? 'sub.regularize_btn'.tr() : 'sub.subscribe_btn'.tr(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],

        // Cancel renewal button (shown when active and not already requested)
        if ((isActive || sub?.isTrial == true) && !cancelRequested) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _confirmCancelRenewal(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'sub.cancel_renewal'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],

        // Cancel renewal already requested notice
        if (cancelRequested) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'sub.cancel_notice'.tr(),
                    style: TextStyle(color: Colors.orange.shade300, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Text(
          'La facturation est gérée via notre portail web sécurisé.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _subscribe(BuildContext context) async {
    final success = await _subService.subscribe();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('sub.activated_success'.tr())),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_subService.error ?? 'common.unknown_error'.tr()),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _confirmCancelRenewal(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('sub.cancel_renewal_title'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'sub.cancel_renewal_body'.tr(),
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.confirm'.tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _subService.cancelRenewal();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'sub.cancel_notice'.tr() : (_subService.error ?? 'common.unknown_error'.tr())),
        backgroundColor: success ? Colors.orange : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

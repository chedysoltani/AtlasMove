import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/driver_subscription_models.dart';
import '../services/subscription_service.dart';
import '../services/location_service.dart';

const _orange = Color(0xFFFF6B35);
const _navy = Color(0xFF1E293B);
const _surface = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF64748B);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);
const _teal = Color(0xFF009387);

class DriverSubscriptionPaymentScreen extends StatefulWidget {
  const DriverSubscriptionPaymentScreen({super.key});

  @override
  State<DriverSubscriptionPaymentScreen> createState() =>
      _DriverSubscriptionPaymentScreenState();
}

class _DriverSubscriptionPaymentScreenState
    extends State<DriverSubscriptionPaymentScreen> {
  SubscriptionPaymentInfo? _info;
  List<SubscriptionPaymentRecord> _history = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  final _hashController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final position = await LocationService().getCurrentPosition();
      final results = await Future.wait([
        SubscriptionPaymentService.fetchPaymentInfo(
          latitude: position?.latitude,
          longitude: position?.longitude,
        ),
        SubscriptionPaymentService.fetchPaymentHistory(),
      ]);
      if (mounted) {
        setState(() {
          _info = results[0] as SubscriptionPaymentInfo?;
          _history = results[1] as List<SubscriptionPaymentRecord>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _hasActivePayment =>
      _history.any((r) => r.isPaid || r.isPending);

  bool get _isFormDisabled =>
      (_info?.subscriptionActive ?? false) || _hasActivePayment;

  SubscriptionPaymentRecord? get _latestRecord =>
      _history.isNotEmpty ? _history.first : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final info = _info;
    if (info == null) return;

    setState(() => _submitting = true);
    try {
      await SubscriptionPaymentService.submitPayment(
        transactionHash: _hashController.text.trim(),
        amount: info.amount,
        currency: info.currency,
      );
      _hashController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('sub_payment.proof_submitted'.tr(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: _amber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
          'sub_payment.title'.tr(),
          style: GoogleFonts.poppins(
              color: _navy, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: _navy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _navy, size: 22),
            onPressed: _loading ? null : _load,
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
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        if (!(_info?.subscriptionActive ?? false)) ...[
                          _buildWalletCard(),
                          const SizedBox(height: 16),
                          _buildStatusBanner(),
                          if (!_isFormDisabled) ...[
                            const SizedBox(height: 16),
                            _buildHashForm(),
                          ],
                        ],
                        const SizedBox(height: 24),
                        _buildHistorySection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

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
              label: Text('common.retry'.tr(),
                  style: GoogleFonts.poppins(color: _orange, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Carte résumé ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final info = _info;
    final isActive = info?.subscriptionActive ?? false;
    final isPending = _latestRecord?.isPending ?? false;
    final amount = info?.amount ?? 90.0;
    final currency = info?.currency ?? 'USDT';

    Color gradientStart;
    Color gradientEnd;
    String statusLabel;
    IconData statusIcon;

    if (isActive) {
      gradientStart = const Color(0xFF16A34A);
      gradientEnd = _green;
      statusLabel = 'sub_payment.status_active'.tr();
      statusIcon = Icons.verified_rounded;
    } else if (isPending) {
      gradientStart = const Color(0xFFD97706);
      gradientEnd = _amber;
      statusLabel = 'sub_payment.status_pending'.tr();
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      gradientStart = _teal;
      gradientEnd = const Color(0xFF00B4A0);
      statusLabel = 'sub_payment.status_required'.tr();
      statusIcon = Icons.payment_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withOpacity(0.35),
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
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'sub_payment.subscription_label'.tr(),
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${amount.toStringAsFixed(0)} $currency / mois',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte wallet ──────────────────────────────────────────────────────────

  Widget _buildWalletCard() {
    final info = _info;
    if (info == null || info.walletAddress.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
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
                  color: _teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: _teal, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'sub_payment.wallet_address'.tr(),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15, color: _navy),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Réseau warning
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'sub_payment.network_warning'.tr(namedArgs: {'network': info.network}),
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Adresse
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    info.walletAddress,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _navy, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: info.walletAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('common.copied'.tr(),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        backgroundColor: _green,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, color: _teal, size: 14),
                        const SizedBox(width: 4),
                        Text('common.copy'.tr(),
                            style: GoogleFonts.poppins(
                                color: _teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // QR Code
          Center(
            child: Column(
              children: [
                Text('sub_payment.scan_wallet'.tr(),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: _textSecondary)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: QrImageView(
                    data: info.walletAddress,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bannière statut ────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final record = _latestRecord;
    if (record == null) return const SizedBox.shrink();

    Color bg;
    Color textColor;
    IconData icon;
    String message;

    if (record.isPaid) {
      bg = _green.withOpacity(0.08);
      textColor = _green;
      icon = Icons.check_circle_rounded;
      message = 'sub_payment.payment_validated'.tr();
    } else if (record.isPending) {
      bg = _amber.withOpacity(0.08);
      textColor = const Color(0xFF92400E);
      icon = Icons.hourglass_top_rounded;
      message = 'sub_payment.proof_pending'.tr();
    } else if (record.isRejected) {
      bg = _red.withOpacity(0.08);
      textColor = _red;
      icon = Icons.cancel_rounded;
      message = 'sub_payment.payment_rejected'.tr();
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Formulaire hash ────────────────────────────────────────────────────────

  Widget _buildHashForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Form(
        key: _formKey,
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
                  child: const Icon(Icons.receipt_long_rounded,
                      color: _orange, size: 20),
                ),
                const SizedBox(width: 10),
                Text('sub_payment.confirm_payment'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15, color: _navy)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'sub_payment.form_hint'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _hashController,
              decoration: InputDecoration(
                labelText: 'sub_payment.txid_label'.tr(),
                labelStyle:
                    GoogleFonts.poppins(fontSize: 13, color: _textSecondary),
                hintText: '0x...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: _border),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _orange, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded,
                      color: _textSecondary, size: 18),
                  tooltip: 'sub_payment.paste'.tr(),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _hashController.text = data!.text!.trim();
                    }
                  },
                ),
              ),
              style: GoogleFonts.poppins(fontSize: 12, color: _navy),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'sub_payment.hash_required'.tr();
                if (v.trim().length < 10) return 'sub_payment.hash_invalid'.tr();
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  disabledBackgroundColor: _orange.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        'sub_payment.confirm_payment'.tr(),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Historique ────────────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('sub_payment.history_title'.tr(),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16, color: _navy)),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.history_rounded, color: _border, size: 40),
                  const SizedBox(height: 10),
                  Text('sub_payment.no_payments'.tr(),
                      style:
                          GoogleFonts.poppins(color: _textSecondary, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ...(_history.map(_buildHistoryItem)),
      ],
    );
  }

  Widget _buildHistoryItem(SubscriptionPaymentRecord record) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (record.isPaid) {
      statusColor = _green;
      statusLabel = 'sub_payment.validated'.tr();
      statusIcon = Icons.check_circle_rounded;
    } else if (record.isPending) {
      statusColor = _amber;
      statusLabel = 'common.pending'.tr();
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = _red;
      statusLabel = 'common.rejected'.tr();
      statusIcon = Icons.cancel_rounded;
    }

    final dateLabel = record.createdAt != null
        ? _formatDate(record.createdAt!)
        : record.paidAt != null
            ? _formatDate(record.paidAt!)
            : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateLabel.isNotEmpty ? 'sub_payment.payment_of'.tr(namedArgs: {'date': dateLabel}) : 'sub_payment.subscription_label'.tr(),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 13, color: _navy),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 13),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: GoogleFonts.poppins(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${record.amount.toStringAsFixed(0)} ${record.currency}',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800, color: statusColor),
          ),
          if (record.transactionHash.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.tag_rounded, size: 12, color: _textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.transactionHash,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: _textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => Clipboard.setData(
                      ClipboardData(text: record.transactionHash)),
                  child: const Icon(Icons.copy_rounded,
                      size: 13, color: _textSecondary),
                ),
              ],
            ),
          ],
          if (record.paidAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'sub_payment.validated_on'.tr(namedArgs: {'date': _formatDate(record.paidAt!)}),
              style: GoogleFonts.poppins(fontSize: 10, color: _textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

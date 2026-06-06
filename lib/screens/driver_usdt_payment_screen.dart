import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/driver_subscription_models.dart';
import '../services/subscription_service.dart';

enum _PayState { loading, error, pending, detected, confirmed, underpaid, expired }

class DriverUsdtPaymentScreen extends StatefulWidget {
  const DriverUsdtPaymentScreen({super.key});

  @override
  State<DriverUsdtPaymentScreen> createState() => _DriverUsdtPaymentScreenState();
}

class _DriverUsdtPaymentScreenState extends State<DriverUsdtPaymentScreen> {
  static const _bg = Color(0xFF0F1017);
  static const _card = Color(0xFF161722);
  static const _teal = Color(0xFF009387); // USDT green
  static const _orange = Color(0xFFFF6B35);

  _PayState _state = _PayState.loading;
  CryptoSubscriptionSession? _session;
  String? _errorMsg;
  Duration _remaining = Duration.zero;

  Timer? _pollTimer;
  Timer? _countdownTimer;

  bool _addressCopied = false;
  bool _amountCopied = false;

  @override
  void initState() {
    super.initState();
    _initiate();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _initiate() async {
    setState(() {
      _state = _PayState.loading;
      _errorMsg = null;
    });
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      final session = await SubscriptionService().initiateSession();
      if (!mounted) return;
      setState(() {
        _session = session;
        _state = _PayState.pending;
        _remaining = session.expiresAt.difference(DateTime.now());
      });
      _startCountdown();
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PayState.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _session == null) return;
      final remaining = _session!.expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        if (mounted && _state == _PayState.pending) {
          setState(() => _state = _PayState.expired);
        }
      } else {
        if (mounted) setState(() => _remaining = remaining);
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_session == null || !mounted) return;
      try {
        final updated = await SubscriptionService().pollSession(_session!.sessionId);
        if (!mounted) return;
        _handleStatusUpdate(updated);
      } catch (_) {
        // polling errors are silent
      }
    });
  }

  void _handleStatusUpdate(CryptoSubscriptionSession polled) {
    // Poll response has no address — preserve it from the original session
    final session = CryptoSubscriptionSession(
      sessionId: _session!.sessionId,
      address: _session!.address,
      amount: _session!.amount,
      expiresAt: polled.expiresAt,
      status: polled.status,
    );
    setState(() => _session = session);
    switch (session.status) {
      case 'detected':
        if (_state != _PayState.detected) {
          _countdownTimer?.cancel();
          setState(() => _state = _PayState.detected);
          // keep polling until confirmed/underpaid
        }
      case 'confirmed':
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() => _state = _PayState.confirmed);
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          SubscriptionService().fetchStatus();
          Navigator.popUntil(
              context, (route) => route.settings.name == '/driver_main' || route.isFirst);
        });
      case 'underpaid':
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() => _state = _PayState.underpaid);
      case 'expired':
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        setState(() => _state = _PayState.expired);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _copyAddress() {
    if (_session == null) return;
    Clipboard.setData(ClipboardData(text: _session!.address));
    HapticFeedback.lightImpact();
    setState(() => _addressCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _addressCopied = false);
    });
  }

  void _copyAmount() {
    if (_session == null) return;
    Clipboard.setData(ClipboardData(text: _session!.amount.toStringAsFixed(2)));
    HapticFeedback.lightImpact();
    setState(() => _amountCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _amountCopied = false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payer via USDT (TRC20)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: switch (_state) {
        _PayState.loading => _buildLoading(),
        _PayState.error => _buildError(),
        _PayState.pending => _buildPending(),
        _PayState.detected => _buildDetected(),
        _PayState.confirmed => _buildConfirmed(),
        _PayState.underpaid => _buildUnderpaid(),
        _PayState.expired => _buildExpired(),
      },
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _teal, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Création de la session de paiement...',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Error (initiation failed) ─────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Impossible de créer la session',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _primaryButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              color: _teal,
              onTap: _initiate,
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending (main payment view) ───────────────────────────────────────────

  Widget _buildPending() {
    final session = _session!;
    final isAlmostExpired = _remaining.inMinutes < 5;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status chip + countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _teal.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'En attente de transfert...',
                      style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              // Countdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAlmostExpired
                      ? Colors.red.withOpacity(0.12)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAlmostExpired
                        ? Colors.red.withOpacity(0.4)
                        : Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: isAlmostExpired ? Colors.redAccent : Colors.white54,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatCountdown(_remaining),
                      style: TextStyle(
                        color: isAlmostExpired ? Colors.redAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // QR Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                // Network badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF009387), Color(0xFF00B894)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₮',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'USDT · Réseau TRON (TRC20)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: QrImageView(
                    data: 'tron:${session.address}',
                    version: QrVersions.auto,
                    size: 190,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F1017),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F1017),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scannez avec votre wallet TRON',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Address row
          _infoRow(
            label: 'Adresse de dépôt',
            value: session.address,
            copied: _addressCopied,
            onCopy: _copyAddress,
            isMonospace: true,
          ),
          const SizedBox(height: 10),

          // Amount row
          _infoRow(
            label: 'Montant exact à envoyer',
            value: '${session.amount.toStringAsFixed(2)} USDT',
            copied: _amountCopied,
            onCopy: _copyAmount,
            isMonospace: false,
            valueColor: _teal,
          ),
          const SizedBox(height: 20),

          // Warning card
          _buildWarningCard(),
          const SizedBox(height: 30),

          // ── Debug simulation panel (debug builds only) ────────────────
          if (kDebugMode) _buildDebugPanel(),
          if (kDebugMode) const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report_rounded, color: Colors.purpleAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'SIMULATION DEBUG',
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _debugBtn('detected', Colors.blue, () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                setState(() => _state = _PayState.detected);
                _startPolling();
              }),
              _debugBtn('confirmed', const Color(0xFF10B981), () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                setState(() => _state = _PayState.confirmed);
                Future.delayed(const Duration(seconds: 3), () {
                  if (!mounted) return;
                  Navigator.popUntil(context,
                      (r) => r.settings.name == '/driver_main' || r.isFirst);
                });
              }),
              _debugBtn('underpaid', Colors.orange, () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                setState(() => _state = _PayState.underpaid);
              }),
              _debugBtn('expired', Colors.red, () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                setState(() => _state = _PayState.expired);
              }),
              _debugBtn('error', Colors.redAccent, () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                setState(() {
                  _state = _PayState.error;
                  _errorMsg = 'Erreur simulée pour test';
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _debugBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    required bool copied,
    required VoidCallback onCopy,
    required bool isMonospace,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: isMonospace ? 'monospace' : null,
                    height: 1.3,
                  ),
                  maxLines: isMonospace ? 1 : 2,
                  overflow: isMonospace ? TextOverflow.ellipsis : TextOverflow.visible,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onCopy,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: copied
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: copied
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : _teal.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 12,
                        color: copied ? const Color(0xFF10B981) : _teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        copied ? 'Copié !' : 'Copier',
                        style: TextStyle(
                          color: copied ? const Color(0xFF10B981) : _teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A00),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withOpacity(0.45), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _orange, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'ATTENTION : Envoyez uniquement de l\'USDT sur le réseau TRON (TRC20). '
              'Tout envoi sur un autre réseau (ERC20, BEP20) ou d\'un autre token '
              'entraînera la perte définitive de vos fonds.',
              style: TextStyle(
                color: Color(0xFFFFAB40),
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detected ──────────────────────────────────────────────────────────────

  Widget _buildDetected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: _teal,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Paiement détecté',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Validation blockchain en cours...\nCela peut prendre quelques minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _teal.withOpacity(0.25)),
              ),
              child: const Text(
                'Ne fermez pas cette page',
                style: TextStyle(color: _teal, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirmed ─────────────────────────────────────────────────────────────

  Widget _buildConfirmed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFF10B981),
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Abonnement activé !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Votre abonnement Premium est maintenant actif.\nBonne route !',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(
              color: Color(0xFF10B981),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 12),
            const Text(
              'Redirection en cours...',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Underpaid ─────────────────────────────────────────────────────────────

  Widget _buildUnderpaid() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.orange, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Montant insuffisant reçu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Le montant envoyé est inférieur au prix de l\'abonnement '
              '(${_session?.amount.toStringAsFixed(2)} USDT requis).\n'
              'Contactez le support.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            _primaryButton(
              label: 'Contacter le support',
              icon: Icons.support_agent_rounded,
              color: Colors.orange,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expired ───────────────────────────────────────────────────────────────

  Widget _buildExpired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded, color: Colors.redAccent, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Session expirée',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'La session de paiement a expiré.\nCréez une nouvelle session pour continuer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            _primaryButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              color: _teal,
              onTap: _initiate,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared button ─────────────────────────────────────────────────────────

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}

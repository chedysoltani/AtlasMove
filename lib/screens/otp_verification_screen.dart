import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../services/auth_service.dart';
import '../models/responses/auth_response.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../core/network/http_client.dart';
import '../core/utils/permission_gate.dart';

const _orange = Color(0xFFFF6B35);
const _orangeLight = Color(0xFFFF8C42);
const _dark = Color(0xFF0F172A);
const _darkCard = Color(0xFF1A2744);
const _surface = Color(0xFFF8F9FB);
const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);
const _textSecondary = Color(0xFF9BA3B4);
const _border = Color(0xFFE2E6EF);

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String sessionToken;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.sessionToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  static const _length = 6;
  static const _codeValidity = 300; // secondes
  static const _resendCooldown = 60; // secondes

  // Un seul champ (invisible) pilote les 6 cases : avec 6 TextField séparés,
  // une saisie rapide perdait des chiffres pendant les changements de focus,
  // et retaper dans la 1re case déclenchait la logique de « collage » → code faux.
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  late String _sessionToken;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  int _validitySeconds = _codeValidity;
  int _cooldownSeconds = _resendCooldown;
  Timer? _timer;

  late final AnimationController _pulseCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _cursorCtrl;
  late final AnimationController _entryCtrl;

  String get _code => _codeCtrl.text;
  bool get _isExpired => _validitySeconds == 0;
  bool get _canResend => _cooldownSeconds == 0 && !_isLoading && !_isSuccess;

  @override
  void initState() {
    super.initState();
    _sessionToken = widget.sessionToken;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _codeFocus.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.email.isEmpty || widget.sessionToken.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('auth.missing_login_params'.tr()),
              backgroundColor: _red,
            ),
          );
          Navigator.pop(context);
        }
      });
      return;
    }

    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _cursorCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Minuteries ────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_validitySeconds > 0) _validitySeconds--;
        if (_cooldownSeconds > 0) _cooldownSeconds--;
      });
      if (_validitySeconds == 0 && _cooldownSeconds == 0) t.cancel();
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '$name***@$domain';
    return '${name[0]}${name[1]}***@$domain';
  }

  // ── Saisie ────────────────────────────────────────────────────────────────

  void _onCodeChanged(String value) {
    if (_errorMessage != null) setState(() => _errorMessage = null);
    if (value.isNotEmpty) HapticFeedback.selectionClick();
    setState(() {});
    if (value.length == _length) _verifyOtp();
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty || !mounted) return;
    final code = digits.length > _length ? digits.substring(0, _length) : digits;
    _codeCtrl.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    _onCodeChanged(code);
  }

  // ── Vérification ──────────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _code;
    if (otp.length != _length || _isLoading || _isSuccess) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final response = await AuthService.verifyOtp(
        email: widget.email,
        otp: otp,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;

      final authProvider =
          provider_pkg.Provider.of<AuthProvider>(context, listen: false);
      authProvider.setUser(response.user);
      authProvider.setToken(response.token);
      unawaited(_primeLocationPermission());

      HapticFeedback.mediumImpact();
      _timer?.cancel();
      _codeFocus.unfocus();
      setState(() { _isSuccess = true; _isLoading = false; });

      // Laisse le temps de voir l'état « vérifié » avant de changer d'écran.
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      final destination = response.user.role == UserRole.delivery
          ? '/driver_main'
          : '/client_dashboard';
      Navigator.of(context).pushNamedAndRemoveUntil(destination, (_) => false);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      _codeCtrl.clear();
      _codeFocus.requestFocus();
      setState(() { _errorMessage = _getErrorMessage(e); _isLoading = false; });
    }
  }

  static Future<void> _primeLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await PermissionGate.run(Geolocator.requestPermission,
            onTimeout: LocationPermission.denied);
      }
    } catch (_) {}
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final response = await AuthService.resendOtp(
        email: widget.email,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;

      // Le serveur peut émettre un nouveau sessionToken avec le nouveau code :
      // continuer avec l'ancien faisait échouer la vérification suivante.
      if (response.sessionToken.isNotEmpty) _sessionToken = response.sessionToken;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message.isNotEmpty
              ? response.message
              : 'auth.otp_code_resent'.tr()),
          backgroundColor: _dark,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
      _codeCtrl.clear();
      setState(() {
        _validitySeconds = _codeValidity;
        _cooldownSeconds = _resendCooldown;
        _isLoading = false;
      });
      _startTimer();
      _codeFocus.requestFocus();
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = _getErrorMessage(e); _isLoading = false; });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is ServiceValidationException) return error.toString();
    if (error is ValidationException) return error.toString();
    if (error is AuthErrorResponse) return error.message;
    if (error is NetworkException) return error.message;
    return 'auth.otp_unexpected_error'.tr();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: _buildHero(compact: keyboardOpen),
                ),
                const SizedBox(height: 18),
                Expanded(child: _buildSheet()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fond ──────────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_dark, _darkCard],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -120, right: -90,
                child: _glow(320, _orange.withOpacity(0.22))),
            Positioned(top: 140, left: -140,
                child: _glow(300, const Color(0xFF3B82F6).withOpacity(0.10))),
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );

  // ── Barre du haut ─────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _glassButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _isSuccess ? null : () => Navigator.pop(context),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, color: _orange, size: 14),
                const SizedBox(width: 6),
                Text(
                  'auth.otp_two_step'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44, height: 44,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  // ── Hero : icône + anneau de validité ─────────────────────────────────────

  Color get _stateColor {
    if (_isSuccess) return _green;
    if (_errorMessage != null) return _red;
    if (_isExpired) return _textSecondary;
    if (_validitySeconds < 60) return _red;
    return _orange;
  }

  Widget _buildHero({required bool compact}) {
    final ringSize = compact ? 92.0 : 148.0;
    final iconSize = compact ? 30.0 : 44.0;
    final color = _stateColor;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
      child: Column(
        children: [
          SizedBox(height: compact ? 4 : 16),
          SizedBox(
            width: ringSize + 40,
            height: ringSize + 40,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RadarPainter(
                  progress: _pulseCtrl.value,
                  color: color,
                  active: !_isSuccess && !_isExpired,
                ),
                child: Center(
                  child: SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: _isSuccess ? 1 : _validitySeconds / _codeValidity,
                      ),
                      duration: const Duration(milliseconds: 600),
                      builder: (_, value, child) => CustomPaint(
                        painter: _CountdownRingPainter(
                          value: value,
                          color: color,
                        ),
                        child: child,
                      ),
                      child: Center(child: _buildHeroIcon(iconSize, color)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _isSuccess ? 'auth.otp_success'.tr() : 'auth.otp_title'.tr(),
                key: ValueKey(_isSuccess),
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildTimerLabel(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroIcon(double size, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: size * 1.9,
      height: size * 1.9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isSuccess
              ? [_green, const Color(0xFF4ADE80)]
              : [_orange, _orangeLight],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          _isSuccess ? Icons.check_rounded : Icons.mark_email_read_rounded,
          key: ValueKey(_isSuccess),
          color: Colors.white,
          size: size,
        ),
      ),
    );
  }

  Widget _buildTimerLabel() {
    if (_isSuccess) {
      return Text(
        'auth.otp_redirecting'.tr(),
        style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.white.withOpacity(0.6)),
      );
    }
    if (_isExpired) {
      return Text(
        'auth.otp_code_expired'.tr(),
        style: GoogleFonts.poppins(
            fontSize: 13, color: Colors.white.withOpacity(0.6)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${'auth.otp_code_valid'.tr()} ',
          style: GoogleFonts.poppins(
              fontSize: 13, color: Colors.white.withOpacity(0.6)),
        ),
        Text(
          _formatTime(_validitySeconds),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _validitySeconds < 60 ? _red : _orangeLight,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Feuille blanche ───────────────────────────────────────────────────────

  Widget _buildSheet() {
    final slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: slide,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              22, 14, 22, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'auth.otp_enter_code'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 10),
              _buildEmailChip(),
              const SizedBox(height: 26),

              _buildCodeInput(),
              const SizedBox(height: 14),

              _buildPasteOrError(),
              const SizedBox(height: 20),

              _buildVerifyButton(),
              const SizedBox(height: 22),

              _buildResendRow(),
              const SizedBox(height: 6),
              Text(
                'auth.otp_check_spam'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 11.5, color: _textSecondary),
              ),
              const SizedBox(height: 24),
              _buildSecurityNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alternate_email_rounded,
                color: _orange, size: 13),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'auth.otp_sent_to_email'
                  .tr(namedArgs: {'email': _maskedEmail(widget.email)}),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _dark.withOpacity(0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Saisie du code ────────────────────────────────────────────────────────

  Widget _buildCodeInput() {
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (_, child) {
        final t = _shakeCtrl.value;
        final dx = _shakeCtrl.isAnimating
            ? math.sin(t * math.pi * 5) * 12 * (1 - t)
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      // Les chiffres se lisent toujours de gauche à droite, même en arabe.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < _length; i++) ...[
                      if (i == _length ~/ 2) _buildSeparator()
                      else if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _buildCell(i)),
                    ],
                  ],
                ),
              ),
              // Champ réel, invisible, posé sur les cases : il reçoit le
              // clavier, l'autoremplissage du code et le retour arrière.
              Positioned.fill(
                child: TextField(
                  controller: _codeCtrl,
                  focusNode: _codeFocus,
                  readOnly: _isLoading || _isSuccess,
                  autofocus: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: _length,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(color: Colors.transparent, fontSize: 1),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  onChanged: _onCodeChanged,
                  onSubmitted: (_) => _verifyOtp(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 10, height: 3,
        decoration: BoxDecoration(
          color: _border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    final code = _code;
    final digit = index < code.length ? code[index] : '';
    final isFilled = digit.isNotEmpty;
    final isActive = _codeFocus.hasFocus &&
        !_isSuccess &&
        (index == code.length || (code.length == _length && index == _length - 1));
    final isError = _errorMessage != null;

    Color borderColor;
    Color bgColor = Colors.white;
    double borderWidth = 1.5;
    List<BoxShadow> shadow = const [];

    if (_isSuccess) {
      borderColor = _green;
      bgColor = _green.withOpacity(0.06);
      borderWidth = 2;
    } else if (isError) {
      borderColor = _red.withOpacity(0.75);
      bgColor = _red.withOpacity(0.04);
      borderWidth = 1.8;
    } else if (isActive) {
      borderColor = _orange;
      borderWidth = 2.2;
      shadow = [
        BoxShadow(
          color: _orange.withOpacity(0.22),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isFilled) {
      borderColor = _orange.withOpacity(0.45);
      borderWidth = 1.6;
    } else {
      borderColor = _border;
    }

    final textColor = _isSuccess ? _green : isError ? _red : _dark;

    return AnimatedContainer(
      duration: Duration(milliseconds: 180 + (_isSuccess ? index * 60 : 0)),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadow,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 0.4, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              digit,
              key: ValueKey('$index-$digit'),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1,
              ),
            ),
          ),
          if (isActive && !isFilled)
            FadeTransition(
              opacity: _cursorCtrl,
              child: Container(
                width: 2, height: 24,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          if (isFilled && !isError && !_isSuccess)
            Positioned(
              bottom: 8,
              child: Container(
                width: 14, height: 3,
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasteOrError() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _errorMessage != null
          ? Container(
              key: const ValueKey('error'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _red.withOpacity(0.22)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: _red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: _red, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          : (_isSuccess || _code.length == _length)
              ? const SizedBox(key: ValueKey('none'), height: 36)
              : TextButton.icon(
                  key: const ValueKey('paste'),
                  onPressed: _isLoading ? null : _pasteCode,
                  style: TextButton.styleFrom(
                    foregroundColor: _orange,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    backgroundColor: _orange.withOpacity(0.08),
                  ),
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: Text(
                    'auth.otp_paste'.tr(),
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
    );
  }

  // ── Bouton ────────────────────────────────────────────────────────────────

  Widget _buildVerifyButton() {
    final isReady = _code.length == _length && !_isLoading && !_isSuccess;
    final colors = _isSuccess
        ? const [_green, Color(0xFF4ADE80)]
        : (isReady || _isLoading)
            ? const [_orange, _orangeLight]
            : [const Color(0xFFE5E7EB), const Color(0xFFE5E7EB)];

    Widget label;
    if (_isSuccess) {
      label = Row(
        key: const ValueKey('success'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('auth.otp_success'.tr(), style: _buttonText(Colors.white)),
        ],
      );
    } else if (_isLoading) {
      label = Row(
        key: const ValueKey('loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Text('auth.otp_verifying'.tr(), style: _buttonText(Colors.white)),
        ],
      );
    } else {
      label = Row(
        key: const ValueKey('idle'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('auth.otp_verify_btn'.tr(),
              style: _buttonText(isReady ? Colors.white : const Color(0xFF9CA3AF))),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded,
              size: 18, color: isReady ? Colors.white : const Color(0xFF9CA3AF)),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(18),
        boxShadow: (isReady || _isSuccess)
            ? [
                BoxShadow(
                  color: colors.first.withOpacity(0.38),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isReady ? _verifyOtp : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: label,
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _buttonText(Color color) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color,
      );

  // ── Renvoi & sécurité ─────────────────────────────────────────────────────

  Widget _buildResendRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${'auth.otp_not_received'.tr()} ',
          style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary),
        ),
        _canResend
            ? InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _resendOtp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'auth.otp_resend'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                      decoration: TextDecoration.underline,
                      decorationColor: _orange.withOpacity(0.4),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  _isSuccess
                      ? 'auth.otp_resend'.tr()
                      : 'auth.otp_resend_in'
                          .tr(namedArgs: {'time': _formatTime(_cooldownSeconds)}),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC4C8D2),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dark.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Icon(Icons.lock_rounded, size: 16, color: _dark.withOpacity(0.7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'auth.otp_never_share'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: _dark.withOpacity(0.6),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Peintres ────────────────────────────────────────────────────────────────

/// Anneau de validité du code : se vide au fil du temps.
class _CountdownRingPainter extends CustomPainter {
  final double value;
  final Color color;

  _CountdownRingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final track = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withOpacity(0.35), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.value != value || old.color != color;
}

/// Ondes qui se propagent autour de l'icône (effet « signal envoyé »).
class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool active;

  _RadarPainter({required this.progress, required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    final minR = maxR * 0.62;
    for (var i = 0; i < 2; i++) {
      final t = (progress + i * 0.5) % 1.0;
      final r = minR + (maxR - minR) * t;
      final paint = Paint()
        ..color = color.withOpacity(0.35 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.color != color || old.active != active;
}

/// Trame de points discrète sur le fond sombre.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.035);
    const gap = 22.0;
    for (double y = 0; y < size.height * 0.5; y += gap) {
      for (double x = 0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

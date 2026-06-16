import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../models/responses/auth_response.dart';
import '../models/user.dart';
import '../core/network/http_client.dart';

const _orange = Color(0xFFFF6B35);
const _orangeLight = Color(0xFFFF8C42);
const _dark = Color(0xFF0F172A);
const _darkCard = Color(0xFF1A2744);
const _surface = Color(0xFFF8F9FB);
const _red = Color(0xFFEF4444);

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

  final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_length, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _remainingSeconds = 300;
  bool _canResend = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

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

    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds == 0) _canResend = true;
        });
        _startCountdown();
      }
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

  String get _otpValue =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _length && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final next = (digits.length < _length ? digits.length : _length - 1);
      _focusNodes[next].requestFocus();
      if (digits.length == _length) _verifyOtp();
      return;
    }

    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    setState(() => _errorMessage = null);

    if (_otpValue.length == _length) {
      Future.delayed(const Duration(milliseconds: 100), _verifyOtp);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length != _length) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.verifyOtp(
        email: widget.email,
        otp: otp,
        sessionToken: widget.sessionToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('auth.login_success'.tr(
                namedArgs: {'name': response.user.fullName})),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        if (response.user.role == UserRole.client) {
          Navigator.pushReplacementNamed(context, '/client_dashboard');
        } else if (response.user.role == UserRole.delivery) {
          Navigator.pushReplacementNamed(context, '/driver_dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        // Shake animation + clear boxes
        _shakeCtrl.forward(from: 0);
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
        setState(() {
          _errorMessage = _getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService.resendOtp(
        email: widget.email,
        sessionToken: widget.sessionToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: _orange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );

        setState(() {
          _remainingSeconds = 300;
          _canResend = false;
          _isLoading = false;
        });
        _startCountdown();
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is ServiceValidationException) return error.toString();
    if (error is ValidationException) return error.toString();
    if (error is AuthErrorResponse) return error.message;
    if (error is NetworkException) return error.message;
    return 'Une erreur inattendue est survenue';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          // ── Hero (dark) ──────────────────────────────────────────────
          SizedBox(
            height: size.height * 0.38,
            child: _buildHero(),
          ),

          // ── Content (light) ──────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Entrez le code à 6 chiffres',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Envoyé à ${_maskedEmail(widget.email)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF9BA3B4),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── OTP Boxes ──────────────────────────────────────
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (_, child) {
                        final dx = _shakeCtrl.isAnimating
                            ? 8 * (0.5 - _shakeAnim.value).abs() * 2
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_length, (i) {
                          return _buildOtpBox(i);
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Error ──────────────────────────────────────────
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: _red.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: _red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _red,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_errorMessage != null) const SizedBox(height: 16),

                    // ── Countdown ──────────────────────────────────────
                    _buildCountdown(),
                    const SizedBox(height: 24),

                    // ── Verify button ──────────────────────────────────
                    _buildVerifyButton(),
                    const SizedBox(height: 16),

                    // ── Resend ──────────────────────────────────────────
                    _buildResendRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_dark, _darkCard],
            ),
          ),
        ),

        // Decorative rings
        Positioned(top: -40, right: -40,
            child: _ring(180, _orange.withOpacity(0.07))),
        Positioned(bottom: 10, left: -60,
            child: _ring(200, Colors.white.withOpacity(0.03))),
        Positioned(top: 50, left: 28,
            child: _dot(6, _orange.withOpacity(0.35))),
        Positioned(bottom: 50, right: 36,
            child: _dot(4, Colors.white.withOpacity(0.18))),
        Positioned(top: 25, right: 70,
            child: _dot(3, _orange.withOpacity(0.22))),

        // Back button
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ),

        // Center content
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing shield icon
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final glow = 16.0 + _pulseCtrl.value * 14;
                    final scale = 1.0 + _pulseCtrl.value * 0.04;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_orange, _orangeLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withOpacity(0.45),
                              blurRadius: glow,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 18),

                Text(
                  'auth.otp_title'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _accentLine(),
                    const SizedBox(width: 10),
                    Text(
                      'Vérification en 2 étapes',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _accentLine(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── OTP Box ────────────────────────────────────────────────────────────

  Widget _buildOtpBox(int index) {
    final isFilled = _controllers[index].text.isNotEmpty;
    final isError = _errorMessage != null;

    return Container(
      width: 44,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? _red.withOpacity(0.6)
              : isFilled
                  ? _orange
                  : const Color(0xFFE2E6EF),
          width: isFilled && !isError ? 1.8 : 1.5,
        ),
        boxShadow: isFilled && !isError
            ? [
                BoxShadow(
                  color: _orange.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) => _onKeyEvent(index, e),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: index == 0 ? _length : 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isError ? _red : _dark,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
      ),
    );
  }

  // ── Countdown ──────────────────────────────────────────────────────────

  Widget _buildCountdown() {
    final isUrgent = _remainingSeconds < 60;
    final color = _canResend
        ? const Color(0xFF9BA3B4)
        : isUrgent
            ? _red
            : _orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _canResend ? Icons.check_circle_rounded : Icons.timer_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            _canResend
                ? 'Code expiré'
                : 'Code valide encore  ${_formatTime(_remainingSeconds)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Verify button ──────────────────────────────────────────────────────

  Widget _buildVerifyButton() {
    final isReady = _otpValue.length == _length && !_isLoading;

    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReady
              ? [_orange, _orangeLight]
              : [Colors.grey.shade300, Colors.grey.shade300],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: _orange.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: TextButton(
        onPressed: isReady ? _verifyOtp : null,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(
                'auth.otp_verify_btn'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isReady ? Colors.white : Colors.grey.shade500,
                ),
              ),
      ),
    );
  }

  // ── Resend row ─────────────────────────────────────────────────────────

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Vous n\'avez pas reçu le code ?  ',
          style: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF9BA3B4)),
        ),
        GestureDetector(
          onTap: (_canResend && !_isLoading) ? _resendOtp : null,
          child: Text(
            'auth.otp_resend'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: (_canResend && !_isLoading)
                  ? _orange
                  : const Color(0xFFCBCDD4),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _ring(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1),
        ),
      );

  Widget _dot(double size, Color color) => Container(
        width: size, height: size,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _accentLine() => Container(
        width: 22, height: 2,
        decoration: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(1),
        ),
      );
}

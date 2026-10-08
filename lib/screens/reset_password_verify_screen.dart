import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import '../core/network/http_client.dart';

const _orange = Color(0xFFFF6B35);
const _orangeLight = Color(0xFFFF8C42);
const _dark = Color(0xFF0F172A);
const _darkCard = Color(0xFF1A2744);
const _surface = Color(0xFFF8F9FB);
const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);

class ResetPasswordVerifyScreen extends StatefulWidget {
  final String email;
  final String sessionToken;

  const ResetPasswordVerifyScreen({
    super.key,
    required this.email,
    required this.sessionToken,
  });

  @override
  State<ResetPasswordVerifyScreen> createState() =>
      _ResetPasswordVerifyScreenState();
}

class _ResetPasswordVerifyScreenState extends State<ResetPasswordVerifyScreen>
    with TickerProviderStateMixin {
  final _tokenCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  late final AnimationController _pulseCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _itemCtrls = List.generate(5, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      );
      Future.delayed(Duration(milliseconds: 200 + i * 90), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _pulseCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    super.dispose();
  }

  Animation<double> _fade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);

  Animation<Offset> _slide(AnimationController c) =>
      Tween(begin: const Offset(0, 0.18), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  Widget _animated(int i, Widget child) {
    if (i >= _itemCtrls.length) return child;
    return SlideTransition(
      position: _slide(_itemCtrls[i]),
      child: FadeTransition(opacity: _fade(_itemCtrls[i]), child: child),
    );
  }

  Future<void> _submit() async {
    final otpCode = _tokenCtrl.text.trim();
    if (otpCode.isEmpty || otpCode.length != 6) {
      setState(() => _errorMessage = 'reset.token_required'.tr());
      return;
    }
    if (_newPassCtrl.text.isEmpty || _confirmPassCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'reset.fill_all_fields'.tr());
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() => _errorMessage = 'auth.passwords_mismatch'.tr());
      return;
    }
    if (_isLoading) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await AuthService.verifyPasswordReset(
        email: widget.email,
        otpCode: otpCode,
        newPassword: _newPassCtrl.text,
        sessionToken: widget.sessionToken,
      );

      if (mounted) {
        setState(() { _isLoading = false; _isSuccess = true; });
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is NetworkException
              ? e.message
              : e is ServiceValidationException
                  ? e.toString()
                  : 'common.unknown_error'.tr();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          SizedBox(height: size.height * 0.35, child: _buildHero()),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: _isSuccess
                  ? _buildSuccess()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _animated(0, _buildSubHeader()),
                          const SizedBox(height: 20),
                          _animated(1, _buildInfoBanner()),
                          const SizedBox(height: 16),
                          _animated(1, _buildTokenField()),
                          const SizedBox(height: 14),
                          if (_errorMessage != null) ...[
                            _buildErrorBanner(),
                            const SizedBox(height: 14),
                          ],
                          _animated(2, _buildPasswordField(
                            controller: _newPassCtrl,
                            hint: 'reset.new_password'.tr(),
                            obscure: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                          )),
                          const SizedBox(height: 12),
                          _animated(3, _buildPasswordField(
                            controller: _confirmPassCtrl,
                            hint: 'auth.confirm_password'.tr(),
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          )),
                          const SizedBox(height: 6),
                          _animated(3, _buildPasswordHint()),
                          const SizedBox(height: 22),
                          _animated(4, _buildSubmitButton()),
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
        Positioned(top: -35, right: -35,
            child: _ring(170, _orange.withOpacity(0.07))),
        Positioned(bottom: 5, left: -55,
            child: _ring(190, Colors.white.withOpacity(0.03))),
        Positioned(top: 50, left: 28,
            child: _dot(6, _orange.withOpacity(0.35))),
        Positioned(bottom: 45, right: 36,
            child: _dot(4, Colors.white.withOpacity(0.18))),

        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) {
                          final glow = 14.0 + _pulseCtrl.value * 16;
                          final scale = 1.0 + _pulseCtrl.value * 0.04;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 74, height: 74,
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
                              child: const Icon(Icons.key_rounded,
                                  color: Colors.white, size: 34),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'reset.new_password'.tr(),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _accentLine(),
                          const SizedBox(width: 10),
                          Text(
                            'reset.token_subtitle'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 0.8,
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
          ),
        ),
      ],
    );
  }

  Widget _buildSubHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'reset.submit'.tr(),
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w800, color: _dark),
        ),
        const SizedBox(height: 4),
        Text(
          'reset.verify_subtitle'.tr(namedArgs: {'email': widget.email}),
          style: GoogleFonts.poppins(
              fontSize: 12, color: const Color(0xFF9BA3B4)),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _orange.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'reset.token_info'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _orange, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: _tokenCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w700, color: _dark,
            letterSpacing: 8),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'reset.token_hint'.tr(),
          hintStyle: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFFCDD3E0), letterSpacing: 0),
          counterText: '',
          prefixIcon: const Icon(Icons.pin_outlined,
              color: Color(0xFF9BA3B4), size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E6EF), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (_) => setState(() => _errorMessage = null),
      ),
    );
  }

  // ── Error ───────────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _red, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Password field ──────────────────────────────────────────────────────

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
              fontSize: 14, color: const Color(0xFFCDD3E0)),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: Color(0xFF9BA3B4), size: 20),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF9BA3B4),
                size: 20,
              ),
            ),
          ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E6EF), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordHint() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 13, color: Color(0xFF9BA3B4)),
          const SizedBox(width: 5),
          Text(
            'auth.password_min8'.tr(),
            style: GoogleFonts.poppins(
                fontSize: 11, color: const Color(0xFF9BA3B4)),
          ),
        ],
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_orange, _orangeLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextButton(
        onPressed: _isLoading ? null : _submit,
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
                'reset.submit'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
      ),
    );
  }

  // ── Success state ────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withOpacity(0.1),
              border: Border.all(color: _green.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: _green, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'reset.success_title'.tr(),
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 8),
          Text(
            'reset.success_subtitle'.tr(),
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF9BA3B4),
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
                color: _orange, strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _ring(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1),
        ),
      );

  Widget _dot(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _accentLine() => Container(
        width: 20, height: 2,
        decoration: BoxDecoration(
          color: _orange, borderRadius: BorderRadius.circular(1)),
      );
}

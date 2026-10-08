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

class ResetPasswordRequestScreen extends StatefulWidget {
  const ResetPasswordRequestScreen({super.key});

  @override
  State<ResetPasswordRequestScreen> createState() =>
      _ResetPasswordRequestScreenState();
}

class _ResetPasswordRequestScreenState
    extends State<ResetPasswordRequestScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _heroCtrl;
  late final AnimationController _pulseCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _itemCtrls = List.generate(4, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      );
      Future.delayed(Duration(milliseconds: 250 + i * 100), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _heroCtrl.dispose();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final sessionToken = await AuthService.requestPasswordReset(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamed(
          context,
          '/reset_password_verify',
          arguments: {
            'email': _emailCtrl.text.trim(),
            'sessionToken': sessionToken,
          },
        );
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
          SizedBox(height: size.height * 0.38, child: _buildHero()),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _animated(0, _buildHeader()),
                      const SizedBox(height: 24),
                      _animated(1, _buildEmailField()),
                      const SizedBox(height: 16),
                      if (_errorMessage != null)
                        _animated(1, _buildError()),
                      if (_errorMessage != null) const SizedBox(height: 12),
                      _animated(2, _buildSubmitButton()),
                      const SizedBox(height: 20),
                      _animated(3, _buildBackRow()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fade(_heroCtrl),
      child: Stack(
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
          Positioned(top: -40, right: -40,
              child: _ring(180, _orange.withOpacity(0.07))),
          Positioned(bottom: 10, left: -60,
              child: _ring(200, Colors.white.withOpacity(0.03))),
          Positioned(top: 55, left: 30,
              child: _dot(6, _orange.withOpacity(0.35))),
          Positioned(bottom: 55, right: 38,
              child: _dot(4, Colors.white.withOpacity(0.18))),
          Positioned(top: 28, right: 75,
              child: _dot(3, _orange.withOpacity(0.22))),

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
                            final scale = 1.0 + _pulseCtrl.value * 0.05;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 78, height: 78,
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
                                child: const Icon(Icons.lock_reset_rounded,
                                    color: Colors.white, size: 36),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'reset.title'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 24,
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
                              'reset.secure_reset'.tr(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                                letterSpacing: 1.1,
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
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'reset.enter_email'.tr(),
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
        ),
        const SizedBox(height: 6),
        Text(
          'reset.enter_email_subtitle'.tr(),
          style: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF9BA3B4), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
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
      child: TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
        decoration: InputDecoration(
          hintText: 'auth.email_hint'.tr(),
          hintStyle: GoogleFonts.poppins(
              fontSize: 14, color: const Color(0xFFCDD3E0)),
          prefixIcon: const Icon(Icons.mail_outline_rounded,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _red, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'auth.email_required'.tr();
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
            return 'auth.email_invalid'.tr();
          }
          return null;
        },
      ),
    );
  }

  Widget _buildError() {
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
              style: GoogleFonts.poppins(fontSize: 12, color: _red, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(
                'reset.send_link'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildBackRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('reset.remember_password'.tr() + '  ',
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xFF9BA3B4))),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('auth.login_btn'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _orange)),
        ),
      ],
    );
  }

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
        width: 22, height: 2,
        decoration: BoxDecoration(
          color: _orange, borderRadius: BorderRadius.circular(1)),
      );
}

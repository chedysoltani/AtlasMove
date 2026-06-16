import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../models/responses/auth_response.dart';
import '../core/network/http_client.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);

  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _selectedRole = UserRole.client;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _heroCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _itemCtrls = List.generate(6, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      );
      Future.delayed(Duration(milliseconds: 280 + i * 100), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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

  // ── Business logic (unchanged) ────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await AuthService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (response.requiresOtp) {
        if (mounted) {
          Navigator.pushNamed(context, '/otp_verification', arguments: {
            'email': _emailCtrl.text.trim(),
            'sessionToken': response.sessionToken ?? response.token,
          });
        }
      } else if (response.isComplete) {
        if (mounted) {
          final authProvider =
              provider_pkg.Provider.of<AuthProvider>(context, listen: false);
          authProvider.setUser(response.user);
          authProvider.setToken(response.token);
          await _saveTokenToPreferences(response.token);

          if (response.user.role == UserRole.client) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/client_dashboard', (_) => false);
          } else if (response.user.role == UserRole.delivery) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/driver_main', (_) => false);
          }
        }
      } else {
        throw Exception('Réponse de connexion invalide');
      }
    } catch (e) {
      String msg = 'Erreur de connexion';
      if (e is ServiceValidationException) {
        msg = e.toString();
      } else if (e is ValidationException) {
        msg = e.toString();
      } else if (e is AuthErrorResponse) {
        msg = e.message;
      } else if (e is NetworkException) {
        msg = e.message;
      } else {
        msg = 'Erreur de connexion: $e';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTokenToPreferences(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          // ── Dark hero header ──────────────────────────────────────────
          SizedBox(
            height: size.height * 0.32,
            child: _buildHero(),
          ),

          // ── White form card ───────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _animated(0, _buildRoleSelector()),
                      const SizedBox(height: 20),
                      _animated(1, _buildEmailField()),
                      const SizedBox(height: 12),
                      _animated(2, _buildPasswordField()),
                      const SizedBox(height: 10),
                      _animated(2, _buildForgotPassword()),
                      const SizedBox(height: 18),
                      _animated(3, _buildLoginButton()),
                      const SizedBox(height: 16),
                      _animated(4, _buildSignupRow()),
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

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fade(_heroCtrl),
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/image4.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // Dark overlay for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F172A).withOpacity(0.55),
                    const Color(0xFF0F172A).withOpacity(0.70),
                  ],
                ),
              ),
            ),
          ),

          // Bottom fade to blend with white card
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0F172A).withOpacity(0.70),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),

                  const Spacer(),

                  // Brand badge
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_orange, _orangeLight]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text('AtlasMove', style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      )),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text('auth.welcome'.tr(), style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  )),
                  const SizedBox(height: 5),
                  Text('auth.login_subtitle'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Role Selector ─────────────────────────────────────────────────────────

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('auth.i_am_a'.tr(), style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F7)),
          _roleTile(
            role: UserRole.client,
            icon: Icons.person_rounded,
            title: 'auth.client'.tr(),
            subtitle: 'auth.client_desc'.tr(),
            isFirst: true,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16,
              color: Color(0xFFF1F3F7)),
          _roleTile(
            role: UserRole.delivery,
            icon: Icons.local_shipping_rounded,
            title: 'auth.driver'.tr(),
            subtitle: 'auth.driver_desc'.tr(),
            isFirst: false,
          ),
        ],
      ),
    );
  }

  Widget _roleTile({
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isFirst,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            bottom: isFirst ? Radius.zero : const Radius.circular(18),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? _orange.withOpacity(0.12)
                    : const Color(0xFFF1F3F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                color: isSelected ? _orange : const Color(0xFF9BA3B4),
                size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isSelected ? _orange : _dark)),
                  Text(subtitle, style: GoogleFonts.poppins(
                    fontSize: 11, color: const Color(0xFF9BA3B4))),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _orange : const Color(0xFFCDD3E0),
                  width: 2,
                ),
                color: isSelected ? _orange.withOpacity(0.15) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _orange)))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Fields ────────────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    return _formField(
      controller: _emailCtrl,
      hint: 'auth.email_hint'.tr(),
      icon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      action: TextInputAction.next,
      validator: (v) {
        if (v == null || v.isEmpty) return 'auth.email_required'.tr();
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
          return 'auth.email_invalid'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _formField(
      controller: _passwordCtrl,
      hint: 'auth.password_hint'.tr(),
      icon: Icons.lock_outline_rounded,
      obscureText: _obscurePassword,
      action: TextInputAction.done,
      onSubmitted: (_) => _handleLogin(),
      suffix: GestureDetector(
        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
        child: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF9BA3B4), size: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'auth.password_required'.tr();
        if (v.length < 6) return 'auth.password_min6'.tr();
        return null;
      },
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    bool obscureText = false,
    Widget? suffix,
    Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: action,
        obscureText: obscureText,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14, color: const Color(0xFFCDD3E0)),
          prefixIcon: Icon(icon, color: const Color(0xFF9BA3B4), size: 20),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12), child: suffix)
              : null,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ── Forgot password ───────────────────────────────────────────────────────

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/reset_password_request'),
        child: Text(
          'Mot de passe oublié ?',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _orange,
          ),
        ),
      ),
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildLoginButton() {
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
            blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: TextButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text('auth.login_btn'.tr(), style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildSignupRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('auth.no_account'.tr(), style: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF9BA3B4))),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/signup'),
              child: Text('auth.register_btn'.tr(), style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: _orange)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Livreur / Chauffeur ?', style: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF9BA3B4))),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/driver_register'),
              child: Text('Inscription livreur', style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: _orange)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Decorative helpers ────────────────────────────────────────────────────

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
}

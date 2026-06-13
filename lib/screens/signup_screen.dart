import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../models/requests/register_request.dart';
import '../models/responses/auth_response.dart';
import '../core/network/http_client.dart';
import '../utils/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late final AnimationController _heroCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _itemCtrls = List.generate(8, (i) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 420));
      Future.delayed(Duration(milliseconds: 280 + i * 90),
          () { if (mounted) c.forward(); });
      return c;
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);
  Animation<Offset> _slide(AnimationController c) =>
      Tween(begin: const Offset(0, 0.16), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
  Widget _a(int i, Widget child) => i < _itemCtrls.length
      ? SlideTransition(
          position: _slide(_itemCtrls[i]),
          child: FadeTransition(opacity: _fade(_itemCtrls[i]), child: child))
      : child;

  // ── Business logic ────────────────────────────────────────────────────────

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final refCode = _referralCtrl.text.trim().toUpperCase();
      final request = ClientRegisterRequest(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
        referralCode: refCode.isNotEmpty ? refCode : null,
      );
      final response = await AuthService.registerClient(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('auth.welcome_user'.tr(namedArgs: {'name': response.user.fullName})),
          backgroundColor: AppTheme.successColor,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      String msg = 'Erreur d\'inscription';
      if (e is ServiceValidationException) msg = e.toString();
      else if (e is ValidationException) msg = e.toString();
      else if (e is AuthErrorResponse) msg = e.message;
      else if (e is NetworkException) msg = e.message;
      else msg = 'Erreur: $e';
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          SizedBox(height: size.height * 0.28, child: _buildHero()),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      _a(0, Row(children: [
                        Expanded(child: _field(
                          ctrl: _firstNameCtrl, hint: 'auth.first_name'.tr(),
                          icon: Icons.person_rounded,
                          action: TextInputAction.next,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'auth.field_required'.tr() : null,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _field(
                          ctrl: _lastNameCtrl, hint: 'auth.last_name'.tr(),
                          icon: Icons.person_outline_rounded,
                          action: TextInputAction.next,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'auth.field_required'.tr() : null,
                        )),
                      ])),
                      const SizedBox(height: 11),
                      _a(1, _field(
                        ctrl: _emailCtrl, hint: 'auth.email_hint'.tr(),
                        icon: Icons.mail_outline_rounded,
                        keyboard: TextInputType.emailAddress,
                        action: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'auth.field_required'.tr();
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v)) return 'auth.email_invalid'.tr();
                          return null;
                        },
                      )),
                      const SizedBox(height: 11),
                      _a(2, _field(
                        ctrl: _phoneCtrl, hint: 'auth.phone'.tr(),
                        icon: Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        action: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'auth.field_required'.tr() : null,
                      )),
                      const SizedBox(height: 11),
                      _a(3, _field(
                        ctrl: _passwordCtrl, hint: 'auth.password_hint'.tr(),
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        action: TextInputAction.next,
                        suffix: _eyeIcon(_obscurePassword,
                            () => setState(() => _obscurePassword = !_obscurePassword)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'auth.field_required'.tr();
                          if (v.length < 8) return 'auth.password_min8'.tr();
                          return null;
                        },
                      )),
                      const SizedBox(height: 11),
                      _a(4, _field(
                        ctrl: _confirmPasswordCtrl,
                        hint: 'auth.confirm_password'.tr(),
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscureConfirm,
                        action: TextInputAction.next,
                        suffix: _eyeIcon(_obscureConfirm,
                            () => setState(() => _obscureConfirm = !_obscureConfirm)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'auth.field_required'.tr();
                          if (v != _passwordCtrl.text)
                            return 'auth.passwords_mismatch'.tr();
                          return null;
                        },
                      )),
                      const SizedBox(height: 11),
                      _a(5, _field(
                        ctrl: _referralCtrl,
                        hint: 'auth.referral_code_hint'.tr(),
                        icon: Icons.card_giftcard_rounded,
                        action: TextInputAction.done,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!RegExp(r'^ATLAS-[A-Z0-9]{6}$')
                                .hasMatch(v.trim().toUpperCase()))
                              return 'auth.referral_format_error'.tr();
                          }
                          return null;
                        },
                      )),
                      const SizedBox(height: 26),
                      _a(6, _buildSignupButton()),
                      const SizedBox(height: 16),
                      _a(7, _buildLoginRow()),
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
      child: Stack(children: [
        // Image de fond
        Positioned.fill(
          child: Image.asset(
            'assets/images/image3.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        // Voile sombre général
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.55),
            ),
          ),
        ),
        // Dégradé bas pour transition douce vers le formulaire
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0F172A).withOpacity(0.75),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Bouton retour à gauche
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const Spacer(),
                // Contenu centré
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_orange, _orangeLight]),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(height: 6),
                      Text('AtlasMove', style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9))),
                      const SizedBox(height: 6),
                      Text('auth.register_title'.tr(), style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1.1)),
                      const SizedBox(height: 3),
                      Text('auth.signup_subtitle'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        textInputAction: action,
        obscureText: obscure,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: _dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFCDD3E0)),
          prefixIcon: Icon(icon, color: const Color(0xFF9BA3B4), size: 19),
          suffixIcon: suffix != null
              ? Padding(padding: const EdgeInsets.only(right: 10), child: suffix)
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E6EF))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _orange, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444))),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _eyeIcon(bool obscure, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Icon(
      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: const Color(0xFF9BA3B4), size: 19),
  );

  Widget _buildSignupButton() {
    return Container(
      width: double.infinity, height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_orange, _orangeLight]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _orange.withOpacity(0.32),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: TextButton(
        onPressed: _isLoading ? null : _handleSignup,
        style: TextButton.styleFrom(shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16))),
        child: _isLoading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Text('auth.register_btn'.tr(), style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildLoginRow() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('auth.have_account'.tr(), style: GoogleFonts.poppins(
          fontSize: 13, color: const Color(0xFF9BA3B4))),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Text('auth.login_btn'.tr(), style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: _orange)),
      ),
    ],
  );

  Widget _ring(double s, Color c) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: c, width: 1)));
  Widget _dot(double s, Color c) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

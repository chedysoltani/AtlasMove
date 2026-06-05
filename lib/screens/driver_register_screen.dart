import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/requests/driver_register_request.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen>
    with TickerProviderStateMixin {
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);
  static const _green = Color(0xFF22C55E);

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _vehicleTypeCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  File? _idCard;
  File? _drivingLicense;
  File? _vehicleRegistration;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _imagePicker = ImagePicker();

  late final AnimationController _heroCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _itemCtrls = List.generate(10, (i) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 420));
      Future.delayed(Duration(milliseconds: 280 + i * 80),
          () { if (mounted) c.forward(); });
      return c;
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passwordCtrl.dispose(); _confirmPasswordCtrl.dispose();
    _vehicleTypeCtrl.dispose(); _referralCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);
  Animation<Offset> _slide(AnimationController c) =>
      Tween(begin: const Offset(0, 0.16), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));
  Widget _a(int i, Widget child) => i < _itemCtrls.length
      ? SlideTransition(position: _slide(_itemCtrls[i]),
          child: FadeTransition(opacity: _fade(_itemCtrls[i]), child: child))
      : child;

  // ── Image pickers ─────────────────────────────────────────────────────────

  Future<void> _pick(Function(File) onPicked) async {
    try {
      final img = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (img != null) { setState(() { onPicked(File(img.path)); }); }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur sélection image: $e');
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────

  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idCard == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner votre carte d\'identité');
      return;
    }
    if (_drivingLicense == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner votre permis de conduire');
      return;
    }
    if (_vehicleRegistration == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner votre carte grise');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final refCode = _referralCtrl.text.trim().toUpperCase();
      final request = DriverRegisterRequest(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
        vehicleType: _vehicleTypeCtrl.text.trim(),
        idCard: _idCard,
        drivingLicense: _drivingLicense,
        vehicleRegistration: _vehicleRegistration,
        referralCode: refCode.isNotEmpty ? refCode : null,
      );
      final response = await AuthService.registerDriver(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.message),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 5),
        ));
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
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
                      // Error banner
                      if (_errorMessage != null) ...[
                        _a(0, _errorBanner()),
                        const SizedBox(height: 14),
                      ],

                      // ── Infos personnelles ─────────────────────────
                      _a(0, _sectionLabel('Informations personnelles',
                          Icons.person_rounded)),
                      const SizedBox(height: 12),
                      _a(1, Row(children: [
                        Expanded(child: _field(ctrl: _firstNameCtrl,
                            hint: 'Prénom', icon: Icons.person_rounded,
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? 'Min 2 caractères' : null)),
                        const SizedBox(width: 10),
                        Expanded(child: _field(ctrl: _lastNameCtrl,
                            hint: 'Nom', icon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? 'Min 2 caractères' : null)),
                      ])),
                      const SizedBox(height: 11),
                      _a(2, _field(ctrl: _emailCtrl, hint: 'Adresse email',
                          icon: Icons.mail_outline_rounded,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatoire';
                            if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(v)) return 'Email invalide';
                            return null;
                          })),
                      const SizedBox(height: 11),
                      _a(3, _field(ctrl: _phoneCtrl, hint: 'Téléphone (+216...)',
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatoire';
                            if (!RegExp(r'^\+[0-9]{10,15}$').hasMatch(v))
                              return 'Format: +21698765432';
                            return null;
                          })),

                      const SizedBox(height: 20),

                      // ── Mot de passe ───────────────────────────────
                      _a(4, _sectionLabel('Mot de passe', Icons.lock_rounded)),
                      const SizedBox(height: 12),
                      _a(4, _field(ctrl: _passwordCtrl, hint: 'Mot de passe',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          suffix: _eyeIcon(_obscurePassword,
                              () => setState(() => _obscurePassword = !_obscurePassword)),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatoire';
                            if (v.length < 8) return 'Min 8 caractères';
                            if (!RegExp(r'(?=.*[a-z])').hasMatch(v))
                              return 'Doit contenir une minuscule';
                            if (!RegExp(r'(?=.*[A-Z])').hasMatch(v))
                              return 'Doit contenir une majuscule';
                            if (!RegExp(r'(?=.*\d)').hasMatch(v))
                              return 'Doit contenir un chiffre';
                            if (!RegExp(r'(?=.*[@$!%*?&])').hasMatch(v))
                              return 'Doit contenir un caractère spécial';
                            return null;
                          })),
                      const SizedBox(height: 11),
                      _a(5, _field(ctrl: _confirmPasswordCtrl,
                          hint: 'Confirmer le mot de passe',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscureConfirm,
                          suffix: _eyeIcon(_obscureConfirm,
                              () => setState(() => _obscureConfirm = !_obscureConfirm)),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatoire';
                            if (v != _passwordCtrl.text)
                              return 'Mots de passe différents';
                            return null;
                          })),
                      const SizedBox(height: 11),
                      _a(5, _field(ctrl: _vehicleTypeCtrl,
                          hint: 'Type de véhicule',
                          icon: Icons.directions_car_rounded,
                          action: TextInputAction.done,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Obligatoire';
                            final valid = ['voiture', 'moto', 'camion', 'fourgonnette'];
                            if (!valid.contains(v.toLowerCase()))
                              return 'voiture, moto, camion ou fourgonnette';
                            return null;
                          })),

                      const SizedBox(height: 20),

                      // ── Documents ──────────────────────────────────
                      _a(6, _sectionLabel('Documents requis',
                          Icons.folder_rounded)),
                      const SizedBox(height: 12),
                      _a(6, _docCard(
                        icon: Icons.credit_card_rounded,
                        title: 'Carte d\'identité',
                        file: _idCard,
                        onTap: () => _pick((f) => _idCard = f),
                      )),
                      const SizedBox(height: 10),
                      _a(7, _docCard(
                        icon: Icons.badge_rounded,
                        title: 'Permis de conduire',
                        file: _drivingLicense,
                        onTap: () => _pick((f) => _drivingLicense = f),
                      )),
                      const SizedBox(height: 10),
                      _a(7, _docCard(
                        icon: Icons.description_rounded,
                        title: 'Carte grise',
                        file: _vehicleRegistration,
                        onTap: () => _pick((f) => _vehicleRegistration = f),
                      )),

                      const SizedBox(height: 20),

                      // ── Parrainage ─────────────────────────────────
                      _a(8, _sectionLabel('Parrainage (facultatif)',
                          Icons.card_giftcard_rounded)),
                      const SizedBox(height: 12),
                      _a(8, _field(ctrl: _referralCtrl,
                          hint: 'Code de parrainage — ATLAS-XXXXXX',
                          icon: Icons.card_giftcard_rounded,
                          action: TextInputAction.done,
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              if (!RegExp(r'^ATLAS-[A-Z0-9]{6}$')
                                  .hasMatch(v.trim().toUpperCase()))
                                return 'Format invalide. Ex: ATLAS-J8K9F2';
                            }
                            return null;
                          })),

                      const SizedBox(height: 28),
                      _a(9, _buildRegisterButton()),
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
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1A2744)],
            ),
          ),
        ),
        Positioned(top: -40, right: -40,
            child: _ring(170, _orange.withOpacity(0.07))),
        Positioned(bottom: 0, left: -50,
            child: _ring(150, Colors.white.withOpacity(0.03))),
        Positioned(top: 55, left: 28,
            child: _dot(6, _orange.withOpacity(0.35))),
        Positioned(bottom: 35, right: 35,
            child: _dot(4, Colors.white.withOpacity(0.18))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_orange, _orangeLight]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('AtlasMove', style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9))),
                ]),
                const SizedBox(height: 10),
                Text('Inscription Livreur', style: GoogleFonts.poppins(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1.1)),
                const SizedBox(height: 4),
                Text('Rejoignez notre réseau de livreurs',
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: _orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _orange, size: 16),
      ),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.poppins(
        fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
    ]);
  }

  Widget _docCard({
    required IconData icon,
    required String title,
    required File? file,
    required VoidCallback onTap,
  }) {
    final uploaded = file != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: uploaded ? _green.withOpacity(0.4) : const Color(0xFFE2E6EF),
            width: uploaded ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: uploaded
                  ? _green.withOpacity(0.08)
                  : _orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(uploaded ? Icons.check_circle_rounded : icon,
                color: uploaded ? _green : _orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: uploaded ? _green : _dark)),
              Text(uploaded ? 'Document ajouté ✓' : 'Appuyer pour sélectionner',
                style: GoogleFonts.poppins(fontSize: 11,
                    color: uploaded
                        ? _green.withOpacity(0.7)
                        : const Color(0xFF9BA3B4))),
            ],
          )),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: uploaded
                  ? _green.withOpacity(0.08)
                  : _orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              uploaded ? Icons.edit_rounded : Icons.upload_rounded,
              color: uploaded ? _green : _orange, size: 15),
          ),
        ]),
      ),
    );
  }

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: Color(0xFFEF4444), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(_errorMessage!, style: GoogleFonts.poppins(
          fontSize: 12, color: const Color(0xFFEF4444)))),
    ]),
  );

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
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500,
            color: _dark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13,
              color: const Color(0xFFCDD3E0)),
          prefixIcon: Icon(icon, color: const Color(0xFF9BA3B4), size: 19),
          suffixIcon: suffix != null
              ? Padding(padding: const EdgeInsets.only(right: 10), child: suffix)
              : null,
          suffixIconConstraints: const BoxConstraints(
              minWidth: 38, minHeight: 38),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
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
              borderSide: const BorderSide(
                  color: Color(0xFFEF4444), width: 1.5)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
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

  Widget _buildRegisterButton() => Container(
    width: double.infinity, height: 52,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_orange, _orangeLight]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: _orange.withOpacity(0.32),
          blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: TextButton(
      onPressed: _isLoading ? null : _registerDriver,
      style: TextButton.styleFrom(shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16))),
      child: _isLoading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white)))
          : Text('S\'inscrire comme Livreur', style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: Colors.white)),
    ),
  );

  Widget _ring(double s, Color c) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: c, width: 1)));
  Widget _dot(double s, Color c) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

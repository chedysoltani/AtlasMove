import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/requests/driver_register_request.dart';
import '../models/service_models.dart';
import '../services/auth_service.dart';
import '../services/service_api.dart';
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
  final _cinCtrl = TextEditingController();
  final _drivingLicenseNumberCtrl = TextEditingController();
  final _vehiclePlateCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  File? _idCard;
  File? _drivingLicense;
  File? _vehicleRegistration;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Sélecteur de type de véhicule via services
  List<ServiceCategory> _serviceCategories = [];
  ServiceCategory? _selectedCategory;
  bool _loadingCategories = false;

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
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      // Tente sans token (inscription = pas encore connecté)
      final cats = await ServiceApi.getCategories(token: '');
      if (mounted) setState(() => _serviceCategories = cats);
    } catch (_) {
      // Fallback liste statique
      if (mounted) {
        setState(() => _serviceCategories = _fallbackCategories());
      }
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  List<ServiceCategory> _fallbackCategories() {
    final data = [
      {'id': 'taxi',      'name': 'Taxi Standard',    'transport_type': 'taxi'},
      {'id': 'vtc',       'name': 'VTC / Chauffeur',  'transport_type': 'vtc'},
      {'id': 'moto',      'name': 'Moto-taxi',        'transport_type': 'moto'},
      {'id': 'livraison', 'name': 'Livraison Moto',   'transport_type': 'livraison'},
      {'id': 'van',       'name': 'Van / Camionnette','transport_type': 'van'},
      {'id': 'camion',    'name': 'Camion / Poids lourd','transport_type': 'camion'},
    ];
    return data.map((d) => ServiceCategory(
      id: d['id']!,
      name: d['name']!,
      transportType: d['transport_type']!,
      status: 'active',
      isActive: true,
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )).toList();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passwordCtrl.dispose(); _confirmPasswordCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    _cinCtrl.dispose(); _drivingLicenseNumberCtrl.dispose();
    _vehiclePlateCtrl.dispose(); _referralCtrl.dispose();
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

  Future<void> _fillTestImages() async {
    try {
      final byteData = await rootBundle.load('assets/images/image1.png');
      final bytes = byteData.buffer.asUint8List();
      final tmpDir = Directory.systemTemp;
      final idFile    = File('${tmpDir.path}/test_id_card.png');
      final licFile   = File('${tmpDir.path}/test_driving_license.png');
      final regFile   = File('${tmpDir.path}/test_vehicle_registration.png');
      await idFile.writeAsBytes(bytes);
      await licFile.writeAsBytes(bytes);
      await regFile.writeAsBytes(bytes);
      setState(() {
        _idCard = idFile;
        _drivingLicense = licFile;
        _vehicleRegistration = regFile;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Erreur images test: $e');
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
        cinNumber: _cinCtrl.text.trim(),
        drivingLicenseNumber: _drivingLicenseNumberCtrl.text.trim(),
        vehiclePlateNumber: _vehiclePlateCtrl.text.trim(),
        idCard: _idCard,
        drivingLicense: _drivingLicense,
        vehicleRegistration: _vehicleRegistration,
        referralCode: refCode.isNotEmpty ? refCode : null,
      );
      await AuthService.registerDriver(request);
      if (mounted) {
        await _showPendingApprovalDialog(context);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPendingApprovalDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    color: Color(0xFFF59E0B), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Inscription réussie !',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1F36)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'Votre compte a été créé avec succès.\n\n'
                'L\'administrateur doit approuver votre compte '
                'avant que vous puissiez vous connecter et utiliser '
                'l\'application.\n\n'
                'Vous serez notifié dès l\'activation de votre compte.',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Compris, aller à la connexion',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      _a(5, _vehicleSelector()),

                      const SizedBox(height: 20),

                      // ── Informations véhicule ──────────────────────
                      _a(5, _sectionLabel('Informations véhicule',
                          Icons.directions_car_rounded)),
                      const SizedBox(height: 12),
                      _a(5, _field(
                        ctrl: _cinCtrl,
                        hint: 'Numéro CIN (8 chiffres)',
                        icon: Icons.credit_card_rounded,
                        keyboard: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obligatoire';
                          if (!RegExp(r'^\d{8}$').hasMatch(v.trim()))
                            return 'Exactement 8 chiffres';
                          return null;
                        },
                      )),
                      const SizedBox(height: 11),
                      _a(5, _field(
                        ctrl: _drivingLicenseNumberCtrl,
                        hint: 'Numéro de permis de conduire',
                        icon: Icons.badge_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoire' : null,
                      )),
                      const SizedBox(height: 11),
                      _a(5, _field(
                        ctrl: _vehiclePlateCtrl,
                        hint: 'Immatriculation du véhicule',
                        icon: Icons.local_shipping_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatoire' : null,
                      )),

                      const SizedBox(height: 20),

                      // ── Documents ──────────────────────────────────
                      _a(6, _sectionLabel('Documents requis',
                          Icons.folder_rounded)),
                      const SizedBox(height: 12),
                      if (kDebugMode) ...[
                        _a(6, _devFillButton()),
                        const SizedBox(height: 10),
                      ],
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

  // ── Vehicle selector ─────────────────────────────────────────────────────

  Widget _vehicleSelector() {
    final hasValue = _selectedCategory != null;
    return GestureDetector(
      onTap: _showVehiclePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasValue ? _orange.withOpacity(0.4) : const Color(0xFFE2E6EF),
            width: hasValue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              hasValue ? _iconForType(_selectedCategory!.transportType) : Icons.directions_car_rounded,
              color: hasValue ? _orange : const Color(0xFF9BA3B4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue ? _selectedCategory!.name : 'Type de véhicule / Service',
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue ? _dark : const Color(0xFF9BA3B4),
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (_loadingCategories)
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _orange))
            else
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: hasValue ? _orange : const Color(0xFF9BA3B4), size: 20),
          ],
        ),
      ),
    );
  }

  void _showVehiclePicker() {
    if (_loadingCategories) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehiclePickerSheet(
        categories: _serviceCategories,
        selected: _selectedCategory,
        onSelect: (cat) {
          setState(() {
            _selectedCategory = cat;
            _vehicleTypeCtrl.text = cat.transportType;
          });
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'taxi': return Icons.local_taxi_rounded;
      case 'vtc': return Icons.directions_car_rounded;
      case 'moto': return Icons.motorcycle_rounded;
      case 'livraison': return Icons.delivery_dining_rounded;
      case 'van': return Icons.airport_shuttle_rounded;
      case 'camion': return Icons.local_shipping_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      default: return Icons.work_outline_rounded;
    }
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fade(_heroCtrl),
      child: Stack(children: [
        // Image de fond
        Positioned.fill(
          child: Image.asset(
            'assets/images/image2.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
        ),
        // Dégradé sombre sur la gauche pour lisibilité du texte
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF0F172A).withOpacity(0.92),
                  const Color(0xFF0F172A).withOpacity(0.55),
                ],
              ),
            ),
          ),
        ),
        // Dégradé sombre en bas pour transition douce vers le formulaire
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0F172A).withOpacity(0.7),
                ],
                stops: const [0.5, 1.0],
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
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_orange, _orangeLight]),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.local_shipping_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(height: 6),
                      Text('AtlasMove', style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9))),
                      const SizedBox(height: 6),
                      Text('Inscription Livreur', style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1.1)),
                      const SizedBox(height: 3),
                      Text('Rejoignez notre réseau de livreurs',
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

  Widget _devFillButton() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _fillTestImages,
      icon: const Icon(Icons.bug_report_rounded, size: 16),
      label: const Text('DEV — Remplir avec images de test'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF7C3AED),
        side: const BorderSide(color: Color(0xFF7C3AED)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );

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

// ── Vehicle Picker Bottom Sheet ───────────────────────────────────────────────

class _VehiclePickerSheet extends StatelessWidget {
  final List<ServiceCategory> categories;
  final ServiceCategory? selected;
  final ValueChanged<ServiceCategory> onSelect;

  const _VehiclePickerSheet({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  static const _orange = Color(0xFFFF6B35);
  static const _dark = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car_rounded, color: _orange, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Type de véhicule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Choisissez le service qui correspond à votre véhicule',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Aucun service disponible',
                  style: TextStyle(color: Colors.grey.shade400)),
            )
          else
            ...categories.map((cat) => _categoryTile(context, cat)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _categoryTile(BuildContext context, ServiceCategory cat) {
    final isSelected = selected?.id == cat.id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onSelect(cat);
        Navigator.of(context).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _orange.withOpacity(0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? _orange.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _orange.withOpacity(0.3) : Colors.grey.shade200,
                ),
              ),
              child: Icon(_iconForType(cat.transportType),
                  color: isSelected ? _orange : Colors.grey.shade500, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _dark : Colors.black87,
                      )),
                  const SizedBox(height: 2),
                  Text(cat.transportType,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      )),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'taxi': return Icons.local_taxi_rounded;
      case 'vtc': return Icons.directions_car_rounded;
      case 'moto': return Icons.motorcycle_rounded;
      case 'livraison': return Icons.delivery_dining_rounded;
      case 'van': return Icons.airport_shuttle_rounded;
      case 'camion': return Icons.local_shipping_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      default: return Icons.work_outline_rounded;
    }
  }
}

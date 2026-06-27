import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/requests/driver_register_request.dart';
import '../models/service_models.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
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

  // Country dial code picker
  _CountryCode _dialCode = _CountryCode.defaultCode;

  // Sélecteur de service via catalogue complet
  List<Service> _allServices = [];
  Service? _selectedService;
  bool _loadingServices = false;

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
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      double? lat, lon;
      try {
        final pos = await LocationService()
            .getCurrentPosition()
            .timeout(const Duration(seconds: 3));
        lat = pos?.latitude;
        lon = pos?.longitude;
      } catch (_) {}

      final catalogue = await ServiceApi.getCatalogue(latitude: lat, longitude: lon);
      final flat = catalogue.data
          .expand((cat) => cat.services.where((s) => s.isActive))
          .toList();
      print('DEBUG REGISTER: catalogue.data=${catalogue.data.length} categories, flat=${flat.length} services');
      if (mounted) {
        setState(() => _allServices = flat.isNotEmpty ? flat : _fallbackServices());
      }
    } catch (e) {
      print('DEBUG REGISTER: getCatalogue error: $e');
      if (mounted) setState(() => _allServices = _fallbackServices());
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  List<Service> _fallbackServices() {
    final now = DateTime.now();
    final entries = [
      ('taxi_fb',     'Taxi Standard',       'taxi',      3.0,  1.2),
      ('vtc_fb',      'VTC / Chauffeur',     'vtc',       5.0,  1.8),
      ('moto_fb',     'Moto-taxi',           'moto',      2.0,  0.8),
      ('livr_fb',     'Livraison Moto',      'livraison', 2.0,  0.8),
      ('van_fb',      'Van / Camionnette',   'van',       7.0,  2.2),
      ('camion_fb',   'Camion / Poids lourd','camion',    10.0, 3.0),
    ];
    return entries.map((e) => Service(
      id: e.$1, name: e.$2, categoryId: '',
      transportType: e.$3, pricingModel: 'combined',
      isActive: true, sortOrder: 0, currency: 'EUR',
      basePrice: e.$4, pricePerKm: e.$5,
      createdAt: now, updatedAt: now,
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


  // ── Register ──────────────────────────────────────────────────────────────

  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null) {
      setState(() => _errorMessage = 'Veuillez sélectionner un type de véhicule/service');
      return;
    }
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
        phone: '${_dialCode.dial}${_phoneCtrl.text.trim().replaceAll(' ', '')}',
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
        vehicleType: _mapToBackendVehicleType(
            _selectedService?.transportType ?? _vehicleTypeCtrl.text.trim()),
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
                      _a(3, _phoneField()),

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

  // Mappe le transport_type du catalogue vers les valeurs acceptées par le backend
  String _mapToBackendVehicleType(String transportType) {
    const t2v = <String, String>{
      // Voiture
      'taxi': 'voiture', 'taxi_standard': 'voiture', 'vtc': 'voiture',
      'voiture': 'voiture', 'voiture_luxe': 'voiture', 'covoiturage': 'voiture',
      'transfert_aeroport': 'voiture', 'transport_scolaire': 'voiture',
      'tuk_tuk': 'voiture', 'ambulance': 'voiture', 'helicoptere': 'voiture',
      // Moto
      'moto': 'moto', 'moto_taxi': 'moto', 'coursier_moto': 'moto',
      'coursier_velo': 'moto',
      // Fourgonnette
      'livraison': 'fourgonnette', 'delivery': 'fourgonnette',
      'livraison_voiture': 'fourgonnette', 'van': 'fourgonnette',
      'camionnette_15t': 'fourgonnette', 'tricycle_cargo': 'fourgonnette',
      // Bus
      'bus': 'bus', 'minibus_collectif': 'bus', 'bus_charter': 'bus',
      // Semi-remorque
      'semi_remorque': 'semi_remorque',
      // Poids lourd
      'poids_lourd': 'poids_lourd', 'pickup_truck': 'poids_lourd',
      'transport_engins': 'poids_lourd',
      // Tracteur
      'tracteur': 'tracteur', 'tracteur_agricole': 'tracteur',
      'chariot_elevateur': 'tracteur',
      // Camion
      'camion': 'camion', 'camion_35t': 'camion', 'camion_10t': 'camion',
      'camion_20t': 'camion', 'camion_plateau': 'camion', 'camion_benne': 'camion',
      'camion_frigo': 'camion', 'camion_citerne': 'camion', 'camion_grue': 'camion',
      'camion_fourgon': 'camion', 'camion_demenagement': 'camion',
      'camion_toupie': 'camion',
    };
    final t = transportType.toLowerCase();
    if (t2v.containsKey(t)) return t2v[t]!;
    if (t.contains('camion')) return 'camion';
    if (t.contains('moto')) return 'moto';
    if (t.contains('bus')) return 'bus';
    return 'voiture';
  }

  // ── Vehicle selector ─────────────────────────────────────────────────────

  Widget _vehicleSelector() {
    final svc = _selectedService;
    final hasValue = svc != null;
    final hasImage = hasValue && svc.imageUrl != null && svc.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _showVehiclePicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValue ? _orange.withOpacity(0.4) : const Color(0xFFE2E6EF),
            width: hasValue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            // ── Image banner quand service sélectionné avec image ──────
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  children: [
                    Image.network(
                      svc.imageUrl!,
                      width: double.infinity,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12, bottom: 10,
                      child: Text(
                        svc.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Row infos ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (!hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40, height: 40,
                        color: hasValue
                            ? _orange.withOpacity(0.1)
                            : const Color(0xFFF1F5F9),
                        child: Icon(
                          _iconForType(svc?.transportType ?? ''),
                          color: hasValue ? _orange : const Color(0xFF9BA3B4),
                          size: 20,
                        ),
                      ),
                    ),
                  if (!hasImage) const SizedBox(width: 12),
                  Expanded(
                    child: hasValue
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!hasImage)
                                Text(svc.name,
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w700,
                                        color: _dark)),
                              if (svc.basePrice != null)
                                Text(
                                  '${svc.basePrice!.toStringAsFixed(2)} ${svc.currency ?? 'EUR'}'
                                  '${svc.pricePerKm != null ? ' + ${svc.pricePerKm!.toStringAsFixed(2)}/km' : ''}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                            ],
                          )
                        : Text('Type de véhicule / Service',
                            style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF9BA3B4))),
                  ),
                  if (_loadingServices)
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _orange))
                  else
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: hasValue ? _orange : const Color(0xFF9BA3B4),
                        size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehiclePicker() {
    if (_loadingServices) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServicePickerSheet(
        services: _allServices,
        selected: _selectedService,
        onSelect: (svc) {
          setState(() {
            _selectedService = svc;
            _vehicleTypeCtrl.text = _mapToBackendVehicleType(svc.transportType);
          });
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('taxi')) return Icons.local_taxi_rounded;
    if (t.contains('vtc') || t.contains('chauffeur')) return Icons.directions_car_rounded;
    if (t.contains('moto')) return Icons.motorcycle_rounded;
    if (t.contains('livraison') || t.contains('coursier') || t.contains('delivery')) return Icons.delivery_dining_rounded;
    if (t.contains('van') || t.contains('camionnette')) return Icons.airport_shuttle_rounded;
    if (t.contains('camion') || t.contains('truck')) return Icons.local_shipping_rounded;
    if (t.contains('bus') || t.contains('minibus')) return Icons.directions_bus_rounded;
    if (t.contains('velo') || t.contains('bicycle')) return Icons.pedal_bike_rounded;
    if (t.contains('tuk')) return Icons.electric_rickshaw_rounded;
    return Icons.work_outline_rounded;
  }

  // ── Phone field with country dial-code prefix ─────────────────────────────

  Widget _phoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500,
            color: _dark),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'Obligatoire' : null,
        decoration: InputDecoration(
          hintText: 'Téléphone',
          hintStyle: GoogleFonts.poppins(fontSize: 13,
              color: const Color(0xFFCDD3E0)),
          prefixIcon: _dialCodeButton(),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _dialCodeButton() {
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_dialCode.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(_dialCode.dial,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _dark)),
            const Icon(Icons.arrow_drop_down_rounded,
                color: Color(0xFF9BA3B4), size: 18),
            Container(width: 1, height: 22, color: const Color(0xFFE2E6EF),
                margin: const EdgeInsets.only(left: 6)),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountryPickerSheet(
        selected: _dialCode,
        onSelected: (code) {
          setState(() => _dialCode = code);
          Navigator.pop(context);
        },
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
            'assets/images/image2.jpg',
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

// ── Service Picker Bottom Sheet ───────────────────────────────────────────────

class _ServicePickerSheet extends StatefulWidget {
  final List<Service> services;
  final Service? selected;
  final ValueChanged<Service> onSelect;

  const _ServicePickerSheet({
    required this.services,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  static const _orange = Color(0xFFFF6B35);
  static const _dark = Color(0xFF0F172A);

  String _search = '';
  late List<Service> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.services;
  }

  void _onSearch(String q) {
    setState(() {
      _search = q.toLowerCase();
      _filtered = widget.services
          .where((s) =>
              s.name.toLowerCase().contains(_search) ||
              s.transportType.toLowerCase().contains(_search))
          .toList();
    });
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('taxi')) return Icons.local_taxi_rounded;
    if (t.contains('vtc') || t.contains('chauffeur')) return Icons.directions_car_rounded;
    if (t.contains('moto')) return Icons.motorcycle_rounded;
    if (t.contains('livraison') || t.contains('coursier') || t.contains('delivery')) return Icons.delivery_dining_rounded;
    if (t.contains('van') || t.contains('camionnette')) return Icons.airport_shuttle_rounded;
    if (t.contains('camion') || t.contains('truck')) return Icons.local_shipping_rounded;
    if (t.contains('bus') || t.contains('minibus')) return Icons.directions_bus_rounded;
    if (t.contains('velo')) return Icons.pedal_bike_rounded;
    if (t.contains('tuk')) return Icons.electric_rickshaw_rounded;
    return Icons.work_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car_rounded, color: _orange, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choisir un service',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
                  Text('${widget.services.length} service${widget.services.length > 1 ? 's' : ''} disponibles',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ]),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: _onSearch,
              style: const TextStyle(fontSize: 13, color: _dark),
              decoration: InputDecoration(
                hintText: 'Rechercher un service...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text('Aucun service trouvé',
                    style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _serviceTile(_filtered[i]),
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 12),
        ],
      ),
    );
  }

  Widget _serviceTile(Service svc) {
    final isSelected = widget.selected?.id == svc.id;
    final hasImage = svc.imageUrl != null && svc.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onSelect(svc);
        Navigator.of(context).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _orange : const Color(0xFFE8ECF0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _orange.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Image or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasImage
                  ? Image.network(
                      svc.imageUrl!,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconBox(svc, isSelected),
                    )
                  : _iconBox(svc, isSelected),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(svc.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _dark : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (svc.basePrice != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${svc.basePrice!.toStringAsFixed(2)} ${svc.currency ?? 'EUR'}'
                      '${svc.pricePerKm != null ? ' + ${svc.pricePerKm!.toStringAsFixed(2)}/km' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            // Badge + check
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isSelected ? _orange : Colors.grey.shade400).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    svc.transportType.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: isSelected ? _orange : Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 6),
                  const Icon(Icons.check_circle_rounded, color: _orange, size: 18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(Service svc, bool isSelected) {
    return Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        color: isSelected ? _orange.withOpacity(0.12) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_iconForType(svc.transportType),
          color: isSelected ? _orange : Colors.grey.shade400, size: 26),
    );
  }
}

// ── Country dial-code data ────────────────────────────────────────────────────

class _CountryCode {
  final String flag;
  final String name;
  final String dial;

  const _CountryCode({required this.flag, required this.name, required this.dial});

  static const _CountryCode defaultCode =
      _CountryCode(flag: '🇹🇳', name: 'Tunisie', dial: '+216');

  static const List<_CountryCode> all = [
    _CountryCode(flag: '🇹🇳', name: 'Tunisie',         dial: '+216'),
    _CountryCode(flag: '🇩🇿', name: 'Algérie',         dial: '+213'),
    _CountryCode(flag: '🇲🇦', name: 'Maroc',           dial: '+212'),
    _CountryCode(flag: '🇱🇾', name: 'Libye',           dial: '+218'),
    _CountryCode(flag: '🇪🇬', name: 'Égypte',          dial: '+20'),
    _CountryCode(flag: '🇸🇦', name: 'Arabie Saoudite', dial: '+966'),
    _CountryCode(flag: '🇦🇪', name: 'Émirats',         dial: '+971'),
    _CountryCode(flag: '🇶🇦', name: 'Qatar',           dial: '+974'),
    _CountryCode(flag: '🇰🇼', name: 'Koweït',          dial: '+965'),
    _CountryCode(flag: '🇧🇭', name: 'Bahreïn',         dial: '+973'),
    _CountryCode(flag: '🇴🇲', name: 'Oman',            dial: '+968'),
    _CountryCode(flag: '🇯🇴', name: 'Jordanie',        dial: '+962'),
    _CountryCode(flag: '🇱🇧', name: 'Liban',           dial: '+961'),
    _CountryCode(flag: '🇸🇩', name: 'Soudan',          dial: '+249'),
    _CountryCode(flag: '🇫🇷', name: 'France',          dial: '+33'),
    _CountryCode(flag: '🇩🇪', name: 'Allemagne',       dial: '+49'),
    _CountryCode(flag: '🇧🇪', name: 'Belgique',        dial: '+32'),
    _CountryCode(flag: '🇨🇭', name: 'Suisse',          dial: '+41'),
    _CountryCode(flag: '🇪🇸', name: 'Espagne',         dial: '+34'),
    _CountryCode(flag: '🇮🇹', name: 'Italie',          dial: '+39'),
    _CountryCode(flag: '🇬🇧', name: 'Royaume-Uni',     dial: '+44'),
    _CountryCode(flag: '🇺🇸', name: 'États-Unis',      dial: '+1'),
    _CountryCode(flag: '🇨🇦', name: 'Canada',          dial: '+1'),
    _CountryCode(flag: '🇸🇳', name: 'Sénégal',         dial: '+221'),
    _CountryCode(flag: '🇨🇮', name: "Côte d'Ivoire",   dial: '+225'),
    _CountryCode(flag: '🇨🇲', name: 'Cameroun',        dial: '+237'),
    _CountryCode(flag: '🇬🇳', name: 'Guinée',          dial: '+224'),
    _CountryCode(flag: '🇲🇱', name: 'Mali',            dial: '+223'),
    _CountryCode(flag: '🇹🇷', name: 'Turquie',         dial: '+90'),
    _CountryCode(flag: '🇵🇰', name: 'Pakistan',        dial: '+92'),
  ];
}

// ── Country picker bottom sheet ───────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final _CountryCode selected;
  final void Function(_CountryCode) onSelected;

  const _CountryPickerSheet({required this.selected, required this.onSelected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  static const _orange = Color(0xFFFF6B35);
  static const _dark   = Color(0xFF0F172A);

  String _search = '';
  late List<_CountryCode> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = _CountryCode.all;
  }

  void _onSearch(String q) {
    setState(() {
      _search = q.toLowerCase();
      _filtered = _CountryCode.all
          .where((c) =>
              c.name.toLowerCase().contains(_search) ||
              c.dial.contains(_search))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('Sélectionner un pays',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: _onSearch,
              style: GoogleFonts.poppins(fontSize: 13, color: _dark),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.grey, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSelected = c.dial == widget.selected.dial &&
                    c.name == widget.selected.name;
                return InkWell(
                  onTap: () => widget.onSelected(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    color: isSelected
                        ? _orange.withOpacity(0.06)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(c.name,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _dark)),
                        ),
                        Text(c.dial,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? _orange : Colors.grey)),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded,
                              color: _orange, size: 18),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

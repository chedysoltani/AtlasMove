import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/driver_onboarding.dart';
import '../models/service_models.dart';
import '../services/driver_onboarding_analytics.dart';
import '../services/driver_onboarding_api.dart';
import '../services/service_api.dart';
import '../utils/driver_phone.dart';
import '../widgets/driver_onboarding_ui.dart';
import 'driver_login_screen.dart';
import 'driver_otp_screen.dart';

/// Inscription chauffeur, étape 1 : un seul écran court (pays, téléphone,
/// nom, ville, type de véhicule), puis le code WhatsApp. Les documents
/// s'envoient ensuite depuis « Mon dossier ».
///
/// Ce qui est saisi est gardé sur l'appareil : si l'app est fermée, le
/// chauffeur le retrouve ; le brouillon est effacé une fois le compte créé.
class DriverSignupScreen extends StatefulWidget {
  static const route = '/driver_register';

  const DriverSignupScreen({super.key});

  /// Brouillon du formulaire (SharedPreferences).
  static const draftKey = 'driver_signup_draft_v1';

  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(draftKey);
    } catch (_) {}
  }

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  static const termsUrl = 'https://api.atla.business/legal/terms-and-conditions';
  static const privacyUrl = 'https://api.atla.business/legal/privacy-policy';

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  DriverRegistrationOptions? _options;
  bool _loadingOptions = true;
  String? _optionsError;

  String? _country;
  String? _vehicleType;
  bool _acceptTerms = false;

  /// Catalogue complet des services (GET /services/catalogue) : le chauffeur
  /// choisit son service, envoyé à `register` comme `service_id`.
  List<({String name, List<Service> services})> _catalogue = [];
  bool _loadingCatalogue = false;
  bool _catalogueFailed = false;
  String? _serviceId;

  bool _submitting = false;
  bool _showErrors = false;
  String? _error;
  String? _errorCode;

  /// Erreurs par champ renvoyées par le serveur (register → VALIDATION_ERROR…).
  Map<String, String> _serverFieldErrors = {};

  Timer? _draftTimer;
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _openUrl(termsUrl);
    _privacyTap = TapGestureRecognizer()..onTap = () => _openUrl(privacyUrl);
    DriverOnboardingAnalytics.registrationStarted();
    _restoreDraft().whenComplete(_loadOptions);
    for (final c in _controllers) {
      c.addListener(_scheduleDraftSave);
    }
  }

  List<TextEditingController> get _controllers =>
      [_phoneCtrl, _emailCtrl, _firstNameCtrl, _lastNameCtrl, _cityCtrl];

  @override
  void dispose() {
    _draftTimer?.cancel();
    _saveDraft();
    _termsTap.dispose();
    _privacyTap.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Brouillon ─────────────────────────────────────────────────────────────

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(DriverSignupScreen.draftKey);
      if (raw == null) return;
      final d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (!mounted) return;
      setState(() {
        _country = d['country'] as String?;
        _vehicleType = d['vehicle_type'] as String?;
        _serviceId = d['service_id'] as String?;
        _phoneCtrl.text = d['phone'] as String? ?? '';
        _emailCtrl.text = d['email'] as String? ?? '';
        _firstNameCtrl.text = d['first_name'] as String? ?? '';
        _lastNameCtrl.text = d['last_name'] as String? ?? '';
        _cityCtrl.text = d['city'] as String? ?? '';
        _acceptTerms = d['accept_terms'] == true;
      });
    } catch (_) {}
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        DriverSignupScreen.draftKey,
        jsonEncode({
          'country': _country,
          'vehicle_type': _vehicleType,
          'service_id': _serviceId,
          'phone': _phoneCtrl.text,
          'email': _emailCtrl.text,
          'first_name': _firstNameCtrl.text,
          'last_name': _lastNameCtrl.text,
          'city': _cityCtrl.text,
          'accept_terms': _acceptTerms,
        }),
      );
    } catch (_) {}
  }

  // ── Options du serveur ────────────────────────────────────────────────────

  Future<void> _loadCatalogue() async {
    setState(() { _loadingCatalogue = true; _catalogueFailed = false; });
    try {
      final catalogue = await ServiceApi.getCatalogue();
      if (!mounted) return;
      // Catégories vides (aucun service actif) écartées.
      final categories = catalogue.data
          .map((c) => (name: c.name, services: c.services.where((s) => s.isActive).toList()))
          .where((e) => e.services.isNotEmpty)
          .toList();
      setState(() {
        _catalogue = categories;
        // Service du brouillon qui n'existe plus : on l'oublie.
        if (_findService(_serviceId) == null) _serviceId = null;
      });
    } catch (_) {
      if (mounted) setState(() => _catalogueFailed = true);
    } finally {
      if (mounted) setState(() => _loadingCatalogue = false);
    }
  }

  /// Type de véhicule évident pour le `transport_type` d'une catégorie ;
  /// null quand ce n'est pas clair (le chauffeur choisit lui-même).
  static const Map<String, String> _vehicleForTransport = {
    'taxi': 'voiture', 'vtc': 'voiture', 'voiture_luxe': 'voiture',
    'covoiturage': 'voiture', 'livraison_voiture': 'voiture', 'transfert_aeroport': 'voiture',
    'moto': 'moto', 'coursier_moto': 'moto',
    'bus_charter': 'bus', 'minibus_collectif': 'bus',
    'camionnette_15t': 'fourgonnette',
    'camion': 'camion', 'camion_10t': 'camion', 'camion_20t': 'camion',
    'camion_plateau': 'camion', 'camion_benne': 'camion', 'camion_frigo': 'camion',
    'camion_citerne': 'camion', 'camion_grue': 'camion', 'camion_fourgon': 'camion',
    'camion_demenagement': 'camion', 'camion_toupie': 'camion',
    'semi_remorque': 'semi_remorque',
    'tracteur_agricole': 'tracteur',
    'transport_engins': 'poids_lourd',
  };

  void _selectService(Service service) {
    setState(() {
      _serviceId = service.id;
      _serverFieldErrors = Map.of(_serverFieldErrors)..remove('service_id');
      final suggested = _vehicleForTransport[service.transportType];
      if (suggested != null && (_options?.vehicleTypes.any((v) => v.value == suggested) ?? false)) {
        _vehicleType = suggested;
        _serverFieldErrors.remove('vehicle_type');
      }
    });
    _scheduleDraftSave();
  }

  Future<void> _openServicePicker() async {
    final picked = await showModalBottomSheet<Service>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ServicePickerSheet(catalogue: _catalogue, selectedId: _serviceId),
    );
    if (picked != null) _selectService(picked);
  }

  Service? _findService(String? id) {
    if (id == null) return null;
    for (final c in _catalogue) {
      for (final s in c.services) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  Future<void> _loadOptions() async {
    if (_catalogue.isEmpty) _loadCatalogue();
    setState(() { _loadingOptions = true; _optionsError = null; });
    try {
      final options = await DriverOnboardingApi.registrationOptions();
      if (!mounted) return;
      setState(() {
        _options = options;
        // Valeurs du brouillon qui ne sont plus proposées : on les oublie.
        if (options.country(_country) == null) {
          _country = options.countries.isNotEmpty ? options.countries.first.code : null;
        }
        if (!options.vehicleTypes.any((v) => v.value == _vehicleType)) _vehicleType = null;
      });
    } on DriverApiException catch (e) {
      DriverOnboardingAnalytics.registrationError(step: 'options', errorCode: e.code);
      if (mounted) setState(() => _optionsError = e.message);
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── Validation ────────────────────────────────────────────────────────────

  DriverCountry? get _selectedCountry => _options?.country(_country);

  String get _dialCode =>
      _selectedCountry?.dialCode ?? DriverPhone.dialCodes[_country] ?? '';

  /// `phone_lengths` du serveur ; à défaut, longueurs connues des 4 marchés.
  List<int> get _phoneLengths {
    final fromServer = _selectedCountry?.phoneLengths ?? const [];
    return fromServer.isNotEmpty ? fromServer : (DriverPhone.knownLengths[_country] ?? const []);
  }

  DriverPhoneCheck get _phoneCheck =>
      DriverPhone.check(_phoneCtrl.text, dialCode: _dialCode, lengths: _phoneLengths);

  bool get _emailRequired => _options?.emailRequired == true;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  String? get _emailError {
    final server = _serverFieldErrors['email'];
    if (server != null) return server;
    if (!_showErrors || !_emailRequired) return null;
    final v = _emailCtrl.text.trim();
    if (v.isEmpty) return 'auth.field_required'.tr();
    if (v.length > 254 || !_emailRegex.hasMatch(v)) return 'auth.email_invalid'.tr();
    return null;
  }

  bool get _emailValid {
    if (!_emailRequired) return true;
    final v = _emailCtrl.text.trim();
    return v.isNotEmpty && v.length <= 254 && _emailRegex.hasMatch(v);
  }

  String? get _phoneError {
    final server = _serverFieldErrors['phone'];
    if (server != null) return server;
    if (!_showErrors) return null;
    switch (_phoneCheck.issue) {
      case DriverPhoneIssue.none:
        return null;
      case DriverPhoneIssue.empty:
        return 'auth.field_required'.tr();
      case DriverPhoneIssue.countryMismatch:
        return 'driver_v2.errors.PHONE_COUNTRY_MISMATCH'.tr();
      case DriverPhoneIssue.invalid:
        return _phoneLengthMessage(_phoneLengths);
    }
  }

  /// « Le numéro doit compter 8 chiffres (sans l'indicatif). »
  static String _phoneLengthMessage(List<int> lengths) => lengths.isEmpty
      ? 'driver_v2.errors.PHONE_INVALID'.tr()
      : 'driver_v2.phone_length'.tr(namedArgs: {
          'digits': lengths.join(' ${'driver_v2.or'.tr()} '),
        });

  String? _textError(TextEditingController c, String field, {int max = 50}) {
    final server = _serverFieldErrors[field];
    if (server != null) return server;
    if (!_showErrors) return null;
    final v = c.text.trim();
    if (v.isEmpty) return 'auth.field_required'.tr();
    if (v.length > max) return 'driver_v2.too_long'.tr(namedArgs: {'max': '$max'});
    return null;
  }

  bool get _formValid =>
      _country != null &&
      _phoneCheck.isValid &&
      _emailValid &&
      // Service obligatoire dès que le catalogue est chargé (sinon : service
      // par défaut du type de véhicule, attribué par le serveur).
      (_catalogue.isEmpty || _findService(_serviceId) != null) &&
      _firstNameCtrl.text.trim().isNotEmpty && _firstNameCtrl.text.trim().length <= 50 &&
      _lastNameCtrl.text.trim().isNotEmpty && _lastNameCtrl.text.trim().length <= 50 &&
      _cityCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().length <= 120 &&
      _vehicleType != null &&
      _acceptTerms;

  // ── Envoi ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _showErrors = true; _serverFieldErrors = {}; _error = null; _errorCode = null; });
    if (!_formValid) {
      DriverOnboardingAnalytics.registrationError(step: 'form', errorCode: 'LOCAL_VALIDATION');
      return;
    }
    final options = _options!;
    final phone = _phoneCheck.e164!;
    final country = _country!;
    final vehicle = options.vehicleTypes.firstWhere((v) => v.value == _vehicleType);
    final email = _emailRequired ? _emailCtrl.text.trim().toLowerCase() : null;

    setState(() => _submitting = true);
    try {
      final otp = await DriverOnboardingApi.sendOtp(
          phone: phone, country: country, purpose: 'register', email: email);
      if (!mounted) return;
      final fieldErrors = await Navigator.of(context).pushNamed(
        DriverOtpScreen.route,
        arguments: DriverOtpArgs(
          purpose: DriverOtpPurpose.register,
          phone: phone,
          country: country,
          otp: otp,
          codeLength: options.otpCodeLength,
          registration: DriverRegistrationData(
            email: email,
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            vehicleType: vehicle.value,
            serviceId: _findService(_serviceId)?.id ?? vehicle.serviceId,
          ),
        ),
      );
      // Retour de l'écran du code avec des erreurs de saisie à corriger.
      if (fieldErrors is Map<String, String> && mounted) {
        setState(() => _serverFieldErrors = fieldErrors);
      }
    } on DriverApiException catch (e) {
      DriverOnboardingAnalytics.registrationError(step: 'otp_send', errorCode: e.code);
      if (!mounted) return;
      setState(() {
        _errorCode = e.code;
        _serverFieldErrors = Map.of(e.fieldErrors);
        switch (e.code) {
          case 'PHONE_INVALID':
            // Le serveur donne la longueur attendue pour le pays.
            _serverFieldErrors['phone'] = e.expectedLengths.isNotEmpty
                ? _phoneLengthMessage(e.expectedLengths)
                : e.message;
            break;
          case 'PHONE_COUNTRY_MISMATCH':
            _serverFieldErrors['phone'] = e.message;
            break;
          case 'EMAIL_ALREADY_REGISTERED':
            // Message explicite sous le champ (fields.email ne dit que « Valeur invalide »).
            _serverFieldErrors['email'] = e.message;
            break;
          case 'PHONE_ALREADY_REGISTERED':
            // Bandeau avec le bouton « Se connecter ».
            _serverFieldErrors.remove('phone');
            break;
        }
        // Erreur rattachée à un champ : affichée sous le champ seulement.
        _error = _serverFieldErrors.isEmpty ? e.message : null;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushNamed(
      DriverLoginScreen.route,
      arguments: DriverLoginArgs(phone: _phoneCtrl.text, country: _country),
    );
  }

  // ── Interface ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DriverOnboardingScaffold(
      title: 'driver_v2.signup_title'.tr(),
      subtitle: 'driver_v2.signup_subtitle'.tr(),
      child: _loadingOptions
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: DriverUi.orange)),
            )
          : _options == null
              ? DriverMessageBanner(
                  message: _optionsError ?? 'driver_v2.errors.generic'.tr(),
                  actionLabel: 'common.retry'.tr(),
                  onAction: _loadOptions,
                )
              : _buildForm(_options!),
    );
  }

  Widget _buildForm(DriverRegistrationOptions options) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DriverUi.label('driver_v2.country'.tr()),
          DriverCountrySelector(
            countries: options.countries,
            selected: _country,
            onChanged: (code) {
              setState(() {
                _country = code;
                _serverFieldErrors = Map.of(_serverFieldErrors)..remove('phone');
              });
              _scheduleDraftSave();
            },
          ),
          const SizedBox(height: 18),
          DriverUi.label(_emailRequired ? 'driver_v2.phone_plain'.tr() : 'driver_v2.phone'.tr()),
          DriverPhoneField(
            controller: _phoneCtrl,
            dialCode: _dialCode,
            errorText: _phoneError,
            onChanged: (_) => setState(() =>
                _serverFieldErrors = Map.of(_serverFieldErrors)..remove('phone')),
          ),
          if (!_emailRequired)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
              child: Text('driver_v2.phone_whatsapp_hint'.tr(),
                  style: DriverUi.text(11.5, color: DriverUi.textSecondary)),
            ),
          if (_emailRequired) ...[
            const SizedBox(height: 18),
            DriverUi.label('driver_v2.email'.tr()),
            Directionality(
              // Adresse e-mail : toujours de gauche à droite, même en arabe.
              textDirection: ui.TextDirection.ltr,
              child: TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                maxLength: 254,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                onChanged: (_) {
                  if (_serverFieldErrors.containsKey('email')) {
                    setState(() => _serverFieldErrors = Map.of(_serverFieldErrors)..remove('email'));
                  }
                },
                style: DriverUi.text(14, weight: FontWeight.w500),
                decoration: DriverUi.input('driver_v2.email_hint'.tr(),
                    icon: Icons.alternate_email_rounded, errorText: _emailError),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
              child: Text('driver_v2.email_code_hint'.tr(),
                  style: DriverUi.text(11.5, color: DriverUi.textSecondary)),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _textField(_firstNameCtrl, 'driver_v2.first_name'.tr(), 'first_name',
                  autofill: AutofillHints.givenName)),
              const SizedBox(width: 10),
              Expanded(child: _textField(_lastNameCtrl, 'driver_v2.last_name'.tr(), 'last_name',
                  autofill: AutofillHints.familyName)),
            ],
          ),
          const SizedBox(height: 18),
          _textField(_cityCtrl, 'driver_v2.city'.tr(), 'city',
              max: 120, icon: Icons.location_city_rounded, autofill: AutofillHints.addressCity),
          const SizedBox(height: 18),
          DriverUi.label('driver_v2.service'.tr()),
          _serviceField(),
          const SizedBox(height: 18),
          DriverUi.label('driver_v2.vehicle_type'.tr()),
          _vehicleSelector(options),
          const SizedBox(height: 18),
          _termsCheckbox(),
          const SizedBox(height: 16),
          if (_error != null) ...[
            DriverMessageBanner(
              message: _error!,
              actionLabel: _errorCode == 'PHONE_ALREADY_REGISTERED' ? 'driver_v2.go_login'.tr() : null,
              onAction: _errorCode == 'PHONE_ALREADY_REGISTERED' ? _goToLogin : null,
            ),
            const SizedBox(height: 14),
          ],
          DriverPrimaryButton(
            label: _emailRequired ? 'driver_v2.receive_code_email'.tr() : 'driver_v2.receive_code'.tr(),
            icon: _emailRequired ? Icons.mark_email_read_rounded : Icons.chat_rounded,
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _goToLogin,
              child: Text('driver_v2.already_registered'.tr(),
                  style: DriverUi.text(13, weight: FontWeight.w600, color: DriverUi.orange)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController c, String label, String field,
      {int max = 50, IconData? icon, String? autofill}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DriverUi.label(label),
        TextField(
          controller: c,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: autofill == null ? null : [autofill],
          maxLength: max,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          onChanged: (_) {
            if (_serverFieldErrors.containsKey(field)) {
              setState(() => _serverFieldErrors = Map.of(_serverFieldErrors)..remove(field));
            }
          },
          style: DriverUi.text(14, weight: FontWeight.w500),
          decoration: DriverUi.input(label, icon: icon, errorText: _textError(c, field, max: max)),
        ),
      ],
    );
  }

  Widget _serviceField() {
    if (_loadingCatalogue && _catalogue.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(color: DriverUi.orange, minHeight: 3),
      );
    }
    if (_catalogue.isEmpty) {
      // Catalogue indisponible : l'inscription reste possible (service par
      // défaut du type de véhicule), avec un bouton pour réessayer.
      return DriverMessageBanner(
        message: 'driver_v2.services_unavailable'.tr(),
        isError: false,
        actionLabel: _catalogueFailed ? 'common.retry'.tr() : null,
        onAction: _catalogueFailed ? _loadCatalogue : null,
      );
    }
    final selected = _findService(_serviceId);
    String? category;
    if (selected != null) {
      for (final c in _catalogue) {
        if (c.services.contains(selected)) category = c.name;
      }
    }
    final error = _serverFieldErrors['service_id'] ??
        (_showErrors && selected == null ? 'driver_v2.service_required'.tr() : null);
    return InkWell(
      onTap: _openServicePicker,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: selected == null,
        decoration: DriverUi.input('driver_v2.choose_service'.tr(),
                icon: Icons.local_taxi_rounded, errorText: error)
            .copyWith(suffixIcon: const Icon(Icons.expand_more_rounded, color: DriverUi.textSecondary)),
        child: selected == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selected.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DriverUi.text(14, weight: FontWeight.w600)),
                  if (category != null && category != selected.name)
                    Text(category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DriverUi.text(11.5, color: DriverUi.textSecondary)),
                ],
              ),
      ),
    );
  }

  Widget _vehicleSelector(DriverRegistrationOptions options) {
    final error = _serverFieldErrors['vehicle_type'] ??
        (_showErrors && _vehicleType == null ? 'driver_v2.vehicle_required'.tr() : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in options.vehicleTypes)
              ChoiceChip(
                selected: v.value == _vehicleType,
                showCheckmark: false,
                avatar: Icon(_vehicleIcon(v.value), size: 18,
                    color: v.value == _vehicleType ? Colors.white : DriverUi.orange),
                label: Text(v.label),
                labelStyle: DriverUi.text(13, weight: FontWeight.w600,
                    color: v.value == _vehicleType ? Colors.white : DriverUi.textPrimary),
                selectedColor: DriverUi.orange,
                backgroundColor: Colors.white,
                side: BorderSide(color: v.value == _vehicleType ? DriverUi.orange : DriverUi.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (_) {
                  setState(() {
                    _vehicleType = v.value;
                    _serverFieldErrors = Map.of(_serverFieldErrors)..remove('vehicle_type');
                  });
                  _scheduleDraftSave();
                },
              ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
            child: Text(error, style: DriverUi.text(12, color: DriverUi.red)),
          ),
      ],
    );
  }

  static IconData _vehicleIcon(String value) {
    switch (value) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'fourgonnette':
        return Icons.airport_shuttle_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'camion':
      case 'semi_remorque':
      case 'poids_lourd':
        return Icons.local_shipping_rounded;
      case 'tracteur':
        return Icons.agriculture_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  Widget _termsCheckbox() {
    final error = _serverFieldErrors['accept_terms'] ??
        (_showErrors && !_acceptTerms ? 'driver_v2.terms_required'.tr() : null);
    final linkStyle = DriverUi.text(12.5, weight: FontWeight.w600, color: DriverUi.orange)
        .copyWith(decoration: TextDecoration.underline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _acceptTerms,
              activeColor: DriverUi.orange,
              onChanged: (v) {
                setState(() {
                  _acceptTerms = v == true;
                  _serverFieldErrors = Map.of(_serverFieldErrors)..remove('accept_terms');
                });
                _scheduleDraftSave();
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: DriverUi.text(12.5, color: DriverUi.textSecondary, height: 1.5),
                    children: [
                      TextSpan(text: '${'driver_v2.terms_prefix'.tr()} '),
                      TextSpan(text: 'driver_v2.terms_link'.tr(), style: linkStyle, recognizer: _termsTap),
                      TextSpan(text: ' ${'driver_v2.terms_and'.tr()} '),
                      TextSpan(text: 'driver_v2.privacy_link'.tr(), style: linkStyle, recognizer: _privacyTap),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Text(error, style: DriverUi.text(12, color: DriverUi.red)),
          ),
      ],
    );
  }
}

/// Liste de tous les services actifs du catalogue, groupés par catégorie,
/// avec recherche (nom du service ou de la catégorie, sans accents).
class _ServicePickerSheet extends StatefulWidget {
  final List<({String name, List<Service> services})> catalogue;
  final String? selectedId;

  const _ServicePickerSheet({required this.catalogue, required this.selectedId});

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  String _query = '';

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final q = _fold(_query.trim());
    // Lignes à afficher : en-tête de catégorie puis ses services.
    final rows = <Object>[];
    for (final c in widget.catalogue) {
      final categoryMatches = q.isEmpty || _fold(c.name).contains(q);
      final services = categoryMatches
          ? c.services
          : c.services.where((s) => _fold(s.name).contains(q)).toList();
      if (services.isEmpty) continue;
      rows.add(c.name);
      rows.addAll(services);
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: DriverUi.border, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 4),
              child: Text('driver_v2.choose_service'.tr(),
                  style: DriverUi.text(16, weight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: DriverUi.text(14),
                decoration: DriverUi.input('driver_v2.search_service'.tr(), icon: Icons.search_rounded),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text('driver_v2.no_service_found'.tr(),
                          style: DriverUi.text(13, color: DriverUi.textSecondary)))
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final row = rows[i];
                        if (row is String) {
                          return Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 6),
                            child: Text(row.toUpperCase(),
                                style: DriverUi.text(11.5,
                                    weight: FontWeight.w700, color: DriverUi.textSecondary)),
                          );
                        }
                        final s = row as Service;
                        final selected = s.id == widget.selectedId;
                        final image = (s.iconUrl?.isNotEmpty ?? false) ? s.iconUrl : s.imageUrl;
                        return ListTile(
                          selected: selected,
                          selectedTileColor: DriverUi.orange.withOpacity(0.08),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: DriverUi.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: image != null && image.isNotEmpty
                                ? Image.network(image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.local_taxi_rounded, color: DriverUi.orange, size: 20))
                                : const Icon(Icons.local_taxi_rounded, color: DriverUi.orange, size: 20),
                          ),
                          title: Text(s.name,
                              style: DriverUi.text(14,
                                  weight: selected ? FontWeight.w700 : FontWeight.w500)),
                          subtitle: (s.description?.isNotEmpty ?? false)
                              ? Text(s.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DriverUi.text(11.5, color: DriverUi.textSecondary))
                              : null,
                          trailing: selected
                              ? const Icon(Icons.check_circle_rounded, color: DriverUi.orange)
                              : null,
                          onTap: () => Navigator.pop(context, s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

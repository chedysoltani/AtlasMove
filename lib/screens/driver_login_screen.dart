import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/storage/token_storage.dart';
import '../models/driver_onboarding.dart';
import '../services/driver_account_store.dart';
import '../services/driver_onboarding_analytics.dart';
import '../services/driver_onboarding_api.dart';
import '../utils/driver_phone.dart';
import '../widgets/driver_onboarding_ui.dart';
import 'driver_otp_screen.dart';
import 'driver_signup_screen.dart';

class DriverLoginArgs {
  final String? phone;
  final String? country;
  /// Ouvrir directement la connexion par mot de passe (compte sans e-mail).
  final bool usePassword;
  const DriverLoginArgs({this.phone, this.country, this.usePassword = false});
}

/// Connexion chauffeur par téléphone : code de vérification (envoyé à
/// l'e-mail du compte), ou mot de passe pour les comptes qui en ont un.
/// Un chauffeur non validé se connecte normalement : il arrive sur
/// « Mon dossier ». La connexion par e-mail reste sur /login.
class DriverLoginScreen extends StatefulWidget {
  static const route = '/driver_login';

  final DriverLoginArgs? args;
  const DriverLoginScreen({super.key, this.args});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  /// Pays du serveur (244) ; en attendant, ou s'il ne répond pas, les 4
  /// marchés principaux.
  List<DriverCountry> _countries = [
    for (final e in DriverPhone.dialCodes.entries)
      DriverCountry(
        code: e.key,
        name: 'countries.${e.key.toLowerCase()}'.tr(),
        dialCode: e.value,
        phoneLengths: DriverPhone.knownLengths[e.key] ?? const [],
        defaultLanguage: 'fr',
      ),
  ];

  late String _country;
  late bool _usePassword;
  bool _obscure = true;
  bool _loading = false;
  bool _showErrors = false;
  String? _error;
  String? _errorCode;
  String? _phoneServerError;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    _country = args?.country?.toUpperCase() ?? 'MA';
    _usePassword = args?.usePassword ?? false;
    // Numéro reçu en E.164 : on le réécrit sans l'indicatif.
    final phone = args?.phone ?? '';
    final dial = _current?.dialCode ?? '';
    _phoneCtrl.text = dial.isNotEmpty && phone.startsWith(dial) ? phone.substring(dial.length) : phone;
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final options = await DriverOnboardingApi.registrationOptions();
      if (!mounted || options.countries.isEmpty) return;
      setState(() => _countries = options.countries);
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  DriverCountry? get _current {
    for (final c in _countries) {
      if (c.code == _country) return c;
    }
    return null;
  }

  List<int> get _phoneLengths {
    final fromServer = _current?.phoneLengths ?? const [];
    return fromServer.isNotEmpty ? fromServer : (DriverPhone.knownLengths[_country] ?? const []);
  }

  DriverPhoneCheck get _phoneCheck => DriverPhone.check(_phoneCtrl.text,
      dialCode: _current?.dialCode ?? '', lengths: _phoneLengths);

  String? get _phoneError {
    if (_phoneServerError != null) return _phoneServerError;
    if (!_showErrors) return null;
    switch (_phoneCheck.issue) {
      case DriverPhoneIssue.none:
        return null;
      case DriverPhoneIssue.empty:
        return 'auth.field_required'.tr();
      case DriverPhoneIssue.countryMismatch:
        return 'driver_v2.errors.PHONE_COUNTRY_MISMATCH'.tr();
      case DriverPhoneIssue.invalid:
        return _lengthMessage(_phoneLengths);
    }
  }

  static String _lengthMessage(List<int> lengths) => lengths.isEmpty
      ? 'driver_v2.errors.PHONE_INVALID'.tr()
      : 'driver_v2.phone_length'.tr(namedArgs: {
          'digits': lengths.join(' ${'driver_v2.or'.tr()} '),
        });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _showErrors = true; _error = null; _errorCode = null; _phoneServerError = null; });
    if (!_phoneCheck.isValid) return;
    if (_usePassword && _passwordCtrl.text.isEmpty) return;
    final phone = _phoneCheck.e164!;

    setState(() => _loading = true);
    try {
      if (_usePassword) {
        await TokenStorage.saveRememberMe(true);
        final session = await DriverOnboardingApi.loginWithPassword(
            phone: phone, country: _country, password: _passwordCtrl.text);
        await DriverAccountStore.instance.startSession(session);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
            DriverAccountStore.routeFor(session.driver), (_) => false);
      } else {
        final otp = await DriverOnboardingApi.sendOtp(phone: phone, country: _country, purpose: 'login');
        if (!mounted) return;
        Navigator.of(context).pushNamed(
          DriverOtpScreen.route,
          arguments: DriverOtpArgs(
            purpose: DriverOtpPurpose.login,
            phone: phone,
            country: _country,
            otp: otp,
          ),
        );
      }
    } on DriverApiException catch (e) {
      DriverOnboardingAnalytics.registrationError(
          step: _usePassword ? 'login' : 'otp_send', errorCode: e.code);
      if (!mounted) return;
      if (e.code == 'ACCOUNT_SUSPENDED') {
        Navigator.of(context).pushNamedAndRemoveUntil(DriverAccountStore.routeSuspended, (_) => false);
        return;
      }
      setState(() {
        _errorCode = e.code;
        if (e.code == 'PHONE_INVALID') {
          _phoneServerError =
              e.expectedLengths.isNotEmpty ? _lengthMessage(e.expectedLengths) : e.message;
        } else if (e.code == 'PHONE_COUNTRY_MISMATCH') {
          _phoneServerError = e.message;
        } else {
          _error = e.message;
        }
        // Pas de mot de passe sur ce compte : on passe au code.
        if (e.code == 'PASSWORD_NOT_SET') _usePassword = false;
        // Pas d'e-mail sur ce compte : aucun code possible, mot de passe seulement.
        if (e.code == 'EMAIL_NOT_SET') _usePassword = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({String label, VoidCallback action})? get _errorAction {
    switch (_errorCode) {
      case 'PHONE_NOT_REGISTERED':
        return (
          label: 'driver_v2.create_account'.tr(),
          action: () => Navigator.of(context).pushReplacementNamed(DriverSignupScreen.route),
        );
      case 'NOT_A_DRIVER_ACCOUNT':
        return (
          label: 'driver_v2.client_login'.tr(),
          action: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false),
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final action = _errorAction;
    return DriverOnboardingScaffold(
      title: 'driver_v2.login_title'.tr(),
      subtitle: 'driver_v2.login_subtitle'.tr(),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chauffeur en attente : il peut se connecter pour suivre son
            // dossier ; les courses arrivent une fois le compte approuvé.
            DriverMessageBanner(message: 'driver_v2.login_info'.tr(), isError: false),
            const SizedBox(height: 18),
            DriverUi.label('driver_v2.country'.tr()),
            DriverCountrySelector(
              countries: _countries,
              selected: _country,
              onChanged: (c) => setState(() { _country = c; _phoneServerError = null; }),
            ),
            const SizedBox(height: 18),
            DriverUi.label('driver_v2.phone_plain'.tr()),
            DriverPhoneField(
              controller: _phoneCtrl,
              dialCode: _current?.dialCode ?? '',
              errorText: _phoneError,
              textInputAction: _usePassword ? TextInputAction.next : TextInputAction.done,
              onChanged: (_) {
                if (_phoneServerError != null) setState(() => _phoneServerError = null);
              },
            ),
            const SizedBox(height: 18),
            if (_usePassword) ...[
              DriverUi.label('auth.password'.tr()),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: DriverUi.text(14, weight: FontWeight.w500),
                decoration: DriverUi.input('auth.password'.tr(),
                    icon: Icons.lock_rounded,
                    errorText: _showErrors && _passwordCtrl.text.isEmpty
                        ? 'auth.field_required'.tr()
                        : null).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: DriverUi.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_error != null) ...[
              DriverMessageBanner(
                message: _error!,
                isError: _errorCode != 'PASSWORD_NOT_SET' && _errorCode != 'EMAIL_NOT_SET',
                actionLabel: action?.label,
                onAction: action?.action,
              ),
              const SizedBox(height: 14),
            ],
            DriverPrimaryButton(
              label: _usePassword ? 'driver_v2.login_btn'.tr() : 'driver_v2.receive_login_code'.tr(),
              icon: _usePassword ? Icons.login_rounded : Icons.verified_user_rounded,
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _usePassword = !_usePassword;
                  _error = null;
                  _errorCode = null;
                }),
                child: Text(
                  _usePassword ? 'driver_v2.use_code'.tr() : 'driver_v2.use_password'.tr(),
                  style: DriverUi.text(13, weight: FontWeight.w600, color: DriverUi.orange),
                ),
              ),
            ),
            const Divider(height: 28),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed(DriverSignupScreen.route),
                child: Text('driver_v2.no_account_yet'.tr(),
                    style: DriverUi.text(13, weight: FontWeight.w600, color: DriverUi.textPrimary)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                child: Text('driver_v2.client_login'.tr(),
                    style: DriverUi.text(12.5, color: DriverUi.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/driver_onboarding.dart';
import '../services/driver_account_store.dart';
import '../services/driver_onboarding_analytics.dart';
import '../services/driver_onboarding_api.dart';
import '../widgets/driver_onboarding_ui.dart';
import 'driver_login_screen.dart';
import 'driver_signup_screen.dart';

enum DriverOtpPurpose { register, login }

/// Informations de l'écran court, envoyées à `register` après le code.
class DriverRegistrationData {
  /// Adresse où le code a été envoyé : la même à verify et register.
  final String? email;
  final String firstName;
  final String lastName;
  final String city;
  final String vehicleType;
  final String? serviceId;

  const DriverRegistrationData({
    this.email,
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.vehicleType,
    this.serviceId,
  });
}

class DriverOtpArgs {
  final DriverOtpPurpose purpose;
  final String phone; // E.164
  final String country;
  final DriverOtpRequest otp;
  final int codeLength;
  final DriverRegistrationData? registration;

  const DriverOtpArgs({
    required this.purpose,
    required this.phone,
    required this.country,
    required this.otp,
    this.codeLength = 6,
    this.registration,
  });
}

/// Saisie du code reçu sur WhatsApp. Inscription : vérification du numéro
/// puis création du compte ; connexion : ouverture de la session. Ensuite,
/// aiguillage selon le statut du compte.
///
/// Inscription refusée pour une erreur de saisie : l'écran se ferme en
/// renvoyant les erreurs par champ au formulaire.
class DriverOtpScreen extends StatefulWidget {
  static const route = '/driver_otp';

  final DriverOtpArgs args;
  const DriverOtpScreen({super.key, required this.args});

  @override
  State<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends State<DriverOtpScreen> {
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  late DriverOtpRequest _otp = widget.args.otp;
  String? _verificationToken;

  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _errorCode;
  int _resendIn = 0;
  Timer? _timer;

  DriverOtpArgs get _args => widget.args;
  bool get _isRegister => _args.purpose == DriverOtpPurpose.register;

  @override
  void initState() {
    super.initState();
    _startResendCountdown(_otp.resendAfter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _resending) return;
    setState(() { _resending = true; _error = null; _errorCode = null; });
    try {
      final otp = await DriverOnboardingApi.sendOtp(
        phone: _args.phone,
        country: _args.country,
        purpose: _isRegister ? 'register' : 'login',
        email: _args.registration?.email,
      );
      if (!mounted) return;
      _otp = otp;
      _verificationToken = null;
      _codeCtrl.clear();
      _startResendCountdown(otp.resendAfter);
      _codeFocus.requestFocus();
    } on DriverApiException catch (e) {
      DriverOnboardingAnalytics.registrationError(step: 'otp_send', errorCode: e.code);
      if (!mounted) return;
      setState(() { _error = e.message; _errorCode = e.code; });
      final wait = e.retryAfter;
      if (wait != null && wait > 0) _startResendCountdown(wait);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != _args.codeLength || _verifying) return;
    setState(() { _verifying = true; _error = null; _errorCode = null; });
    var step = _isRegister ? 'otp_verify' : 'login';
    try {
      final DriverSession session;
      if (_isRegister) {
        // Le jeton reste valable si `register` échoue sur une erreur de saisie.
        final r = _args.registration!;
        _verificationToken ??= await DriverOnboardingApi.verifyOtp(
          phone: _args.phone,
          country: _args.country,
          email: r.email,
          requestId: _otp.requestId,
          code: code,
        );
        step = 'register';
        session = await DriverOnboardingApi.register(
          verificationToken: _verificationToken!,
          phone: _args.phone,
          country: _args.country,
          email: r.email,
          city: r.city,
          firstName: r.firstName,
          lastName: r.lastName,
          vehicleType: r.vehicleType,
          serviceId: r.serviceId,
        );
        DriverOnboardingAnalytics.accountCreated(
            country: _args.country, vehicleType: r.vehicleType);
        await DriverSignupScreen.clearDraft();
      } else {
        session = await DriverOnboardingApi.loginWithOtp(
          phone: _args.phone,
          country: _args.country,
          requestId: _otp.requestId,
          code: code,
        );
      }
      await DriverAccountStore.instance.startSession(session);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final nav = Navigator.of(context);
      final route = DriverAccountStore.routeFor(session.driver);
      nav.pushNamedAndRemoveUntil(route, (_) => false);
      // Compte à compléter : « Mon dossier » par-dessus l'app (retour possible),
      // pour envoyer les documents tout de suite.
      if (route == DriverAccountStore.routeMain && !session.driver.isActive) {
        nav.pushNamed(DriverAccountStore.routeDossier);
      }
    } on DriverApiException catch (e) {
      DriverOnboardingAnalytics.registrationError(step: step, errorCode: e.code);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _handleError(e);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _handleError(DriverApiException e) {
    switch (e.code) {
      case 'VERIFICATION_TOKEN_INVALID':
      case 'OTP_EXPIRED':
      case 'OTP_TOO_MANY_ATTEMPTS':
        // Il faut un nouveau code.
        _verificationToken = null;
        _codeCtrl.clear();
        if (_resendIn > 0 && e.code != 'OTP_TOO_MANY_ATTEMPTS') _startResendCountdown(0);
        break;
      case 'ACCOUNT_SUSPENDED':
        Navigator.of(context).pushNamedAndRemoveUntil(DriverAccountStore.routeSuspended, (_) => false);
        return;
      case 'VALIDATION_ERROR':
      case 'SERVICE_NOT_AVAILABLE':
        // Erreur de saisie à l'inscription : retour au formulaire, champs signalés.
        if (_isRegister && e.fieldErrors.isNotEmpty) {
          Navigator.of(context).pop(e.fieldErrors);
          return;
        }
        break;
      case 'OTP_INVALID':
        _codeCtrl.clear();
        _codeFocus.requestFocus();
        break;
    }
    setState(() { _error = e.message; _errorCode = e.code; });
  }

  ({String label, VoidCallback action})? get _errorAction {
    switch (_errorCode) {
      case 'PHONE_ALREADY_REGISTERED':
        return (
          label: 'driver_v2.go_login'.tr(),
          action: () => Navigator.of(context).pushReplacementNamed(
                DriverLoginScreen.route,
                arguments: DriverLoginArgs(phone: _args.phone, country: _args.country),
              ),
        );
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
      case 'EMAIL_NOT_SET':
        // Compte sans e-mail : seul le mot de passe permet de se connecter.
        return (
          label: 'driver_v2.use_password'.tr(),
          action: () => Navigator.of(context).pushReplacementNamed(
                DriverLoginScreen.route,
                arguments: DriverLoginArgs(phone: _args.phone, country: _args.country, usePassword: true),
              ),
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final action = _errorAction;
    // Code par e-mail (contrat du 14/10) : on montre l'adresse masquée renvoyée
    // par le serveur ; sinon (serveur pas encore à jour) le numéro WhatsApp.
    final byEmail = _otp.isEmail;
    final destination = byEmail ? (_otp.sentTo ?? _args.registration?.email ?? '') : _args.phone;
    final accent = byEmail ? DriverUi.orange : const Color(0xFF25D366);
    return DriverOnboardingScaffold(
      title: 'driver_v2.otp_title'.tr(),
      subtitle: byEmail ? 'driver_v2.otp_subtitle_email'.tr() : 'driver_v2.otp_subtitle'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(byEmail ? Icons.mark_email_unread_rounded : Icons.chat_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(TextSpan(
                  style: DriverUi.text(13, color: DriverUi.textSecondary, height: 1.4),
                  children: [
                    TextSpan(text: '${byEmail ? 'driver_v2.otp_sent_to_email'.tr() : 'driver_v2.otp_sent_to'.tr()}\n'),
                    // Adresse ou numéro isolé en LTR pour rester lisible en arabe.
                    TextSpan(
                      text: '\u2066$destination\u2069',
                      style: DriverUi.text(15, weight: FontWeight.w700),
                    ),
                  ],
                )),
              ),
            ],
          ),
          if (byEmail) ...[
            const SizedBox(height: 12),
            DriverMessageBanner(message: 'driver_v2.otp_spam_hint'.tr(), isError: false),
          ],
          const SizedBox(height: 24),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _codeCtrl,
              focusNode: _codeFocus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: _args.codeLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: DriverUi.text(28, weight: FontWeight.w800).copyWith(letterSpacing: 10),
              decoration: DriverUi.input('•' * _args.codeLength).copyWith(counterText: ''),
              onChanged: (v) {
                if (_error != null) setState(() { _error = null; _errorCode = null; });
                if (v.length == _args.codeLength) _verify();
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            DriverMessageBanner(
              message: _error!,
              actionLabel: action?.label,
              onAction: action?.action,
            ),
            const SizedBox(height: 14),
          ],
          DriverPrimaryButton(
            label: _isRegister ? 'driver_v2.create_my_account'.tr() : 'driver_v2.login_btn'.tr(),
            loading: _verifying,
            onPressed: _verify,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: (_resendIn > 0 || _resending) ? null : _resend,
              child: _resending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: DriverUi.orange))
                  : Text(
                      _resendIn > 0
                          ? 'driver_v2.resend_in'.tr(namedArgs: {'seconds': '$_resendIn'})
                          : 'driver_v2.resend'.tr(),
                      style: DriverUi.text(13,
                          weight: FontWeight.w600,
                          color: _resendIn > 0 ? DriverUi.textSecondary : DriverUi.orange),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

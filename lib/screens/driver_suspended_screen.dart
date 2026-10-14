import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/app_config.dart';
import '../core/constants/support_constants.dart';
import '../services/auth_service.dart';
import '../services/support_whatsapp.dart';
import '../widgets/driver_onboarding_ui.dart';

/// Compte chauffeur suspendu (ACCOUNT_SUSPENDED) : information et contact
/// du support. La connexion est refusée par le serveur tant que dure la
/// suspension.
class DriverSuspendedScreen extends StatelessWidget {
  static const route = '/driver_suspended';

  const DriverSuspendedScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    if (await SupportWhatsApp.open() || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('support_extra.wa_unavailable'.tr(namedArgs: {
        'number': '\u2066${SupportConstants.whatsAppDisplayNumber}\u2069',
      })),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'common.copy'.tr(),
        onPressed: () => Clipboard.setData(
            const ClipboardData(text: '+${SupportConstants.whatsAppNumber}')),
      ),
    ));
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/driver_login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: DriverOnboardingScaffold(
        title: 'driver_v2.suspended_title'.tr(),
        showBack: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: DriverUi.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pause_circle_outline_rounded, color: DriverUi.red, size: 40),
            ),
            const SizedBox(height: 18),
            Text('driver_v2.suspended_body'.tr(),
                textAlign: TextAlign.center,
                style: DriverUi.text(14, height: 1.6)),
            const SizedBox(height: 28),
            DriverPrimaryButton(
              label: 'support_extra.whatsapp_cta'.tr(),
              icon: Icons.chat_rounded,
              onPressed: () => _openWhatsApp(context),
            ),
            const SizedBox(height: 12),
            SelectableText(AppConfig.supportEmail,
                style: DriverUi.text(13, weight: FontWeight.w600, color: DriverUi.textSecondary)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _logout(context),
              child: Text('driver_v2.logout'.tr(),
                  style: DriverUi.text(13, weight: FontWeight.w600, color: DriverUi.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

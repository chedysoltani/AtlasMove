import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_gate_service.dart';

/// Par-dessus toute l'app (MaterialApp.builder, dans un Positioned.fill) :
/// écran « Mettre à jour », écran « Maintenance » ou bandeau de maintenance
/// pendant une course. Hors écran plein, les touchers passent à l'app dessous.
class AppGateOverlay extends StatelessWidget {
  const AppGateOverlay({super.key});

  static const _appStoreUrl = 'https://apps.apple.com/app/id6804859837';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.atlasmove.app';

  static const _dark = Color(0xFF0F172A);
  static const _orange = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppGateService.instance,
      builder: (context, _) {
        final gate = AppGateService.instance;
        switch (gate.mode) {
          case AppGateMode.none:
            return const SizedBox.shrink();
          case AppGateMode.maintenanceBanner:
            return _banner(context);
          case AppGateMode.forceUpdate:
            return _fullScreen(
              context,
              icon: Icons.system_update_rounded,
              title: 'app_gate.update_title'.tr(),
              body: 'app_gate.update_body'.tr(),
              action: FilledButton.icon(
                onPressed: _openStore,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text('app_gate.update_button'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            );
          case AppGateMode.maintenance:
            final eta = gate.maintenanceEta;
            return _fullScreen(
              context,
              icon: Icons.construction_rounded,
              title: 'app_gate.maintenance_title'.tr(),
              body: gate.maintenanceMessage(Localizations.localeOf(context).languageCode) ??
                  'app_gate.maintenance_body'.tr(),
              footnote: eta == null
                  ? 'app_gate.maintenance_auto'.tr()
                  : 'app_gate.maintenance_eta'.tr(namedArgs: {'time': eta}),
            );
        }
      },
    );
  }

  static Future<void> _openStore() async {
    try {
      await launchUrl(Uri.parse(Platform.isIOS ? _appStoreUrl : _playStoreUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Écran plein, opaque : rien n'est cliquable dessous.
  Widget _fullScreen(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    String? footnote,
    Widget? action,
  }) {
    return Material(
      color: _dark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/images/new_logo_mobile.png', width: 88, height: 88),
              ),
              const SizedBox(height: 28),
              Icon(icon, color: _orange, size: 36),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 15, height: 1.5)),
              if (footnote != null) ...[
                const SizedBox(height: 18),
                Text(footnote,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.4)),
              ],
              const Spacer(flex: 3),
              if (action != null) ...[action, const SizedBox(height: 24)],
            ],
          ),
        ),
      ),
    );
  }

  /// Bandeau en haut de l'écran : la course continue normalement.
  Widget _banner(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _dark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.construction_rounded, color: _orange, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('app_gate.maintenance_banner'.tr(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';

/// Explique et demande la permission de localisation « toujours » (arrière-plan)
/// au chauffeur, avant de la demander au système — Google Play et l'App Store
/// exigent cette explication pour l'accès en arrière-plan, et sans elle iOS/Android
/// affichent une simple pop-up système sans contexte, souvent refusée par réflexe.
///
/// N'est proposée qu'aux chauffeurs (le suivi pendant une course doit continuer
/// app fermée / verrouillée) et une seule fois par installation.
class LocationAlwaysPermissionSheet {
  LocationAlwaysPermissionSheet._();

  static const _shownKey = 'bg_location_permission_shown';

  /// Affiche l'explication si nécessaire (permission pas encore « toujours »,
  /// et jamais proposée sur cet appareil). Sans effet sinon.
  static Future<void> promptIfNeeded(BuildContext context) async {
    final status = await LocationService().backgroundPermissionStatus();
    if (status.isGranted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;
    await prefs.setBool(_shownKey, true);

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _Sheet(),
    );
  }

  /// Rouvre l'explication à la demande (ex. bouton dans le profil chauffeur),
  /// même si elle a déjà été montrée.
  static Future<void> show(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        isDismissible: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _Sheet(),
      );
}

class _Sheet extends StatefulWidget {
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _requesting = false;

  Future<void> _handleAllow() async {
    setState(() => _requesting = true);
    final result = await LocationService().requestBackgroundLocationPermission();
    if (!mounted) return;
    setState(() => _requesting = false);

    if (result.isGranted) {
      Navigator.of(context).pop();
      return;
    }
    if (result.isPermanentlyDenied) {
      _showSettingsPrompt();
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('location_always.later_notice'.tr())),
    );
  }

  void _showSettingsPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('location_always.settings_title'.tr()),
        content: Text('location_always.settings_body'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              LocationService().openAppSettings();
            },
            child: Text('location_always.open_settings'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded, color: Color(0xFFFF6600), size: 32),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'location_always.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'location_always.body'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _requesting ? null : _handleAllow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _requesting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('location_always.allow'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _requesting ? null : () => Navigator.of(context).pop(),
              child: Text('location_always.not_now'.tr(),
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }
}

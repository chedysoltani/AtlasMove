import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/support_constants.dart';
import '../core/storage/token_storage.dart';

/// Conversation WhatsApp avec le support (page Support, « Mon dossier »,
/// compte suspendu), avec un message prérempli : type de compte, identifiant,
/// version, plateforme — pour que le support retrouve le compte.
class SupportWhatsApp {
  SupportWhatsApp._();

  /// App WhatsApp (ou WhatsApp Business), sinon wa.me dans le navigateur.
  /// Renvoie false si rien n'a pu s'ouvrir : à l'appelant d'afficher le numéro.
  static Future<bool> open() async {
    final uri = SupportConstants.whatsAppUri(await message());
    if (await _tryLaunch(uri, LaunchMode.externalNonBrowserApplication)) return true;
    return _tryLaunch(uri, LaunchMode.externalApplication);
  }

  static Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('WhatsApp launch error ($mode): $e');
      return false;
    }
  }

  static Future<String> message() async {
    final lines = <String>['support_extra.wa_greeting'.tr()];
    try {
      final loggedIn = await TokenStorage.hasSession() &&
          !await TokenStorage.wasExplicitlyLoggedOut();
      if (loggedIn) {
        final role = await TokenStorage.getUserRole();
        final userId = await TokenStorage.getUserId();
        if (role != null && role.isNotEmpty) {
          final roleLabel = (role == 'delivery' || role == 'driver')
              ? 'rdv.driver'.tr()
              : 'auth.client'.tr();
          lines.add('support_extra.wa_role'.tr(namedArgs: {'role': roleLabel}));
        }
        if (userId != null && userId.isNotEmpty) {
          lines.add('support_extra.wa_user_id'.tr(namedArgs: {'id': userId}));
        }
      } else {
        lines.add('support_extra.wa_not_logged_in'.tr());
      }
    } catch (_) {}
    try {
      final info = await PackageInfo.fromPlatform();
      lines.add('support_extra.wa_version'.tr(
          namedArgs: {'version': '${info.version} (${info.buildNumber})'}));
    } catch (_) {}
    lines.add('support_extra.wa_platform'.tr(namedArgs: {
      'platform': Platform.isIOS
          ? 'iOS'
          : Platform.isAndroid ? 'Android' : Platform.operatingSystem,
    }));
    return lines.join('\n');
  }
}

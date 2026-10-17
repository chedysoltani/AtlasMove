import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_token_service.dart';

class LocaleProvider extends ChangeNotifier {
  static const _key = 'selected_locale';

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
    Locale('it'),
    Locale('de'),
    Locale('es'),
  ];

  static const localeNames = {
    'fr': 'Français',
    'en': 'English',
    'ar': 'العربية',
    'it': 'Italiano',
    'de': 'Deutsch',
    'es': 'Español',
  };

  static const localeFlags = {
    'fr': '🇫🇷',
    'en': '🇬🇧',
    'ar': '🇸🇦',
    'it': '🇮🇹',
    'de': '🇩🇪',
    'es': '🇪🇸',
  };

  /// Langue choisie, lisible sans await (en-tête Accept-Language des requêtes API).
  /// Chargée au démarrage par getSavedLocale(), mise à jour par saveLocale().
  static String _currentCode = 'fr';
  static String get currentCode => _currentCode;

  static Future<Locale> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'fr';
    _currentCode = code;
    return Locale(code);
  }

  static Future<void> saveLocale(String code) async {
    _currentCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  static Future<void> changeLocale(BuildContext context, Locale locale) async {
    await saveLocale(locale.languageCode);
    await context.setLocale(locale);
    // Le backend localise les push selon la langue de l'appareil enregistrée
    unawaited(DeviceTokenService().syncRegistration());
  }

  static bool isRtl(Locale locale) => locale.languageCode == 'ar';
}

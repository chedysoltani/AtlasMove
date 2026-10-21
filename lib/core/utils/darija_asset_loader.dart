import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Traductions de l'app, avec la darija algérienne (`ar-DZ.json`) et
/// marocaine (`ar-MA.json`) posées sur l'arabe standard (`ar.json`) : une clé
/// absente ou vide dans le fichier darija affiche l'arabe standard, jamais un
/// texte vide. Les autres langues se chargent comme avant.
class DarijaAssetLoader extends RootBundleAssetLoader {
  const DarijaAssetLoader();

  static const darijaCountries = {'DZ', 'MA'};

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    if (locale.languageCode != 'ar' || !darijaCountries.contains(locale.countryCode)) {
      return super.load(path, locale);
    }
    final base = await super.load(path, const Locale('ar')) ?? <String, dynamic>{};
    try {
      final darija = await super.load(path, locale);
      if (darija != null) return overlay(base, darija);
    } catch (e) {
      debugPrint('Darija ${locale.countryCode} : $e');
    }
    return base;
  }

  /// [base] complété par les textes non vides de [top], section par section.
  static Map<String, dynamic> overlay(Map<String, dynamic> base, Map<String, dynamic> top) {
    final result = Map<String, dynamic>.of(base);
    top.forEach((key, value) {
      final current = result[key];
      if (value is Map && current is Map) {
        result[key] = overlay(Map<String, dynamic>.from(current), Map<String, dynamic>.from(value));
      } else if (value is String && value.trim().isNotEmpty) {
        result[key] = value;
      }
    });
    return result;
  }
}

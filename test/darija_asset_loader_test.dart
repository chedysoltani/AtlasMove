import 'dart:convert';
import 'dart:io';

import 'package:atlasmove/core/utils/darija_asset_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Darija posée sur l\'arabe standard', () {
    final base = {
      'driver_v2': {'trust_title': 'وثائقك محمية', 'trust_secure': 'محفوظة بشكل آمن'},
      'common': {'retry': 'إعادة المحاولة'},
    };

    test('clé vide ou absente : arabe standard', () {
      final merged = DarijaAssetLoader.overlay(base, {
        'driver_v2': {'trust_title': '', 'trust_secure': '   '},
      });
      expect(merged, base);
    });

    test('clé remplie : texte darija', () {
      final merged = DarijaAssetLoader.overlay(base, {
        'driver_v2': {'trust_title': 'الوثائق ديالك محمية'},
      });
      expect((merged['driver_v2'] as Map)['trust_title'], 'الوثائق ديالك محمية');
      expect((merged['driver_v2'] as Map)['trust_secure'], 'محفوظة بشكل آمن');
      expect((merged['common'] as Map)['retry'], 'إعادة المحاولة');
    });

    test('fichiers ar-DZ et ar-MA : mêmes clés que l\'arabe, aucune clé inconnue', () {
      Map<String, dynamic> read(String name) =>
          jsonDecode(File('assets/translations/$name.json').readAsStringSync());
      final ar = read('ar')['driver_v2'] as Map<String, dynamic>;
      for (final name in ['ar-DZ', 'ar-MA']) {
        final darija = read(name)['driver_v2'] as Map<String, dynamic>;
        expect(darija.keys.where((k) => !ar.containsKey(k)), isEmpty, reason: name);
      }
    });
  });
}

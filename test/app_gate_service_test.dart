import 'package:atlasmove/services/app_gate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Comparaison de versions', () {
    test('ordre numérique, pas alphabétique', () {
      expect(AppGateService.compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(AppGateService.compareVersions('1.0.10', '1.0.9'), greaterThan(0));
      expect(AppGateService.compareVersions('1.0.8', '1.0.8'), 0);
    });

    test('numéro de build ignoré, parties manquantes = 0', () {
      expect(AppGateService.compareVersions('1.0.8+20', '1.0.8'), 0);
      expect(AppGateService.compareVersions('1.1', '1.1.0'), 0);
      expect(AppGateService.compareVersions('2', '1.9.9'), greaterThan(0));
    });

    test('défaut « 0.0.0 » : aucune version imposée', () {
      expect(AppGateService.compareVersions('1.0.8', '0.0.0'), greaterThan(0));
      expect(AppGateService.compareVersions('1.0.8', ''), greaterThan(0));
    });
  });

  group('Décision', () {
    AppGateMode decide({bool maintenance = false, bool update = false, bool onTrip = false}) =>
        AppGateService.decide(maintenance: maintenance, updateNeeded: update, onTrip: onTrip);

    test('rien à faire : app normale', () {
      expect(decide(), AppGateMode.none);
    });

    test('mise à jour obligatoire : écran bloquant, sauf en course', () {
      expect(decide(update: true), AppGateMode.forceUpdate);
      expect(decide(update: true, onTrip: true), AppGateMode.none);
    });

    test('maintenance : écran bloquant, simple bandeau en course', () {
      expect(decide(maintenance: true), AppGateMode.maintenance);
      expect(decide(maintenance: true, onTrip: true), AppGateMode.maintenanceBanner);
    });

    test('maintenance prioritaire sur la mise à jour', () {
      expect(decide(maintenance: true, update: true), AppGateMode.maintenance);
    });
  });

  group('Message de maintenance de la console', () {
    test('vide : texte par défaut de l\'app', () {
      expect(AppGateService.pickMessage('', 'fr'), isNull);
      expect(AppGateService.pickMessage('   ', 'ar'), isNull);
    });

    test('texte simple : affiché tel quel dans toutes les langues', () {
      expect(AppGateService.pickMessage('Retour à 15h', 'ar'), 'Retour à 15h');
    });

    test('JSON par langue, repli sur le français', () {
      const raw = '{"fr": "Maintenance jusqu\'à 15h", "ar": "صيانة حتى الساعة 15"}';
      expect(AppGateService.pickMessage(raw, 'ar'), 'صيانة حتى الساعة 15');
      expect(AppGateService.pickMessage(raw, 'de'), "Maintenance jusqu'à 15h");
    });

    test('JSON illisible : texte par défaut', () {
      expect(AppGateService.pickMessage('{pas du json', 'fr'), isNull);
    });
  });
}

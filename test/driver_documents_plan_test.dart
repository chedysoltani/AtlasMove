import 'package:atlasmove/models/driver_onboarding.dart';
import 'package:atlasmove/services/driver_documents_plan.dart';
import 'package:flutter_test/flutter_test.dart';

DriverDocument _doc(String type, {String? stage}) => DriverDocument(
    type: type, label: type, required: true, status: DriverDocumentStatus.missing, stage: stage);

void main() {
  final docs = [
    _doc('selfie'),
    _doc('driving_license'),
    _doc('vehicle_registration'),
  ];

  group('Documents progressifs', () {
    test('par défaut (Remote Config absent) : variante A, flag désactivé', () {
      final plan = DriverDocumentsPlan.current;
      expect(plan.variant, DriverDocumentsPlan.variantA);
      final split = plan.split(docs);
      expect(split.start, docs);
      expect(split.later, isEmpty);
    });

    test('variante A : tous les documents ensemble', () {
      const plan = DriverDocumentsPlan(variant: 'A', startTypes: {'driving_license'});
      expect(plan.split(docs).later, isEmpty);
    });

    test('variante B : types de départ d\'abord, le reste plus tard, ordre du serveur', () {
      const plan = DriverDocumentsPlan(variant: 'B', startTypes: {'vehicle_registration', 'driving_license'});
      final split = plan.split(docs);
      expect(split.start.map((d) => d.type), ['driving_license', 'vehicle_registration']);
      expect(split.later.map((d) => d.type), ['selfie']);
    });

    test('variante B avec un type inconnu : retombe sur tous les documents', () {
      const plan = DriverDocumentsPlan(variant: 'B', startTypes: {'cin_recto'});
      final split = plan.split(docs);
      expect(split.start, docs);
      expect(split.later, isEmpty);
    });

    test('variante B, étapes données par le serveur : priorité sur Remote Config', () {
      final serverDocs = [
        _doc('id_card', stage: 'start'),
        _doc('driving_license', stage: 'start'),
        _doc('vehicle_registration', stage: 'later'),
        _doc('selfie', stage: 'later'),
      ];
      const plan = DriverDocumentsPlan(variant: 'B', startTypes: {'selfie'});
      final split = plan.split(serverDocs);
      expect(split.start.map((d) => d.type), ['id_card', 'driving_license']);
      expect(split.later.map((d) => d.type), ['vehicle_registration', 'selfie']);
    });

    test('variante A : étapes du serveur ignorées, une seule liste', () {
      const plan = DriverDocumentsPlan(variant: 'A');
      final split = plan.split([_doc('id_card', stage: 'start'), _doc('selfie', stage: 'later')]);
      expect(split.later, isEmpty);
    });

    test('liste Remote Config illisible : aucun type', () {
      expect(DriverDocumentsPlan.parseTypes('["driving_license", " id_front "]'),
          {'driving_license', 'id_front'});
      expect(DriverDocumentsPlan.parseTypes('driving_license'), isEmpty);
      expect(DriverDocumentsPlan.parseTypes('{"a": 1}'), isEmpty);
    });
  });
}

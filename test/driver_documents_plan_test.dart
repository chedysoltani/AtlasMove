import 'package:atlasmove/models/driver_onboarding.dart';
import 'package:atlasmove/services/driver_documents_plan.dart';
import 'package:flutter_test/flutter_test.dart';

DriverDocument _doc(String type) =>
    DriverDocument(type: type, label: type, required: true, status: DriverDocumentStatus.missing);

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

    test('liste Remote Config illisible : aucun type', () {
      expect(DriverDocumentsPlan.parseTypes('["driving_license", " id_front "]'),
          {'driving_license', 'id_front'});
      expect(DriverDocumentsPlan.parseTypes('driving_license'), isEmpty);
      expect(DriverDocumentsPlan.parseTypes('{"a": 1}'), isEmpty);
    });
  });
}

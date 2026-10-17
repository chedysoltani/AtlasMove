import 'dart:convert';

import 'package:atlasmove/core/network/http_client.dart';
import 'package:atlasmove/services/rendezvous_service.dart';
import 'package:atlasmove/widgets/driver_dossier_gate.dart';
import 'package:flutter_test/flutter_test.dart';

ForbiddenException _forbidden(Map<String, dynamic> body) => ForbiddenException(
      'forbidden',
      HttpResponse(statusCode: 403, body: jsonEncode(body), headers: const {}),
    );

void main() {
  group('DriverDossierGate.blockCode', () {
    test('lit le code au premier niveau', () {
      final e = _forbidden({
        'statusCode': 403,
        'code': 'COMMISSION_UNPAID',
        'error': {'code': 'commission_unpaid'},
      });
      expect(DriverDossierGate.blockCode(e), DriverDossierGate.commissionUnpaid);
    });

    test("se replie sur error.code, même en minuscules", () {
      final e = _forbidden({'error': {'code': 'subscription_required'}});
      expect(DriverDossierGate.blockCode(e), DriverDossierGate.subscriptionRequired);
    });

    test('reconnaît DOCUMENTS_REQUIRED', () {
      final e = _forbidden({'code': 'DOCUMENTS_REQUIRED'});
      expect(DriverDossierGate.isDocumentsRequired(e), isTrue);
    });

    test('garde le code à travers RendezvousException', () {
      final e = RendezvousException.from(_forbidden({'code': 'SERVICE_NOT_ASSIGNED'}));
      expect(e.statusCode, 403);
      expect(DriverDossierGate.blockCode(e), DriverDossierGate.serviceNotAssigned);
    });

    test("ignore une erreur sans code ou qui n'est pas une erreur d'API", () {
      expect(DriverDossierGate.blockCode(_forbidden({'message': 'x'})), isNull);
      expect(DriverDossierGate.blockCode(Exception('réseau')), isNull);
    });
  });
}

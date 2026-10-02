import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:atlasmove/core/utils/permission_gate.dart';

void main() {
  test('deux demandes simultanées sont exécutées l\'une après l\'autre, jamais en parallèle', () async {
    var running = 0;
    var maxParallel = 0;
    final order = <String>[];

    Future<String> request(String name, int ms) async {
      running++;
      if (running > maxParallel) maxParallel = running;
      order.add('start $name');
      await Future<void>.delayed(Duration(milliseconds: ms));
      order.add('end $name');
      running--;
      return name;
    }

    // Notifications puis localisation, lancées au même instant (le cas du login)
    final results = await Future.wait([
      PermissionGate.run(() => request('notifications', 60)),
      PermissionGate.run(() => request('location', 10)),
    ]);

    expect(results, ['notifications', 'location']);
    expect(maxParallel, 1, reason: 'Android n\'accepte qu\'une demande à la fois');
    expect(order, ['start notifications', 'end notifications', 'start location', 'end location']);
  });

  test('une demande jamais résolue n\'affame pas la file (timeout + valeur de repli)', () async {
    final never = Completer<int>();
    final first = PermissionGate.run<int>(
      () => never.future,
      timeout: const Duration(milliseconds: 50),
      onTimeout: -1,
    );
    final second = PermissionGate.run<int>(() async => 42);

    expect(await first, -1);
    expect(await second, 42);
  });

  test('sans valeur de repli, le timeout lève une TimeoutException et la file continue', () async {
    final never = Completer<int>();
    await expectLater(
      PermissionGate.run<int>(() => never.future, timeout: const Duration(milliseconds: 30)),
      throwsA(isA<TimeoutException>()),
    );
    expect(await PermissionGate.run<int>(() async => 7), 7);
  });
}

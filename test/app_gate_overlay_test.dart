import 'package:atlasmove/services/app_gate_service.dart';
import 'package:atlasmove/widgets/app_gate_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'app « dessous » : un bouton qui compte les touchers, puis l'overlay
/// placé comme dans main.dart (Positioned.fill dans le Stack du builder).
Widget _app(ValueNotifier<int> taps) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => taps.value++, child: const Text('app')),
        ),
      ),
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const Positioned.fill(child: AppGateOverlay()),
        ],
      ),
    );

void main() {
  final gate = AppGateService.instance;
  tearDown(() => gate.debugMode = AppGateMode.none);

  testWidgets('aucun blocage : l\'app reste utilisable', (tester) async {
    final taps = ValueNotifier(0);
    gate.debugMode = AppGateMode.none;
    await tester.pumpWidget(_app(taps));
    await tester.tap(find.text('app'));
    expect(taps.value, 1);
  });

  testWidgets('mise à jour obligatoire : écran plein, rien de cliquable dessous', (tester) async {
    final taps = ValueNotifier(0);
    gate.debugMode = AppGateMode.forceUpdate;
    await tester.pumpWidget(_app(taps));
    expect(find.text('app_gate.update_button'), findsOneWidget);
    await tester.tap(find.text('app'), warnIfMissed: false);
    expect(taps.value, 0);
  });

  testWidgets('maintenance : écran plein, rien de cliquable dessous', (tester) async {
    final taps = ValueNotifier(0);
    gate.debugMode = AppGateMode.maintenance;
    await tester.pumpWidget(_app(taps));
    expect(find.text('app_gate.maintenance_title'), findsOneWidget);
    await tester.tap(find.text('app'), warnIfMissed: false);
    expect(taps.value, 0);
  });

  testWidgets('maintenance en course : bandeau, l\'app reste utilisable', (tester) async {
    final taps = ValueNotifier(0);
    gate.debugMode = AppGateMode.maintenanceBanner;
    await tester.pumpWidget(_app(taps));
    expect(find.text('app_gate.maintenance_banner'), findsOneWidget);
    await tester.tap(find.text('app'));
    expect(taps.value, 1);
  });

  testWidgets('fin de maintenance : l\'écran disparaît tout seul', (tester) async {
    final taps = ValueNotifier(0);
    gate.debugMode = AppGateMode.maintenance;
    await tester.pumpWidget(_app(taps));
    gate.debugMode = AppGateMode.none;
    await tester.pump();
    expect(find.text('app_gate.maintenance_title'), findsNothing);
    await tester.tap(find.text('app'));
    expect(taps.value, 1);
  });
}

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/widgets/pilot_console_content.dart';
import 'package:demon_attack/widgets/power_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [240.0, 296.0, 366.0, 520.0, 760.0, 1100.0]) {
    testWidgets('console contains powers left of guidance at $width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var dragDistance = 0.0;
      Future<void> show(Map<Power, double> timers) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'monospace'),
          home: Scaffold(
            body: Center(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerMove: (event) => dragDistance += event.delta.dx,
                child: SizedBox(
                  key: const ValueKey('console-bounds'),
                  width: width,
                  height: 94,
                  child: PilotConsoleContent(
                    timers: timers,
                    touching: false,
                    collecting: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await show({});
      final guidanceBefore = tester.getRect(
        find.byKey(const ValueKey('controller-guidance')),
      );
      for (final pair in [
        {Power.spread: 9.0, Power.rapid: 8.0, Power.shield: 7.0},
        {Power.large: 9.0, Power.powerful: 8.0, Power.shield: 7.0},
      ]) {
        await show(pair);
        final bounds = tester.getRect(
          find.byKey(const ValueKey('console-bounds')),
        );
        final status = tester.getRect(find.byType(PowerStatus));
        final guidance = tester.getRect(
          find.byKey(const ValueKey('controller-guidance')),
        );
        expect(status.left, greaterThanOrEqualTo(bounds.left));
        expect(status.top, greaterThanOrEqualTo(bounds.top));
        expect(status.bottom, lessThanOrEqualTo(bounds.bottom));
        expect(status.right, lessThan(guidance.left));
        expect(guidance.right, lessThanOrEqualTo(bounds.right));
        expect(guidance, guidanceBefore);
        for (final power in pair.keys) {
          final timer = tester.getRect(
            find.byKey(ValueKey('power-time-${power.name}')),
          );
          expect(timer.left, greaterThanOrEqualTo(bounds.left));
          expect(timer.right, lessThan(guidance.left));
          expect(timer.bottom, lessThanOrEqualTo(bounds.bottom));
        }
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('combined-power-glyph'))),
          const Offset(25, 0),
        );
        expect(dragDistance, greaterThan(0));
        expect(tester.takeException(), isNull);
      }
    });
  }
}

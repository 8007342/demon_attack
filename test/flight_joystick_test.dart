import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/widgets/flight_joystick.dart';
import 'package:demon_attack/widgets/flight_joystick_atlas.dart';
import 'package:demon_attack/widgets/pilot_console_content.dart';
import 'package:demon_attack/widgets/power_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(WidgetTester tester, Offset target, {bool reduce = false}) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 80,
            height: 92,
            child: FlightJoystick(target: target, reduceMotion: reduce),
          ),
        ),
      ),
    );

FlightJoystickState _state(WidgetTester tester) =>
    tester.state<FlightJoystickState>(find.byType(FlightJoystick));

void main() {
  group('atlas', () {
    test('the page holds every pose at the generated cell size', () async {
      final bytes = File(FlightJoystickAtlas.asset).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      const poses =
          1 +
          FlightJoystickAtlas.directions *
              3; // rest + dirs x tilts (tiltDegrees)
      expect(FlightJoystickAtlas.tiltDegrees, hasLength(3));
      expect(
        img.width,
        FlightJoystickAtlas.cellWidth * FlightJoystickAtlas.columns,
      );
      expect(
        img.height,
        FlightJoystickAtlas.cellHeight *
            (poses / FlightJoystickAtlas.columns).ceil(),
      );
      // small enough for mobile: one page, well under 64 KB on the wire
      expect(bytes.length, lessThan(64 * 1024));
    });
  });

  group('cell', () {
    test('rests inside the dead zone', () {
      expect(flightJoystickCell(Offset.zero), 0);
      expect(flightJoystickCell(const Offset(.03, -.02)), 0);
    });

    test('directions: 0 right, 90 forward, 180 left, 270 back', () {
      const d = FlightJoystickAtlas.directions;
      // full tilt is the third step: cells 1 + 2d + k
      expect(flightJoystickCell(const Offset(1, 0)), 1 + 2 * d + 0);
      expect(flightJoystickCell(const Offset(0, 1)), 1 + 2 * d + 2);
      expect(flightJoystickCell(const Offset(-1, 0)), 1 + 2 * d + 4);
      expect(flightJoystickCell(const Offset(0, -1)), 1 + 2 * d + 6);
      expect(flightJoystickCell(const Offset(.7, .7)), 1 + 2 * d + 1);
    });

    test('the tilt step follows the speed', () {
      const d = FlightJoystickAtlas.directions;
      expect(flightJoystickCell(const Offset(-.2, 0)), 1 + 4); // 9°
      expect(flightJoystickCell(const Offset(-.55, 0)), 1 + d + 4); // 18°
      expect(flightJoystickCell(const Offset(-.95, 0)), 1 + 2 * d + 4); // 27°
      // reduced motion leans by the first step only
      expect(flightJoystickCell(const Offset(-1, 0), maxTilt: 1), 1 + 4);
    });
  });

  group('target', () {
    test('rests when the ship is still at cruise', () {
      final m = ArcadeModel()..mode = RunMode.playing;
      expect(flightJoystickTarget(m), Offset.zero);
    });

    test('x is the lateral speed over the top speed', () {
      final m = ArcadeModel()..mode = RunMode.playing;
      m.shipVx = -180;
      expect(flightJoystickTarget(m).dx, closeTo(-.5, 1e-9));
      m.shipVx = 360;
      expect(flightJoystickTarget(m).dx, 1);
    });

    test('y is the forward surge: the carrier climb boost pushes forward', () {
      final m = ArcadeModel()..mode = RunMode.playing;
      expect(flightJoystickTarget(m, boost: 1).dy, 0);
      expect(flightJoystickTarget(m, boost: 1.6).dy, closeTo(.5, 1e-9));
      expect(flightJoystickTarget(m, boost: 2.2).dy, 1);
    });
  });

  group('widget', () {
    testWidgets('eases out to the lean and back to rest, then idles', (
      tester,
    ) async {
      await _show(tester, Offset.zero);
      expect(_state(tester).cell, 0);
      await _show(tester, const Offset(-1, 0));
      expect(_state(tester).cell, 0, reason: 'eased: not there at once');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      final early = _state(tester).shown.dx;
      expect(early, inExclusiveRange(-1, 0));
      await tester.pumpAndSettle();
      expect(_state(tester).cell, 1 + 2 * FlightJoystickAtlas.directions + 4);
      await _show(tester, Offset.zero);
      await tester.pumpAndSettle(); // the ticker stops at rest
      expect(_state(tester).cell, 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion snaps and leans by one step', (tester) async {
      await _show(tester, const Offset(1, 0), reduce: true);
      expect(_state(tester).cell, 1);
      expect(tester.hasRunningAnimations, isFalse);
      await _show(tester, Offset.zero, reduce: true);
      expect(_state(tester).cell, 0);
    });

    testWidgets('the console sets the stick between powers and guidance', (
      tester,
    ) async {
      for (final width in [240.0, 366.0, 760.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                key: const ValueKey('console-bounds'),
                width: width,
                height: 94,
                child: PilotConsoleContent(
                  timers: const {Power.spread: 9},
                  touching: false,
                  collecting: false,
                  joystick: const Offset(.5, 0),
                ),
              ),
            ),
          ),
        );
        final bounds = tester.getRect(
          find.byKey(const ValueKey('console-bounds')),
        );
        final stick = tester.getRect(
          find.byKey(const ValueKey('controller-stick')),
        );
        final power = tester.getRect(find.byType(PowerStatus));
        final guidance = tester.getRect(
          find.byKey(const ValueKey('controller-guidance')),
        );
        expect(power.right, lessThan(stick.left));
        expect(stick.right, lessThan(guidance.left));
        expect(stick.top, greaterThanOrEqualTo(bounds.top));
        expect(stick.bottom, lessThanOrEqualTo(bounds.bottom));
        expect(guidance.right, lessThanOrEqualTo(bounds.right));
        expect(find.text(PilotConsoleContent.guidance), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}

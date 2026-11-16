import 'package:demon_attack/game/arena_camera.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/ship_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// boss-grandeur §3.1: the arena camera's gameplay-safety rules.
void main() {
  group('zoom transform', () {
    test('touch round trip: the four corners and the ship', () {
      for (final z in [1.0, .94, .9, ArenaCamera.minZoom]) {
        final cam = ArenaCamera()..zoom = z;
        for (final p in const [
          Offset(0, 0),
          Offset(360, 0),
          Offset(0, 520),
          Offset(360, 520),
          Offset(180, ArcadeModel.shipY),
          Offset(42, ArcadeModel.shipY),
        ]) {
          final back = cam.toArena(cam.toScreen(p));
          expect((back - p).distance, lessThan(1e-9), reason: 'z $z at $p');
        }
        // The pivot is the ship row: a thumb on the ship never drifts.
        expect(cam.toScreen(const Offset(180, ArcadeModel.shipY)),
            const Offset(180, ArcadeModel.shipY));
        expect(cam.toScreen(const Offset(80, ArcadeModel.shipY)).dy,
            ArcadeModel.shipY);
        // A drag the ship follows exactly on screen.
        expect(cam.deltaToArena(10 * z), closeTo(10, 1e-9));
      }
    });

    test('the gameplay matrix is the zoom about (180, shipY)', () {
      final cam = ArenaCamera()..zoom = .9;
      final m = cam.gameplayMatrix;
      const p = Offset(37, 120);
      final s = Offset(m[0] * p.dx + m[4] * p.dy + m[12],
          m[1] * p.dx + m[5] * p.dy + m[13]);
      expect((s - cam.toScreen(p)).distance, lessThan(1e-9));
    });

    test('target zoom clamps to [0.86, 1] and grows with range and swerve', () {
      expect(ArenaCamera.targetZoom(range: 0, swerve: 0, altitude: 1), 1);
      expect(ArenaCamera.targetZoom(range: 9, swerve: 9, altitude: 9),
          ArenaCamera.minZoom);
      final a = ArenaCamera.targetZoom(range: .5, swerve: 0, altitude: 1.3);
      final b = ArenaCamera.targetZoom(range: 1, swerve: 1, altitude: 1.3);
      expect(b, lessThan(a));
    });

    test('rate limit 0.05/s, holds during threats, eases back in', () {
      final cam = ArenaCamera();
      for (var i = 0; i < 60; i++) {
        final before = cam.zoom;
        cam.stepZoom(1 / 60, ArenaCamera.minZoom);
        expect(before - cam.zoom, lessThanOrEqualTo(.05 / 60 + 1e-12));
      }
      final moving = cam.zoom;
      expect(moving, lessThan(1));
      cam.stepZoom(1 / 60, ArenaCamera.minZoom, hold: true);
      expect(cam.zoom, greaterThanOrEqualTo(moving));
      for (var i = 0; i < 600; i++) {
        cam.stepZoom(1 / 60, ArenaCamera.minZoom, hold: true);
      }
      expect(cam.zoom, closeTo(1, 1e-6));
    });

    test('reduced motion: one static framing, never below 0.94', () {
      final cam = ArenaCamera();
      for (var i = 0; i < 600; i++) {
        cam.stepZoom(1 / 60, ArenaCamera.minZoom, reduced: true);
        expect(cam.zoom, greaterThanOrEqualTo(ArenaCamera.reducedZoom - 1e-9));
      }
      expect(cam.zoom, closeTo(ArenaCamera.reducedZoom, 1e-9));
    });
  });

  test('phone readability floors at the minimum zoom (360 CSS px arena)', () {
    const z = ArenaCamera.minZoom;
    // A fighting creature at the formation's far row, the ship, the
    // smallest enemy bullet (5 × 7 units with its glow).
    final creature = 44 * Perspective.scaleOf(Perspective.nearTop) * z;
    expect(creature, greaterThanOrEqualTo(34));
    expect(ShipPainter.size * z, greaterThanOrEqualTo(36));
    expect(5 * z, greaterThanOrEqualTo(3));
  });

  group('carrier band (boss-carrier-wire, boss-hero-assets §8.3)', () {
    test('target zoom runs in [0.70, 0.86]: engage framing, full spread', () {
      expect(
        ArenaCamera.targetZoom(range: 0, swerve: 0, altitude: 1, carrier: true),
        ArenaCamera.carrierMaxZoom,
      );
      expect(
        ArenaCamera.targetZoom(range: 1, swerve: 1, altitude: 1.6, carrier: true),
        closeTo(ArenaCamera.carrierMinZoom, 1e-9),
      );
      expect(
        ArenaCamera.targetZoom(range: 9, swerve: 9, altitude: 9, carrier: true),
        ArenaCamera.carrierMinZoom,
      );
    });

    test('same rate limit; a hold eases back to the engage framing, not 1', () {
      final cam = ArenaCamera();
      for (var i = 0; i < 60 * 12; i++) {
        final before = cam.zoom;
        cam.stepZoom(1 / 60, ArenaCamera.carrierMinZoom, carrier: true);
        expect(before - cam.zoom, lessThanOrEqualTo(.05 / 60 + 1e-12));
      }
      expect(cam.zoom, closeTo(ArenaCamera.carrierMinZoom, 1e-6));
      // (eased: the hold creeps back in at the slow end of the rate.)
      for (var i = 0; i < 60 * 40; i++) {
        cam.stepZoom(1 / 60, ArenaCamera.carrierMinZoom, hold: true, carrier: true);
        expect(cam.zoom, lessThanOrEqualTo(ArenaCamera.carrierMaxZoom + 1e-9));
      }
      expect(cam.zoom, closeTo(ArenaCamera.carrierMaxZoom, 1e-6));
      // Reduced motion: one static framing.
      final r = ArenaCamera();
      for (var i = 0; i < 60 * 10; i++) {
        r.stepZoom(1 / 60, ArenaCamera.carrierMinZoom, reduced: true, carrier: true);
      }
      expect(r.zoom, closeTo(ArenaCamera.carrierReducedZoom, 1e-9));
    });

    test('phone floors at 0.70 hold as draw-size floors', () {
      final cam = ArenaCamera()..zoom = ArenaCamera.carrierMinZoom;
      final far = 44 * Perspective.scaleOf(Perspective.nearTop);
      expect(far * cam.zoom, lessThan(ArenaCamera.creatureFloor),
          reason: 'the floor binds here');
      expect(far * cam.zoom * cam.floorScale(far, ArenaCamera.creatureFloor),
          greaterThanOrEqualTo(ArenaCamera.creatureFloor - 1e-9));
      expect(
          ShipPainter.size * cam.zoom *
              cam.floorScale(ShipPainter.size, ArenaCamera.shipFloor),
          greaterThanOrEqualTo(ArenaCamera.shipFloor - 1e-9));
      expect(5 * cam.zoom, greaterThanOrEqualTo(ArenaCamera.bulletFloor));
      // Above the band's floor nothing is scaled.
      cam.zoom = 1;
      expect(cam.floorScale(far, ArenaCamera.creatureFloor), 1);
    });
  });

  test('background follow: far layers move less than near ones', () {
    final cam = ArenaCamera()
      ..fx = 24
      ..fy = 0
      ..followStrength = 1;
    final horizon = cam.backgroundPoint(const Offset(180, GroundCamera.horizon));
    final near = cam.backgroundPoint(const Offset(180, 520));
    const k = 1 + ArenaCamera.overscan; // the overscan about the centre
    expect(horizon.dx - 180, closeTo(24 * .3 * k, 1e-9));
    expect(near.dx - 180, closeTo(24 * k, 1e-9));
    // The pan never uncovers the frame: the overscan covers it.
    final left = cam.backgroundPoint(const Offset(0, 520));
    expect(left.dx, lessThanOrEqualTo(0));
  });

  test('altitude: the ground stretches about the horizon (farther, slower)', () {
    final cam = ArenaCamera()..altitude = 1.5;
    final p = cam.backgroundPoint(const Offset(180, 300));
    expect(p.dy, closeTo(GroundCamera.horizon + 1.5 * (300 - GroundCamera.horizon), 1e-9));
    expect(cam.backgroundPoint(const Offset(180, GroundCamera.horizon)).dy,
        closeTo(GroundCamera.horizon, 1e-9));
  });

  test('hitbox invariance: a scripted boss fight is identical at Z 1 and 0.86', () {
    // The pilot drags in screen space; the drag maps through the camera, so
    // on screen the ship follows the finger and in the arena it moves the
    // same units at every zoom: every hit, miss, spawn and shot is equal.
    List<String> fight(double z) {
      final cam = ArenaCamera()..zoom = z;
      final m = ArcadeModel(seed: 77)..startAt(sector: 5, route: 1, wave: 3);
      final log = <String>[];
      for (var f = 0; f < 60 * 40; f++) {
        if (m.combat) {
          final b = m.boss;
          final want = b?.x ?? 180;
          final screenDrag = (want - m.targetX) * z * .2; // finger on screen
          m.moveBy(cam.deltaToArena(screenDrag));
          m.invulnerable = 2;
        }
        m.update(1 / 60);
        for (final e in m.takeEvents()) {
          log.add('$f:$e:${m.shots.length}:${m.demons.length}:${m.boss?.shield}:${m.boss?.core}');
        }
      }
      return log;
    }

    final a = fight(1), b = fight(ArenaCamera.minZoom);
    expect(fight(ArenaCamera.carrierMinZoom), a, reason: 'the carrier band');
    expect(a, isNotEmpty);
    expect(a.where((e) => e.contains(':hit:')), isNotEmpty);
    expect(b, a);
  });
}

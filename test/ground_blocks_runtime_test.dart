import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_blocks_atlas.dart';
import 'package:demon_attack/game/ground_blocks_cast.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_heading.dart';
import 'package:demon_attack/game/ground_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runtime half of the ground block contract (openspec changes
/// ground-blocks-runtime and ground-forces-rework task 7.2): the cast, every
/// cell the painter can request, the turn tracker, turret seating, and
/// gameplay parity with the old atlases.

const _review = String.fromEnvironment(
  'GROUND_BLOCKS_REVIEW_DIR',
  defaultValue: '.cache/ground-blocks-review',
);

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Map<String, ui.Image>> _atlases(int sector) async => {
      for (final f in GroundBlocksLayer.files(sector))
        f.substring('ground-blocks/'.length):
            await _decode('assets/images/$f'),
    };

/// Every state the painter asks `GroundBlockCells.state` / `.hull` for.
const _states = [
  'move', 'walk', 'idle', 'special', 'wreck', 'rubble', 'fall', 'arrive',
  'totalled', 'pod', 'aim', 'fire', 'hit', 'run', 'flourish', 'pitchUp',
  'pitchDown', 'ford', 'air',
];
const _overlays = ['lights', 'dmg1', 'dmg2', 'fill1', 'fill2', 'fill3'];

typedef _Px = ({Uint8List rgba, int width});

Future<_Px> _pixels(ui.Image img) async {
  final b = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (rgba: b.buffer.asUint8List(), width: img.width);
}

bool _opaque(_Px px, int x, int y) =>
    x >= 0 && px.rgba[(y * px.width + x) * 4 + 3] > 0;

void main() {
  group('cast', () {
    test('every role of every sector is cast from that sector', () {
      for (var s = 0; s < GroundBlocks.sectors.length; s++) {
        final name = GroundBlocksCast.sectorName(s);
        for (final role in GroundCastRole.values) {
          for (var id = 0; id < 8; id++) {
            final u = GroundBlocksCast.unitFor(role, s,
                id: id, member: id % 3, members: 4, variant: id);
            expect(u, isNotNull, reason: '$role in $name');
            expect(GroundBlocks.placement[name]!.containsKey(u), isTrue,
                reason: '$u is not packed in $name');
          }
        }
      }
      // The threat front keeps its sector vehicles.
      expect([for (var s = 0; s < 5; s++) GroundBlocksCast.unitFor(GroundCastRole.threat, s)],
          ['spout-runner', 'scrapmason', 'kiln-ox', 'belfry', 'belfry']);
      for (var s = 0; s < 5; s++) {
        for (final id in GroundBlocksCast.skirmishRoster(GroundBlocksCast.sectorName(s))) {
          expect(GroundBlocks.units[id]!.threat, isFalse);
          expect(GroundBlocks.units[id]!.faction, 'host');
        }
      }
    });

    test('every cell the painter can request exists in every sector', () {
      var checked = 0;
      for (var s = 0; s < GroundBlocks.sectors.length; s++) {
        final sector = GroundBlocksCast.sectorName(s);
        for (final id in GroundBlocksCast.castable(s)) {
          final cells = GroundBlockCells(id);
          final u = cells.unit;
          void must(String name) {
            checked++;
            expect(GroundBlocks.cell(sector, name), isNotNull,
                reason: '$name in $sector');
          }

          for (var k = 0; k < u.headings.length; k++) {
            expect(cells.moveFrames(k), greaterThan(0), reason: '$id h$k');
            for (final st in _states) {
              for (var f = 0; f < 8; f++) {
                must(cells.hull(st, k, f));
                must(cells.state(st, k, f).$1);
              }
            }
            for (final o in _overlays) {
              final n = cells.hullOverlay(o, k);
              if (n != null) must(n);
            }
          }
          for (var a = 0; a < u.angles.length; a++) {
            for (final fire in [false, true]) {
              for (var e = 0; e < 3; e++) {
                must(cells.art(a, fire: fire, elevation: e));
              }
            }
            for (final o in [..._overlays, 'dent']) {
              final n = cells.artOverlay(o, a);
              if (n != null) must(n);
            }
          }
          for (var p = 0; p < u.pieces.length; p++) {
            must(cells.debris(p ~/ 6)!);
          }
          // State frames the painter relies on.
          if (u.threat) {
            expect(cells.frames('special', cells.headingOf('special')!),
                greaterThanOrEqualTo(4), reason: '$id telegraph frames');
          }
          if (u.faction == 'host' && u.block != 'I') {
            expect(cells.headingOf(u.block == 'K' ? 'fall' : 'wreck'), isNotNull,
                reason: id);
            expect(cells.headingOf('rubble'), isNotNull, reason: id);
          }
          if (u.faction == 'fleet' && u.block != 'I') {
            expect(cells.frames('totalled', 0), 4, reason: id);
            expect(cells.frames('pod', 0), 2, reason: id);
          }
          if (u.block == 'I') {
            for (final st in ['aim', 'fire', 'hit', 'fall', 'idle', 'run']) {
              expect(cells.headingOf(st), isNotNull, reason: '$id $st');
            }
          }
        }
      }
      expect(checked, greaterThan(10000));
    });

    test('a missing overlay has no name (draws nothing)', () {
      // The Cairn's lights face away from the camera at 0°.
      expect(GroundBlockCells('cairn').hullOverlay('lights', 0), isNull);
      expect(GroundBlockCells('cairn').hullOverlay('lights', 1), isNotNull);
      expect(GroundBlockCells('crocket').artOverlay('fill1', 0), isNull);
    });
  });

  group('GroundHeading', () {
    GroundHeading tracker(String id, {double? initial}) {
      final u = GroundBlocks.units[id]!;
      return GroundHeading(u.headings, GroundBlocks.turn[u.unitClass]!,
          initial: initial);
    }

    /// Drives [h] with a velocity at [angle] (degrees) for [seconds]; returns
    /// (time, shown) for every step.
    List<(double, double)> drive(GroundHeading h, double Function(double t) angle,
        double seconds, {double t0 = 0, double speed = 40}) {
      final out = <(double, double)>[];
      const dt = 1 / 60;
      for (var t = t0; t < t0 + seconds; t += dt) {
        final a = angle(t) * 3.141592653589793 / 180;
        if (h.update(dt, lateral: speed * math.sin(a), depth: speed * math.cos(a)) != 0) {
          out.add((t, h.shown));
        }
      }
      return out;
    }

    test('a heavy turns 90° through every heading in 1.0-1.4 s', () {
      final h = tracker('lodestar', initial: 0);
      expect(drive(h, (_) => 0, 1), isEmpty);
      final steps = drive(h, (_) => 90, 3, t0: 1);
      expect([for (final s in steps) s.$2], [22.5, 45, 67.5, 90]);
      expect(steps.last.$1 - 1, inInclusiveRange(1.0, 1.4));
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i].$1 - steps[i - 1].$1, greaterThanOrEqualTo(.2 - 1e-9));
      }
    });

    test('never skips a heading and holds each step for minHold', () {
      for (final id in ['sleet', 'lodestar', 'stilt', 'crocket', 'chapterhouse',
          'ashlar', 'trooper-rifle']) {
        final u = GroundBlocks.units[id]!;
        final hold = GroundBlocks.turn[u.unitClass]!.minHold;
        final h = tracker(id);
        // A violent swerve: the travel direction jumps around every 0.7 s.
        final steps = drive(h, (t) => const <double>[-170, 170, 20, -60, 130, -10][(t / .7).floor() % 6], 12);
        expect(steps, isNotEmpty, reason: id);
        var prev = (-1.0, h.ring.unwrap(GroundHeadingRing.signed(0)));
        final ring = [for (final s in h.ring.steps) GroundHeadingRing.signed(s.u)];
        var last = -1;
        for (final (t, shown) in steps) {
          final i = ring.indexOf(shown);
          if (last >= 0) expect((i - last).abs(), 1, reason: '$id skipped at $t');
          if (prev.$1 >= 0) {
            expect(t - prev.$1, greaterThanOrEqualTo(hold - 1e-9), reason: id);
          }
          last = i;
          prev = (t, shown);
        }
      }
    });

    test('deterministic for the same input', () {
      List<(double, double)> run() =>
          drive(tracker('tympanum'), (t) => 180 - 120 * math.sin(t * 1.3), 10);
      expect(run(), run());
    });

    test('a wobble of ±5° around a midpoint does not flicker', () {
      for (final (wobble, label) in [
        ((double t) => 11.25 + 5 * math.sin(t * 2 * 3.141592653589793 * 4), '4 Hz'),
        ((double t) => 11.25 + ((t * 60).round().isEven ? 5.0 : -5.0), 'per frame'),
      ]) {
        final h = tracker('sleet', initial: 0);
        expect(drive(h, (_) => 11.25, 2), isEmpty);
        expect(drive(h, wobble, 6, t0: 2), isEmpty, reason: label);
        expect(h.shown, 0);
      }
    });

    test('the Host turns through the mirrored half past 180°', () {
      final h = tracker('crocket', initial: 180);
      final steps = drive(h, (_) => -90, 3);
      expect([for (final s in steps) s.$2], [-157.5, -135, -112.5, -90]);
      expect(h.mirror, isTrue);
      expect(h.index, 0);
    });

    test('targets behind the arc clamp to the nearer end', () {
      final h = tracker('crocket', initial: 135);
      drive(h, (_) => 10, 3); // up the plane, to the right
      expect(h.shown, 90);
      final f = tracker('lodestar', initial: 0);
      drive(f, (_) => -150, 3);
      expect(f.shown, -90);
    });

    test('level of detail shows every other heading beyond 1200', () {
      final h = tracker('lodestar', initial: 22.5);
      expect(h.index, 1);
      expect(GroundBlocksLayer.hullShown(h, 800), (1, false));
      final (k, _) = GroundBlocksLayer.hullShown(h, 1250);
      expect(k.isEven, isTrue);
      final a = GroundHeading(GroundBlocks.units['lodestar']!.angles,
          GroundBlocks.turn['heavy']!, layer: true, initial: 67.5);
      expect(GroundBlocksLayer.artShown(a, (1, false), 1000, [0, 22.5, 45, 67.5, 90],
              [0, 22.5, 45, 67.5, 90]).$1.isEven,
          isTrue);
      expect(GroundBlocksLayer.artShown(a, (1, false), 1300, [0, 22.5, 45, 67.5, 90],
              [0, 22.5, 45, 67.5, 90]),
          (1, false));
      expect(GroundBlocksLayer.nearDetail(899), isTrue);
      expect(GroundBlocksLayer.nearDetail(900), isFalse);
    });

    test('a convoy vehicle falling back drives in reverse', () {
      final layer = GroundBlocksLayer();
      final t = GroundBlockTrack(Object(), GroundBlockCells('lodestar'));
      var z = 400.0;
      for (var f = 0; f < 120; f++) {
        layer.begin(f / 60);
        layer.observe(t, 200, z, reversible: true);
        z -= 1.5; // toward the camera
      }
      expect(t.reverse, isTrue);
      expect(t.hull.shown.abs(), lessThan(23));
    });
  });

  testWidgets('turret seating for every heading and layer angle', (tester) async {
    await tester.runAsync(() async {
      // Placement goes through the painter's own helpers (topLeft, pivotAt)
      // at scale 1: the layer's texels around its pivot must lie on (or
      // within one texel of) the hull, for every hull heading, layer angle
      // and mirror combination ("driving one way, aiming another").
      final done = <String>{};
      var pairs = 0;
      for (var s = 0; s < GroundBlocks.sectors.length; s++) {
        final sector = GroundBlocksCast.sectorName(s);
        final images = <String, _Px>{};
        for (final MapEntry(key: id) in GroundBlocks.placement[sector]!.entries) {
          final u = GroundBlocks.units[id]!;
          if (u.angles.isEmpty || !done.add(id)) continue;
          final cells = GroundBlockCells(id);
          Future<(_Px, int, int)> at(String name) async {
            final ref = GroundBlocks.cell(sector, name)!;
            final px = images[ref.file] ??=
                await _pixels(await _decode('assets/images/ground-blocks/${ref.file}'));
            final rowH = ref.h == 80 ? 40 : ref.h;
            return (px, ref.col * ref.w, ref.row * rowH);
          }

          final w = u.cellW.toDouble();
          for (var k = 0; k < u.headings.length; k++) {
            final (hp, hx0, hy0) = await at(cells.hull('move', k, 0));
            for (final hm in [false, true]) {
              final htl = GroundBlocksLayer.topLeft(w, u.origin, hm, 0, 0, 1);
              final hl = htl.dx.round(), ht = htl.dy.round();
              bool hullAt(int sx, int sy) {
                var x = sx - hl;
                final y = sy - ht;
                if (hm) x = u.cellW - 1 - x;
                return x >= 0 && y >= 0 && x < u.cellW && y < u.cellH &&
                    _opaque(hp, hx0 + x, hy0 + y);
              }

              final pv = GroundBlocksLayer.pivotAt(u, k, hm, 0, 0, 1);
              for (var a = 0; a < u.angles.length; a++) {
                final (ap, ax0, ay0) = await at(cells.art(a));
                for (final am in [false, true]) {
                  final atl =
                      GroundBlocksLayer.topLeft(w, u.artPivot, am, pv.dx, pv.dy, 1);
                  final al = atl.dx.round(), at0 = atl.dy.round();
                  var near = 0;
                  var seated = false;
                  final cx = pv.dx.floor(), cy = pv.dy.floor();
                  for (var sy = cy - 2; sy <= cy + 2 && !seated; sy++) {
                    for (var sx = cx - 2; sx <= cx + 2 && !seated; sx++) {
                      var x = sx - al;
                      final y = sy - at0;
                      if (am) x = u.cellW - 1 - x;
                      if (x < 0 || y < 0 || x >= u.cellW || y >= u.cellH) continue;
                      if (!_opaque(ap, ax0 + x, ay0 + y)) continue;
                      near++;
                      for (var dy = -1; dy <= 1 && !seated; dy++) {
                        for (var dx = -1; dx <= 1 && !seated; dx++) {
                          seated = hullAt(sx + dx, sy + dy);
                        }
                      }
                    }
                  }
                  pairs++;
                  final tag = '$id h$k${hm ? "m" : ""} a$a${am ? "m" : ""}';
                  expect(near, greaterThan(0), reason: '$tag: no layer at its pivot');
                  expect(seated, isTrue, reason: '$tag: layer floats off the hull');
                }
              }
            }
          }
        }
      }
      expect(pairs, greaterThan(1000));
    });
  });

  testWidgets('painter requests resolve in every sector; gameplay unchanged',
      (tester) async {
    await tester.runAsync(() async {
      final legacy = await _decode('assets/images/${GroundAtlas.file}');
      final troops = await _decode('assets/images/${GroundTroopsAtlas.file}');
      for (var sector = 1; sector <= 5; sector++) {
        final fingerprints = <bool, List<Object>>{};
        for (final on in [true, false]) {
          GroundPainter.useBlocks = on;
          final m = ArcadeModel(seed: 1982)..startAt(sector: sector);
          final scene = DemonScene(m, () {});
          scene.groundForces
            ..image = legacy
            ..troops = troops;
          if (on) {
            scene.groundForces.blocks
              ..install(sector - 1, await _atlases(sector - 1))
              ..requested = {}
              ..requestedOverlays = {};
          }
          var next = 0.0;
          for (var f = 0; f < 60 * 45; f++) {
            if (m.combat) {
              m.invulnerable = 2;
              if (m.levelClock >= next) {
                next = m.levelClock + 2.6;
                final t = m.demons.where((x) => !x.entering).firstOrNull;
                if (t != null) m.hitDemon(t, damage: 99);
              }
              m.shipX = m.targetX = 180 + 120 * ((f / 600) % 2 < 1 ? 1 : -1) *
                  (((f / 600) % 1) - .5).abs();
            }
            m.update(1 / 60);
            if (f % 2 == 0) {
              final r = ui.PictureRecorder();
              scene.groundForces.paintGround(ui.Canvas(r), m);
              r.endRecording().dispose();
            }
          }
          fingerprints[on] = [
            m.score, m.ground.unitsSpawned, m.ground.engagements,
            for (final u in m.ground.units) (u.id, u.z, u.x, u.hp, u.destroyed),
            for (final a in m.ground.allies) (a.id, a.z, a.x, a.hp, a.totalled),
          ];
          if (on) {
            final b = scene.groundForces.blocks;
            final name = GroundBlocksCast.sectorName(sector - 1);
            expect(b.requested, isNotEmpty, reason: 'sector $sector drew no blocks');
            for (final n in {...b.requested!, ...b.requestedOverlays!}) {
              expect(GroundBlocks.cell(name, n), isNotNull, reason: '$n in $name');
            }
            final units = {for (final n in b.requested!) n.split('.').first};
            // ignore: avoid_print
            print('L$sector blocks drawn: ${units.toList()..sort()} '
                '(${b.requested!.length} cells, ${b.requestedOverlays!.length} overlays)');
          }
        }
        expect(fingerprints[true], fingerprints[false],
            reason: 'sector $sector: blocks changed the simulation');
      }
      GroundPainter.useBlocks = true;
    });
  });

  testWidgets('review frames from the blocks', (tester) async {
    await tester.runAsync(() async {
      for (var sector = 1; sector <= 5; sector++) {
        final m = ArcadeModel(seed: 1982)..startAt(sector: sector);
        final scene = DemonScene(m, () {});
        for (var i = 0; i < 5; i++) {
          scene.sectors.images[i] = await _decode('assets/images/sector-${i + 1}.png');
        }
        await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
        scene.sectors.flyover.reducedMotionOverride = false;
        scene.atlas = await _decode('assets/images/combat.png');
        scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
        scene.ship.image = await _decode('assets/images/ship-weapons.png');
        scene.groundForces
          ..image = await _decode('assets/images/${GroundAtlas.file}')
          ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}')
          ..blocks.install(sector - 1, await _atlases(sector - 1));
        scene.environment = sector - 1.0;
        var next = 0.0;
        for (var f = 0; f < 60 * 40; f++) {
          if (m.combat) {
            m.invulnerable = 2;
            if (m.levelClock >= next) {
              next = m.levelClock + 2.6;
              final t = m.demons.where((x) => !x.entering).firstOrNull;
              if (t != null) m.hitDemon(t, damage: 99);
            }
            m.shipX = m.targetX = 180 + 120 * ((f / 600) % 2 < 1 ? 1 : -1) *
                (((f / 600) % 1) - .5).abs();
          }
          scene.sectors.advance(1 / 60, m, scene.environment);
          m.update(1 / 60);
          final r = ui.PictureRecorder();
          scene.groundForces.paintGround(ui.Canvas(r), m);
          r.endRecording().dispose();
          if (f > 60 * 20 &&
              m.ground.tracers.isNotEmpty &&
              m.ground.units.where((u) => u.alive && u.z < 800).length >= 2) {
            break;
          }
        }
        for (final (w, h, tag) in [(360, 780, 'portrait'), (1280, 720, 'wide'), (720, 1040, 'ground'), (720, 1040, 'ground-legacy')]) {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
              ui.Paint()..color = const ui.Color(0xFF000000));
          if (tag.startsWith('ground')) {
            GroundPainter.useBlocks = tag == 'ground';
            // The ground layer alone at 2x on flat grey: the units unfogged.
            canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
                ui.Paint()..color = const ui.Color(0xFF5A6070));
            canvas.scale(2);
            scene.groundForces.paintGround(canvas, m);
            GroundPainter.useBlocks = true;
          } else {
            scene.paintArena(canvas, Vector2(w.toDouble(), h.toDouble()));
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(w, h);
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final file = File('$_review/l$sector-$tag.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      }
    });
  });
}


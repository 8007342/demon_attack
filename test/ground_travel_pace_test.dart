// Ground travel pace (openspec change ground-travel-pace): skirmish units
// and the convoy travel slower, the threat front keeps its clocks, and a
// legged unit's walk cycle follows the ground it covers (feet plant).
import 'dart:math' as math;

import 'package:demon_attack/game/ground_blocks_atlas.dart';
import 'package:demon_attack/game/ground_blocks_cast.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_painter.dart';
import 'package:demon_attack/game/ground_presentation.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

ArcadeModel fly(int sector, double seconds,
    {bool v4 = true,
    Difficulty d = Difficulty.normal,
    int route = 0,
    void Function(ArcadeModel m)? each}) {
  SkirmishFront.enabled = v4;
  try {
    final m = ArcadeModel(seed: 1982)
      ..startAt(difficulty: d, sector: sector, route: route);
    for (var f = 0; f < (seconds * 60).round() && m.level == sector; f++) {
      if (m.combat) m.invulnerable = 2;
      m.update(1 / 60);
      each?.call(m);
    }
    return m;
  } finally {
    SkirmishFront.enabled = true;
  }
}

void main() {
  group('travel', () {
    test('skirmish units at the skirmish pace, walkers slower, threats at 1',
        () {
      expect(GroundV4Tuning.skirmishPace, .6);
      expect(GroundV4Tuning.walkerPace, .45);
      final paces = <String, Set<double>>{};
      // Hollow (sector index 3) fields the Buttress Strider and the
      // Chapterhouse as skirmish vehicles (now and then: vehicles are one
      // draw in six there), so fly it at every difficulty and route.
      for (final d in Difficulty.values) {
        for (final r in const [0, 1]) {
          fly(4, 150, d: d, route: r, each: (m) {
            for (final u in m.ground.units) {
              final key = !u.skirmish
                  ? 'threat'
                  : GroundV4Tuning.walks(u.force, u.sector, u.id)
                      ? 'walker'
                      : 'skirmish';
              (paces[key] ??= {}).add(u.travelPace);
            }
          });
        }
      }
      expect(paces['threat'], {1.0});
      expect(paces['skirmish'], {GroundV4Tuning.skirmishPace});
      expect(paces['walker'], {GroundV4Tuning.walkerPace});
    });

    test('walkers are the skirmish vehicles cast as W or K blocks', () {
      for (var sector = 0; sector < 5; sector++) {
        for (var id = 0; id < 12; id++) {
          final cast = GroundBlocksCast.unitFor(
              GroundCastRole.skirmishVehicle, sector,
              id: id);
          final legged = cast != null &&
              GroundPace.isWalker(GroundBlocks.units[cast]!);
          expect(GroundV4Tuning.walks(GroundForce.vehicle, sector, id), legged,
              reason: '$sector/$id $cast');
          expect(GroundV4Tuning.walks(GroundForce.infantry, sector, id), false);
        }
      }
    });

    test('a skirmish unit approaches at the paced speed', () {
      final seen = <int, (double, double)>{};
      var checked = 0;
      fly(2, 40, each: (m) {
        for (final u in m.ground.units) {
          if (!u.skirmish || !u.alive) continue;
          final p = seen[u.id];
          seen[u.id] = (m.levelClock, u.z);
          if (p == null || u.z <= u.holdZ + 1 || m.levelClock - p.$1 <= 0) {
            continue;
          }
          final v = (p.$2 - u.z) / (m.levelClock - p.$1);
          final want = GroundV4Tuning.approach(u.force) *
              u.travelPace *
              m.policy.hostileRate;
          expect(v, closeTo(want, want * .02), reason: '${u.force}');
          checked++;
        }
      });
      expect(checked, greaterThan(100));
    });

    test('the threat front keeps its clocks (telegraphs, launches)', () {
      // Every threat unit's spawn, telegraph and launch times and its depth
      // each second: identical with the skirmish layer on and off.
      List<String> clocks(bool v4) {
        final out = <String>[];
        final state = <GroundUnit, String>{};
        fly(3, 150, v4: v4, each: (m) {
          for (final u in m.ground.units) {
            if (u.skirmish) continue;
            final s = '${u.telegraphing}/${u.shotsLeft}/${u.destroyed}';
            if (state[u] != s) {
              state[u] = s;
              out.add('${m.levelClock.toStringAsFixed(3)} '
                  'z ${u.z.toStringAsFixed(2)} $s');
            }
          }
        });
        return out;
      }

      final off = clocks(false), on = clocks(true);
      expect(off.length, greaterThan(10));
      expect(on, off);
    });
  });

  group('feet plant', () {
    test('the walk cycle advances with the ground covered', () {
      final layer = GroundBlocksLayer();
      final unit = GroundBlocksCast.unitFor(GroundCastRole.demonRifle, 0)!;
      final track = GroundBlockTrack(Object(), GroundBlockCells(unit));
      const dt = 1 / 60;
      var x = 120.0, z = 900.0, covered = 0.0;
      double? px, py;
      for (var f = 0; f < 60 * 6; f++) {
        layer.begin(f * dt);
        // An approach toward the camera with a sidestep.
        z -= 25 * dt;
        x += (f < 180 ? 4 : -3) * dt;
        layer.observe(track, x, z);
        final s = GroundCamera.texel(z) * GroundTuning.unitScale *
            GroundSize.trooper;
        layer.gaitOf(track, s, z);
        final y = GroundCamera.yOf(z);
        if (px != null) {
          covered += math.sqrt(math.pow(x - px, 2) + math.pow(y - py!, 2)) / s;
        }
        px = x;
        py = y;
        layer.end();
      }
      // Cell texels the feet stepped through vs the ground covered.
      expect(track.gait * GroundStride.trooper, closeTo(covered, covered * .01));
      expect(track.gait, greaterThan(1), reason: 'it visibly walks');
    });

    test('never faster than the authored cadence', () {
      final layer = GroundBlocksLayer();
      final track = GroundBlockTrack(Object(), GroundBlockCells('strider'));
      const dt = 1 / 60;
      var x = 40.0;
      for (var f = 0; f < 120; f++) {
        layer.begin(f * dt);
        x += 120 * dt; // far faster than any walker travels
        layer.observe(track, x, 600);
        layer.gaitOf(track, .5, 600);
      }
      expect(track.gait, lessThanOrEqualTo(GroundStride.maxWalker * 2 + 1e-9));
    });

    test('in play, marching troopers slide far less than with the clock gait',
        () {
      // Per marching second: ground covered vs the ground the feet stepped
      // through (cell texels), for the clock-driven W1 gait (8 fps x 0.5
      // over 4 frames) and the distance-locked one.
      final layer = GroundBlocksLayer();
      final tracks = <int, GroundBlockTrack>{};
      final last = <int, (double, double)>{};
      var covered = 0.0, slide = 0.0, clockSlide = 0.0;
      var f = 0;
      fly(3, 90, each: (m) {
        layer.begin(f++ / 60);
        for (final u in m.ground.units) {
          if (!u.skirmish || !u.alive || u.force != GroundForce.infantry) {
            continue;
          }
          final moving = u.z > u.holdZ + 1 || u.vx.abs() > 2;
          final t = tracks.putIfAbsent(
              u.id,
              () => GroundBlockTrack(
                  u,
                  GroundBlockCells(GroundBlocksCast.unitFor(
                      GroundCastRole.demonRifle, u.sector,
                      id: u.id)!)));
          layer.observe(t, u.x, u.z);
          final s = GroundPainter.drawScale(u) * GroundPainter.troopScale;
          final before = t.gait;
          final g = layer.gaitOf(t, s, u.z);
          final y = GroundCamera.yOf(u.z);
          final p = last[u.id];
          last[u.id] = (u.x, y);
          if (p == null || !moving) continue;
          final d = math.sqrt(
                  math.pow(u.x - p.$1, 2) + math.pow(y - p.$2, 2)) /
              s;
          covered += d;
          slide += (d - (g - before).abs() * GroundStride.trooper).abs();
          clockSlide +=
              (d - 8 * GroundPace.anim / 4 / 60 * GroundStride.trooper).abs();
        }
        layer.end();
      });
      final slideBefore = clockSlide / covered, slideAfter = slide / covered;
      // ignore: avoid_print
      print('marching troopers: covered ${covered.toStringAsFixed(0)} cell '
          'texels; clock gait slide ${(slideBefore * 100).toStringAsFixed(0)} %, '
          'distance-locked slide ${(slideAfter * 100).toStringAsFixed(0)} %');
      expect(slideAfter, lessThan(.1));
      expect(slideAfter, lessThan(slideBefore / 3));
    });
  });
}

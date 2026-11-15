import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/easter_eggs.dart';
import 'package:demon_attack/game/flyover_background.dart';
import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_atlas.dart';
import 'package:demon_attack/game/ground_blocks_cast.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/ground_wildlife_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/vegetation_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ground easter eggs (openspec change ground-easter-eggs,
/// plan/ground-easter-eggs.md): the budget, suppression, the flock, the
/// assets the eggs draw, and simulation parity with the eggs on and off.

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
    f.substring('ground-blocks/'.length): await _decode('assets/images/$f'),
};

/// A model in combat, past the opening protection.
ArcadeModel _playing() {
  final m = ArcadeModel(seed: 1982)..startAt(sector: 1);
  for (var i = 0; i < 60 * 12 && !(m.combat && m.invulnerable <= 0); i++) {
    m.update(1 / 60);
  }
  m.ground.units.clear();
  m.ground.missiles.clear();
  m.shots.clear();
  for (final d in m.demons) {
    d.dive = 0;
    d.telegraph = 0;
  }
  return m;
}

void main() {
  group('budget', () {
    List<bool> sequence(int seed) {
      final b = EasterEggBudget(seed: seed);
      return [
        for (var i = 0; i < 300; i++) ...[
          b.request(EasterEgg.flock, key: i, band: i % 2),
          b.request(EasterEgg.jackpot, key: i * 3, band: (i + 1) % 2),
          () {
            b.tick(7);
            return b.running > 0;
          }(),
        ],
      ];
    }

    test('deterministic from the run seed', () {
      expect(sequence(1982), sequence(1982));
      expect(sequence(1982), isNot(sequence(7)));
      final a = EasterEggBudget(seed: 5), b = EasterEggBudget(seed: 5);
      for (var k = 0; k < 50; k++) {
        expect(a.roll(EasterEgg.dance, k), b.roll(EasterEgg.dance, k));
        expect(a.pick(EasterEgg.flock, k, 1, 5, 9), inInclusiveRange(5, 9));
      }
    });

    test('rarities are the operator defaults', () {
      final b = EasterEggBudget();
      for (final (egg, p) in [
        (EasterEgg.dance, 1 / 3),
        (EasterEgg.jackpot, 1 / 8),
        (EasterEgg.flock, 2 / 5),
        (EasterEgg.jig, 1 / 4),
      ]) {
        final rule = EasterEggBudget.rules[egg]!;
        var hits = 0;
        const n = 20000;
        for (var k = 0; k < n; k++) {
          if (b.roll(egg, k) * rule.den < rule.num) hits++;
        }
        expect(hits / n, closeTo(p, .02), reason: '$egg');
      }
      expect(EasterEggBudget.rules[EasterEgg.dance]!.cooldown, 40);
      expect(EasterEggBudget.rules[EasterEgg.jackpot]!.cooldown, 20);
      expect(EasterEggBudget.rules[EasterEgg.flock]!.cooldown, 12);
      expect(EasterEggBudget.rules[EasterEgg.jig]!.cooldown, 60);
      expect(EasterEggBudget.rules[EasterEgg.critters]!.cooldown, 8);
      for (final r in EasterEggBudget.rules.entries) {
        expect(
          r.value.duration,
          lessThanOrEqualTo(r.key == EasterEgg.sectorDance ? 3 : 2.5),
        );
      }
    });

    test('one per band, two on screen, cooldowns', () {
      final b = EasterEggBudget()..alwaysRoll = true;
      expect(b.request(EasterEgg.flock, key: 1, band: 0), isTrue);
      expect(
        b.request(EasterEgg.critters, key: 2, band: 0),
        isFalse,
        reason: 'band 0 is busy',
      );
      expect(b.request(EasterEgg.critters, key: 3, band: 1), isTrue);
      expect(b.running, 2);
      expect(
        b.request(EasterEgg.jackpot, key: 4, band: 1),
        isFalse,
        reason: 'two on screen',
      );
      b.tick(2.6);
      expect(b.running, 0);
      expect(
        b.request(EasterEgg.flock, key: 5, band: 1),
        isFalse,
        reason: 'flock cooldown 12 s',
      );
      expect(
        b.request(EasterEgg.critters, key: 6, band: 0),
        isTrue,
        reason: 'critter cooldown is per band',
      );
      b.tick(2.6);
      expect(
        b.request(EasterEgg.critters, key: 7, band: 1),
        isFalse,
        reason: 'band 1 critters cooled down 5.2 s of 8',
      );
      b.tick(3);
      expect(b.request(EasterEgg.critters, key: 8, band: 1), isTrue);
      b.tick(7);
      expect(b.request(EasterEgg.flock, key: 9, band: 0), isTrue);
      // A decision is asked once per owner.
      final owner = Object();
      b.tick(30);
      final first = b.decide(owner, EasterEgg.jackpot, key: 1, band: 0);
      b.tick(.1);
      expect(b.decide(owner, EasterEgg.jackpot, key: 1, band: 0), first);
      expect(b.decided(owner, EasterEgg.jackpot), first);
    });

    test('debris counts per breakup', () {
      final b = EasterEggBudget();
      for (var id = 0; id < 200; id++) {
        expect(b.debrisPieces(id, light: true), inInclusiveRange(5, 8));
        expect(b.debrisPieces(id, light: false), inInclusiveRange(3, 4));
      }
    });
  });

  group('suppression', () {
    test('quiet while it matters', () {
      final m = _playing();
      expect(EasterEggBudget.quietReason(m), isNull);
      final b = EasterEggBudget()
        ..alwaysRoll = true
        ..update(0, m);
      expect(b.request(EasterEgg.flock, key: 1, band: 0), isTrue);

      void check(String reason, void Function() set, void Function() unset) {
        set();
        b
          ..tick(60)
          ..update(0, m);
        expect(b.quiet, reason);
        for (final egg in EasterEgg.values) {
          if (egg == EasterEgg.sectorDance) continue;
          expect(
            b.request(egg, key: 1, band: 0),
            isFalse,
            reason: '$egg during $reason',
          );
        }
        expect(
          b.request(EasterEgg.sectorDance, key: 1, band: 0, guaranteed: true),
          isTrue,
        );
        unset();
        b.update(0, m);
        expect(b.quiet, isNull, reason: 'after $reason');
      }

      final tele = GroundUnit(900, 0, 0, .5, 500)..telegraph = 1;
      check(
        'telegraph',
        () => m.ground.units.add(tele),
        () => m.ground.units.remove(tele),
      );
      check('last life', () => m.lives = 1, () => m.lives = 3);
      check('player hit', () => m.invulnerable = 1.5, () => m.invulnerable = 0);
      check('dense fight', () {
        for (var i = 0; i < 6; i++) {
          m.shots.add(Shot(100, 100, 0, 100, hostile: true));
        }
      }, m.shots.clear);
      final boss = ArcadeModel(seed: 1982)..startAt(sector: 5);
      expect(EasterEggBudget.quietReason(boss), 'boss');
    });

    test('reduced motion and the master switch grant nothing', () {
      final b = EasterEggBudget()
        ..alwaysRoll = true
        ..reducedMotion = true;
      for (final egg in EasterEgg.values) {
        expect(b.request(egg, key: 1, band: 0, guaranteed: true), isFalse);
      }
      b
        ..reducedMotion = false
        ..enabled = false;
      expect(b.request(EasterEgg.flock, key: 1, band: 0), isFalse);
    });
  });

  group('flock', () {
    test('bursts 5-9 flyers that fly out of the lane and the swarm band', () {
      final m = ArcadeModel(seed: 1982);
      List<(double, double)> run() {
        final f = FlyoverBackground()..reducedMotionOverride = false;
        f.spawnFlock(0, 42, 0, 70, 420, 300);
        final n = f.debugFlyers.length;
        expect(n, inInclusiveRange(5, 9));
        var seen = 0;
        final trail = <(double, double)>[];
        for (var i = 0; i < 60 * 3; i++) {
          f.advance(1 / 60, m, 0);
          for (final p in f.debugFlyers) {
            final o = FlyoverBackground.flyerOpacity(p);
            if (o <= 0) continue;
            seen++;
            expect(p.y, greaterThanOrEqualTo(FlyoverBackground.flockCeiling));
            if (p.y > 300) {
              expect(
                p.x,
                lessThan(FlyoverBackground.laneLeft),
                reason: 'a flyer entered the lane',
              );
            }
            expect(p.scale, lessThan(.7));
            trail.add((p.x, p.y));
          }
          if (i == 60 * 2.6) {
            expect(f.debugFlyers, isEmpty, reason: 'gone in 2.5 s');
          }
        }
        expect(seen, greaterThan(n * 30));
        return trail;
      }

      expect(run(), run(), reason: 'deterministic');
    });

    test(
      'only falling trees and stalks release flocks, one species per sector',
      () {
        expect(GroundWildlifeAtlas.flockSpecies, hasLength(5));
        final kinds = {for (final s in VegetationAtlas.species) s.kind};
        expect(kinds.containsAll(FlyoverBackground.flockKinds), isTrue);
        expect(FlyoverBackground.flockKinds.contains('crystal'), isFalse);
      },
    );
  });

  group('assets', () {
    test('every cell an egg draws exists in every sector', () {
      for (var s = 0; s < GroundBlocks.sectors.length; s++) {
        final name = GroundBlocksCast.sectorName(s);
        final placed = GroundBlocks.placement[name]!.keys.toSet();
        // The jackpot: every light Host vehicle has a head to pop.
        for (final id in placed) {
          final u = GroundBlocks.units[id]!;
          if (u.faction != 'host' || u.block == 'I') continue;
          final cells = GroundBlockCells(id);
          expect(cells.debris(0), isNotNull, reason: '$id debris in $name');
          expect(GroundBlocks.cell(name, cells.debris(0)!), isNotNull);
          if (u.unitClass != 'light') continue;
          final (art, piece) = GroundBlocksLayer.jackpotHead(cells);
          if (art != null) {
            expect(GroundBlocks.cell(name, art), isNotNull, reason: art);
          } else {
            expect(piece, greaterThanOrEqualTo(0), reason: '$id head');
          }
        }
        // The jackpot crew climbs out, looks and runs.
        final crew = GroundBlockCells(GroundBlocksLayer.crewUnit(s));
        expect(placed, contains(crew.id));
        for (final st in ['arrive', 'idle', 'run']) {
          expect(crew.headingOf(st), isNotNull, reason: '${crew.id} $st');
          expect(GroundBlocks.cell(name, crew.state(st, 0, 0).$1), isNotNull);
        }
        // Dances and jigs.
        for (final role in [
          GroundCastRole.allyRifle,
          GroundCastRole.allyRocket,
          GroundCastRole.demonRifle,
        ]) {
          for (var id = 0; id < 6; id++) {
            final u = GroundBlocksCast.unitFor(role, s, id: id)!;
            final cells = GroundBlockCells(u);
            expect(
              cells.headingOf('flourish'),
              isNotNull,
              reason: '$u flourish in $name',
            );
            for (var f = 0; f < 4; f++) {
              expect(
                GroundBlocks.cell(name, cells.state('flourish', 0, f).$1),
                isNotNull,
              );
            }
          }
        }
        // Convoy turret twirl: every angle of every Fleet layer.
        for (var v = 0; v < 6; v++) {
          final u = GroundBlocksCast.unitFor(
            GroundCastRole.convoy,
            s,
            id: v,
            variant: v,
          )!;
          final cells = GroundBlockCells(u);
          for (var a = 0; a < cells.unit.angles.length; a++) {
            expect(GroundBlocks.cell(name, cells.art(a)), isNotNull);
          }
        }
      }
    });

    test('the jackpot turret bounces once and lands upright', () {
      final (_, h0, f0) = GroundBlocksLayer.jackpotArc(.5);
      expect(f0, isTrue);
      expect(h0, greaterThan(10));
      final (_, h1, f1) = GroundBlocksLayer.jackpotArc(2);
      expect(f1, isFalse);
      expect(h1, 0);
      var bounces = 0;
      var prev = 1.0;
      for (var t = .13; t < 2.5; t += .005) {
        final h = GroundBlocksLayer.jackpotArc(t).$2;
        if (prev > .5 &&
            h < .5 &&
            GroundBlocksLayer.jackpotArc(t + .05).$2 > h) {
          bounces++;
        }
        prev = h;
      }
      expect(bounces, 1);
    });
  });

  testWidgets('simulation identical with the eggs on and off', (tester) async {
    await tester.runAsync(() async {
      final legacy = await _decode('assets/images/${GroundAtlas.file}');
      final troops = await _decode('assets/images/${GroundTroopsAtlas.file}');
      final started = <EasterEgg, int>{};
      for (final sector in [1, 3]) {
        final fingerprints = <bool, List<Object>>{};
        for (final on in [true, false]) {
          final m = ArcadeModel(seed: 1982)..startAt(sector: sector);
          final scene = DemonScene(m, () {});
          scene.sectors.flyover.reducedMotionOverride = false;
          scene.sectors.flyover.eggs
            ..enabled = on
            ..alwaysRoll = true;
          scene.groundForces
            ..image = legacy
            ..troops = troops
            ..blocks.install(sector - 1, await _atlases(sector - 1));
          scene.environment = sector - 1.0;
          var next = 0.0;
          for (var f = 0; f < 60 * 40; f++) {
            if (m.combat) {
              if (m.levelClock >= next) {
                next = m.levelClock + 2.6;
                final t = m.demons.where((x) => !x.entering).firstOrNull;
                if (t != null) m.hitDemon(t, damage: 99);
              }
              m.shipX = m.targetX =
                  180 +
                  120 *
                      ((f / 600) % 2 < 1 ? 1 : -1) *
                      (((f / 600) % 1) - .5).abs();
            }
            // The ship is kept alive for the run, but not "just hit" for
            // the budget (both runs do exactly the same).
            m.invulnerable = 0;
            scene.sectors.advance(1 / 60, m, scene.environment);
            if (m.combat) m.invulnerable = 2;
            m.update(1 / 60);
            if (f % 2 == 0) {
              final r = ui.PictureRecorder();
              scene.groundForces.paintGround(ui.Canvas(r), m);
              r.endRecording().dispose();
            }
          }
          fingerprints[on] = [
            m.score,
            m.lives,
            m.kills,
            m.ground.unitsSpawned,
            m.ground.engagements,
            m.demons.length,
            m.shots.length,
            m.random.nextDouble(),
            for (final u in m.ground.units) (u.id, u.z, u.x, u.hp, u.destroyed),
            for (final a in m.ground.allies)
              (a.id, a.z, a.x, a.hp, a.totalled, a.saved),
          ];
          if (on) {
            scene.sectors.flyover.eggs.started.forEach(
              (k, v) => started[k] = (started[k] ?? 0) + v,
            );
          } else {
            expect(scene.sectors.flyover.eggs.started, isEmpty);
          }
        }
        expect(
          fingerprints[true],
          fingerprints[false],
          reason: 'sector $sector: eggs changed the simulation',
        );
      }
      // ignore: avoid_print
      print('eggs started (always-roll, 2 x 40 s): $started');
      expect(started.values.fold(0, (a, b) => a + b), greaterThan(0));
    });
  });

  testWidgets('review frame: a flock over Krybor', (tester) async {
    await tester.runAsync(() async {
      const sector = 1;
      final m = ArcadeModel(seed: 1982)..startAt(sector: sector);
      final scene = DemonScene(m, () {});
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] = await _decode(
          'assets/images/sector-${i + 1}.png',
        );
      }
      await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
      final fly = scene.sectors.flyover..reducedMotionOverride = false;
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
      scene.ship.image = await _decode('assets/images/ship-weapons.png');
      scene.groundForces
        ..image = await _decode('assets/images/${GroundAtlas.file}')
        ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}')
        ..blocks.install(sector - 1, await _atlases(sector - 1));
      // The in-game atmosphere: fog tiles and the ground-atmosphere art.
      await scene.atmosphere.load(shader: false);
      scene.atmosphere.groundArt = GroundAtmosphereArt(
        await _decode('assets/images/${GroundAtmosphereAtlas.file}'),
      );
      scene.environment = sector - 1.0;
      for (var f = 0; f < 60 * 6; f++) {
        scene.sectors.advance(1 / 60, m, scene.environment);
        scene.syncAtmosphere(1 / 60);
        m.update(1 / 60);
      }
      // Bursts from the nearest side-band tree crown on screen (or a fixed
      // spot when none is in view).
      final rects =
          fly
              .debugVegetationRects()
              .where(
                (r) =>
                    r.center.dx < FlyoverBackground.laneLeft &&
                    r.top > 260 &&
                    r.bottom < 500,
              )
              .toList()
            ..sort((a, b) => b.bottom.compareTo(a.bottom));
      final at = rects.isEmpty
          ? const ui.Offset(60, 400)
          : rects.first.topCenter;
      fly.spawnFlock(0, 7, 0, at.dx, at.dy + 4, 260);
      for (var f = 0; f < 60 * .7; f++) {
        scene.sectors.advance(1 / 60, m, scene.environment);
        scene.syncAtmosphere(1 / 60);
        m.update(1 / 60);
      }
      // The flyers draw over the ground fog (not under it): with the
      // flock sheet removed, the pixels around them change visibly.
      expect(fly.deferFlyers, isTrue);
      Future<List<int>> lumas() async {
        final r = ui.PictureRecorder();
        scene.paintArena(ui.Canvas(r), Vector2(360, 520));
        final pic = r.endRecording();
        final img = await pic.toImage(360, 520);
        final b = (await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        img.dispose();
        pic.dispose();
        return [
          for (var i = 0; i < b.length; i += 4)
            (2126 * b[i] + 7152 * b[i + 1] + 722 * b[i + 2]) ~/ 10000,
        ];
      }

      final withFlock = await lumas();
      final sheet = fly.wildlife;
      fly.wildlife = null;
      final without = await lumas();
      fly.wildlife = sheet;
      var visible = 0;
      for (final p in fly.debugFlyers) {
        if (FlyoverBackground.flyerOpacity(p) <= 0) continue;
        for (var dy = -5; dy <= 5; dy++) {
          for (var dx = -6; dx <= 6; dx++) {
            final x = p.x.round() + dx, y = p.y.round() + dy;
            if (x < 0 || x >= 360 || y < 0 || y >= 520) continue;
            if ((withFlock[y * 360 + x] - without[y * 360 + x]).abs() >= 12) {
              visible++;
            }
          }
        }
      }
      expect(visible, greaterThan(40), reason: 'the flock reads over the fog');
      expect(
        fly.debugFlyers.where((p) => FlyoverBackground.flyerOpacity(p) > 0),
        isNotEmpty,
      );
      // ignore: avoid_print
      print(
        'flock from $at: ${[for (final p in fly.debugFlyers) '(${p.x.round()},${p.y.round()} s${p.scale.toStringAsFixed(2)} o${FlyoverBackground.flyerOpacity(p).toStringAsFixed(2)})']}',
      );
      for (final (w, h, scale, tag) in [
        (360, 780, 1.0, 'portrait'),
        (720, 520 * 2, 2.0, 'zoom'),
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Paint()..color = const ui.Color(0xFF000000),
        );
        if (scale > 1) canvas.scale(scale);
        scene.paintArena(canvas, Vector2(w / scale, h / scale));
        final picture = recorder.endRecording();
        final image = await picture.toImage(w, h);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('$_review/l$sector-eggs-flock-$tag.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    });
  });

  test('the painter keeps the budget the scene hands it', () {
    final m = ArcadeModel(seed: 1982);
    final scene = DemonScene(m, () {});
    expect(
      identical(scene.groundForces.eggs, scene.sectors.flyover.eggs),
      isTrue,
    );
    expect(GroundPainter().eggs, isNull);
  });
}

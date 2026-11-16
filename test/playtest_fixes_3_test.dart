// playtest-fixes-3 (openspec/changes/playtest-fixes-3): the sentinel's
// berserk rush rules, its shadow, the diving shields' shape, the
// background through the toast band and the straight-up ascent.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show clearWave, reach;

const dt = 1 / 60;

(ArcadeModel, Demon) _arena(Difficulty difficulty, {int route = 1}) {
  final m = ArcadeModel(seed: 1)
    ..startAt(difficulty: difficulty, sector: 2, route: route);
  m
    ..mode = RunMode.playing
    ..invulnerable = 0
    ..lives = 99;
  m.demons.clear();
  m.shots.clear();
  final d = Demon(
    180,
    44,
    2,
    12,
    0,
    archetype: EnemyArchetype.shieldSentinel,
    lastStandEligible: true,
  )..hp = 4;
  m.demons.add(d);
  return (m, d);
}

/// Hits [d] until its rush starts (a quarter hull).
void _startRush(ArcadeModel m, Demon d) {
  for (var k = 0; k < 40 && !d.lastStand; k++) {
    m.hitDemon(d);
  }
  expect(d.lastStand, isTrue);
}

void _until(ArcadeModel m, bool Function() done) {
  for (var f = 0; f < 600 && !done(); f++) {
    m.invulnerable = 5;
    m.update(dt);
    m.shots.clear();
  }
}

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<ByteData> _pixels(DemonScene scene, double w, double h) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(c, Vector2(w, h), alignY: 1);
  final pic = rec.endRecording();
  final img = await pic.toImage(w.round(), h.round());
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  img.dispose();
  pic.dispose();
  return data;
}

void main() {
  group('sentinel berserk rush', () {
    test('invulnerable in the transformation: hits deflect with a spark', () {
      final (m, d) = _arena(Difficulty.normal);
      _startRush(m, d);
      final hp = d.hp, rush = d.rushShield;
      expect(d.rushPhase, RushPhase.rally);
      m.powerTimers[Power.powerful] = 9; // even powered hits glance off
      m.deflects.clear();
      for (var i = 0; i < 5; i++) {
        m.hitDemon(d, damage: 2, atX: d.x, atY: d.y + 20);
        m.hitDemon(d, damage: 2, homing: true);
      }
      _until(m, () => d.rushPhase == RushPhase.lock);
      m.hitDemon(d, damage: 2, atX: d.x + 4, atY: d.y + 22);
      expect(d.hp, hp);
      expect(d.rushShield, rush);
      expect(m.deflects, isNotEmpty);
      expect(d.flash, 0, reason: 'no hit flash: the hit did not land');
    });

    test('the rush shield wears only under offensive powers or homing', () {
      for (final difficulty in Difficulty.values) {
        final (m, d) = _arena(difficulty);
        _startRush(m, d);
        _until(m, () => d.rushPhase == RushPhase.rush);
        final full = d.rushShield;
        m.deflects.clear();
        m.hitDemon(d, atX: d.x, atY: d.y + 30); // the bare gun
        expect(d.rushShield, full, reason: '$difficulty bare gun');
        expect(m.deflects, hasLength(1));
        m.powerTimers[Power.powerful] = 9;
        m.hitDemon(d, damage: 2);
        expect(d.rushShield, full - 3, reason: 'Powerful: 2 + 1 breaker');
        m.powerTimers.clear();
        m.hitDemon(d, homing: true);
        expect(d.rushShield, full - 4, reason: 'a homing hit');
      }
    });

    test('tuning: more frequent, a stronger shield', () {
      final (e, _) = _arena(Difficulty.easy);
      final (n, _) = _arena(Difficulty.normal);
      final (h, _) = _arena(Difficulty.hard);
      expect(e.policy.rushChance, .28);
      expect(n.policy.rushChance, .45);
      expect(h.policy.rushChance, .55);
      expect(e.policy.rushShieldFor(3), 6);
      expect(n.policy.rushShieldFor(3), 9);
      expect(h.policy.rushShieldFor(4), 12);
    });

    test('dodging always pays better than breaking the shield', () {
      expect(RushTuning.dodgePoints, greaterThan(RushTuning.breakPoints));
      for (final difficulty in Difficulty.values) {
        // Dodge every pass, outlast it, versus break it on the last pass
        // and shoot it down: the dodge's score is never lower.
        final (m, d) = _arena(difficulty);
        _startRush(m, d);
        final passes = m.policy.rushPasses;
        final before = m.score;
        var left = true;
        for (var f = 0; f < 60 * 30 && left; f++) {
          m.invulnerable = 0;
          // The ship sits far from the charge's line.
          m.shipX = d.x < 180 ? 330 : 30;
          m.targetX = m.shipX;
          m.update(dt);
          m.shots.clear();
          left = m.demons.contains(d);
        }
        expect(left, isFalse, reason: '$difficulty: it burnt out');
        final dodged = m.score - before;
        final kill =
            (100 + 2 * 75 + 11 * 50) * (m.cycle + 1) * m.policy.enemyPoints;
        final unit = (m.cycle + 1) * m.policy.enemyPoints;
        expect(
          dodged,
          greaterThanOrEqualTo(
            ((passes - 1) * RushTuning.dodgePoints + RushTuning.breakPoints) *
                    unit +
                kill -
                1,
          ),
          reason: '$difficulty: $dodged',
        );
      }
    });
  });

  group('sentinel shadow', () {
    test('one size rule: the lurk hands over without a jump', () {
      // The lurk at the front (its low pass, ground nearness .43) and the
      // in-play sentinel just arrived (fight altitude, nearness .6).
      final lurkEnd = DemonScene.sentinelShadowScale(.43, 120);
      final play = DemonScene.sentinelShadowScale(.6, 85);
      expect(play / lurkEnd, inInclusiveRange(.8, 1.35));
      // Far and high the lurk is broad for its ground; it never vanishes.
      final far = DemonScene.sentinelShadowScale(.2, 220);
      expect(far / (1.6 * .2), greaterThan(2));
      // In the fight it is the sentinel's own drawn size (scale 1 at .62).
      expect(DemonScene.sentinelShadowScale(.62, 85), closeTo(1.1, .1));
    });

    testWidgets('a fighting sentinel always casts its shadow', (t) async {
      await t.runAsync(() async {
        final m = ArcadeModel(seed: 3)..startAt(sector: 2, route: 1);
        m
          ..mode = RunMode.playing
          ..invulnerable = 0;
        m.demons.clear();
        m.incoming.clear();
        final d =
            Demon(180, 70, 0, 9, 0, archetype: EnemyArchetype.shieldSentinel)
              ..nearness = .62
              ..altitude = 0;
        m.demons.add(d);
        final scene = DemonScene(m, () {});
        scene.effectsAtlas = await _decode(
          'assets/images/sentinel-effects.png',
        );
        scene.paintShadowPass(ui.Canvas(ui.PictureRecorder()));
        expect(scene.shadowScaleOf(d), isNotNull);
        expect(DemonScene.sentinelShadowAltitude(d), greaterThan(0));
      });
    });
  });

  group('diving shield shape', () {
    test('the bow is one continuous crescent tapering to its tips', () {
      const b = (span: 24.0, nose: 7.5, lead: 5.5, thick: 7.5, lick: 3.5);
      var last = DemonScene.bowLead(b, -1);
      for (var i = 1; i <= 40; i++) {
        final u = -1 + i / 20;
        final y = DemonScene.bowLead(b, u);
        expect((y - last).abs(), lessThan(1.0), reason: 'continuous at $u');
        last = y;
      }
      expect(
        DemonScene.bowThick(b, 0),
        greaterThan(DemonScene.bowThick(b, .95) * 3),
      );
    });

    test('heading turns the bow toward the dive, within ±0.45 rad', () {
      final d = Demon(0, 0, 0, 1, 0)
        ..vx = 300
        ..vy = 200;
      expect(DemonScene.bowTurn(d), inInclusiveRange(-.45, 0));
      d.vy = 0;
      expect(DemonScene.bowTurn(d), 0);
    });
  });

  testWidgets('the background fills the toast band; gameplay never does', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 7)..startAt(sector: 4, route: 1);
      m.mode = RunMode.playing;
      m.demons.clear();
      m.incoming.clear();
      final scene = DemonScene(m, () {});
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] = await _decode(
          'assets/images/sector-${i + 1}.png',
        );
      }
      await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
      scene.atlas = await _decode('assets/images/combat.png');
      await scene.atmosphere.load();
      scene.environment = 3;
      for (final (w, h) in const [(360.0, 640.0), (390.0, 844.0)]) {
        final plain = await _pixels(scene, w, h);
        final band = h - 520 * math.min(w / 360, h / 520);
        expect(scene.headroom, greaterThan(100), reason: '$w x $h');
        // Every row of the band carries background (not the black clear).
        for (var y = 0; y < band - 1; y += 8) {
          var lit = 0;
          for (var x = 0; x < w; x += 4) {
            final i = (y * w.round() + x) * 4;
            if (plain.getUint8(i) +
                    plain.getUint8(i + 1) +
                    plain.getUint8(i + 2) >
                6) {
              lit++;
            }
          }
          expect(lit, greaterThan(w / 4 * .5), reason: 'row $y of $w x $h');
        }
        // A creature and a shot above the arena are not drawn in the band.
        m.demons.add(Demon(180, -30, 1, 1, 0)..nearness = 1);
        m.shots.add(Shot(180, -20, 0, -390));
        final busy = await _pixels(scene, w, h);
        m.demons.clear();
        m.shots.clear();
        var diff = 0;
        for (var i = 0; i < (band.floor() * w.round()) * 4; i++) {
          if (plain.getUint8(i) != busy.getUint8(i)) diff++;
        }
        expect(diff, 0, reason: 'no gameplay in the band ($w x $h)');
      }
      // Desktop: height-limited, no band.
      await _pixels(scene, 1280, 720);
      expect(scene.headroom, 0);
    });
  });

  test(
    'the sector change climbs straight up: no bank, pitch from the climb',
    () {
      final plan = FlowPlan.sectorChange();
      final p1 = plan.descentAt, p0 = p1 - plan.pursuitSeconds;
      final cloudUp = plan.beat('cloud')!.a;
      for (var s = 0.0; s < plan.seconds; s += .1) {
        expect(plan.envAt('roll', s), 0, reason: 'no bank at $s');
      }
      // The world pitches in clear air, before the cloud comes in.
      expect(plan.envAt('pitch', (p0 + cloudUp) / 2 + .3), greaterThan(0));
      expect(plan.envAt('cloud', (p0 + cloudUp) / 2 + .3), 0);
    },
  );

  test('the pursued flock climbs ahead of the ship, not sideways', () {
    final m = ArcadeModel(seed: 11)
      ..startAt(
        sector: 2,
        route: 1,
        wave: ArcadeModel.wavesFor(sector: 2, route: 1),
      );
    reach(m, RunMode.playing);
    for (var i = 0; i < 240; i++) {
      m.invulnerable = 5;
      m.update(dt);
    }
    clearWave(m);
    // A sector's last kill leaves no flock (playtest-fixes); a carrier's
    // fall does. Pose a remnant to see where the Pursuit takes it.
    for (var i = 0; i < 5; i++) {
      final d = Demon(120.0 + i * 30, 150, i % 4, 1, i.toDouble())
        ..nearness = .4
        ..scale = .8;
      m.flowFlock.add(FlowMember(d, d.x, d.y, .4, i, i * 1.3));
    }
    final plan = m.flow.plan;
    final p0 = plan.descentAt - plan.pursuitSeconds;
    double? x0, y0;
    var maxDx = 0.0, rise = 0.0;
    for (var f = 0; f < 60 * 30 && m.flow.active; f++) {
      m.update(dt);
      final s = m.flow.seconds;
      if (m.flowFlock.isEmpty || s < p0 + 1 || s > plan.descentAt) continue;
      final cx =
          m.flowFlock.map((f) => f.demon.x).reduce((a, b) => a + b) /
          m.flowFlock.length;
      final cy =
          m.flowFlock.map((f) => f.demon.y).reduce((a, b) => a + b) /
          m.flowFlock.length;
      x0 ??= cx;
      y0 ??= cy;
      maxDx = math.max(maxDx, (cx - x0).abs());
      rise = math.max(rise, y0 - cy);
    }
    expect(maxDx, lessThan(12), reason: 'no lateral stream');
    expect(rise, greaterThan(20), reason: 'it climbs');
  });
}

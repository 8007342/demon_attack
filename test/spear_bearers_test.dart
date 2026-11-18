import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/game/insignia_rank.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/spear_bearer_atlas.dart';
import 'package:demon_attack/game/spear_bearer_painter.dart';
import 'package:demon_attack/game/sprite_atlas.dart'
    show AlienRank, CombatAtlas;
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// spear-bearers (openspec/changes/spear-bearers): the schedule, the
/// mid-dive throw and its telegraph, the spear in the wind, lightning's
/// stun, the buckler rule and the painter. Every loop here is bounded by a
/// frame guard; every ui.Image made here is disposed.

const _dt = 1 / 60;

/// A playing run on [route]/[sector] with its wave cleared, so a test
/// places its own bearer.
ArcadeModel _staged({
  int route = 2,
  int sector = 3,
  Difficulty difficulty = Difficulty.normal,
  WindSpec? Function(int, int)? wind,
}) {
  final m = ArcadeModel(seed: 1982)..windRun.force = wind;
  m.startAt(sector: sector, route: route, difficulty: difficulty);
  reach(m, RunMode.playing);
  for (var f = 0; f < 900 && !m.demons.any((d) => !d.entering); f++) {
    m.invulnerable = 5;
    m.update(_dt);
  }
  m
    ..demons.clear()
    ..shots.clear()
    ..invulnerable = 5;
  return m;
}

Demon _bearer(ArcadeModel m, {double x = 180, double y = 140}) {
  final d = Demon(x, y, 0, 3, 1.3, elite: true)
    ..spear = SpearKit()
    ..nearness = 1
    ..attackLeft = 99
    ..evadeCooldown = 99;
  m.demons.add(d);
  return d;
}

/// Starts [d]'s dive now (as the end of its tell does).
void _dive(ArcadeModel m, Demon d) {
  d
    ..dive = .001
    ..targetX = m.shipX
    ..threadLine = d.x
    ..telegraph = 0
    ..divePrep = 0;
}

/// One step with the ship protected and the dive scheduler held off.
void _step(ArcadeModel m) {
  m.invulnerable = 5;
  m.update(_dt);
}

Iterable<Shot> _spears(ArcadeModel m) =>
    m.shots.where((s) => s.kind == ShotKind.spear);

void main() {
  group('the appearance schedule', () {
    bool at(
      int route,
      int sector, {
      Difficulty d = Difficulty.normal,
      int wave = 1,
      int elite = 1,
      bool bonus = false,
    }) => spearBearerScheduled(
      difficulty: d,
      route: route,
      sector: sector,
      wave: wave,
      eliteOrdinal: elite,
      bonus: bonus,
    );

    test('from the third tour, sectors 2-4; Easy a tour later', () {
      for (final d in [Difficulty.normal, Difficulty.hard]) {
        expect(at(0, 3, d: d), isFalse);
        expect(at(1, 3, d: d), isFalse);
        expect(at(2, 1, d: d), isFalse);
        for (var s = 2; s <= 4; s++) {
          expect(at(2, s, d: d), isTrue);
          expect(at(4, s, d: d), isTrue);
        }
        expect(at(2, 5, d: d), isFalse); // the carrier sector
      }
      const e = Difficulty.easy;
      expect(at(2, 3, d: e), isFalse);
      expect(at(3, 2, d: e), isFalse);
      expect(at(3, 3, d: e), isTrue);
      expect(at(4, 4, d: e), isTrue);
    });

    test('half the elites: (wave + elite ordinal) even; never a bonus', () {
      expect(at(2, 3, wave: 1, elite: 1), isTrue);
      expect(at(2, 3, wave: 1, elite: 2), isFalse);
      expect(at(2, 3, wave: 2, elite: 1), isFalse);
      expect(at(2, 3, wave: 2, elite: 2), isTrue);
      expect(at(2, 3, bonus: true), isFalse);
      expect(at(2, 3, elite: 0), isFalse);
    });

    test('a live run: bearers are born only where scheduled, as elites', () {
      int born(int route, int sector) {
        final m = ArcadeModel(seed: 7)..startAt(sector: sector, route: route);
        reach(m, RunMode.playing);
        for (var f = 0; f < 60 * 40; f++) {
          m.invulnerable = 5;
          m.update(_dt);
          for (final d in m.demons) {
            if (d.spear != null) {
              expect(d.elite, isTrue);
              expect(d.isLarge, isFalse);
            }
          }
        }
        return m.spearRun.born;
      }

      expect(born(1, 3), 0);
      expect(born(2, 1), 0);
      expect(born(2, 3), greaterThan(0));
    });
  });

  group('the throw', () {
    test('mid-dive, after a wind-up of its telegraph lead', () {
      final m = _staged();
      final d = _bearer(m);
      _dive(m, d);
      final from = d.y;
      double? windAt, windY, throwAt, throwY;
      final events = <String>[];
      for (var f = 0; f < 600 && throwAt == null && d.dive > 0; f++) {
        _step(m);
        events.addAll(m.takeEvents());
        final t = f * _dt;
        if (windAt == null && d.spear!.windingUp) {
          windAt = t;
          windY = d.y;
        }
        if (_spears(m).isNotEmpty) {
          throwAt = t;
          throwY = _spears(m).first.y;
        }
      }
      expect(windAt, isNotNull);
      expect(throwAt, isNotNull);
      // Mid-dive: a third of the way down, not at the start.
      final reach = from + SpearTuning.windupAt * (ArcadeModel.shipY - from);
      expect(windY!, greaterThanOrEqualTo(reach - 4));
      // The telegraph lead: the wind-up's length at this pace, ≥ 0.45 s.
      final lead = throwAt! - windAt!;
      final want = SpearTuning.windup / m.policy.hostileRate;
      expect(lead, closeTo(want, 2 * _dt));
      expect(lead, greaterThanOrEqualTo(.45));
      expect(throwY!, lessThan(ArcadeModel.shipY - SpearTuning.minRelease));
      // The glint's ting before the release; the war-cry hook queued.
      expect(events.indexOf('spearGlint'), greaterThanOrEqualTo(0));
      expect(
        events.indexOf('spearRelease'),
        greaterThan(events.indexOf('spearGlint')),
      );
      expect(
        m.takeGameEvents().map((e) => e.name),
        contains(GameEventNames.spearThrow),
      );
      expect(d.spear!.armed, isFalse);
      expect(d.spear!.throws, 1);
    });

    test('one throw a dive; withheld too near the ship; re-armed home', () {
      final m = _staged();
      final d = _bearer(m, y: 360);
      _dive(m, d);
      for (var f = 0; f < 600 && d.dive > 0; f++) {
        _step(m);
      }
      expect(d.spear!.throws, 0, reason: 'too close to the ship row');
      expect(d.spear!.armed, isTrue);
      final m2 = _staged();
      // Wide of the ship, so its own dive never meets the ship's guns.
      final b = _bearer(m2, x: 50);
      m2
        ..shipX = 310
        ..targetX = 310;
      _dive(m2, b);
      b.targetX = 50;
      var thrown = 0;
      for (var f = 0; f < 600 && b.dive > 0; f++) {
        _step(m2);
        thrown = _spears(m2).length > thrown ? _spears(m2).length : thrown;
      }
      expect(b.spear!.throws, 1);
      expect(thrown, 1);
      // Back on its station it holds a fresh spear.
      for (var f = 0; f < 900 && !b.spear!.armed; f++) {
        _step(m2);
      }
      expect(b.spear!.armed, isTrue);
    });

    test('a bearer never fires the hunter\'s triple spread', () {
      final m = _staged();
      final d = _bearer(m)..attackLeft = .001;
      for (var f = 0; f < 3; f++) {
        _step(m);
      }
      final fromIt = m.shots.where(
        (s) => s.hostile && (s.x - d.x).abs() < 1 && s.kind != ShotKind.spear,
      );
      expect(fromIt.length, lessThan(3));
    });
  });

  group('the spear in the wind', () {
    test('drifts exactly like any other hostile shot', () {
      final m = _staged(wind: (r, s) => WindPlan.draw(5, tier: WindTier.gale));
      for (var f = 0; f < 60 * 60 && m.wind.lateral.abs() < .4; f++) {
        _step(m);
      }
      expect(m.wind.lateral.abs(), greaterThanOrEqualTo(.4));
      final spear = Shot(180, 100, 0, 255, hostile: true, kind: ShotKind.spear);
      final bolt = Shot(180, 100, 0, 255, hostile: true);
      m.shots
        ..clear()
        ..addAll([spear, bolt]);
      for (var f = 0; f < 30; f++) {
        // A cohort's merge dissolves leftover fire: not under test here.
        spear.fizzleIn = bolt.fizzleIn = null;
        _step(m);
        expect(m.shots, containsAll([spear, bolt]));
      }
      expect(spear.windVx, isNot(0));
      expect(spear.windVx.sign, m.wind.lateral.sign);
      expect(spear.windVx, bolt.windVx);
      expect(spear.x, closeTo(bolt.x, 1e-9));
      // It is drawn leaning along its drift.
      final lean = SpearBearerPainter.lean(spear, m.policy.hostileRate);
      expect(lean.sign, spear.windVx.sign);
    });
  });

  group('lightning', () {
    test('stuns the bearer: the wind-up is lost, its guard is down', () {
      final m = _staged();
      final d = _bearer(m);
      _dive(m, d);
      for (var f = 0; f < 600 && !d.spear!.windingUp && d.dive > 0; f++) {
        _step(m);
      }
      expect(d.spear!.windingUp, isTrue);
      final hit = m.strikeLightning(d.x, 4);
      expect(hit.stunned, contains(d));
      _step(m);
      expect(d.stunned, isTrue);
      expect(d.spear!.windingUp, isFalse);
      // Stunned: the buckler blocks nothing, and no spear flies.
      final hp = d.hp, buckler = d.spear!.buckler;
      m.hitDemon(d, atX: d.x, atY: d.y + 6);
      expect(d.hp, hp - 1);
      expect(d.spear!.buckler, buckler);
      for (var f = 0; f < 600 && d.stunned; f++) {
        _step(m);
      }
      expect(_spears(m), isEmpty);
      expect(d.spear!.throws, 0);
    });
  });

  group('the buckler', () {
    test('blocks from the front while diving, then is knocked away', () {
      final m = _staged();
      final d = _bearer(m);
      final hp = d.hp;
      // In formation it is carried at the side: a hit reaches the body.
      m.hitDemon(d, atX: d.x, atY: d.y + 6);
      expect(d.hp, hp - 1);
      expect(d.spear!.buckler, SpearTuning.buckler);
      _dive(m, d);
      _step(m);
      // It replaces the thermal dive shield.
      expect(d.diveShield, 0);
      m.hitDemon(d, atX: d.x, atY: d.y + 6);
      expect(d.hp, hp - 1, reason: 'the buckler took it');
      expect(d.spear!.buckler, SpearTuning.buckler - 1);
      expect(m.takeEvents(), contains('bucklerClang'));
      // A homing missile comes round the side.
      m.hitDemon(d, atX: d.x, atY: d.y + 6, homing: true);
      expect(d.hp, hp - 2);
      m.hitDemon(d, atX: d.x, atY: d.y + 6);
      expect(d.spear!.hasBuckler, isFalse);
      expect(m.spearRun.fallen, hasLength(1));
      expect(m.takeEvents(), contains('bucklerOff'));
      expect(d.hp, hp - 2);
      // The dive it was lost in has no thermal shield to fall back on.
      expect(d.diveShield, 0);
      // The fallen buckler tumbles out within its life.
      for (var f = 0; f < 200 && m.spearRun.fallen.isNotEmpty; f++) {
        _step(m);
      }
      expect(m.spearRun.fallen, isEmpty);
    });

    test('never refreshes; later dives get the hunter\'s thermal shield', () {
      final m = _staged();
      final d = _bearer(m)..spear!.buckler = 1;
      _dive(m, d);
      _step(m);
      m.hitDemon(d, atX: d.x, atY: d.y + 6);
      expect(d.spear!.hasBuckler, isFalse);
      // The dive ends (as it does off the bottom) and it is back home.
      d
        ..dive = 0
        ..diveShield = 0
        ..diveShieldMax = 0
        ..y = 140;
      _step(m);
      expect(d.spear!.buckler, 0, reason: 'no new buckler');
      _dive(m, d);
      _step(m);
      expect(d.diveShieldMax, 2, reason: "the hunter's thermal shield");
    });
  });

  group('the painter', () {
    // --- round8: insignia-ranks design §4. The bearer keeps the hunter's
    // behaviour rank but wears the crownlet (no fang), for life.
    test(
      'a bearer wears the crownlet, from the one ladder (insignia-ranks §4)',
      () {
        final m = _staged();
        final d = _bearer(m);
        expect(CombatAtlas.rankOf(d), AlienRank.hunter, reason: 'behaviour');
        expect(InsigniaRanks.markOf(d), RankMark.crownlet);
        expect(SpearBearerPainter.markOf(d), InsigniaRanks.markOf(d));
        expect(InsigniaRanks.hasFang(InsigniaRanks.markOf(d)), isFalse);
        // Still the crownlet empty-handed and with the buckler knocked off.
        d.spear!
          ..armed = false
          ..buckler = 0;
        expect(InsigniaRanks.markOf(d), RankMark.crownlet);
        // The same elite without a kit is a hunter: Fang and Wings.
        final h = Demon(120, 140, 0, 3, 1.3, elite: true);
        expect(InsigniaRanks.markOf(h), RankMark.fangWings);
      },
    );

    test('frames follow the state', () {
      final m = _staged();
      final d = _bearer(m);
      final t = m.clock;
      expect(SpearBearerPainter.spearFrame(d, t), SpearBearerAtlas.spearIdle);
      expect(
        SpearBearerPainter.bucklerFrame(d, t),
        SpearBearerAtlas.bucklerCarried,
      );
      d.dive = .5;
      expect(SpearBearerPainter.spearFrame(d, t), SpearBearerAtlas.spearLevel);
      expect(
        SpearBearerPainter.bucklerFrame(d, t),
        SpearBearerAtlas.bucklerRaised,
      );
      d.spear!.windup = .2;
      expect(SpearBearerPainter.spearFrame(d, t), SpearBearerAtlas.spearWind);
      d.spear!
        ..windup = 0
        ..armed = false
        ..releasedAt = t;
      expect(
        SpearBearerPainter.spearFrame(d, t),
        SpearBearerAtlas.spearRelease,
      );
      expect(SpearBearerPainter.spearFrame(d, t + 1), isNull);
      d.spear!.hitAt = t;
      expect(
        SpearBearerPainter.bucklerFrame(d, t),
        SpearBearerAtlas.bucklerHit,
      );
      d.spear!.buckler = 0;
      expect(SpearBearerPainter.bucklerFrame(d, t), isNull);
    });

    test('draws gear, spears and fallen bucklers within its budget', () async {
      final m = _staged();
      final d = _bearer(m);
      _dive(m, d);
      d.spear!.windup = .3;
      m.shots.add(Shot(100, 200, 10, 255, hostile: true, kind: ShotKind.spear));
      m.spearRun.fallen.add(FallenBuckler(50, 50, 0, 0, 1, 1));
      final src = ui.PictureRecorder();
      Canvas(src).drawRect(
        const Rect.fromLTWH(0, 0, 4, 4),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final pic = src.endRecording();
      final img = await pic.toImage(
        SpearBearerAtlas.width,
        SpearBearerAtlas.height,
      );
      pic.dispose();
      SpearBearerPainter.image = img;
      try {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        SpearBearerPainter.gear(c, d, Offset(d.x, d.y), 40, 0, m.clock);
        SpearBearerPainter.spears(c, m, 0);
        SpearBearerPainter.fallen(c, m);
        rec.endRecording().dispose();
      } finally {
        SpearBearerPainter.image = null;
        img.dispose();
      }
    });
  });

  // --- round8: spear-bearers tasks 3.3/3.4 with fang-and-wings-comms §API.
  // The release queues ONE structured `spearThrow` (no raw string of that
  // name), so the radio hears one throw and offers one shout.
  group('the throw shout (fang-and-wings-comms)', () {
    /// Every event the radio would hear over one bearer's dive: the raw
    /// strings forwarded by the observer, the model's structured events, and
    /// what the observer derives from them.
    List<GameEvent> heard() {
      final m = _staged();
      final observer = GameEventObserver(m, dispatch: false);
      final d = _bearer(m);
      _dive(m, d);
      final out = <GameEvent>[];
      for (var f = 0; f < 600 && d.spear!.throws == 0 && d.dive > 0; f++) {
        _step(m);
        out.addAll(observer.observe(m.takeEvents()));
        for (final e in m.takeGameEvents()) {
          out
            ..add(e)
            ..addAll(observer.onGameEvent(e));
        }
      }
      expect(d.spear!.throws, 1);
      return out;
    }

    test('a throw yields exactly one spearThrow, with one shout candidate', () {
      final events = heard();
      final throws = events.where((e) => e.name == GameEventNames.spearThrow);
      expect(throws, hasLength(1), reason: 'one structured event, no raw twin');
      expect(throws.single.data['throws'], 1);
      // The raw sounds never reach a comms trigger.
      for (final raw in ['spearGlint', 'spearRelease']) {
        expect(commsDemonTriggers.containsKey(raw), isFalse, reason: raw);
      }
      expect(
        commsDemonTriggers[GameEventNames.spearThrow]!.lines,
        hasLength(6),
      );
      var offered = 0;
      for (var seed = 1; seed <= 12; seed++) {
        final director = CommsDirector(random: math.Random(seed))
          ..setSector(3, 0);
        for (final e in events) {
          director.handle(e, 10);
        }
        final shouts = [
          ...director.queue,
          ...director.active,
        ].where((c) => c.line.id.startsWith('spearThrow.'));
        expect(shouts.length, lessThanOrEqualTo(1), reason: 'seed $seed');
        offered += shouts.length;
      }
      // Chance 0.6 a throw: most seeds offer the one shout.
      expect(offered, greaterThan(3));
    });
  });
}

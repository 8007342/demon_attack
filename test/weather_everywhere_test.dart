import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/game/bonus/levels/storm_cell.dart';
import 'package:demon_attack/game/bonus/levels/stormfront_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/sprite_atlas.dart';
import 'package:demon_attack/game/weather/lightning_painter.dart';
import 'package:demon_attack/game/weather/rain_plan.dart';
import 'package:demon_attack/game/weather/storm_layer.dart';
import 'package:demon_attack/game/weather/wind_flap.dart';
import 'package:demon_attack/game/wind_flap_atlas.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// weather-everywhere (openspec/changes/weather-everywhere): lightning in
/// regular sectors and its flash limits, the radio's weather lines, the
/// wind-flap frames and the smart demons riding the wind into a dive.
/// Every loop here is bounded by a frame, seed or sample count.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const downpour = RainSpec(tier: RainTier.downpour, peak: .95, wind: .2);

  /// An unseeded run on [sector] with a storm (and optionally a gale)
  /// forced on every level.
  ArcadeModel stormy({
    int sector = 2,
    int route = 0,
    int seed = 7,
    bool gale = false,
    bool storm = true,
  }) {
    final m = ArcadeModel(seed: seed)
      ..weatherRun.forceStorm = storm
          ? (r, s) => StormPlan.force(downpour, seed * 17 + s)
          : null
      ..windRun.force = gale
          ? (r, s) => WindPlan.draw(seed * 31 + s, tier: WindTier.gale)
          : null;
    m.startAt(sector: sector, route: route);
    m.mode = RunMode.playing;
    return m;
  }

  group('storm plan', () {
    test('rarer than rain, about as rare as wind; heavy rain only', () {
      var levels = 0, rainy = 0, windy = 0, storms = 0;
      for (var seed = 1; seed <= 2000; seed++) {
        for (var route = 0; route < 3; route++) {
          for (var sector = 1; sector <= 4; sector++) {
            if (route == 0 && sector == 1) {
              expect(
                StormPlan.forLevel(seed, route: route, sector: sector),
                isNull,
              );
              continue;
            }
            levels++;
            final rain = RainPlan.forLevel(seed, route: route, sector: sector);
            final storm = StormPlan.forLevel(
              seed,
              route: route,
              sector: sector,
            );
            if (rain != null) rainy++;
            if (WindPlan.forLevel(seed, route: route, sector: sector) != null) {
              windy++;
            }
            if (storm == null) continue;
            storms++;
            expect(rain, isNotNull);
            expect(rain!.tier, isNot(RainTier.drizzle));
            expect(storm.rain.peak, rain.peak);
          }
        }
      }
      final pr = rainy / levels, pw = windy / levels, ps = storms / levels;
      expect(
        ps,
        inInclusiveRange(StormPlan.expected - .02, StormPlan.expected + .02),
      );
      expect(pr, greaterThan(ps + .07), reason: 'rain $pr > lightning $ps');
      expect(
        (pw - ps).abs(),
        lessThan(.08),
        reason: 'wind $pw ≈ lightning $ps',
      );
    });

    test('unseeded runs, bonus levels and the carrier never storm', () {
      for (var s = 1; s <= 5; s++) {
        expect(StormPlan.forLevel(null, route: 1, sector: s), isNull);
        expect(StormPlan.forLevel(3, route: 1, sector: s, bonus: true), isNull);
      }
      expect(StormPlan.forLevel(3, route: 1, sector: 5), isNull);
      final m = ArcadeModel(seed: 1982)..start();
      m.mode = RunMode.playing;
      for (var f = 0; f < 60 * 20; f++) {
        m.update(1 / 60);
        expect(
          m.takeGameEvents().where((e) => e.name == GameEventNames.stormStart),
          isEmpty,
        );
      }
      expect(m.stormCell, isNull);
    });

    test('a storm strikes only while its rain is heavy', () {
      const late = RainSpec(
        tier: RainTier.rain,
        peak: .55,
        wind: 0,
        startAt: 20,
        rampIn: 8,
      );
      final s = StormPlan.force(late, 4);
      expect(s.activeAt(10), isFalse);
      expect(s.activeAt(40), isTrue);
    });
  });

  group('lightning in a regular sector', () {
    test('bolts fall at the documented rate and stun; one start per level', () {
      final m = stormy(seed: 5)..invulnerable = 1e6;
      final landed = <double>[];
      final starts = <int, int>{};
      var tells = 0, stuns = 0, combat = 0.0, lastLevel = m.level;
      var last = -1e9;
      // Two minutes of combat (the level may clear and the next one storm).
      for (var f = 0; f < 60 * 600 && combat < 120; f++) {
        m.update(1 / 60);
        m.invulnerable = 1e6;
        if (m.combat) combat += 1 / 60;
        if (m.level != lastLevel) {
          lastLevel = m.level;
          last = -1e9;
        }
        for (final e in m.takeGameEvents()) {
          if (e.name == GameEventNames.stormStart) {
            starts[m.level] = (starts[m.level] ?? 0) + 1;
          }
          if (e.name == GameEventNames.lightningStun) stuns++;
        }
        final raw = m.takeEvents();
        tells += raw.where((e) => e == 'stormTell').length;
        if (raw.contains('stormBolt')) {
          landed.add(m.levelClock);
          expect(m.levelClock - last, greaterThan(5));
          last = m.levelClock;
        }
        expect(m.stormCell?.strikes.length ?? 0, lessThanOrEqualTo(4));
      }
      expect(combat, greaterThanOrEqualTo(119));
      expect(starts.values, everyElement(1));
      expect(tells, greaterThanOrEqualTo(landed.length));
      expect(stuns, greaterThan(0));
      // 6 s to the first, then 6.5-10 s after each bolt plus a 1.25 s tell
      // (at Normal's hostile rate): 9-16 in two minutes of combat.
      expect(landed.length, inInclusiveRange(9, 16));
    });

    test('flash limits: at most three a second, under a 10 % step', () {
      // Large-area changes: the wash and the cloud glow, over any backdrop.
      const white = ui.Color(0xFFFFFFFF), halo = ui.Color(0xFFCFC4FF);
      for (final look in [StormLook.regular, StormLook.stormfront]) {
        expect(
          FlashSafety.washStep(white, look.maxFlash),
          lessThan(FlashSafety.flashStep),
        );
      }
      for (final look in [StormLook.regular, StormLook.stormfront]) {
        expect(
          FlashSafety.washStep(halo, look.skyGlow),
          lessThan(FlashSafety.flashStep),
        );
      }
      // Bolts: a regular storm at the fastest hostile rate, 15 minutes.
      final cell = StormCell(9, tuning: StormPlan.regular);
      final bolts = <double>[];
      var t = 0.0;
      for (var f = 0; f < 60 * 900; f++) {
        t += 1 / 60;
        final out = cell.step(
          1 / 60,
          shipX: 180 + 120 * math.sin(t),
          swarm: const [90, 140, 200, 260],
          rate: 1.3,
        );
        if (out.isNotEmpty) bolts.add(t);
      }
      expect(bolts.length, greaterThan(50));
      for (var i = 0; i < bolts.length; i++) {
        final inSecond = bolts.where((b) => b >= bolts[i] && b < bolts[i] + 1);
        expect(inSecond.length, lessThanOrEqualTo(1));
      }
      // The tell's marker: never more than three blinks in any second.
      final s = StormStrike(0, 100, StrikeAim.ship, 1.25, 1);
      final ons = <double>[];
      var was = StormPainter.markerOn(s);
      for (var i = 1; i <= 1250; i++) {
        s.tellLeft = 1.25 - i / 1000;
        final on = StormPainter.markerOn(s);
        if (on && !was) ons.add(i / 1000);
        was = on;
      }
      for (final o in ons) {
        expect(
          ons.where((x) => x >= o && x < o + 1).length,
          lessThanOrEqualTo(3),
        );
      }
      expect(StormPainter.blinkHz(1), lessThanOrEqualTo(3));
      // The ship's zap flicker: at most three times a second.
      final m = ArcadeModel(seed: 1)..shipShock = 10;
      var hides = 0;
      var hidden = false;
      for (var i = 0; i < 1000; i++) {
        m.clock = i / 1000;
        final now = LightningPainter.shipFlickerOff(m);
        if (now && !hidden) hides++;
        hidden = now;
      }
      expect(hides, lessThanOrEqualTo(FlashSafety.maxFlashesPerSecond));
    });

    test('reduced flashing: no wash, no glow, no flicker', () {
      final m = stormy(seed: 5);
      final layer = StormLayer()..reducedFlash = true;
      FlashSafety.override = true;
      addTearDown(() => FlashSafety.override = null);
      m.shipShock = 10;
      for (var f = 0; f < 60 * 40; f++) {
        m.update(1 / 60);
        expect(layer.washOf(m.stormCell!), 0);
        expect(LightningPainter.shipFlickerOff(m), isFalse);
      }
      expect(m.weatherRun.bolts, greaterThan(0));
      expect(FlashSafety.reduced(reducedMotion: false), isTrue);
    });
  });

  group('radio', () {
    test('every weather moment has short written lines, squad and brood', () {
      for (final name in [
        'windStart.gale',
        'windGust.swing',
        GameEventNames.windDive,
        GameEventNames.stormStart,
        GameEventNames.stormStop,
        GameEventNames.rainStart,
      ]) {
        final spec = commsHumanTriggers[name];
        expect(spec, isNotNull, reason: name);
        expect(spec!.group, 'weather', reason: name);
        for (final line in spec.lines) {
          expect(line.silent, isTrue, reason: '${line.id}: its own words');
          expect(line.text!.length, lessThan(70), reason: line.id);
        }
        expect(commsDemonTriggers[name]?.lines, isNotEmpty, reason: name);
      }
    });

    test(
      'a storm start speaks once; a wind call right after waits its gap',
      () {
        final started = <CommsMessage>[];
        final d = CommsDirector(random: math.Random(3))..onStart = started.add;
        d.setSector(3, 0);
        for (var t = 0.0; t < 12; t += 1 / 60) {
          for (final (at, e) in [
            (1.0, const GameEvent(GameEventNames.stormStart, {'sector': 3})),
            (3.0, const GameEvent(GameEventNames.stormStart, {'sector': 3})),
            (
              5.0,
              const GameEvent(GameEventNames.windStart, {
                'variant': 'gale',
                'tier': 'gale',
              }),
            ),
          ]) {
            if ((t - at).abs() < 1 / 120) d.handle(e, t);
          }
          d.update(t, combat: true);
        }
        final human = started.where((m) => !m.isDemon).toList();
        expect(human, hasLength(1));
        expect(human.single.trigger.name, GameEventNames.stormStart);
      },
    );

    test('the model calls the storm and the wind turns', () {
      final m = stormy(seed: 3, gale: true)..invulnerable = 1e6;
      final names = <String>{};
      for (var f = 0; f < 60 * 60; f++) {
        m.update(1 / 60);
        for (final e in m.takeGameEvents()) {
          names.add(e.variant == null ? e.name : '${e.name}.${e.variant}');
        }
      }
      expect(names, contains('${GameEventNames.stormStart}.downpour'));
      expect(names, contains('windStart.gale'));
      expect(names, contains('windGust.swing'));
    });
  });

  group('wind flap', () {
    Demon flyer() => Demon(100, 120, 1, 1, 1);
    final calm = (
      row: CombatAtlas.base(1),
      col: 13,
      tintFlash: false,
      eliteRow: CombatAtlas.eliteRow(1),
      eliteCol: 4,
      lift: 0,
    );

    test('the side follows the wind; calm, dives and tells keep theirs', () {
      final d = flyer();
      final right = WindFlap.cell(d, calm, 1, lateral: .8);
      final left = WindFlap.cell(d, calm, 1, lateral: -.8);
      expect(WindFlap.isWind(right.row), isTrue);
      expect(right.col ~/ WindFlapAtlas.frames, 1);
      expect(left.col ~/ WindFlapAtlas.frames, 0);
      expect(WindFlap.cell(d, calm, 1, lateral: .05), calm);
      d.dive = .5;
      expect(WindFlap.cell(d, calm, 1, lateral: .8), calm);
      d
        ..dive = 0
        ..telegraph = .3;
      expect(WindFlap.cell(d, calm, 1, lateral: .8), calm);
      // The insignia rides the wind-flap skull.
      final head = CombatAtlas.headAnchor(right.row, right.col);
      expect(head.dy, inInclusiveRange(-20, -4));
    });

    test('the upwind wing beats higher in the frames themselves', () async {
      final data = await rootBundle.load(
        'assets/images/${WindFlapAtlas.asset}',
      );
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      addTearDown(image.dispose);
      final bytes = (await image.toByteData())!;
      final w = image.width;
      int top(int col, int row, {required bool leftHalf}) {
        for (var y = 0; y < 64; y++) {
          for (var x = leftHalf ? 0 : 33; x < (leftHalf ? 31 : 64); x++) {
            final a = bytes.getUint8(
              ((row * 64 + y) * w + col * 64 + x) * 4 + 3,
            );
            if (a > 0) return y;
          }
        }
        return 64;
      }

      for (var k = 0; k < 4; k++) {
        final row = k * WindFlapAtlas.speciesRows;
        // Frames 0 and 7: the wings up. Wind to the right: the left wing
        // (upwind) reaches higher; to the left, the right one.
        for (final f in const [0, 7]) {
          expect(
            top(8 + f, row, leftHalf: true),
            lessThan(top(8 + f, row, leftHalf: false)),
            reason: 'species $k frame $f, wind blowing right',
          );
          expect(
            top(f, row, leftHalf: false),
            lessThan(top(f, row, leftHalf: true)),
            reason: 'species $k frame $f, wind blowing left',
          );
        }
      }
    });
  });

  group('smart demons ride the wind', () {
    test('the wait is bounded, and none without wind or wits', () {
      final m = stormy(gale: true, storm: false, sector: 3, route: 2);
      final drone = Demon(100, 120, 0, 1, 1);
      final hunter = Demon(100, 120, 0, 1, 1, elite: true);
      expect(ArcadeWindDive.windSmart(drone, 4), isFalse);
      expect(ArcadeWindDive.windSmart(hunter, 0), isTrue);
      for (var i = 0; i < 300; i++) {
        m.levelClock = i * .2;
        expect(m.windDiveDelay(drone), 0);
        expect(
          m.windDiveDelay(hunter),
          inInclusiveRange(-1, ArcadeWindDive.maxWait),
        );
      }
      final still = stormy(storm: false, sector: 3, route: 2);
      expect(still.windDiveDelay(hunter), 0);
    });

    test('a smart demon starts its dives in a tailwind more often', () {
      var smart = 0, smartAligned = 0, grunt = 0, gruntAligned = 0;
      for (final seed in const [3, 5, 8, 13, 21, 34]) {
        final m = stormy(
          seed: seed,
          gale: true,
          storm: false,
          sector: 3,
          route: 2,
        )..invulnerable = 1e6;
        for (var f = 0; f < 60 * 90; f++) {
          m.update(1 / 60);
          m.invulnerable = 1e6;
          m.lives = math.max(m.lives, 3);
          for (final d in m.demons) {
            expect(
              d.windWait,
              lessThanOrEqualTo(ArcadeWindDive.maxWait + 1e-9),
            );
          }
        }
        final r = m.weatherRun;
        smart += r.smartDives;
        smartAligned += r.smartAligned;
        grunt += r.gruntDives;
        gruntAligned += r.gruntAligned;
      }
      expect(smart, greaterThan(10));
      expect(grunt, greaterThan(10));
      final ps = smartAligned / smart, pg = gruntAligned / grunt;
      expect(ps, greaterThan(pg + .15), reason: 'smart $ps vs grunt $pg');
    });

    test('calm air: every dive is prepared at once, as before', () {
      final m = stormy(storm: false, sector: 3, route: 2)..invulnerable = 1e6;
      for (var f = 0; f < 60 * 40; f++) {
        m.update(1 / 60);
        m.invulnerable = 1e6;
        for (final d in m.demons) {
          expect(d.windWait, 0);
          expect(d.windRide, 0);
        }
      }
      expect(m.weatherRun.smartDives + m.weatherRun.gruntDives, 0);
    });
  });
}

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/average_pilot.dart';

/// crosswind (specs/bonus-level-crosswind): the level's rules, its kites
/// and its completion. Every loop is bounded by a frame count.
void main() {
  ArcadeModel level({int seed = 5, int sector = 3, String? modifier}) {
    final m = ArcadeModel(seed: seed)
      ..startAt(
        sector: sector,
        route: 1,
        runSeed: seed,
        bonus: 'crosswind',
        modifier: modifier,
      );
    m.mode = RunMode.playing;
    return m;
  }

  /// A wind-aware pilot: the nearest live kite (else the first demon),
  /// led for its drift and for the wind's.
  void steer(ArcadeModel m) {
    final c = m.bonusMechanic! as CrosswindMechanic;
    final kite = c.kites
        .where((k) => k.popped == null && !k.gone && k.x > 8 && k.x < 352)
        .firstOrNull;
    final demon = m.demons.where((d) => !d.entering).firstOrNull;
    double? x, y, vx;
    if (kite != null) {
      (x, y, vx) = (kite.x, kite.y, kite.vx);
    } else if (demon != null) {
      (x, y, vx) = (demon.x, demon.y, demon.vx);
    }
    if (x == null) return;
    final flight = (ArcadeModel.shipY - y!) / ArcadeModel.shotSpeed;
    m.moveTo(x + vx! * flight - AveragePilot.expectedDrift(m, y));
  }

  test('the catalogue entry: wind on, single shots, the briefing, the cue', () {
    final def = bonusLevelById('crosswind')!;
    expect(def.wind, isTrue);
    expect(def.rules.banned, containsAll({Power.spread, Power.rapid}));
    expect(def.brief, isNotEmpty);
    expect(def.how, isNotEmpty);
    expect(def.look.cue, 'bonus-wind');
    expect(def.mechanic, isNotNull);
    expect(bonusLevels.last, same(def)); // appended, never reordered
  });

  test('the level blows the crosswind tier from its start', () {
    final m = level();
    expect(m.bonus?.id, 'crosswind');
    expect(m.windRun.spec?.tier, WindTier.crosswind);
    for (var f = 0; f < 30; f++) {
      m.update(1 / 60);
    }
    expect(m.wind.amount, 1);
  });

  test('no multifire and no Rapid: carried-in modules are stripped and '
      'every volley is one shot', () {
    final m = level()..invulnerable = 1e6;
    m.collect(Power.spread);
    m.collect(Power.rapid);
    m.update(1 / 60);
    expect(m.hasPower(Power.spread), isFalse);
    expect(m.hasPower(Power.rapid), isFalse);
    for (var f = 0; f < 60 * 30; f++) {
      final before = m.shots.where((s) => !s.hostile).toSet();
      m.update(1 / 60);
      final fresh = m.shots.where((s) => !s.hostile && !before.contains(s));
      expect(fresh.length, lessThanOrEqualTo(1));
      expect(m.hasPower(Power.spread) || m.hasPower(Power.rapid), isFalse);
    }
  });

  test('a Spread-only run cannot bring Spread into the level', () {
    final m = level(modifier: 'spreadOnly')..invulnerable = 1e6;
    for (var f = 0; f < 60 * 60; f++) {
      steer(m);
      m.update(1 / 60);
      expect(m.hasPower(Power.spread), isFalse);
      expect(
        m.pickups.any((p) => p.bonus == null && p.power == Power.spread),
        isFalse,
      );
    }
  });

  test('kites ride the wind and some get away; deterministic per seed', () {
    List<String> trace(int seed) {
      final m = level(seed: seed)..invulnerable = 1e6;
      final c = m.bonusMechanic! as CrosswindMechanic;
      final out = <String>[];
      var rode = 0;
      for (var f = 0; f < 60 * 40; f++) {
        m.update(1 / 60);
        for (final k in c.kites) {
          if (k.age > 2 &&
              m.windDrift.abs() > 30 &&
              k.vx.sign == m.windDrift.sign) {
            rode++;
          }
        }
        if (f % 120 == 0) {
          out.add(c.kites.map((k) => k.x.toStringAsFixed(2)).join(','));
        }
      }
      expect(c.launched, greaterThan(0));
      expect(rode, greaterThan(0));
      return out;
    }

    expect(trace(9), trace(9));
    expect(trace(9), isNot(trace(10)));
  });

  test('the level completes, and a wind-aware pilot pops kites', () {
    final m = level(seed: 21)..invulnerable = 1e6;
    final c = m.bonusMechanic! as CrosswindMechanic;
    final names = <String>[];
    var cleared = false;
    for (var f = 0; f < 60 * 600 && !cleared; f++) {
      steer(m);
      m.update(1 / 60);
      names.addAll(m.takeGameEvents().map((e) => e.name));
      cleared = m.mode == RunMode.salvage || m.level != 3;
    }
    expect(cleared, isTrue);
    expect(names, contains(GameEventNames.bonusCleared));
    expect(c.launched, greaterThanOrEqualTo(c.perWave));
    expect(c.popped, greaterThan(c.launched ~/ 2));
    expect(names, contains(GameEventNames.kitePopped));
  });
}

import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3 task 6.1: the intro's events in the game event queue, in
/// order, with their data; the hatch cascade's events (carrier-hatches).
void main() {
  void clearWave(ArcadeModel m) {
    for (final d in List.of(m.demons)) {
      m.hitDemon(d, damage: 999);
    }
  }

  test('approach → gates → in range → take-off → climb peak, in order', () {
    final m = ArcadeModel(seed: 5)..startAt(sector: 5, route: 0, wave: 1);
    final dir = BossDirector(seed: 5);
    final log = <GameEvent>[];
    void step(int frames) {
      for (var i = 0; i < frames; i++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        dir.update(m, 1 / 60, carrier: true, threat: false);
        log.addAll(m.takeGameEvents());
      }
    }

    step(60 * 8); // the first volleys leave the gates
    for (var g = 0; g < 60 * 300 && m.boss == null; g++) {
      if (m.loomClock > 4) clearWave(m);
      step(1);
    }
    final b = m.boss!;
    for (var g = 0; g < 60 * 30 && !b.fightReady; g++) {
      step(1);
    }
    step(60 * 12);
    final names = log.map((e) => e.name).toList();
    int first(String n) => names.indexOf(n);
    for (final n in [
      GameEventNames.bossApproach,
      GameEventNames.bossHatchTelegraph,
      GameEventNames.bossHatchOpen,
      GameEventNames.bossLaunch,
      GameEventNames.bossHatchClose,
      GameEventNames.bossInRange,
      GameEventNames.bossTakeoff,
      GameEventNames.bossClimbPeak,
    ]) {
      expect(first(n), greaterThanOrEqualTo(0), reason: n);
    }
    expect(first(GameEventNames.bossApproach),
        lessThan(first(GameEventNames.bossHatchTelegraph)));
    expect(first(GameEventNames.bossHatchTelegraph),
        lessThan(first(GameEventNames.bossHatchOpen)));
    expect(first(GameEventNames.bossHatchOpen),
        lessThan(first(GameEventNames.bossLaunch)));
    expect(first(GameEventNames.bossLaunch),
        lessThan(first(GameEventNames.bossHatchClose)));
    expect(first(GameEventNames.bossInRange) + 1,
        first(GameEventNames.bossTakeoff));
    expect(first(GameEventNames.bossTakeoff),
        lessThan(first(GameEventNames.bossClimbPeak)));
    // Every one carries the route, tour and set.
    for (final e in log.where((e) => GameEventNames.carrierIntro.contains(e.name))) {
      expect(e.data['route'], 0);
      expect(e.data['tour'], 1);
      expect(e.data['set'], isA<String>());
    }
    final launch = log.firstWhere((e) => e.name == GameEventNames.bossLaunch);
    expect(launch.data['hatch'], isA<String>());
    expect(launch.data['count'], isA<int>());
    // Each step closer.
    expect(log.where((e) => e.name == GameEventNames.bossApproach).length,
        greaterThanOrEqualTo(2));
  });

  // carrier-hatches §A8 (the hull-wide field and its impacts are retired):
  // a tier's destruction, the transformation and the core, in order, all
  // structured, none raw.
  test('hatches → tier → transformation → core exposed, in order', () {
    final m = ArcadeModel(seed: 6)..startAt(sector: 5, route: 0);
    final b = m.boss!;
    for (var g = 0; g < 60 * 60 && !(b.fightReady && m.combat); g++) {
      m.invulnerable = 2;
      m.update(1 / 60);
    }
    expect(m.combat, isTrue);
    final log = <GameEvent>[...m.takeGameEvents()];
    final raw = <String>[];
    for (var guard = 0; guard < 600 && b.chapter.name != 'core'; guard++) {
      for (final (i, h) in b.hatches.indexed) {
        if (!h.destroyed) m.hitHatch(i, damage: 2);
      }
      m.invulnerable = 2;
      m.update(1 / 60);
      log.addAll(m.takeGameEvents());
      raw.addAll(m.takeEvents());
    }
    final names = log.map((e) => e.name).toList();
    int first(String n) => names.indexOf(n);
    expect(first(GameEventNames.bossHatchTier), greaterThanOrEqualTo(0));
    expect(first(GameEventNames.bossHatchFieldDown),
        lessThan(first(GameEventNames.bossHatchDrop)));
    expect(first(GameEventNames.bossHatchDrop),
        lessThan(first(GameEventNames.bossShieldDown)));
    expect(first(GameEventNames.bossShieldDown),
        lessThan(first(GameEventNames.bossTransform)));
    expect(first(GameEventNames.bossTransform),
        lessThan(first(GameEventNames.bossCoreExposed)));
    final tiers = log.where((e) => e.name == GameEventNames.bossHatchTier);
    expect([for (final e in tiers) e.data['tier']], [1, 2, 3]);
    expect(tiers.last.data['tiers'], 3);
    expect(tiers.last.data['depth'], 1.0);
    expect(log.where((e) => e.name == GameEventNames.bossHatchDrop),
        hasLength(4));
    for (final n in [
      GameEventNames.bossHatchDrop,
      GameEventNames.bossHatchTier,
      GameEventNames.bossTransform,
      GameEventNames.bossHatchFieldDown,
    ]) {
      expect(raw.contains(n), isFalse, reason: 'structured only: $n');
    }
    expect(names.contains('bossGateOpen'), isFalse);
  });
}

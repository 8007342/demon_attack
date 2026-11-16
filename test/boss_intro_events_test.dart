import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3 task 6.1: the intro's events in the game event queue, in
/// order, with their data; field impacts throttled to 4 per second.
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
      GameEventNames.bossGateTelegraph,
      GameEventNames.bossGateOpen,
      GameEventNames.bossLaunch,
      GameEventNames.bossGateClose,
      GameEventNames.bossInRange,
      GameEventNames.bossTakeoff,
      GameEventNames.bossClimbPeak,
    ]) {
      expect(first(n), greaterThanOrEqualTo(0), reason: n);
    }
    expect(first(GameEventNames.bossApproach),
        lessThan(first(GameEventNames.bossGateTelegraph)));
    expect(first(GameEventNames.bossGateTelegraph),
        lessThan(first(GameEventNames.bossGateOpen)));
    expect(first(GameEventNames.bossGateOpen),
        lessThan(first(GameEventNames.bossLaunch)));
    expect(first(GameEventNames.bossLaunch),
        lessThan(first(GameEventNames.bossGateClose)));
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
    expect(launch.data['gate'], isA<String>());
    expect(launch.data['count'], isA<int>());
    // Each step closer.
    expect(log.where((e) => e.name == GameEventNames.bossApproach).length,
        greaterThanOrEqualTo(2));
  });

  test('field impacts: at most 4 per second', () {
    final m = ArcadeModel(seed: 6)..startAt(sector: 5, route: 0);
    final b = m.boss!;
    for (var g = 0; g < 60 * 60 && !(b.fightReady && m.combat); g++) {
      m.invulnerable = 2;
      m.update(1 / 60);
    }
    expect(m.combat, isTrue);
    m.takeGameEvents();
    for (var i = 0; i < 10; i++) {
      m.hitBoss(b.x + i * 5);
      m.invulnerable = 2;
      m.update(1 / 60);
    }
    final impacts = m
        .takeGameEvents()
        .where((e) => e.name == GameEventNames.bossFieldImpact)
        .toList();
    expect(impacts, hasLength(4));
    expect(impacts.first.data['region'], isA<String>());
    final cells = m.takeGameEvents();
    expect(cells, isEmpty);
  });
}

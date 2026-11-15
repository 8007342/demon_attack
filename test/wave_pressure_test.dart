// Cohort merge (openspec/changes/continuous-swarm design §2.3 and §9,
// rewritten from the old wave-pressure test): when a wave is down to its
// last few, the next wave's first skeins rise out of the fog while the
// stragglers still fight; there is no transition phase between the waves
// of a sector, and a faster clear shortens the next approach.
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/swarm_stream.dart';
import 'package:flutter_test/flutter_test.dart';

ArcadeModel _combat(Difficulty d, {int wave = 1, int route = 0}) {
  final m = ArcadeModel(seed: 7)
    ..startAt(difficulty: d, wave: wave, route: route);
  for (var i = 0; i < 60 * 20 && !m.combat; i++) {
    m.update(1 / 60);
  }
  expect(m.combat, isTrue);
  return m;
}

/// Kills settled enemies (all reinforcements in) until [left] remain;
/// returns the events seen on the way.
List<String> _killDownTo(ArcadeModel m, int left) {
  final seen = <String>[];
  for (var f = 0; f < 60 * 120; f++) {
    m.invulnerable = 2;
    seen.addAll(m.takeEvents());
    if (m.flocksRemaining == 0 && m.demons.length <= left) return seen;
    final target = m.demons.where((d) => !d.entering).firstOrNull;
    if (target != null && (m.flocksRemaining > 0 || m.demons.length > left)) {
      m.hitDemon(target, damage: 99);
    }
    m.update(1 / 60);
  }
  fail('could not reduce the wave to $left (left ${m.demons.length})');
}

void _step(ArcadeModel m, double seconds, {void Function()? each}) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    m.invulnerable = 2;
    m.update(1 / 60);
    each?.call();
  }
}

void main() {
  for (final d in Difficulty.values) {
    test(
      '${d.name}: the next wave is sighted at the threshold, untargetable',
      () {
        final m = _combat(d);
        final threshold = m.policy.pressureThreshold;
        _killDownTo(m, threshold + 1);
        m.update(1 / 60);
        expect(m.incoming, isEmpty, reason: 'above the threshold: no pressure');
        final seen = _killDownTo(m, threshold);
        m.update(1 / 60);
        seen.addAll(m.takeEvents());
        expect(m.incoming, isNotEmpty);
        expect(seen, contains('incoming'));
        expect(m.wave, 1, reason: 'the current wave is still being fought');
        expect(
          m.incoming.length,
          m.policy.rosterCount(sector: 1, wave: 2, route: 0),
        );
        // The first half of its skeins approach; the rest wait in reserve.
        final approaching = m.incoming
            .where((x) => x.swarmState == SwarmState.approaching)
            .length;
        expect(approaching, greaterThan(0));
        expect(
          m.incoming.where((x) => x.swarmState == SwarmState.reserve).length +
              approaching,
          m.incoming.length,
        );
        for (final x in m.incoming) {
          expect(m.demons, isNot(contains(x)), reason: 'not targetable yet');
          expect(x.entering, isTrue, reason: 'silent: entering never fires');
        }
      },
    );
  }

  test('the approaching cohort never fires and cannot be hit', () {
    final m = _combat(Difficulty.normal);
    _killDownTo(m, m.policy.pressureThreshold);
    m.update(1 / 60);
    final cohort = Set.of(m.incoming);
    final hostileBefore = m.shots.where((s) => s.hostile).toSet();
    _step(
      m,
      2,
      each: () {
        for (final s in m.shots.where((s) => s.hostile)) {
          if (hostileBefore.contains(s)) continue;
          for (final x in cohort) {
            expect(
              (s.x - x.x).abs() < 1 && (s.y - x.y - x.muzzleDy).abs() < 1,
              isFalse,
              reason: 'a shot from an approaching creature',
            );
          }
        }
      },
    );
    for (final x in cohort) {
      final hp = x.hp;
      m.shots.add(Shot(x.x, x.y, 0, 0));
      m.update(1 / 60);
      expect(x.hp, hp);
    }
  });

  test('stragglers first: a lull at the fog front, no transition phase', () {
    final m = _combat(Difficulty.normal);
    _killDownTo(m, m.policy.pressureThreshold);
    _step(m, 1);
    final approaching = List.of(m.incoming);
    expect(approaching, isNotEmpty);
    m.shots.add(Shot(100, 300, 0, 40, hostile: true));
    for (final x in List.of(m.demons)) {
      m.hitDemon(x, damage: 99);
    }
    m.takeEvents();
    m.takeGameEvents();
    m.update(1 / 60);
    expect(m.wave, 2);
    expect(m.mode, RunMode.playing, reason: 'no interwave transition');
    expect(m.incoming, isEmpty);
    expect(m.demons.toSet(), approaching.toSet());
    final events = m.takeEvents();
    expect(events, containsAll(['wave', 'checkpoint', 'shotsFizzle']));
    final merged = m
        .takeGameEvents()
        .where((e) => e.name == GameEventNames.cohortMerged)
        .single;
    expect(merged.data['forced'], isFalse);
    final lull = merged.data['lull'] as double;
    expect(lull, SwarmStream.lull(m.stream.q));
    // Leftover hostile shots dissolve within 0.25 s.
    _step(m, .3);
    expect(m.shots.where((s) => s.hostile && s.fizzleIn != null), isEmpty);
    // During the lull nothing is targetable and the approach holds.
    final held = {
      for (final x in m.demons)
        if (x.swarmState == SwarmState.approaching) x: x.entranceProgress,
    };
    _step(m, lull - .4);
    for (final e in held.entries) {
      expect(e.key.entering, isTrue);
      expect(e.key.entranceProgress, e.value, reason: 'held at the front');
    }
    // Then it closes in and fights.
    _step(m, lull + 3);
    expect(m.demons.where((x) => !x.entering), isNotEmpty);
    expect(m.mode, RunMode.playing);
  });

  test('lingering: a forced merge closes in beside the stragglers', () {
    final m = _combat(Difficulty.normal);
    final threshold = m.policy.pressureThreshold;
    _killDownTo(m, threshold);
    m.update(1 / 60);
    final stragglers = List.of(m.demons);
    final roster = m.incoming.length;
    expect(roster, greaterThan(0));
    m.takeGameEvents();
    // Keep the stragglers alive: nobody shoots in this test.
    _step(
      m,
      m.incomingTotal / m.policy.hostileRate + .2,
      each: () => m.shots.removeWhere((s) => !s.hostile),
    );
    expect(m.wave, 2);
    expect(m.combat, isTrue, reason: 'no transition pause on a forced join');
    expect(m.incoming, isEmpty);
    expect(
      m.takeGameEvents().where(
        (e) =>
            e.name == GameEventNames.cohortMerged && e.data['forced'] == true,
      ),
      hasLength(1),
    );
    final alive = stragglers.where(m.demons.contains).length;
    expect(m.demons.length, alive + roster);
    // Occupancy stays inside the calibrated bound: roster + a group.
    expect(
      m.swarmOccupancy,
      lessThanOrEqualTo(
        roster + m.policy.reinforcementSize(route: 0, flock: 1),
      ),
    );
  });

  test('a lost life pauses the approach clock and resets q', () {
    final m = _combat(Difficulty.normal);
    _killDownTo(m, m.policy.pressureThreshold);
    m.update(1 / 60);
    final before = m.incomingLeft;
    m.lifeLossPhase = LifeLossPhase.exploding;
    m.update(.5);
    expect(m.incomingLeft, before);
    m.stream.lifeLost();
    expect(m.stream.q, 1);
    expect(
      m.stream.paceNext(cohortHp: 1000, floor: m.policy.paceFloor),
      1,
      reason: 'the next cohort is unaccelerated',
    );
  });

  test('the last wave of a level brings no next cohort', () {
    final m = ArcadeModel(seed: 7)..startAt(difficulty: Difficulty.normal);
    final last = m.wavesPerLevel;
    final l = _combat(Difficulty.normal, wave: last);
    expect(l.wave, last);
    _killDownTo(l, 1);
    _step(l, 2);
    expect(l.incoming, isEmpty);
  });

  test('the approaching roster is exactly a fresh wave 2 roster', () {
    final m = _combat(Difficulty.hard, route: 2);
    _killDownTo(m, m.policy.pressureThreshold);
    m.update(1 / 60);
    final fresh = _combat(Difficulty.hard, wave: 2, route: 2);
    List<(int, int, bool)> profile(Iterable<Demon> ds) => [
      for (final x in ds) (x.kind, x.hp, x.elite),
    ];
    expect(profile(m.incoming), profile(fresh.demons.take(m.incoming.length)));
  });

  test('no transition phase between the waves of a sector', () {
    for (final d in Difficulty.values) {
      final m = ArcadeModel(seed: 3)..startAt(difficulty: d);
      for (var i = 0; i < 60 * 20 && !m.combat; i++) {
        m.update(1 / 60);
      }
      final waves = m.wavesPerLevel;
      for (var f = 0; f < 60 * 600 && m.level == 1; f++) {
        m.invulnerable = 2;
        if (m.mode == RunMode.salvage) break;
        expect(
          m.mode,
          isNot(RunMode.transition),
          reason: '${d.name} wave ${m.wave}',
        );
        for (final x in List.of(m.demons)) {
          if (!x.entering) m.hitDemon(x, damage: 99);
        }
        m.update(1 / 60);
      }
      expect(m.wave, waves);
      expect(m.mode, RunMode.salvage);
    }
  });

  test('a fast clear shortens the next approach, never below the floor', () {
    for (final d in Difficulty.values) {
      final m = _combat(d);
      // Kill as fast as possible: the clear is far under T_expected.
      _killDownTo(m, m.policy.pressureThreshold);
      m.update(1 / 60);
      expect(m.incoming, isNotEmpty);
      final full = m.policy.incomingSeconds;
      expect(m.incomingTotal, lessThan(full));
      expect(
        m.incomingTotal,
        greaterThanOrEqualTo(full * m.policy.paceFloor - 1e-9),
      );
    }
  });
}

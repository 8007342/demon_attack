// Wave pressure: the next wave approaches out of the horizon fog once the
// current wave is down to its last few, and joins the fight if the player
// lingers (lib/game/model.dart `--- wave pressure`).
import 'package:demon_attack/game/model.dart';
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

void _step(ArcadeModel m, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    m.invulnerable = 2;
    m.update(1 / 60);
  }
}

void main() {
  for (final d in Difficulty.values) {
    test('${d.name}: the next wave appears at the threshold, untargetable', () {
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
      for (final x in m.incoming) {
        expect(m.demons, isNot(contains(x)), reason: 'not targetable yet');
      }
    });
  }

  test(
    'finishing the stragglers first: the usual short release, no forfeit',
    () {
      final m = _combat(Difficulty.normal);
      _killDownTo(m, m.policy.pressureThreshold);
      _step(m, 1);
      final approaching = List.of(m.incoming);
      expect(approaching, isNotEmpty);
      for (final x in List.of(m.demons)) {
        m.hitDemon(x, damage: 99);
      }
      m.takeEvents();
      m.update(1 / 60);
      expect(m.wave, 2);
      expect(m.mode, RunMode.transition);
      expect(m.incoming, isEmpty);
      expect(m.demons.toSet(), approaching.toSet());
      expect(m.takeEvents(), containsAll(['wave', 'checkpoint']));
    },
  );

  test('lingering: the approaching wave joins the fight, combat goes on', () {
    final m = _combat(Difficulty.normal);
    final threshold = m.policy.pressureThreshold;
    _killDownTo(m, threshold);
    m.update(1 / 60);
    final stragglers = List.of(m.demons);
    final roster = m.incoming.length;
    expect(roster, greaterThan(0));
    // Keep the stragglers alive: nobody shoots in this test.
    _step(m, m.policy.incomingSeconds / m.policy.hostileRate + .2);
    expect(m.wave, 2);
    expect(m.combat, isTrue, reason: 'no transition pause on a forced join');
    expect(m.incoming, isEmpty);
    final alive = stragglers.where(m.demons.contains).length;
    expect(m.demons.length, alive + roster);
    // Occupancy stays inside the calibrated bound: roster + a group.
    expect(
      m.demons.length,
      lessThanOrEqualTo(
        roster + m.policy.reinforcementSize(route: 0, flock: 0),
      ),
    );
  });

  test('a lost life pauses the approach clock', () {
    final m = _combat(Difficulty.normal);
    _killDownTo(m, m.policy.pressureThreshold);
    m.update(1 / 60);
    final before = m.incomingLeft;
    m.lifeLossPhase = LifeLossPhase.exploding;
    m.update(.5);
    expect(m.incomingLeft, before);
  });

  test('the last wave of a level brings no early arrival', () {
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
}

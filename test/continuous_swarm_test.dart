// Continuous swarm (openspec/changes/continuous-swarm): the stream inside
// the model: groups wait in the reserve, roster skeins release by the
// gap, the occupancy bound holds at every step, divers rejoin out of the
// fog, and a sector replays identically from the same seed.
import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/swarm_stream.dart';
import 'package:flutter_test/flutter_test.dart';

ArcadeModel _combat(
  Difficulty d, {
  int sector = 1,
  int wave = 1,
  int route = 0,
  int seed = 7,
}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(difficulty: d, sector: sector, wave: wave, route: route);
  for (var i = 0; i < 60 * 20 && !m.combat; i++) {
    m.update(1 / 60);
  }
  expect(m.combat, isTrue);
  return m;
}

/// Everything the fight depends on: entering creatures by their entrance
/// clock, every other creature by its exact position.
String signature(ArcadeModel m) {
  final b = StringBuffer()
    ..write('${m.mode} ${m.level} ${m.wave} ${m.score} ${m.lives} ')
    ..write('${m.kills} ${m.shots.length} ${m.incoming.length}|');
  for (final d in m.demons) {
    b.write(
      '${d.x.toStringAsFixed(9)},${d.y.toStringAsFixed(9)},'
      '${d.nearness.toStringAsFixed(9)},${d.hp},${d.dive},'
      '${d.entranceProgress},${d.swarmState.index};',
    );
  }
  return b.toString();
}

/// A simple deterministic pilot: chase the first settled enemy.
void _pilot(ArcadeModel m) {
  final d = m.demons.where((d) => !d.entering).firstOrNull;
  if (d != null) m.moveTo(d.x + d.vx * .3);
}

void main() {
  test('groups wait in the reserve: untargetable, silent, not counted', () {
    final m = _combat(Difficulty.normal);
    expect(m.flocksPlanned, 2);
    final reserve = m.swarmReserve.toList();
    expect(
      reserve.length,
      greaterThanOrEqualTo(
        m.policy.reinforcementSize(route: 0, flock: 0) +
            m.policy.reinforcementSize(route: 0, flock: 1),
      ),
    );
    for (final d in reserve) {
      expect(d.swarmState, SwarmState.reserve);
      expect(d.nearness, inInclusiveRange(.08, .22), reason: 'deep fog');
      expect(d.entering, isTrue);
    }
    final grouped = reserve.where((d) => !m.demons.contains(d)).toList();
    expect(grouped, isNotEmpty, reason: 'groups are not in the fight');
    // They drift (Lévy steps) while they wait.
    final before = {for (final d in grouped) d: (d.x, d.y)};
    for (var i = 0; i < 120; i++) {
      m.invulnerable = 2;
      m.update(1 / 60);
    }
    final moved = grouped.where(
      (d) =>
          m.swarmReserve.contains(d) &&
          ((d.x - before[d]!.$1).abs() + (d.y - before[d]!.$2).abs()) > .5,
    );
    expect(moved, isNotEmpty);
  });

  test('admission flips a group from the reserve to a swoop', () {
    final m = _combat(Difficulty.normal);
    final first = m.swarmReserve.where((d) => !m.demons.contains(d)).toList();
    final waiting = first.take(m.policy.reinforcementSize(route: 0, flock: 0));
    var admitted = false;
    for (var f = 0; f < 60 * 30 && !admitted; f++) {
      m.invulnerable = 2;
      final target = m.demons.where((d) => !d.entering).firstOrNull;
      if (target != null) m.hitDemon(target, damage: 99);
      m.update(1 / 60);
      admitted = m.takeEvents().contains('reinforcements');
    }
    expect(admitted, isTrue);
    for (final d in waiting) {
      expect(m.demons, contains(d), reason: 'the creature seen in the fog');
      expect(d.swarmState, SwarmState.approaching);
    }
  });

  test('a streamed wave releases its roster skein by skein', () {
    final m = _combat(Difficulty.normal);
    // Clear wave 1 at once (above the threshold): wave 2 streams in.
    for (var f = 0; f < 60 * 60 && m.wave == 1; f++) {
      m.invulnerable = 2;
      for (final d in List.of(m.demons)) {
        if (!d.entering) m.hitDemon(d, damage: 99);
      }
      m.update(1 / 60);
    }
    expect(m.wave, 2);
    expect(m.mode, RunMode.playing);
    var maxReleased = 0, sawPending = false;
    for (var f = 0; f < 60 * 8; f++) {
      m.invulnerable = 2;
      m.shots.removeWhere((s) => !s.hostile);
      final pending = m.demons
          .where((d) => d.swarmState == SwarmState.reserve)
          .length;
      if (pending > 0) sawPending = true;
      final released = m.demons.length - pending;
      expect(released, greaterThanOrEqualTo(maxReleased));
      if (released > maxReleased) maxReleased = released;
      m.update(1 / 60);
    }
    expect(sawPending, isTrue, reason: 'later skeins waited for their gap');
    expect(maxReleased, m.demons.length, reason: 'all released in time');
  });

  test('occupancy bound holds at every step of a busy sector', () {
    for (final d in Difficulty.values) {
      for (final (sector, route) in [(1, 0), (2, 1), (4, 3)]) {
        final m = _combat(d, sector: sector, route: route);
        for (var f = 0; f < 60 * 240 && m.level == sector; f++) {
          m.invulnerable = 2;
          _pilot(m);
          m.update(1 / 60);
          expect(
            m.swarmOccupancy,
            lessThanOrEqualTo(m.swarmOccupancyBound),
            reason: '${d.name} $sector/$route wave ${m.wave}',
          );
        }
      }
    }
  });

  test('a diver that leaves the bottom rejoins out of the fog', () {
    final m = _combat(Difficulty.normal, sector: 2);
    for (var f = 0; f < 60 * 4; f++) {
      m.invulnerable = 2;
      m.shots.removeWhere((s) => !s.hostile);
      m.update(1 / 60);
    }
    final d = m.demons.firstWhere((d) => !d.entering && !d.isLarge);
    d
      ..dive = .5
      ..targetX = d.x
      ..y = ArcadeModel.height + 19;
    m.invulnerable = 2;
    m.update(1 / 60);
    expect(d.swarmState, SwarmState.reentering);
    expect(d.entering, isTrue, reason: 'untargetable until it lands');
    expect(d.nearness, lessThan(.2), reason: 'far in the fog');
    expect(d.y, lessThan(Perspective.horizonY + 10), reason: 'not the top');
    for (var f = 0; f < 60 * 3 && d.entering; f++) {
      m.invulnerable = 2;
      m.shots.removeWhere((s) => !s.hostile);
      m.update(1 / 60);
    }
    expect(d.entering, isFalse);
    expect(d.swarmState, isNot(SwarmState.reentering));
  });

  test('a sector replays identically from the same seed', () {
    List<String> run() {
      final m = _combat(Difficulty.normal, sector: 2, seed: 33);
      final out = <String>[];
      for (var f = 0; f < 60 * 90; f++) {
        m.invulnerable = 2;
        _pilot(m);
        m.update(1 / 60);
        if (f % 5 == 0) out.add(signature(m));
        out.addAll(m.takeEvents().where((e) => e != 'shot'));
      }
      return out;
    }

    final a = run(), b = run();
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) fail('diverged at $i:\n${a[i]}\n${b[i]}');
    }
  });
  test('the swarm knows the fog bands the fog draws', () {
    expect(swarmFogBands, Atmosphere.bandNearness);
  });

  test('the sentinel rises through every fog band, >= 0.6 s per band', () {
    // Rise path alone (design §6.3): from a silhouette at n .2 to n .62.
    final times = <double>[];
    var prev = sentinelRiseNearness(0, .2, .62);
    for (var f = 1; f <= (sentinelRiseSeconds * 60).round(); f++) {
      final t = f / 60;
      final n = sentinelRiseNearness(t / sentinelRiseSeconds, .2, .62);
      for (final b in swarmFogBands) {
        if (prev < b && n >= b) times.add(t);
      }
      expect(n, greaterThanOrEqualTo(prev - 1e-12), reason: 'monotone');
      prev = n;
    }
    expect(times, hasLength(swarmFogBands.length));
    for (var i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], greaterThanOrEqualTo(.6 - 1 / 60));
    }
    expect(prev, closeTo(.62, 1e-9));
  });

  test('in play: a foreshadowed sentinel rises with its eta announced', () {
    // A sentinel wave: the escort pours out, the sentinel rises from its
    // silhouette; the observer's sentinelIncoming carries the eta.
    final m = ArcadeModel(seed: 7)
      ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
    var w = 2;
    while (m.sentinelFor(w) == null) {
      w++;
    }
    final s = ArcadeModel(seed: 7)
      ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1, wave: w);
    final observer = GameEventObserver(s, dispatch: false);
    double? eta;
    final crossings = <double>[];
    double? prevN;
    var t = 0.0;
    for (var f = 0; f < 60 * 30; f++) {
      s.invulnerable = 5;
      s.shots.removeWhere((x) => !x.hostile);
      s.update(1 / 60);
      t += 1 / 60;
      for (final e in observer.observe(s.takeEvents())) {
        if (e.name == GameEventNames.sentinelIncoming &&
            e.data['eta'] != null) {
          eta ??= (e.data['eta'] as num).toDouble();
        }
      }
      final sentinel = s.demons.where((d) => d.isLarge).firstOrNull;
      if (sentinel == null || sentinel.entranceProgress <= 0) continue;
      final n = sentinel.nearness;
      if (prevN != null && sentinel.entering) {
        for (final b in swarmFogBands) {
          if (prevN < b && n >= b) crossings.add(t);
        }
      }
      prevN = n;
      if (!sentinel.entering) break;
    }
    expect(eta, isNotNull);
    expect(eta!, greaterThan(sentinelRiseSeconds));
    expect(crossings.length, greaterThanOrEqualTo(3));
    for (var i = 1; i < crossings.length; i++) {
      expect(crossings[i] - crossings[i - 1], greaterThanOrEqualTo(.55));
    }
  });

  test('a reinforcement call carries its swoop eta', () {
    final m = _combat(Difficulty.normal);
    final observer = GameEventObserver(m, dispatch: false);
    double? eta;
    for (var f = 0; f < 60 * 30 && eta == null; f++) {
      m.invulnerable = 2;
      final target = m.demons.where((d) => !d.entering).firstOrNull;
      if (target != null) m.hitDemon(target, damage: 99);
      m.update(1 / 60);
      for (final e in observer.observe(m.takeEvents())) {
        if (e.name == GameEventNames.reinforcements) {
          eta = (e.data['eta'] as num?)?.toDouble();
        }
      }
    }
    expect(eta, closeTo(ArcadeModel.swoopSeconds, .5));
  });
}

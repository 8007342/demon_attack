import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// fire-rate-tune (openspec/changes/fire-rate-tune): the player's cadence in
/// whole steps, the anti-strobe speeds, the frame-time snap and the
/// rebalance for the slower gun.
ArcadeModel _playing() => ArcadeModel(seed: 3)
  ..start()
  ..mode = RunMode.playing
  ..invulnerable = 1000;

/// Steps between the volleys fired over [steps] model steps.
List<int> _gaps(ArcadeModel m, int steps) {
  final at = <int>[];
  for (var n = 0; n < steps; n++) {
    m.invulnerable = 1000;
    m.update(1 / 60);
    if (m.takeEvents().contains('shot')) at.add(n);
  }
  return [for (var i = 1; i < at.length; i++) at[i] - at[i - 1]];
}

void main() {
  test('the base gun volleys every 18 steps, Rapid every 8', () {
    final base = _gaps(_playing(), 240);
    expect(base, isNotEmpty);
    expect(base.toSet(), {ArcadeModel.fireSteps});
    expect(ArcadeModel.fireSteps, 18);
    final m = _playing()..collect(Power.rapid);
    final rapid = _gaps(m, 120);
    expect(rapid.toSet(), {ArcadeModel.rapidFireSteps});
    expect(ArcadeModel.rapidFireSteps, 8);
  });

  test('player shots climb whole units per step', () {
    final m = _playing()..collect(Power.spread);
    m.update(1 / 60);
    final volley = m.shots.where((s) => !s.hostile).toList();
    expect(volley, hasLength(3));
    for (final s in volley) {
      expect(s.vy / 60, s.vy ~/ 60, reason: 'vy ${s.vy}');
    }
    expect(volley.map((s) => s.vy).toSet(), {
      -ArcadeModel.shotSpeed,
      -ArcadeModel.spreadShotSpeed,
    });
    final y0 = volley.first.y;
    m.update(1 / 60);
    expect(volley.first.y, y0 + volley.first.vy / 60);
  });

  test('hostile climbs sit on the 15 u/s grid, within 7.5 u/s', () {
    for (final v in [101.7, 113.0, 139.4, 152.0, 240.0, 291.9]) {
      final q = ArcadeModel.hostileVy(v);
      expect(q % ArcadeModel.hostileSpeedGrid, 0);
      expect((q - v).abs(), lessThanOrEqualTo(7.5));
    }
    final m = ArcadeModel(seed: 11)..startAt(sector: 3, route: 2);
    for (var f = 0; f < 60 * 30; f++) {
      m.invulnerable = 5;
      m.update(1 / 60);
      m.takeEvents();
      for (final s in m.shots.where((s) => s.hostile)) {
        expect(s.vy % ArcadeModel.hostileSpeedGrid, 0, reason: 'vy ${s.vy}');
      }
    }
  });

  test('the accumulator runs whole steps without drift', () {
    // Whole-step frame times run whole steps, with no float drift: one
    // step every 1/60 s frame, two every 1/30 s, one every second 1/120 s.
    final m = _playing();
    for (final (dt, steps) in [(1 / 60, 1.0), (1 / 30, 2.0), (1 / 120, .5)]) {
      final before = m.levelClock;
      for (var f = 0; f < 240; f++) {
        m.update(dt);
      }
      expect((m.levelClock - before) * 60, closeTo(240 * steps, 1e-6));
    }
  });

  test('sentinel hull is 70 % and dive shields lose a point', () {
    const p = DifficultyPolicy(Difficulty.normal);
    expect(p.sentinelHull(route: 0, armored: false), 6);
    expect(p.sentinelHull(route: 4, armored: true), 14);
    final m = ArcadeModel(seed: 99)..startAt(sector: 2, route: 2);
    m
      ..mode = RunMode.playing
      ..invulnerable = 1000;
    m.demons.clear();
    Demon diver(Demon d) => d
      ..entranceProgress = 1
      ..telegraph = .01;
    final basic = diver(Demon(60, 120, 0, 1, 0));
    final heavy = diver(Demon(120, 120, 3, 3, 0));
    final elite = diver(Demon(180, 120, 0, 3, 0, elite: true));
    final sentinel = diver(
      Demon(
        260,
        80,
        0,
        9,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 3,
        armorMax: 2,
      )..waitingForEscort = false,
    );
    m.demons.addAll([basic, heavy, elite, sentinel]);
    m.update(1 / 60);
    m.update(1 / 60);
    expect(
      [
        for (final d in [basic, heavy, elite, sentinel]) d.diveShieldMax,
      ],
      [1, 1, 2, 4],
    );
  });

  test('route 0 drops a power every 5 kills, later routes every 8', () {
    for (final (route, every) in [(0, 5), (1, 8)]) {
      final m = ArcadeModel(seed: 4)..startAt(sector: 2, route: route);
      m
        ..mode = RunMode.playing
        ..invulnerable = 1000;
      m.demons.clear();
      m.pickups.clear();
      final before = m.kills;
      for (var i = 0; i < 40; i++) {
        final d = Demon(20, 70, 0, 1, 0);
        m.demons.add(d);
        m.hitDemon(d);
      }
      expect(m.killDropEvery, every);
      final drops = (m.kills ~/ every) - (before ~/ every);
      expect(m.pickups, hasLength(drops), reason: 'route $route');
    }
  });

  test('the carrier keeps Easy below Normal below or at Hard', () {
    for (var route = 0; route < 5; route++) {
      final e = Carrier(route, difficulty: Difficulty.easy);
      final n = Carrier(route);
      final h = Carrier(route, difficulty: Difficulty.hard);
      expect(e.shieldMax, lessThan(n.shieldMax), reason: 'tour $route');
      expect(h.shieldMax, greaterThanOrEqualTo(n.shieldMax));
    }
    expect(ArcadeModel.loomCap, 120);
  });
}

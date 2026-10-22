import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(ArcadeModel model, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    model.update(1 / 60);
  }
}

void main() {
  test(
    'first Normal casualty promptly brings a bounded fresh flock, then another',
    () {
      final m = ArcadeModel()..restoreCheckpoint({'wave': 2});
      m.mode = RunMode.playing;
      m.invulnerable = 1000;
      expect(m.flocksPlanned, greaterThanOrEqualTo(2));
      final initial = m.demons.toSet();
      m.hitDemon(m.demons.first, damage: 1000);
      advance(m, .65);
      expect(m.flocksSpawned, 1);
      final first = m.demons.where((d) => !initial.contains(d)).toList();
      expect(first, hasLength(m.policy.reinforcementSize(route: 0, flock: 0)));
      expect(first.every((d) => d.maxHp == 1), isTrue);
      final beforeSecond = m.demons.toSet();
      for (final d in m.demons.where(initial.contains).take(3).toList()) {
        m.hitDemon(d, damage: 1000);
      }
      advance(m, 1.25);
      expect(m.flocksSpawned, 2);
      final second = m.demons.where((d) => !beforeSecond.contains(d)).toList();
      expect(second.length, greaterThan(first.length));
      expect(second.length, first.length + 1);
      expect(second.every((d) => d.maxHp == 1), isTrue);
    },
  );

  test('a sentinel gets its own largest fresh escort after prior ordinary arrivals', () {
    for (final difficulty in Difficulty.values) {
      final m = ArcadeModel()
        ..restoreCheckpoint({
          'difficulty': difficulty.name,
          'routeIndex': 1,
          'sector': 2,
          'wave': 4,
        });
      m.mode = RunMode.playing;
      m.invulnerable = 1000;
      final sentinel = m.demons.singleWhere((d) => d.isLarge);
      m.hitDemon(m.demons.firstWhere((d) => !d.isLarge), damage: 1000);
      advance(m, .7);
      expect(m.flocksSpawned, 1);
      expect(m.escortSpawned, isFalse);
      expect(sentinel.waitingForEscort, isTrue);
      expect(sentinel.entranceProgress, 0);
      final earlier = m.demons.toSet();
      final openingSize = m.policy.rosterCount(sector: 2, wave: 4, route: 1);
      while (m.demons.where((d) => !d.isLarge).length > openingSize) {
        final d = m.demons.firstWhere((d) => !d.isLarge && !d.entering);
        m.hitDemon(d, damage: 1000);
      }
      for (var frame = 0; frame < 240 && !m.escortSpawned; frame++) {
        m.update(1 / 60);
        expect(m.demons.length, lessThanOrEqualTo(ArcadeModel.maxActiveDemons));
      }
      expect(m.escortSpawned, isTrue);
      final escorts = m.demons.where((d) => d.isEscort).toList();
      expect(escorts, hasLength(m.plannedEscortSize));
      expect(
        escorts.every((d) => !earlier.contains(d) && d.homeY >= 124),
        isTrue,
      );
      for (var flock = 0; flock < m.flocksPlanned; flock++) {
        expect(
          escorts.length,
          greaterThan(m.policy.reinforcementSize(route: m.cycle, flock: flock)),
        );
      }
      expect(sentinel.entranceProgress, 0);
      advance(m, .9);
      expect(escorts.every((d) => !d.entering), isTrue);
      expect(sentinel.entranceProgress, 0);
      expect(m.demons.where((d) => d.isLarge), hasLength(1));
    }
  });

  test(
    'group counts stay finite and species health does not inflate by mode',
    () {
      for (var route = 0; route < 5; route++) {
        final policies = Difficulty.values.map(DifficultyPolicy.new).toList();
        for (final p in policies) {
          expect(
            p.reinforcementFlocks(route: route, sector: 1),
            lessThanOrEqualTo(2),
          );
          expect(
            p.reinforcementSize(route: route, flock: 1),
            p.reinforcementSize(route: route, flock: 0) + 1,
          );
          for (var kind = 0; kind < 4; kind++) {
            for (final elite in [false, true]) {
              expect(
                p.ordinaryHealth(route: route, kind: kind, elite: elite),
                policies.first.ordinaryHealth(
                  route: route,
                  kind: kind,
                  elite: elite,
                ),
              );
            }
          }
        }
        for (var mode = 0; mode < 2; mode++) {
          expect(
            policies[mode].reinforcementSize(route: route, flock: 0),
            lessThanOrEqualTo(
              policies[mode + 1].reinforcementSize(route: route, flock: 0),
            ),
          );
        }
      }
    },
  );

  test('full-width carrier field intercepts flank bolts before hull and contracts in depth', () {
    final m = ArcadeModel()..restoreCheckpoint({'sector': 5});
    m.mode = RunMode.playing;
    m.invulnerable = 1000;
    m.update(1 / 60);
    final b = m.boss!;
    expect(b.forceFieldHalfWidth, 110);
    expect(b.forceFieldDepth, 75);
    expect(
      b.forceFieldSurfaceY(b.x - 60),
      closeTo(b.forceFieldSurfaceY(b.x + 60), .0001),
    );
    final core = b.core, shield = b.shield;
    final shotX = b.x + (b.direction > 0 ? 100 : -100);
    m.shots.add(Shot(shotX, b.forceFieldSurfaceY(shotX) + 3, 0, -390));
    m.update(1 / 60);
    expect(b.shield, shield - 1);
    expect(b.core, core);
    final oldSurface = b.forceFieldSurfaceY(b.x);
    m.hitBoss(b.x, damage: b.shield - 1);
    expect(m.blasts.last.y, oldSurface);
    expect(b.forceFieldHalfWidth, 110);
    expect(b.forceFieldDepth, greaterThan(43));
    expect(b.forceFieldDepth, lessThan(44));
    final lastSurface = b.forceFieldSurfaceY(b.x + 100);
    m.hitBoss(b.x + 100);
    expect(m.blasts.last.y, lastSurface);
    expect(b.shield, 0);
    expect(b.core, core);
    b.door = 0;
    expect(m.hitBoss(b.x, blastRadius: 30), isFalse);
    b.door = 1;
    expect(m.hitBoss(b.x + 100, blastRadius: 30), isFalse);
    expect(m.hitBoss(b.x), isTrue);
  });
}

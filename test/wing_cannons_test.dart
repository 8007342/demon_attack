import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

ArcadeModel playing() => ArcadeModel()
  ..start()
  ..mode = RunMode.playing
  ..invulnerable = 100;

List<Shot> playerShots(ArcadeModel m) =>
    m.shots.where((s) => !s.hostile).toList();

/// Steps until the next player volley and returns the shots it added.
List<Shot> nextVolley(ArcadeModel m) {
  final before = playerShots(m).toSet();
  for (var i = 0; i < 60; i++) {
    m.update(1 / 60);
    final added = playerShots(m).where((s) => !before.contains(s)).toList();
    if (added.isNotEmpty) return added;
  }
  fail('no volley within a second');
}

void main() {
  for (final power in [Power.rapid, Power.powerful]) {
    test(
      '${power.name} wing cannons alternate single shots left and right',
      () {
        final m = playing()..collect(power);
        final sides = <double>[];
        for (var i = 0; i < 4; i++) {
          final volley = nextVolley(m);
          expect(volley, hasLength(1), reason: 'one shot per trigger');
          sides.add((volley.single.x - m.shipX).sign);
          expect(
            (volley.single.x - m.shipX).abs(),
            closeTo(m.wingMuzzles[power]!.x.abs(), 3.5),
            reason: 'the shot leaves from the wing muzzle',
          );
          expect(volley.single.vy, -390);
        }
        expect(sides, [-1, 1, -1, 1]);
      },
    );
  }

  test('the cannon that fired recoils, the other stays still', () {
    final m = playing()..collect(Power.rapid);
    nextVolley(m);
    expect(m.wingRecoil[0], greaterThan(0));
    expect(m.wingRecoil[1], 0);
    nextVolley(m);
    expect(m.wingRecoil[1], greaterThan(0));
    for (var i = 0; i < 10; i++) {
      m.update(1 / 60);
    }
    expect(
      m.wingRecoil,
      everyElement(lessThan(ArcadeModel.wingRecoilDuration)),
    );
  });

  test('wing cannons keep the primary shot with a nose module fitted', () {
    final spread = playing()
      ..collect(Power.powerful)
      ..collect(Power.spread);
    expect(spread.wingGun, Power.powerful);
    final volley = nextVolley(spread);
    expect(volley, hasLength(3), reason: 'wing shot plus the angled pair');
    final primary = volley.where((s) => s.vy == -390).single;
    expect((primary.x - spread.shipX).abs(), greaterThan(10));
    expect(
      volley.where((s) => s.vy == -370).map((s) => (s.x - spread.shipX).abs()),
      everyElement(lessThan(8)),
      reason: 'spread still fans from the nose',
    );

    final large = playing()
      ..collect(Power.rapid)
      ..collect(Power.large);
    final shot = nextVolley(large).single;
    expect(shot.kind, ShotKind.large);
    expect((shot.x - large.shipX).abs(), greaterThan(10));
  });

  test('without a wing module the ship fires from the nose', () {
    final m = playing();
    expect(m.wingGun, isNull);
    final volley = nextVolley(m);
    expect(volley.single.x, closeTo(m.shipX, 4));
    expect(m.noseFlash, greaterThan(0), reason: 'nose flash, not wing kick');
    expect(m.wingRecoil, everyElement(0));
  });
}

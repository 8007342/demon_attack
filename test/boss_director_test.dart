import 'package:demon_attack/game/arena_camera.dart';
import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// boss-grandeur §1, §5 and carrier-v3 §5: the boss level's phases (the
/// approach, its steps and cap, the hittable threshold, the take-off), the
/// glide bounds, view selection and determinism.
void main() {
  const frigate = [
    ('spine', null),
    ('bow', null),
    ('tower', 1),
    ('engineL', 2),
    ('engineR', 2),
  ];

  /// Clears whatever fights (the loom waves) with the model's own kill.
  void clearWave(ArcadeModel m) {
    for (final d in List.of(m.demons)) {
      m.hitDemon(d, damage: 999);
    }
  }

  test('the boss level opens with launch waves: 2 on tours 1–3, 3 from 4', () {
    expect(ArcadeModel.loomWavesFor(0), 2);
    expect(ArcadeModel.loomWavesFor(2), 2);
    expect(ArcadeModel.loomWavesFor(3), 3);
    expect(ArcadeModel.wavesFor(sector: 5, route: 0), 3);
    expect(ArcadeModel.wavesFor(sector: 5, route: 3), 4);
    final m = ArcadeModel(seed: 3)..startAt(sector: 5, route: 0, wave: 1);
    expect(m.boss, isNull);
    expect(m.looming, isTrue);
    expect(m.demons, isNotEmpty);
  });

  test('phases: approach, close (no hitbox, no fire), take-off, climb, '
      'collapse', () {
    final m = ArcadeModel(seed: 5)..startAt(sector: 5, route: 0, wave: 1);
    final dir = BossDirector(seed: 5);
    final seen = <BossPhase>[];
    void step(int frames) {
      for (var i = 0; i < frames; i++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        dir.update(m, 1 / 60, modules: frigate);
        if (seen.isEmpty || seen.last != dir.phase) seen.add(dir.phase);
      }
    }

    step(60 * 6); // the arrival hint, then the launch wave's fight
    expect(dir.phase, BossPhase.approach);
    while (m.boss == null) {
      clearWave(m);
      step(1);
    }
    final b = m.boss!;
    expect(b.fightReady, isFalse);
    expect(dir.phase, BossPhase.close);
    // While it rises nothing hits it and it fires nothing.
    expect(m.hitBoss(b.x, damage: 5), isFalse);
    final shield = b.shield;
    step(60 * 2);
    expect(b.shield, shield);
    expect(m.shots.where((s) => s.hostile), isEmpty);
    step((60 * Carrier.riseSeconds).ceil());
    expect(b.fightReady, isTrue);
    expect(dir.phase, BossPhase.takeoff);
    step(60 * 3);
    expect(dir.phase, BossPhase.climb);
    step(60 * 6);
    expect(dir.altitude, greaterThan(1.3));
    expect(dir.camera.zoom, lessThan(1));
    // Down to its core: the collapse breaks it into module wrecks.
    b.shield = 0;
    for (var guard = 0; guard < 100000 && m.boss != null; guard++) {
      m.hitBoss(b.x, damage: 50);
      if (m.boss != null) b.door = 1;
      step(1);
    }
    step(2);
    expect(dir.phase, BossPhase.collapse);
    expect(dir.wrecks.map((w) => w.module).toSet(),
        containsAll(['spine', 'bow', 'engineL', 'engineR']));
    expect(seen, containsAllInOrder([
      BossPhase.approach,
      BossPhase.close,
      BossPhase.takeoff,
      BossPhase.climb,
      BossPhase.collapse,
    ]));
  });

  test('the approach cap: after 90 s the carrier closes regardless', () {
    final m = ArcadeModel(seed: 8)..startAt(sector: 5, route: 2, wave: 1);
    var t = 0.0;
    while (m.boss == null && t < 200) {
      m.invulnerable = 2;
      m.update(1 / 60);
      if (m.combat) t += 1 / 60;
    }
    expect(m.boss, isNotNull);
    expect(t, lessThanOrEqualTo(ArcadeModel.loomCap + 1));
    // Nothing of the loom waves is left in the fog or the reserve.
    expect(m.incoming, isEmpty);
    expect(m.swarmReserve, isEmpty);
  });

  test('glide bounds: the boss row never leaves 205 ± 16 over a full fight', () {
    for (final seed in [1, 2, 3]) {
      final m = ArcadeModel(seed: seed)..startAt(sector: 5, route: 4, wave: 4);
      final b = m.boss!;
      var lo = 999.0, hi = -999.0;
      for (var f = 0; f < 60 * 120; f++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        lo = lo < b.y ? lo : b.y;
        hi = hi > b.y ? hi : b.y;
        // The force field follows the row.
        expect(b.forceFieldSurfaceY(b.x), greaterThan(b.y));
      }
      expect(lo, greaterThanOrEqualTo(189 - 1e-9));
      expect(hi, lessThanOrEqualTo(221 + 1e-9));
      expect(hi - lo, greaterThan(20), reason: 'it glides');
    }
  });

  test('determinism: the same seed gives the same glide and views', () {
    List<String> run() {
      final m = ArcadeModel(seed: 42)..startAt(sector: 5, route: 1, wave: 3);
      final d = BossDirector(seed: 42);
      final out = <String>[];
      for (var f = 0; f < 60 * 30; f++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        d.update(m, 1 / 60, modules: frigate);
        if (f % 30 == 0) out.add('${m.boss?.y.toStringAsFixed(4)} ${d.view} ${d.camera.zoom.toStringAsFixed(4)}');
      }
      return out;
    }

    expect(run(), run());
  });

  test('view selection: pitch from the glide, yaw through 0 with holds', () {
    final m = ArcadeModel(seed: 9)..startAt(sector: 5, route: 0, wave: 3);
    final d = BossDirector(seed: 9);
    final views = <BossView>{};
    var changes = 0, last = d.view;
    var lastChange = 0.0, minHeld = 99.0, t = 0.0;
    var direct = 0;
    for (var f = 0; f < 60 * 60; f++) {
      m.invulnerable = 2;
      m.update(1 / 60);
      d.update(m, 1 / 60, modules: frigate);
      t += 1 / 60;
      views.add(d.view);
      if (d.view != last) {
        if (d.view.yaw != last.yaw && d.view.yaw != 0 && last.yaw != 0) direct++;
        if (d.view.yaw != last.yaw) {
          minHeld = minHeld < t - lastChange ? minHeld : t - lastChange;
          lastChange = t;
        }
        changes++;
        last = d.view;
        expect(d.blend, lessThan(1));
      }
    }
    expect(views.map((v) => v.pitch).toSet(), {0, 1, 2});
    expect(views.map((v) => v.yaw).toSet(), {-1, 0, 1});
    expect(direct, 0, reason: 'a swerve passes through the front view');
    expect(minHeld, greaterThanOrEqualTo(BossDirector.yawHold - 1e-9));
    expect(changes, greaterThan(4));
  });

  test('stages S0–S3 from shield and form; detach at the form change', () {
    final m = ArcadeModel(seed: 4)..startAt(sector: 5, route: 0, wave: 3);
    final b = m.boss!;
    final d = BossDirector(seed: 4);
    d.update(m, 1 / 60, modules: frigate);
    expect(d.stage, 0);
    b.shield = b.shieldMax ~/ 2;
    d.update(m, 1 / 60, modules: frigate);
    expect(d.stage, 1);
    b.shield = 0;
    d.update(m, 1 / 60, modules: frigate);
    expect(d.stage, 2);
    b.core = b.coreMax ~/ 2 - 1;
    d.update(m, 1 / 60, modules: frigate);
    expect(d.stage, 3);
    expect(d.detached, {1});
    expect(d.wrecks.single.module, 'tower');
    expect(d.list, greaterThan(0));
  });

  test('reduced motion: static framing, no follow', () {
    final m = ArcadeModel(seed: 11)..startAt(sector: 5, route: 0, wave: 3);
    final d = BossDirector(seed: 11);
    for (var f = 0; f < 60 * 30; f++) {
      m.invulnerable = 2;
      m.update(1 / 60);
      d.update(m, 1 / 60, reduced: true, modules: frigate);
      expect(d.camera.zoom, greaterThanOrEqualTo(ArenaCamera.reducedZoom - 1e-9));
      expect(d.camera.followStrength, lessThan(1e-9));
    }
    expect(d.camera.zoom, closeTo(ArenaCamera.reducedZoom, 1e-6));
  });

  // --- carrier-v3 §5: the approach, the hittable threshold, the take-off.

  test('approach: D steps closer as each launch wave is cleared, creeps '
      'between steps, never past the next step', () {
    final m = ArcadeModel(seed: 5)..startAt(sector: 5, route: 0, wave: 1);
    final dir = BossDirector(seed: 5);
    final steps = m.carrierScript.approach.distances;
    expect(steps, [4.0, 2.4, 1.35]);
    void step(int frames) {
      for (var i = 0; i < frames; i++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        dir.update(m, 1 / 60, modules: frigate, carrier: true);
      }
    }

    while (!m.combat || m.approachD == 0) {
      step(1);
    }
    expect(m.approachD, closeTo(4, 1e-9));
    expect(dir.phase, BossPhase.approach);
    expect(dir.loomScale, closeTo(.25, 1e-3), reason: 'a quarter size');
    expect(dir.fog, closeTo(.81, .01));
    step(60 * 10);
    // Creeping at 0.012/s, never past 2.4.
    expect(m.approachD, lessThan(4));
    expect(m.approachD, greaterThan(4 - .012 * 11));
    // Wave 1 cleared: the next wave is merged and D eases to 2.4 over 3 s.
    final w = m.wave;
    while (m.wave == w && m.boss == null) {
      clearWave(m);
      step(1);
    }
    expect(m.boss, isNull);
    step(60 * 3 + 2);
    expect(m.approachD, closeTo(2.4, .02));
    expect(dir.loomAt.dy, lessThan(205 - 87 * (2.4 - 1) / 3 + 1));
    // Wave 2 cleared: the Close, D → 1 over 4 s; hittable only at D = 1.
    while (m.boss == null) {
      clearWave(m);
      step(1);
    }
    final b = m.boss!;
    expect(dir.phase, BossPhase.close);
    var t = 0.0;
    while (!b.fightReady) {
      expect(m.hitBoss(b.x, damage: 3), isFalse, reason: 'no hitbox yet');
      expect(m.approachD, greaterThan(1 - 1e-9));
      step(1);
      t += 1 / 60;
    }
    expect(t, closeTo(Carrier.riseSeconds, .1));
    expect(m.approachD, 1);
    expect(b.shield, b.shieldMax, reason: 'the shield starts full');
    expect(dir.phase, BossPhase.takeoff);
    // The take-off beat: 2.4 s, the altitude target jumps at once.
    step(1);
    expect(dir.altitudeTarget, greaterThan(1));
    expect(dir.takeoff, greaterThan(0));
    step((60 * BossDirector.takeoffSeconds).ceil());
    expect(dir.phase, BossPhase.climb);
    expect(dir.takeoff, 0);
    expect(dir.worldPitch, 0);
  });

  test('approach cap: after 90 s the Close starts anyway; nothing stays in '
      'the fog', () {
    final m = ArcadeModel(seed: 8)..startAt(sector: 5, route: 3, wave: 1);
    expect(m.carrierScript.approach.distances, [5.0, 3.2, 2.0, 1.35]);
    var t = 0.0;
    while (m.boss == null && t < 200) {
      m.invulnerable = 2;
      m.update(1 / 60);
      if (m.combat) t += 1 / 60;
    }
    expect(t, closeTo(ArcadeModel.loomCap, 1));
    expect(m.boss!.fightReady, isFalse);
    expect(m.incoming, isEmpty);
    expect(m.swarmReserve, isEmpty);
  });

  test('the take-off: zoom eases to the tour minimum at the rate limit', () {
    for (final route in [0, 4]) {
      final m = ArcadeModel(seed: 2)
        ..startAt(sector: 5, route: route, wave: route >= 3 ? 4 : 3);
      final d = BossDirector(seed: 2);
      var t = 0.0;
      var lo = 1.0;
      while (t < 40) {
        m.invulnerable = 2;
        m.update(1 / 60);
        d.update(m, 1 / 60, modules: frigate, carrier: true, threat: false);
        lo = lo < d.camera.zoom ? lo : d.camera.zoom;
        t += 1 / 60;
      }
      final floor = ArenaCamera.carrierMinZoomFor(route);
      expect(lo, greaterThanOrEqualTo(floor - 1e-9));
      expect(d.camera.carrierFloor, floor);
      expect(lo, lessThan(.8), reason: 'route $route frames wide');
    }
  });

  test('the bend stays within its limits and the view never changes', () {
    final m = ArcadeModel(seed: 9)..startAt(sector: 5, route: 0, wave: 3);
    final d = BossDirector(seed: 9);
    const deg = 3.14159265 / 180;
    var maxLean = 0.0;
    for (var f = 0; f < 60 * 60; f++) {
      m.invulnerable = 2;
      m.update(1 / 60);
      d.update(m, 1 / 60, modules: frigate, carrier: true);
      expect(d.view, BossView.hero);
      expect(d.bend.lean.abs(), lessThanOrEqualTo(3 * deg + 1e-9));
      expect(d.bend.bank.abs(), lessThanOrEqualTo(2.5 * deg + 1e-9));
      expect(d.bend.pitch.abs(), lessThanOrEqualTo(3 * deg + 1e-9));
      if (d.phase == BossPhase.climb) {
        expect(d.bend.pitch.abs(), lessThanOrEqualTo(2 * deg + 1e-6));
      }
      maxLean = maxLean > d.bend.lean.abs() ? maxLean : d.bend.lean.abs();
    }
    expect(maxLean, greaterThan(1.5 * deg), reason: 'it leans into travel');
  });
}

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'arena_camera.dart';
import 'model.dart';

/// boss-grandeur: the boss level's presentation phases (design §1).
enum BossPhase { none, overflight, loom, rise, engage, climb, collapse }

/// One of the 3 × 3 views: pitch index 0..2 (38°, 45°, 52°) and yaw −1, 0,
/// +1 (−12°, 0°, +12°). Yaw −1 is drawn as +1 mirrored.
class BossView {
  const BossView(this.pitch, this.yaw);
  static const pitches = [38, 45, 52];
  static const hero = BossView(1, 0);
  final int pitch, yaw;
  int get pitchDegrees => pitches[pitch];
  int get yawDegrees => 12 * yaw;
  bool get mirrored => yaw < 0;

  /// The stored view's tag in the hero atlas (`p45_y+12`).
  String get storedTag => 'p$pitchDegrees${yaw == 0 ? '_y+00' : '_y+12'}';

  @override
  bool operator ==(Object other) =>
      other is BossView && other.pitch == pitch && other.yaw == yaw;
  @override
  int get hashCode => pitch * 3 + yaw;
  @override
  String toString() => 'BossView($pitchDegrees°, $yawDegrees°)';
}

/// A cosmetic falling piece: a module wreck (S3 detach, S4 collapse) or an
/// armour plate (S2). Never collides; drawn by the scene.
class BossWreck {
  BossWreck({
    required this.module,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.life,
    this.delay = 0,
    this.plate = false,
  });
  final String module;
  double x, y, vx, vy, spin, rotation = 0, age = 0;
  final double life, delay;
  final bool plate;

  /// 0 at the break, 1 when it has sunk into the fog.
  double get progress => ((age - delay) / life).clamp(0.0, 1.0);
  bool get started => age >= delay;
  bool get done => age - delay >= life;

  /// Drawn scale: it falls away from the camera toward the ground fog.
  double get scale => 1 - .45 * progress;

  /// Opacity of its body (the fog takes it in its last third).
  double get opacity => 1 - ((progress - .62) / .38).clamp(0.0, 1.0);
}

/// The boss level's director (design §0): phases, the presentation altitude,
/// the arena camera (zoom and follow), the view selection, the damage
/// stages and the cosmetic wrecks. It reads the model and never writes it.
class BossDirector {
  BossDirector({this.seed = 1982}) : _rng = math.Random(seed ^ 0xB055 ^ 0x77);
  final int seed;
  final math.Random _rng;

  final camera = ArenaCamera();
  BossPhase phase = BossPhase.none;
  double phaseTime = 0;

  // --- altitude (design §2): critically damped spring, ω = 1.2.
  double altitude = 1, _altitudeV = 0, altitudeTarget = 1;
  static const omega = 1.2;

  /// The fight's altitude at full climb: 1.6, 1.75 on tours 4–5 (raised
  /// from 1.45 / 1.6 by the operator's R8: the fight plays much higher).
  static double maxAltitudeFor(int route) => route >= 3 ? 1.75 : 1.6;

  /// The fight climbs 1.5 s after it engages.
  static const engageSeconds = 1.5;

  /// Overflight length (design §1).
  static double overflightSeconds(bool reduced) => reduced ? 2.0 : 3.2;

  // --- views (design §5).
  BossView view = BossView.hero, previous = BossView.hero;

  /// Crossfade from [previous] to [view], 0..1.
  double blend = 1;
  double _pitchHeld = 9, _yawHeld = 9;
  static const pitchHold = .4, yawHold = .35;
  static const crossfade = .12, crossfadeReduced = .2;

  /// Pitch bands on the boss row (y): above [highRow] 38°, below [lowRow]
  /// 52°, with [hysteresis] units of hysteresis.
  static const highRow = 197.0, lowRow = 213.0, hysteresis = 4.0;

  /// Yaw: |vx| above [yawEnter] of the current max picks ±12°; below
  /// [yawLeave] it returns to 0°.
  static const yawEnter = .4, yawLeave = .3;

  // --- stages (design §6).
  int stage = 0;
  int _form = 0;

  /// The hull's list (radians) once a module broke away (S3: +4°).
  double list = 0;

  /// Detach orders gone (the scene hides those modules' layers).
  final Set<int> detached = {};

  final List<BossWreck> wrecks = [];
  static const maxPlates = 6, maxFalling = 8;
  double _lastDoor = 0;

  // --- progress of the transitions.
  double overflight = 0, loom = 0, rise = 1;

  /// Where the looming carrier is drawn (under the far fog) and its scale;
  /// the Rise starts from here.
  Offset loomAt = const Offset(180, 112);
  double loomScale = .42;

  /// The boss's range of motion over the last 3 s (0..1).
  double range = 0;
  final _xs = ListQueue<(double, double)>();
  double _clock = 0;

  /// The fog's flow speed factor (R8: faster cloud and fog in the fight).
  double flowBoost = 1;
  static const maxFlowBoost = 2.2;

  /// The fight's climb progress 0..1 ((A − 1) / (Amax − 1)).
  double climb = 0;

  void reset() {
    phase = BossPhase.none;
    phaseTime = 0;
    altitude = altitudeTarget = 1;
    _altitudeV = 0;
    camera.reset();
    view = previous = BossView.hero;
    blend = 1;
    stage = 0;
    _form = 0;
    list = 0;
    detached.clear();
    wrecks.clear();
    overflight = loom = 0;
    rise = 1;
    range = 0;
    _xs.clear();
    flowBoost = 1;
    climb = 0;
  }

  BossPhase _phaseOf(ArcadeModel m) {
    final flow = m.flow;
    if (m.wreckBoss != null &&
        (m.presentationMode == RunMode.victory || wrecks.isNotEmpty)) {
      return BossPhase.collapse;
    }
    final b = m.boss;
    if (b != null) {
      if (!b.fightReady) return BossPhase.rise;
      return phase == BossPhase.climb ||
              (phase == BossPhase.engage && phaseTime >= engageSeconds)
          ? BossPhase.climb
          : BossPhase.engage;
    }
    if (flow.active &&
        flow.kind == FlowKind.bossArrival &&
        flow.seconds >= flow.plan.descentAt) {
      return BossPhase.overflight;
    }
    if (m.looming && !flow.active) return BossPhase.loom;
    if (m.level == 5 && m.boss == null && m.clearedLevel == null &&
        m.wreckBoss == null) {
      return m.flow.active ? BossPhase.overflight : BossPhase.loom;
    }
    return BossPhase.none;
  }

  /// One presentation step. [modules]: the drawn hull's module ids and
  /// detach orders (null: never detaches), for the wrecks. [threat]: a dive
  /// tell, rush lock or ground-missile warning is up (the zoom holds).
  void update(
    ArcadeModel m,
    double dt, {
    bool reduced = false,
    List<(String, int?)> modules = const [],
    bool? threat,
  }) {
    _clock += dt;
    final next = _phaseOf(m);
    if (next != phase) {
      if (next == BossPhase.collapse) _collapse(m, modules);
      if (next == BossPhase.none) reset();
      phase = next;
      phaseTime = 0;
    } else {
      phaseTime += dt;
    }
    final b = m.boss ?? m.wreckBoss;

    // Transitions.
    final flow = m.flow;
    if (phase == BossPhase.overflight && flow.active) {
      overflight = ((flow.seconds - flow.plan.descentAt) /
              overflightSeconds(flow.plan.reduced))
          .clamp(0.0, 1.0);
    } else if (phase != BossPhase.overflight) {
      overflight = phase == BossPhase.none ? 0 : 1;
    }
    loom = phase == BossPhase.loom
        ? (m.loomClock / (m.loomWaves * 30.0)).clamp(0.0, 1.0)
        : (phase == BossPhase.rise ? 1 : loom);
    rise = m.boss == null ? (phase == BossPhase.loom ? 0 : 1) : m.boss!.emerge;
    if (phase == BossPhase.loom || phase == BossPhase.overflight) {
      // It drifts slowly under the far banks and rises one layer per ~8 s.
      loomAt = Offset(
        180 + 46 * math.sin(_clock * .13),
        104 + 46 * loom,
      );
      loomScale = .4 + .22 * loom;
    }

    // Altitude.
    final route = m.cycle;
    final top = maxAltitudeFor(route);
    if (phase == BossPhase.climb && m.boss != null) {
      final forms = math.max(1, m.boss!.formCount - 1);
      altitudeTarget =
          1 + (top - 1) * (.65 + .35 * (m.boss!.phase / forms).clamp(0.0, 1.0));
    } else if (phase == BossPhase.collapse) {
      // Holds through the fall.
    } else {
      altitudeTarget = 1;
    }
    if (reduced) {
      // A 1 s ramp instead of the spring (design §2: never a step).
      final d = altitudeTarget - altitude;
      altitude += d.clamp(-dt * (top - 1), dt * (top - 1));
      _altitudeV = 0;
    } else {
      final acc = omega * omega * (altitudeTarget - altitude) -
          2 * omega * _altitudeV;
      _altitudeV += acc * dt;
      altitude += _altitudeV * dt;
    }
    altitude = altitude.clamp(1.0, top);
    climb = ((altitude - 1) / (top - 1)).clamp(0.0, 1.0);
    flowBoost = 1 + (maxFlowBoost - 1) * climb * (reduced ? 0 : 1);

    // Range of motion and views.
    if (b != null && m.boss != null) {
      _xs.addLast((_clock, b.x));
      while (_xs.isNotEmpty && _xs.first.$1 < _clock - 3) {
        _xs.removeFirst();
      }
      var lo = b.x, hi = b.x;
      for (final (_, x) in _xs) {
        lo = math.min(lo, x);
        hi = math.max(hi, x);
      }
      range = ((hi - lo) / 196).clamp(0.0, 1.0);
      _selectView(b, dt, reduced: reduced, ready: b.fightReady);
    } else {
      range = 0;
      _xs.clear();
    }
    blend = math.min(1.0, blend + dt / (reduced ? crossfadeReduced : crossfade));

    // Stages and detaches.
    if (m.boss != null) {
      final c = m.boss!;
      stage = stageOf(c);
      if (c.phase > _form) {
        for (var f = _form + 1; f <= c.phase; f++) {
          _detach(c, f, modules);
        }
        _form = c.phase;
      }
      list = detached.isEmpty ? 0 : 4 * math.pi / 180;
      // S2: plates peel off as the bay doors cycle (2 per cycle, ≤ 6).
      if (stage >= 2) {
        final opening = c.door >= .6 && _lastDoor < .6;
        final plates = wrecks.where((w) => w.plate && !w.done).length;
        if (opening && plates < maxPlates && wrecks.length < maxFalling) {
          for (var i = 0; i < 2; i++) {
            wrecks.add(BossWreck(
              module: 'plate',
              plate: true,
              x: c.x + (_rng.nextDouble() - .5) * 120,
              y: c.y - 10 + _rng.nextDouble() * 40,
              vx: (_rng.nextDouble() - .5) * 60,
              vy: 20 + _rng.nextDouble() * 30,
              spin: (_rng.nextDouble() - .5) * 6,
              life: 2.2 + _rng.nextDouble(),
            ));
          }
        }
      }
      _lastDoor = c.door;
    } else if (m.wreckBoss == null) {
      _form = 0;
      detached.clear();
      list = 0;
    }
    for (final w in wrecks) {
      w.age += dt;
      if (!w.started) continue;
      w.vy += (w.plate ? 70 : 34) * dt;
      w.x += w.vx * dt;
      w.y += w.vy * dt;
      w.rotation += w.spin * dt;
    }
    wrecks.removeWhere((w) => w.done);

    // Camera.
    final threatUp = threat ?? _threat(m);
    final fighting = phase == BossPhase.engage || phase == BossPhase.climb;
    final want = fighting
        ? ArenaCamera.targetZoom(
            range: range,
            swerve: view.yaw.abs().toDouble(),
            altitude: altitude,
          )
        : 1.0;
    camera.stepZoom(
      dt,
      reduced ? (phase == BossPhase.climb ? ArenaCamera.reducedZoom : 1) : want,
      hold: threatUp,
      reduced: reduced,
    );
    camera.altitude = altitude;
    camera.stepFollow(
      dt,
      bossX: b?.x ?? 180,
      glide: b?.glide ?? 0,
      strength: reduced || phase == BossPhase.none ? 0 : climb,
    );
  }

  /// A threat the player must read: a dive tell, a sentinel rush lock or a
  /// ground missile in flight toward the ship row.
  static bool _threat(ArcadeModel m) {
    for (final d in m.demons) {
      if (d.telegraph > 0) return true;
      if (d.rushing) return true;
    }
    for (final g in m.ground.missiles) {
      if (!g.spent && g.t < 1) return true;
    }
    return false;
  }

  /// Damage stage S0–S3 (S4 is the collapse): S0 shield > 50 %, S1 shield
  /// ≤ 50 %, S2 shield gone, S3 after the first form change.
  static int stageOf(Carrier c) {
    if (c.phase >= 1) return 3;
    if (c.shield <= 0) return 2;
    if (c.shield * 2 <= c.shieldMax) return 1;
    return 0;
  }

  void _selectView(Carrier b, double dt, {required bool reduced, required bool ready}) {
    _pitchHeld += dt;
    _yawHeld += dt;
    var p = view.pitch, y = view.yaw;
    if (!ready) {
      p = 1;
      y = 0;
    } else {
      // Pitch from the glide (higher on screen: shallower 38°).
      const h = hysteresis / 2;
      final want = switch (p) {
        0 => b.y > highRow + h ? (b.y > lowRow + h ? 2 : 1) : 0,
        2 => b.y < lowRow - h ? (b.y < highRow - h ? 0 : 1) : 2,
        _ => b.y < highRow - h ? 0 : (b.y > lowRow + h ? 2 : 1),
      };
      if (want != p && _pitchHeld >= (reduced ? .8 : pitchHold)) {
        p = want;
        _pitchHeld = 0;
      }
      // Yaw from the horizontal velocity, through 0° when it reverses.
      final maxV = .7 * b.movementRate * (80 + b.rage * 10);
      final v = b.horizontalVelocity / math.max(1.0, maxV);
      var wantY = y;
      if (y == 0) {
        if (v.abs() > yawEnter) wantY = v.sign.toInt();
      } else if (v * y < yawLeave) {
        wantY = 0;
      }
      // Never straight from one side to the other: through the front view.
      if (wantY != 0 && y != 0 && wantY != y) wantY = 0;
      if (wantY != y && _yawHeld >= (reduced ? .7 : yawHold)) {
        y = wantY;
        _yawHeld = 0;
      }
    }
    final next = BossView(p, y);
    if (next != view) {
      previous = view;
      view = next;
      blend = 0;
    }
  }

  void _detach(Carrier c, int order, List<(String, int?)> modules) {
    detached.add(order);
    for (final (id, d) in modules) {
      if (d != order || wrecks.length >= maxFalling) continue;
      wrecks.add(BossWreck(
        module: id,
        x: c.x,
        y: c.y,
        vx: (_rng.nextDouble() - .5) * 30,
        vy: 8,
        spin: (_rng.nextDouble() - .5) * .8,
        life: 4 + _rng.nextDouble() * 2,
      ));
    }
  }

  /// S4: every remaining module breaks away in its detach order, the spine
  /// last, each sinking into the fog over 4–6 s.
  void _collapse(ArcadeModel m, List<(String, int?)> modules) {
    final w = m.wreckBoss;
    if (w == null) return;
    final left = [
      for (final (id, d) in modules)
        if (d == null || !detached.contains(d)) (id, d),
    ]..sort((a, b) => (a.$2 ?? 99).compareTo(b.$2 ?? 99));
    for (final (i, (id, _)) in left.indexed) {
      final spine = i == left.length - 1;
      wrecks.add(BossWreck(
        module: id,
        x: w.x,
        y: w.y,
        vx: spine ? 0 : (_rng.nextDouble() - .5) * 50,
        vy: spine ? 4 : 10,
        spin: (_rng.nextDouble() - .5) * (spine ? .3 : 1.0),
        life: 4 + _rng.nextDouble() * 2,
        delay: spine ? .9 : i * .25,
      ));
    }
    detached.addAll([for (final (_, d) in modules) ?d]);
  }
}

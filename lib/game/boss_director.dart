import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'arena_camera.dart';
import 'carrier_bend.dart';
import 'carrier_script.dart';
import 'model.dart';

/// The boss level's presentation phases (carrier-v3 §5.1: Overflight →
/// Approach → Close → Take-off → Climb, then the Collapse). Approach
/// replaces boss-grandeur's Loom, Close its Rise, Take-off its Engage.
enum BossPhase { none, overflight, approach, close, takeoff, climb, collapse }

/// One of the 3 × 3 views: pitch index 0..2 (38°, 45°, 52°) and yaw −1, 0,
/// +1 (−12°, 0°, +12°). Yaw −1 is drawn as +1 mirrored. carrier-v3: a v2
/// carrier is drawn from [hero] only, bent at runtime ([CarrierBend]); the
/// selection stays for hulls that are not carriers.
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
    this.sink = .45,
  });
  final String module;
  double x, y, vx, vy, spin, rotation = 0, age = 0;
  final double life, delay;
  final bool plate;

  /// How much it shrinks as it sinks (a carrier's pieces fall far below).
  final double sink;

  /// 0 at the break, 1 when it has sunk into the fog.
  double get progress => ((age - delay) / life).clamp(0.0, 1.0);
  bool get started => age >= delay;
  bool get done => age - delay >= life;

  /// Drawn scale: it falls away from the camera toward the ground fog.
  double get scale => 1 - sink * progress;

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

  /// The fight climbs 1.5 s after it engages (boss-grandeur; carrier-v3
  /// drops the wait: the take-off is the start of the climb).
  static const engageSeconds = 1.5;

  /// carrier-v3 §5.4: the take-off beat, its pitch-up and fog-rush peak.
  static const takeoffSeconds = 2.4, takeoffPeak = .8;

  /// The world's pitch at the take-off's peak (the transition-ascent
  /// pitch's q).
  static const takeoffWorldPitch = .6;

  /// Units the horizon drops per unit of [worldPitch] (36 at the peak).
  static const takeoffHorizon = 60.0;

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

  // --- carrier-v3: the approach, the take-off and the speed cues.
  /// The tour's script (the model's).
  CarrierScript script = CarrierScript.authored(0);

  /// The runtime bend (design §2), driven here, drawn by the painter.
  final bend = CarrierBend();

  /// The approach distance D drawn (1 in range) and its fog mix.
  double distance = 1, fog = 0;

  /// The take-off's pulse 0..1 (nose up), the world's pitch q and the
  /// follow strength's ramp.
  double takeoff = 0, worldPitch = 0;

  /// Speed cues: strength 0..1 (climb × the script's intensity; 0 under
  /// reduced motion), the surge 0..1 and the cloud punch's progress
  /// (−1: none).
  double cues = 0, surge = 0, punch = -1;
  double _surgeLeft = 0, _nextSurge = 14;
  int _surges = 0;
  math.Random _cueRng = math.Random(1);

  /// Trauma shake (design §7): trauma 0..1, offset (units).
  double trauma = 0;
  Offset shake = Offset.zero;

  bool _peaked = false;
  double _vxPrev = 0, _ax = 0;

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
    bend.reset();
    distance = 1;
    fog = takeoff = worldPitch = 0;
    cues = surge = 0;
    punch = -1;
    _surgeLeft = 0;
    _surges = 0;
    trauma = 0;
    shake = Offset.zero;
    _peaked = false;
    _vxPrev = _ax = 0;
  }

  BossPhase _phaseOf(ArcadeModel m) {
    final flow = m.flow;
    if (m.wreckBoss != null &&
        (m.presentationMode == RunMode.victory || wrecks.isNotEmpty)) {
      return BossPhase.collapse;
    }
    final b = m.boss;
    if (b != null) {
      if (!b.fightReady) return BossPhase.close;
      return phase == BossPhase.climb ||
              (phase == BossPhase.takeoff && phaseTime >= takeoffSeconds)
          ? BossPhase.climb
          : BossPhase.takeoff;
    }
    if (flow.active &&
        flow.kind == FlowKind.bossArrival &&
        flow.seconds >= flow.plan.descentAt) {
      return BossPhase.overflight;
    }
    if (m.looming && !flow.active) return BossPhase.approach;
    if (m.level == 5 &&
        m.boss == null &&
        m.clearedLevel == null &&
        m.wreckBoss == null) {
      return m.flow.active ? BossPhase.overflight : BossPhase.approach;
    }
    return BossPhase.none;
  }

  /// One presentation step. [modules]: the drawn hull's module ids and
  /// detach orders (null: never detaches), for the wrecks. [threat]: a dive
  /// tell, rush lock or ground-missile warning is up (the zoom holds).
  /// [carrier]: a v2 carrier is drawn (boss-carrier-wire): the fight's zoom
  /// runs in the carrier band (`ArenaCamera.carrierMinZoom` … `carrierMaxZoom`).
  void update(
    ArcadeModel m,
    double dt, {
    bool reduced = false,
    List<(String, int?)> modules = const [],
    bool? threat,
    bool carrier = false,
  }) {
    _clock += dt;
    _carrier = carrier;
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
      overflight =
          ((flow.seconds - flow.plan.descentAt) /
                  overflightSeconds(flow.plan.reduced))
              .clamp(0.0, 1.0);
    } else if (phase != BossPhase.overflight) {
      overflight = phase == BossPhase.none ? 0 : 1;
    }
    script = m.carrierScript;
    bend.limits = script.bend;
    final steps = script.approach.distances;
    loom = phase == BossPhase.approach
        ? ((steps.first - math.max(1.0, m.approachD)) /
                  (steps.first - steps.last))
              .clamp(0.0, 1.0)
        : (phase == BossPhase.close ? 1 : loom);
    rise = m.boss == null
        ? (phase == BossPhase.approach ? 0 : 1)
        : m.boss!.emerge;
    // carrier-v3 §5.2: the approach distance, its placement and haze.
    if (phase == BossPhase.approach || phase == BossPhase.overflight) {
      distance = m.approachD > 1 ? m.approachD : steps.first;
      final at = m.approachD > 1
          ? m.approachAt
          : CarrierApproachScript.placement(distance, 0);
      loomAt = Offset(at.x, at.y);
      loomScale = 1 / distance;
    } else if (phase == BossPhase.close) {
      // The Close eases from where the approach was to the fight row.
      distance = math.max(1.0, m.approachD);
      if (phaseTime == 0) {
        final at = CarrierApproachScript.placement(
          m.closeFromD,
          m.approachClock,
        );
        loomAt = Offset(at.x, at.y);
        loomScale = 1 / m.closeFromD;
      }
    } else {
      distance = 1;
    }
    fog = CarrierApproachScript.fogMix(distance);

    // Altitude.
    final route = m.cycle;
    final top = carrier ? script.camera.maxAltitude : maxAltitudeFor(route);
    final fighting0 =
        phase == BossPhase.climb ||
        (carrier && phase == BossPhase.takeoff);
    if (fighting0 && m.boss != null) {
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
      final acc =
          omega * omega * (altitudeTarget - altitude) - 2 * omega * _altitudeV;
      _altitudeV += acc * dt;
      altitude += _altitudeV * dt;
    }
    altitude = altitude.clamp(1.0, top);
    climb = ((altitude - 1) / (top - 1)).clamp(0.0, 1.0);
    _cues(m, dt, reduced: reduced, carrier: carrier);

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
      if (carrier) {
        // carrier-v3 §2: one stored view, bent; no view changes.
        view = previous = BossView.hero;
        blend = 1;
      } else {
        _selectView(b, dt, reduced: reduced, ready: b.fightReady);
      }
    } else {
      range = 0;
      _xs.clear();
    }
    _bend(m, dt, reduced: reduced);
    blend = math.min(
      1.0,
      blend + dt / (reduced ? crossfadeReduced : crossfade),
    );

    // Stages and detaches.
    if (m.boss != null) {
      final c = m.boss!;
      stage = stageOf(c);
      if (c.phase > _form) {
        for (var f = _form + 1; f <= c.phase; f++) {
          _detach(c, f, modules);
        }
        // carrier-v3 §7: shake on a module lost, more when the core shows.
        _kick(c.phase >= c.formCount - 1 ? .25 : .30);
        _form = c.phase;
      }
      list = detached.isEmpty ? 0 : 4 * math.pi / 180;
      // S2: plates peel off as the bay doors cycle (2 per cycle, ≤ 6).
      if (stage >= 2) {
        final opening = c.door >= .6 && _lastDoor < .6;
        final plates = wrecks.where((w) => w.plate && !w.done).length;
        if (opening && plates < maxPlates && wrecks.length < maxFalling) {
          for (var i = 0; i < 2; i++) {
            wrecks.add(
              BossWreck(
                module: 'plate',
                plate: true,
                x: c.x + (_rng.nextDouble() - .5) * 120,
                y: c.y - 10 + _rng.nextDouble() * 40,
                vx: (_rng.nextDouble() - .5) * 60,
                vy: 20 + _rng.nextDouble() * 30,
                spin: (_rng.nextDouble() - .5) * 6,
                life: 2.2 + _rng.nextDouble(),
              ),
            );
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
      // A carrier's modules are hundreds of units across: they sink away
      // into the fog below (slower fall, more shrink) rather than sliding
      // down over the ship.
      w.vy += (w.plate ? 70 : (_carrier ? 9 : 34)) * dt;
      w.x += w.vx * dt;
      w.y += w.vy * dt;
      w.rotation += w.spin * dt;
    }
    wrecks.removeWhere((w) => w.done);

    // Camera.
    final threatUp = threat ?? _threat(m);
    final fighting = phase == BossPhase.takeoff || phase == BossPhase.climb;
    final floor = carrier
        ? script.camera.minZoom
        : ArenaCamera.carrierMinZoom;
    final want = fighting
        ? ArenaCamera.targetZoom(
            range: range,
            // carrier-v3: the lean stands in for the retired swerve view.
            swerve: carrier
                ? (bend.lean.abs() / (script.bend.leanMax * CarrierBend.deg))
                : view.yaw.abs().toDouble(),
            altitude: altitude,
            carrier: carrier,
            carrierFloor: floor,
          )
        // A carrier closes into its band: it is framed before it fights.
        : (carrier && phase == BossPhase.close
              ? ArenaCamera.carrierMaxZoom
              : 1.0);
    final framing = carrier
        ? ArenaCamera.carrierReducedFor(floor)
        : ArenaCamera.reducedZoom;
    final reducedFight =
        phase == BossPhase.climb || (carrier && phase == BossPhase.takeoff);
    camera.stepZoom(
      dt,
      reduced ? (reducedFight ? framing : 1) : want,
      hold: threatUp,
      reduced: reduced,
      carrier: carrier,
      carrierFloor: carrier ? floor : null,
    );
    camera.altitude = altitude;
    // carrier-v3 §6.1: the follow ramps in over the take-off; the horizon
    // sinks as the fight climbs (the ground battle drops lower).
    final follow = !carrier
        ? climb
        : phase == BossPhase.takeoff
        ? (phaseTime / takeoffSeconds).clamp(0.0, 1.0)
        : (phase == BossPhase.climb || phase == BossPhase.collapse ? 1.0 : 0.0);
    camera.stepFollow(
      dt,
      bossX: b?.x ?? 180,
      glide: b?.glide ?? 0,
      strength: reduced || phase == BossPhase.none ? 0 : follow,
    );
    // The take-off's world pitch: the horizon drops further at its peak
    // (the transition-ascent pitch, on the background only).
    camera.horizonDrop = reduced || !carrier
        ? 0
        : script.camera.horizonDrop * climb + takeoffHorizon * worldPitch;
    _shake(dt, reduced: reduced);
  }

  // --- carrier-v3 -----------------------------------------------------------

  /// Adds trauma (design §7: the take-off, a module lost, the core
  /// exposed, the collapse; nothing else shakes).
  void _kick(double t) => trauma = math.min(1.0, trauma + t);

  void _shake(double dt, {required bool reduced}) {
    trauma = math.max(0.0, trauma - .8 * dt);
    if (reduced || trauma <= 0) {
      shake = Offset.zero;
      return;
    }
    final a = trauma * trauma * 4;
    final t = _clock;
    shake = Offset(
      a * (.6 * math.sin(t * 37.1) + .4 * math.sin(t * 23.3 + 1.7)),
      a * (.6 * math.sin(t * 31.7 + .9) + .4 * math.sin(t * 19.9 + 2.3)),
    );
  }

  /// The take-off beat, the flow, the surges and punches, the climb peak.
  void _cues(
    ArcadeModel m,
    double dt, {
    required bool reduced,
    required bool carrier,
  }) {
    final c = script.cues;
    final t = phase == BossPhase.takeoff ? phaseTime : -1.0;
    if (phase == BossPhase.takeoff && phaseTime == 0 && carrier) {
      _kick(.35);
      _peaked = false;
      _nextSurge = c.firstSurge;
      _surges = 0;
      _cueRng = math.Random(c.surgeSeed ^ seed ^ m.cycle);
    }
    // The take-off pulse: nose up to its peak at 0.8 s, then eased back.
    if (t >= 0 && carrier && !reduced) {
      final up = (t / takeoffPeak).clamp(0.0, 1.0);
      final down = ((t - takeoffPeak) / (takeoffSeconds - takeoffPeak)).clamp(
        0.0,
        1.0,
      );
      final e = t <= takeoffPeak
          ? up * up * (3 - 2 * up)
          : 1 - down * down * (3 - 2 * down);
      takeoff = e;
      worldPitch = takeoffWorldPitch * e;
    } else {
      takeoff = 0;
      worldPitch = 0;
    }
    // Surges and cloud punches (seeded), in the climbed fight only.
    final fight = carrier && phase == BossPhase.climb && !reduced;
    if (fight) {
      _nextSurge -= dt;
      if (_nextSurge <= 0) {
        _surges++;
        _surgeLeft = 1.5;
        final (lo, hi) = c.surgeEvery;
        _nextSurge = lo + (hi - lo) * _cueRng.nextDouble();
        m.queuePresentationEvent(GameEventNames.bossSpeedSurge, {
          'intensity': double.parse((c.intensity * climb).toStringAsFixed(2)),
        });
        if (_surges % c.punchShare == 0) {
          punch = 0;
          m.queuePresentationEvent(GameEventNames.bossCloudPunch);
        }
      }
    }
    _surgeLeft = math.max(0, _surgeLeft - dt);
    surge = _surgeLeft <= 0 ? 0 : math.sin(math.pi * (1 - _surgeLeft / 1.5));
    if (punch >= 0) {
      punch += dt / .8;
      if (punch >= 1) punch = -1;
    }
    // The fog's flow: faster with the climb, rushing at the take-off's
    // peak, pushed by surges; none of it under reduced motion.
    final base = 1 + (c.flowBoostMax - 1) * climb;
    var boost = base;
    if (carrier && t >= 0) {
      final rush = t <= takeoffPeak
          ? t / takeoffPeak
          : 1 - ((t - takeoffPeak) / (takeoffSeconds - takeoffPeak));
      boost = math.max(base, 1 + (c.takeoffBoost - 1) * rush.clamp(0.0, 1.0));
    }
    boost += c.surgeBoost * surge;
    flowBoost = reduced ? 1 : (carrier ? boost : 1 + (maxFlowBoost - 1) * climb);
    final fightCue =
        carrier && (phase == BossPhase.takeoff || phase == BossPhase.climb);
    cues = reduced || !fightCue
        ? 0
        : (math.max(climb, takeoff) * c.intensity).clamp(0.0, 1.0);
    // The top of the climb.
    if (carrier &&
        !_peaked &&
        (phase == BossPhase.climb || phase == BossPhase.takeoff) &&
        altitudeTarget > 1 &&
        altitude - 1 >= .98 * (altitudeTarget - 1)) {
      _peaked = true;
      m.queuePresentationEvent(GameEventNames.bossClimbPeak, {
        'altitude': double.parse(altitude.toStringAsFixed(3)),
      });
    }
  }

  /// The bend's drivers (design §2.3): lean into the travel, bank into the
  /// turn, pitch with the glide, nose up in the take-off, buffet with the
  /// climb and the speed.
  void _bend(ArcadeModel m, double dt, {required bool reduced}) {
    final b = m.boss;
    double vx = 0, glide = 0;
    if (b != null && b.fightReady) {
      final maxV = .7 * b.movementRate * (80 + b.rage * 10);
      vx = b.horizontalVelocity / math.max(1.0, maxV);
      glide = math.cos(b.glidePhase);
      final w = .7 * b.movementRate;
      final a = dt > 0 ? (vx - _vxPrev) / dt / math.max(.1, w) : 0.0;
      _ax += (a - _ax) * (1 - math.exp(-dt / .3));
    } else if (phase == BossPhase.approach) {
      // The approach's slow drift.
      vx = .13 * 46 * math.cos(_clock * .13) * (1 - 1 / distance) / 56;
      _ax = 0;
    } else {
      _ax = 0;
    }
    _vxPrev = vx;
    final buffet =
        (climb * (flowBoost - 1) / math.max(.1, script.cues.flowBoostMax - 1))
            .clamp(0.0, 1.0);
    bend.update(
      dt,
      vx: vx,
      // Banks into the turn: against the acceleration's sign along x.
      ax: -_ax,
      glide: glide,
      takeoff: takeoff,
      buffet: buffet,
      reduced: reduced,
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

  void _selectView(
    Carrier b,
    double dt, {
    required bool reduced,
    required bool ready,
  }) {
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

  bool _carrier = false;

  /// The module that sinks last: the v2 carapace (or the v1 spine).
  static bool _isBase(String id) => id == 'carapace' || id == 'spine';

  void _detach(Carrier c, int order, List<(String, int?)> modules) {
    detached.add(order);
    for (final (id, d) in modules) {
      if (d != order || wrecks.length >= maxFalling) continue;
      wrecks.add(
        BossWreck(
          module: id,
          x: c.x,
          y: c.y,
          vx: (_rng.nextDouble() - .5) * 30,
          vy: 8,
          spin: (_rng.nextDouble() - .5) * (_carrier ? .3 : .8),
          life: 4 + _rng.nextDouble() * 2,
          sink: _carrier ? .7 : .45,
        ),
      );
    }
  }

  /// S4: every remaining module breaks away in its detach order, the spine
  /// last, each sinking into the fog over 4–6 s.
  void _collapse(ArcadeModel m, List<(String, int?)> modules) {
    final w = m.wreckBoss;
    if (w == null) return;
    _kick(.5); // carrier-v3 §7: the collapse's shake
    final left =
        [
          for (final (id, d) in modules)
            if (d == null || !detached.contains(d)) (id, d),
        ]..sort((a, b) {
          final r = (a.$2 ?? 99).compareTo(b.$2 ?? 99);
          return r != 0 ? r : (_isBase(a.$1) ? 1 : 0) - (_isBase(b.$1) ? 1 : 0);
        });
    for (final (i, (id, _)) in left.indexed) {
      final spine = i == left.length - 1;
      final k = _carrier ? .35 : 1.0;
      wrecks.add(
        BossWreck(
          module: id,
          x: w.x,
          y: w.y,
          vx: spine ? 0 : (_rng.nextDouble() - .5) * 50,
          vy: spine ? 4 : 10,
          spin: (_rng.nextDouble() - .5) * (spine ? .3 : 1.0) * k,
          life: 4 + _rng.nextDouble() * 2,
          delay: spine ? .9 : i * .25,
          sink: _carrier ? .7 : .45,
        ),
      );
    }
    detached.addAll([for (final (_, d) in modules) ?d]);
  }
}

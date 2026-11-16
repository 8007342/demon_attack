import 'dart:math' as math;

/// carrier-v3 §4: the hull's gates and compartments. Gate positions are
/// simulation geometry, like the core window: hull-local arena units from
/// the carrier centre (x right, y down-screen), each with an outward normal.
/// The art conforms to them (the rig's anchor gate, ±3 units), never the
/// reverse, so the simulation stays art-free and deterministic.
enum CarrierGateKind { leaf, iris, hatch, sac }

class CarrierGate {
  const CarrierGate(
    this.id,
    this.slot,
    this.kind,
    this.x,
    this.y,
    this.nx,
    this.ny, {
    this.width = 22,
  });
  final String id;

  /// The module slot it sits in (`prow`, `maw`, `carapace`, `sac`).
  final String slot;
  final CarrierGateKind kind;
  final double x, y;

  /// Outward normal (unit).
  final double nx, ny;

  /// The opening's width (units), for the runtime-drawn doors.
  final double width;

  /// −1 left, +1 right, 0 on the centre line.
  int get side => x < -1 ? -1 : (x > 1 ? 1 : 0);
}

abstract final class CarrierGates {
  /// Tour 1: the two deck bays (the deck's side hatches at ±46) and two
  /// prong gates under the prongs.
  static const bayL = CarrierGate(
    'bayL', 'prow', CarrierGateKind.leaf, -46, 21, -.3, .954, width: 16);
  static const bayR = CarrierGate(
    'bayR', 'prow', CarrierGateKind.leaf, 46, 21, .3, .954, width: 16);
  static const prongL = CarrierGate(
    'prongL', 'prow', CarrierGateKind.leaf, -150, 52, -.2, .98);
  static const prongR = CarrierGate(
    'prongR', 'prow', CarrierGateKind.leaf, 150, 52, .2, .98);

  /// Tour 2: flank maws (the existing `maw` slot), irises.
  static const mawL = CarrierGate(
    'mawL', 'maw', CarrierGateKind.iris, -228, -40, -.6, .8, width: 26);
  static const mawR = CarrierGate(
    'mawR', 'maw', CarrierGateKind.iris, 228, -40, .6, .8, width: 26);

  /// Tour 3: dorsal compartments on the citadel terrace (creatures rise,
  /// then swoop).
  static const dorsalL = CarrierGate(
    'dorsalL', 'carapace', CarrierGateKind.hatch, -78, -168, -.2, -.98);
  static const dorsalR = CarrierGate(
    'dorsalR', 'carapace', CarrierGateKind.hatch, 78, -168, .2, -.98);

  /// Tour 4: brood sacs (the existing `sac` slot; they split open).
  static const sacL = CarrierGate(
    'sacL', 'sac', CarrierGateKind.sac, -262, -118, -.7, .714, width: 28);
  static const sacR = CarrierGate(
    'sacR', 'sac', CarrierGateKind.sac, 262, -118, .7, .714, width: 28);

  /// Tour 5: aft prong gates.
  static const aftL = CarrierGate(
    'aftL', 'carapace', CarrierGateKind.leaf, -176, -300, -.4, .917);
  static const aftR = CarrierGate(
    'aftR', 'carapace', CarrierGateKind.leaf, 176, -300, .4, .917);

  static const _byTour = [
    [bayL, bayR, prongL, prongR],
    [mawL, mawR],
    [dorsalL, dorsalR],
    [sacL, sacR],
    [aftL, aftR],
  ];

  /// The gates of tour [route] (zero-based): 4, 6, 8, 10, 12 instances.
  static List<CarrierGate> forTour(int route) => [
    for (var t = 0; t <= route.clamp(0, 4); t++) ..._byTour[t],
  ];

  /// The authored round-robin, inner rings first, crossing sides and rings
  /// (bayL, prongR, bayR, prongL, …), so the two deck bays never telegraph
  /// as a pair under the dome (no eye reading, styleguide §3.4).
  static List<int> alternating(List<CarrierGate> gates) {
    // Pairs (left, right) in the order they were added (inner first).
    final pairs = <(int, int)>[];
    for (var i = 0; i + 1 < gates.length; i += 2) {
      final a = gates[i], b = gates[i + 1];
      pairs.add(a.x <= b.x ? (i, i + 1) : (i + 1, i));
    }
    final out = <int>[];
    for (var p = 0; p < pairs.length; p += 2) {
      if (p + 1 < pairs.length) {
        out.addAll([pairs[p].$1, pairs[p + 1].$2, pairs[p].$2, pairs[p + 1].$1]);
      } else {
        out.addAll([pairs[p].$1, pairs[p].$2]);
      }
    }
    if (gates.length.isOdd) out.add(gates.length - 1);
    return out;
  }


  /// The fight's gates near the deck: |x| ≤ 150 (task 2.3).
  static const fightReach = 150.0;

  /// The arena's launch band: a gate outside it does not launch (§4.2).
  static const arenaLeft = 16.0, arenaRight = 344.0;
}

enum GateState { closed, telegraph, opening, launching, closing }

/// One gate's volley state machine: closed → telegraph (1.2 s) → opening
/// (0.5 s) → launching (one creature per 0.12 s) → closing (0.8 s after
/// the last).
class GateRun {
  GateRun(this.index, this.gate);
  final int index;
  final CarrierGate gate;
  GateState state = GateState.closed;

  /// Seconds in the current state.
  double t = 0;

  /// Creatures still to eject in this volley, and ejected so far.
  int queued = 0, launched = 0;

  /// The volley's tier (creature kind), for `bossLaunch`.
  int tier = 1;

  /// A launch waiting on the gameplay (the fight's flock timer): the doors
  /// hold open until [release].
  bool hold = false;

  bool get busy => state != GateState.closed;

  /// 0 closed … 1 fully open (presentation).
  double door(CarrierVolleyTiming v) => switch (state) {
    GateState.closed || GateState.telegraph => 0,
    GateState.opening => (t / v.open).clamp(0.0, 1.0),
    GateState.launching => 1,
    GateState.closing => 1 - (t / v.close).clamp(0.0, 1.0),
  };

  /// The telegraph's glow 0..1 (ember → amber), held while open.
  double glow(CarrierVolleyTiming v) => switch (state) {
    GateState.closed => 0,
    GateState.telegraph => (t / v.telegraph).clamp(0.0, 1.0),
    GateState.opening || GateState.launching => 1,
    GateState.closing => 1 - (t / v.close).clamp(0.0, 1.0),
  };

  /// Seconds until this gate can eject its next creature.
  double untilLaunch(CarrierVolleyTiming v) => switch (state) {
    GateState.closed => v.telegraph + v.open,
    GateState.telegraph => v.telegraph - t + v.open + queued * v.interval,
    GateState.opening => v.open - t + queued * v.interval,
    GateState.launching => math.max(0, (launched + queued) * v.interval - t),
    GateState.closing => double.infinity,
  };
}

/// The volley timings the controller needs (a view of `CarrierVolley`).
class CarrierVolleyTiming {
  const CarrierVolleyTiming({
    this.telegraph = 1.2,
    this.open = .5,
    this.interval = .12,
    this.close = .8,
    this.maxOpen = 2,
  });
  final double telegraph, open, interval, close;
  final int maxOpen;
}

/// A gate event for the game event queue (`bossGateTelegraph`, …).
class GateEvent {
  const GateEvent(this.kind, this.run, {this.count = 0});
  final GateState kind; // telegraph, opening (open), launching, closed
  final GateRun run;
  final int count;
}

/// The carrier's launches (design §4.2–§4.4): gate state machines, the
/// round-robin, the at-most-two-open rule and the off-arena skip. Pure,
/// deterministic: its own PRNG stream (`seed ^ 0xB055 ^ 0x6A7E`) picks the
/// round-robin's start.
class CarrierLaunches {
  CarrierLaunches({
    required List<CarrierGate> gates,
    required List<int> order,
    required int seed,
    this.timing = const CarrierVolleyTiming(),
  }) : runs = [for (final (i, g) in gates.indexed) GateRun(i, g)],
       _order = order.isEmpty ? [for (var i = 0; i < gates.length; i++) i] : order,
       _rng = math.Random(seed ^ 0xB055 ^ 0x6A7E) {
    _next = _rng.nextInt(math.max(1, _order.length));
  }

  final List<GateRun> runs;
  final List<int> _order;
  final math.Random _rng;
  final CarrierVolleyTiming timing;
  int _next = 0;

  /// Events since the last [takeEvents].
  final List<GateEvent> _events = [];
  List<GateEvent> takeEvents() {
    final out = List<GateEvent>.of(_events);
    _events.clear();
    return out;
  }

  int get openCount => runs.where((r) => r.busy).length;

  /// Picks the next gate of the round-robin whose screen position
  /// ([screenX] of a gate) is inside the arena and that [eligible] allows;
  /// a busy gate that is still before its launch is shared (its skein
  /// queues behind). Null when no gate qualifies.
  GateRun? pick(
    double Function(CarrierGate) screenX, {
    bool Function(CarrierGate)? eligible,
  }) {
    GateRun? sharable;
    for (var k = 0; k < _order.length; k++) {
      final i = _order[(_next + k) % _order.length];
      final r = runs[i];
      final x = screenX(r.gate);
      if (x < CarrierGates.arenaLeft || x > CarrierGates.arenaRight) continue;
      if (eligible != null && !eligible(r.gate)) continue;
      if (r.state == GateState.closed) {
        if (openCount >= timing.maxOpen) {
          continue;
        }
        _next = (_next + k + 1) % _order.length;
        return r;
      }
      if (r.state != GateState.closing) sharable ??= r;
    }
    if (sharable != null) return sharable;
    return null;
  }

  /// Schedules a volley of [count] at [run]; returns each creature's delay
  /// (s) until it leaves the gate. A closed gate starts its telegraph now.
  List<double> volley(GateRun run, int count, {int tier = 1, bool hold = false}) {
    final v = timing;
    if (run.state == GateState.closed) {
      run
        ..state = GateState.telegraph
        ..t = 0
        ..queued = 0
        ..launched = 0
        ..tier = tier;
      _events.add(GateEvent(GateState.telegraph, run));
    }
    final base = run.untilLaunch(v);
    final delays = [for (var i = 0; i < count; i++) base + i * v.interval];
    run
      ..queued += count
      ..hold = hold;
    return delays;
  }

  /// Releases a held launch (the fight's flock timer fired).
  void release(GateRun run) => run.hold = false;

  /// Advances every gate by [dt] (combat seconds).
  void step(double dt) {
    final v = timing;
    for (final r in runs) {
      if (r.state == GateState.closed) continue;
      r.t += dt;
      switch (r.state) {
        case GateState.telegraph:
          if (r.t >= v.telegraph) {
            r
              ..state = GateState.opening
              ..t -= v.telegraph;
            _events.add(GateEvent(GateState.opening, r));
          }
        case GateState.opening:
          if (r.t >= v.open && !r.hold) {
            r
              ..state = GateState.launching
              ..t -= v.open;
            _events.add(GateEvent(GateState.launching, r, count: r.queued));
          }
        case GateState.launching:
          // Creature k leaves at t = k · interval: the first at the doors'
          // full opening.
          while (r.queued > 0 && r.t + 1e-9 >= r.launched * v.interval) {
            r.queued -= 1;
            r.launched += 1;
          }
          if (r.queued <= 0 &&
              !r.hold &&
              r.t + 1e-9 >= (r.launched - 1) * v.interval) {
            r
              ..state = GateState.closing
              ..t = 0;
          }
        case GateState.closing:
          if (r.t >= v.close) {
            r
              ..state = GateState.closed
              ..t = 0
              ..launched = 0;
            _events.add(GateEvent(GateState.closed, r));
          }
        case GateState.closed:
          break;
      }
    }
  }

  /// Every gate closed at once (the approach's end, a reset).
  void closeAll() {
    for (final r in runs) {
      if (r.busy) {
        r
          ..state = GateState.closed
          ..t = 0
          ..queued = 0
          ..hold = false;
      }
    }
  }
}

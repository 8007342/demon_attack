import 'dart:math' as math;

/// The swarm keeps flocking while it fights (openspec/changes/continuous-
/// swarm design §4, plan/swarm-research.md §3.2).
///
/// A **squad** is the arrived members of one skein. It has a station S (the
/// mean of its members' calibrated home slots, so density and depth match
/// the old grid) and an anchor A(t); each member flies toward
/// `T_i(t) = A(t) + offset_i(state, t)`. The collective states follow
/// Couzin et al. 2002 (swarm -> torus -> parallel), with an order dial phi:
///
/// | state  | phi | anchor                            | member offset              |
/// |--------|-----|-----------------------------------|----------------------------|
/// | mill   | 0   | S + slow drift (±20)              | a ring at a slant, turning |
/// | ribbon | .5  | Gerono 1:2 figure-eight around S  | a chain on the anchor track|
/// | sweep  | 1   | S.x ± span/2, smootherstep        | a stretched line behind it |
/// | cloud  | -   | the sentinel                      | insect orbit               |
/// | hover  | -   | the slot (legacy, onboarding)     | the model's own sines      |
///
/// A squad dwells 7-12 s, then moves to a *neighbouring* state (mill <->
/// ribbon <-> sweep: collective memory) over a 1.2 s smootherstep
/// crossfade. When a member dies or dives its neighbours close the gap over
/// 0.6 s (the vacuole). Pure Dart, seeded, deterministic; it never draws
/// from the model's random.
enum SquadState { mill, ribbon, sweep, cloud, hover }

class SwarmBounds {
  /// Anchor x range, member x range, and the lowest member row (screen y)
  /// outside a dive: `shipY - 130`.
  static const anchorLeft = 48.0, anchorRight = 312.0;
  static const memberLeft = 20.0, memberRight = 340.0;
  static const lowest = 477.0 - 130;

  /// The anchor stays within the squad's home band ± this.
  static const band = 24.0;
}

/// One member's place in its squad.
class SquadSlot {
  SquadSlot(this.order, this.jitter);

  /// Fixed order in the skein (the ring and chain are re-indexed over the
  /// members still flying, in this order).
  final int order;
  final double jitter;

  /// Eased index fraction in [0, 1) (ring phase) and rank (chains): they
  /// move to their new values over 0.6 s when a neighbour is lost.
  double fraction = -1, rank = -1;

  /// While its tell plays (divePrep, telegraph) the member holds the
  /// target it had (tells read cleanly); null otherwise.
  (double, double)? held;
}

class Squad {
  Squad(
    this.id,
    math.Random rng, {
    required this.stationX,
    required this.stationY,
    this.state = SquadState.mill,
  }) : previous = state,
       radius = 34 + 22 * rng.nextDouble(),
       omega = .7 + .4 * rng.nextDouble(),
       turn = id.isEven ? 1 : -1,
       ribbonA = 60 + 30 * rng.nextDouble(),
       ribbonPeriod = 9 + 3 * rng.nextDouble(),
       sweepSpan = 90 + 90 * rng.nextDouble(),
       sweepPeriod = 4.5 + 2.5 * rng.nextDouble(),
       phase = rng.nextDouble() * 2 * math.pi,
       _rng = rng {
    dwellLeft = _dwell();
    phi = _phiOf(state);
  }

  final int id;
  final math.Random _rng;
  final double stationX, stationY;
  final double radius, omega, ribbonA, ribbonPeriod, sweepSpan, sweepPeriod;
  final double phase;

  /// Mill direction (alternates by squad).
  final int turn;

  SquadState state, previous;

  /// Order dial (0 mill .. 1 sweep), eased at 0.8 / s; published for the
  /// presentation (cinematic-flow, W5b, reads it).
  double phi = 0;

  /// Crossfade 0 -> 1 from [previous] to [state] (1 = settled).
  double fade = 1;
  double dwellLeft = 10;

  /// Squad clock (s, times tempo).
  double clock = 0;

  /// Lateral velocity of the anchor (u/s), for the squad heading rule of
  /// the creature motion (design §7).
  double anchorVx = 0;

  static const crossfade = 1.2, vacuole = .6;

  /// Chain spacing in time along the anchor's track (ribbon, sweep).
  static const ribbonLag = .6, sweepLag = .55;

  final slots = <Object, SquadSlot>{};

  double _dwell() => 7 + 5 * _rng.nextDouble();

  static double _phiOf(SquadState s) => switch (s) {
    SquadState.mill => 0,
    SquadState.ribbon => .5,
    SquadState.sweep => 1,
    _ => 0,
  };

  bool get patterned => state != SquadState.hover;

  /// Adds a member (by identity) in its skein order.
  void add(Object member, int order) =>
      slots[member] ??= SquadSlot(order, _rng.nextDouble() - .5);

  /// Advances the squad clock, its dwell and state switching, and eases
  /// every flying member's fraction toward its index among [flying].
  void update(
    double dt, {
    required double tempo,
    required Iterable<Object> flying,
  }) {
    if (dt <= 0) return;
    final x0 = _anchor(state, clock).$1;
    clock += dt * tempo;
    if (fade < 1) fade = math.min(1, fade + dt / crossfade);
    phi += (_phiOf(state) - phi).clamp(-.8 * dt, .8 * dt);
    if (state == SquadState.mill ||
        state == SquadState.ribbon ||
        state == SquadState.sweep) {
      dwellLeft -= dt;
      if (dwellLeft <= 0 && fade >= 1) {
        final next = switch (state) {
          SquadState.mill => SquadState.ribbon,
          SquadState.sweep => SquadState.ribbon,
          _ => _rng.nextBool() ? SquadState.mill : SquadState.sweep,
        };
        switchTo(next);
      }
    }
    anchorVx = (_anchor(state, clock).$1 - x0) / dt;
    final order = [
      for (final m in flying)
        if (slots.containsKey(m)) m,
    ]..sort((a, b) => slots[a]!.order.compareTo(slots[b]!.order));
    final k = order.length;
    final ease = 1 - math.exp(-dt / (vacuole / 4));
    for (var i = 0; i < k; i++) {
      final s = slots[order[i]]!;
      final f = i / math.max(1, k);
      final r = i.toDouble();
      if (s.fraction < 0) {
        s
          ..fraction = f
          ..rank = r;
        continue;
      }
      // Shortest way round the ring.
      var df = f - s.fraction;
      df -= df.roundToDouble();
      s
        ..fraction = (s.fraction + df * ease) % 1
        ..rank = s.rank + (r - s.rank) * ease;
    }
    _count = k;
  }

  int _count = 1;

  /// Switches to [next] (a neighbouring state) over the crossfade.
  void switchTo(SquadState next) {
    if (next == state) return;
    previous = state;
    state = next;
    fade = 0;
    dwellLeft = _dwell();
  }

  double _smoother(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }

  /// Anchor of [s] at squad time [t], clamped (design §4 bounds).
  (double, double) _anchor(SquadState s, double t) {
    double x = stationX, y = stationY;
    switch (s) {
      case SquadState.mill:
        x += 20 * math.sin(.13 * t + phase);
        y += 8 * math.sin(.17 * t + phase * .7);
      case SquadState.ribbon:
        final tau = 2 * math.pi * t / ribbonPeriod + phase;
        final tt = tau + .15 * math.sin(2 * tau);
        x += ribbonA * math.sin(tt);
        y += ribbonA * .3 * math.sin(2 * tt);
      case SquadState.sweep:
        // Back and forth across the band: smootherstep on a triangle wave.
        final p = ((t / sweepPeriod) + phase / (2 * math.pi)) % 2;
        final tri = p < 1 ? p : 2 - p;
        x += sweepSpan / 2 * (2 * _smoother(tri) - 1);
        y += 6 * math.sin(math.pi * tri);
      case SquadState.cloud:
      case SquadState.hover:
        break;
    }
    return (
      x.clamp(SwarmBounds.anchorLeft, SwarmBounds.anchorRight),
      y.clamp(stationY - SwarmBounds.band, stationY + SwarmBounds.band),
    );
  }

  (double, double) _offset(SquadState s, SquadSlot slot, double t) {
    switch (s) {
      case SquadState.mill:
        final a =
            2 * math.pi * slot.fraction +
            turn * omega * t +
            slot.jitter * .3 +
            phase;
        final r = _count <= 1 ? 0.0 : radius;
        return (r * math.cos(a), .45 * r * math.sin(a));
      case SquadState.ribbon:
        final (ax, ay) = _anchor(s, t - ribbonLag * slot.rank);
        final (bx, by) = _anchor(s, t);
        return (ax - bx, ay - by + 4 * math.sin(t * 2.3 + slot.order));
      case SquadState.sweep:
        final (ax, ay) = _anchor(s, t - sweepLag * slot.rank);
        final (bx, by) = _anchor(s, t);
        // A stretched line, staggered a little in depth (y).
        final stagger = (slot.order.isEven ? 1 : -1) * 9.0;
        return (ax - bx, ay - by + stagger);
      case SquadState.cloud:
        final w = t * (2.2 + slot.jitter) + slot.order * 1.7;
        final r = 40 + 30 * (slot.jitter + .5);
        return (math.cos(w) * r, math.sin(w * 1.3) * r * .45);
      case SquadState.hover:
        return (0, 0);
    }
  }

  (double, double) _targetIn(
    SquadState s,
    SquadSlot slot,
    double t, {
    double? cx,
    double? cy,
  }) {
    final (ax, ay) = s == SquadState.cloud && cx != null && cy != null
        ? (cx, cy)
        : _anchor(s, t);
    final (ox, oy) = _offset(s, slot, t);
    return (ax + ox, ay + oy);
  }

  /// Pattern target of [member] now; null for a hover squad or a stranger.
  /// [centreX]/[centreY]: the sentinel a cloud is bound to.
  (double, double)? target(Object member, {double? centreX, double? centreY}) {
    final slot = slots[member];
    if (slot == null || !patterned) return null;
    if (slot.fraction < 0) {
      slot
        ..fraction = slot.order / math.max(1, slots.length)
        ..rank = slot.order.toDouble();
    }
    var (x, y) = _targetIn(state, slot, clock, cx: centreX, cy: centreY);
    if (fade < 1) {
      final (px, py) = _targetIn(
        previous,
        slot,
        clock,
        cx: centreX,
        cy: centreY,
      );
      final b = _smoother(fade);
      x = px + (x - px) * b;
      y = py + (y - py) * b;
    }
    return (
      x.clamp(SwarmBounds.memberLeft, SwarmBounds.memberRight),
      math.min(y, SwarmBounds.lowest),
    );
  }

  /// The cosmetic altitude channel (design §8.1) on top of the fighting
  /// altitude [fight]: the mill's ring tilts ±12, a sweep dips 10 at its
  /// turns, a ribbon breathes 14 · sin 2t.
  double altitude(Object member, double fight) {
    final slot = slots[member];
    if (slot == null) return fight;
    double of(SquadState s) => switch (s) {
      SquadState.mill =>
        12 *
            math.sin(
              2 * math.pi * slot.fraction + turn * omega * clock + phase,
            ),
      SquadState.ribbon => 14 * math.sin(2 * clock + slot.order),
      SquadState.sweep => () {
        final p = ((clock / sweepPeriod) + phase / (2 * math.pi)) % 1;
        return -10 * math.exp(-math.pow((p - .5).abs() * 2 - 1, 2) * 30);
      }(),
      _ => 0.0,
    };
    final b = fade < 1 ? _smoother(fade) : 1.0;
    return fight + of(previous) * (1 - b) + of(state) * b;
  }
}

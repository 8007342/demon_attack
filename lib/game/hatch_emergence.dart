import 'dart:math' as math;

import 'carrier_gates.dart';
import 'model.dart';

/// hatch-emergence (openspec/changes/hatch-emergence, design §2–§4): the
/// carrier's launched creatures climb out of their hatch once, in seven
/// beats, inside the launch timing the fight already has:
///
/// 1. a claw grips the rim, 2. the head and shoulders peek out, 3. it holds
///    the door (the hatch's telegraph and opening, before the creature
///    exists in the simulation: a *lurker* drawn by the hatch);
/// 4. an anticipation crouch, 5. the leap, 6. the wings open and it glides
///    down (the creature's own entrance, untargetable as before);
/// 7. the hand-off: the entrance ends and the flight sprites take over.
///
/// Presentation only. It reads the model (the gate runs, the carrier, the
/// entering creatures) and never writes it, so every arrival moment, kill
/// window and calibration number is unchanged (the parity test). Pure Dart:
/// the painter is `hatch_emergence_painter.dart`.

/// The atlas columns (`HatchEmergenceAtlas.poses`, rig order).
enum EmergePose {
  flare,
  grip1,
  grip2,
  peek1,
  peek2,
  hold,
  crouch1,
  crouch2,
  leap,
  unfurl,
  glide1,
  glide2,
}

/// Three ways out, so a flock never climbs out in lockstep (design §2.3).
enum EmergeVariant {
  /// The flock's lead: grips, peeks, holds the door, then leaps (all seven
  /// beats). It holds the hatch's outboard tusk.
  peek,

  /// The second: grips the other tusk as the doors part and vaults out
  /// (no peek), leaping higher.
  vault,

  /// The third: springs straight out of the dark from a low crouch.
  spring,
}

/// One drawn emergence frame (hull-local offsets in arena units).
class EmergeFrame {
  const EmergeFrame(
    this.pose, {
    this.dx = 0,
    this.hop = 0,
    this.toModel = 0,
    this.flip = false,
    this.clipped = false,
  });
  final EmergePose pose;

  /// Lateral offset from the hatch centre toward the held tusk (units).
  final double dx;

  /// Height above the rim (units, up-screen).
  final double hop;

  /// 0 = drawn at the hatch, 1 = at the model's own position (the blend
  /// into the entrance path).
  final double toModel;

  /// Mirrored (the creature holds the left tusk).
  final bool flip;

  /// Clipped at the rim: the body is still inside the hatch.
  final bool clipped;
}

/// The timing of the seven beats (design §3, the budget table).
abstract final class EmergeTiming {
  /// The grip starts this long before the telegraph ends (inside it).
  static const gripLead = .5;

  /// Opening beats: peek1, peek2, then hold.
  static const peek1End = .18, peek2End = .34;

  /// Launched beats on the entrance clock (seconds after its delay).
  static const crouch1End = .08,
      crouch2End = .16,
      leapEnd = .28,
      unfurlEnd = .36,
      flareEnd = .44,
      glide1End = .6;

  /// The hop's arc and the blend from the hatch into the model's path.
  static const hopStart = .16, hopSeconds = .4;
  static const blendStart = .24, blendSeconds = .32;

  /// Pre-glide beats in total: the shortest transit (0.55 s, the core door)
  /// still leaves 0.11 s of glide before the hand-off.
  static const launchBeats = flareEnd;

  /// Lateral offset of the tusk-holding lurkers (units).
  static const side = 9.0;

  /// Hop height per variant (units).
  static double hopOf(EmergeVariant v) => switch (v) {
    EmergeVariant.peek => 9,
    EmergeVariant.vault => 12,
    EmergeVariant.spring => 6,
  };
}

/// The atlas row of a creature kind (violet, coral, gold); null for kinds
/// the fight never launches (teal), which keep the flight sprites.
int? emergeRow(int kind) => switch (kind) {
  1 => 0,
  2 => 1,
  3 => 2,
  _ => null,
};

/// The variant of the [index]-th member of a flock (by entrance delay).
EmergeVariant emergeVariantOf(int index) =>
    EmergeVariant.values[index.clamp(0, 2)];

/// Whether the variant holds the outboard tusk of hatch [h] mirrored: the
/// lead holds the outer tusk (left on a left hatch), the vault the inner.
bool emergeFlip(EmergeVariant v, CarrierGate h) => switch (v) {
  EmergeVariant.peek => h.x < 0,
  EmergeVariant.vault => h.x >= 0,
  EmergeVariant.spring => false,
};

double _side(EmergeVariant v, CarrierGate h) => switch (v) {
  EmergeVariant.spring => 0,
  _ => emergeFlip(v, h) ? -EmergeTiming.side : EmergeTiming.side,
};

/// Beats 1–3: the lurker of variant [v] in a hatch whose volley is in
/// [state] for [t] seconds; null when nothing shows.
EmergeFrame? lurkFrame(
  EmergeVariant v,
  CarrierGate h,
  GateState state,
  double t,
  CarrierVolleyTiming timing,
) {
  final flip = emergeFlip(v, h), dx = _side(v, h);
  EmergeFrame f(EmergePose p) =>
      EmergeFrame(p, dx: dx, flip: flip, clipped: true);
  switch (state) {
    case GateState.telegraph:
      if (v != EmergeVariant.peek) return null;
      final left = timing.telegraph - t;
      if (left > EmergeTiming.gripLead) return null;
      return f(
        left > EmergeTiming.gripLead / 2 ? EmergePose.grip1 : EmergePose.grip2,
      );
    case GateState.opening:
      return switch (v) {
        EmergeVariant.peek => f(
          t < EmergeTiming.peek1End
              ? EmergePose.peek1
              : t < EmergeTiming.peek2End
              ? EmergePose.peek2
              : EmergePose.hold,
        ),
        EmergeVariant.vault => f(t < .12 ? EmergePose.grip1 : EmergePose.grip2),
        EmergeVariant.spring => t < .25 ? null : f(EmergePose.grip1),
      };
    case GateState.closed:
    case GateState.launching:
    case GateState.closing:
      return null;
  }
}

/// A creature parked in its hatch (its entrance delay or the core door's
/// hold): the variant's held lurk pose.
EmergeFrame heldFrame(EmergeVariant v, CarrierGate h) => EmergeFrame(
  switch (v) {
    EmergeVariant.peek => EmergePose.hold,
    EmergeVariant.vault => EmergePose.grip2,
    EmergeVariant.spring => EmergePose.grip1,
  },
  dx: _side(v, h),
  flip: emergeFlip(v, h),
  clipped: true,
);

/// Beats 4–6 on the entrance clock [e] (seconds after the delay).
EmergeFrame launchFrame(EmergeVariant v, CarrierGate h, double e) {
  final p = switch (e) {
    < EmergeTiming.crouch1End =>
      v == EmergeVariant.spring ? EmergePose.crouch2 : EmergePose.crouch1,
    < EmergeTiming.crouch2End => EmergePose.crouch2,
    < EmergeTiming.leapEnd => EmergePose.leap,
    < EmergeTiming.unfurlEnd => EmergePose.unfurl,
    < EmergeTiming.flareEnd => EmergePose.flare,
    < EmergeTiming.glide1End => EmergePose.glide1,
    _ => EmergePose.glide2,
  };
  final u = ((e - EmergeTiming.hopStart) / EmergeTiming.hopSeconds).clamp(
    0.0,
    1.0,
  );
  final hop = EmergeTiming.hopOf(v) * math.sin(math.pi * u);
  final b = ((e - EmergeTiming.blendStart) / EmergeTiming.blendSeconds).clamp(
    0.0,
    1.0,
  );
  return EmergeFrame(
    p,
    dx: _side(v, h) * (1 - b),
    hop: hop,
    toModel: b * b * (3 - 2 * b),
    flip: emergeFlip(v, h) && e < EmergeTiming.leapEnd,
  );
}

/// One creature's emergence (presentation state).
class Emergence {
  Emergence(this.demon, this.hatch, this.variant, this.row);
  final Demon demon;

  /// The hatch it climbs out of (hull-local; the painter bends it).
  final CarrierGate hatch;
  final EmergeVariant variant;
  final int row;

  /// Poses shown so far, in order (tests: one pass, never restarted).
  final List<EmergePose> shown = [];
  bool done = false;

  /// The model ended the entrance early (the game-over celebration snaps
  /// every entrance): handed off before its sequence played out.
  bool cut = false;

  /// The entrance progress last seen.
  double progress = 0;

  /// The frame this step (null once handed off).
  EmergeFrame? frame;
}

/// The scene's emergence director: registers each creature a fight hatch
/// launches, once, and steps its frame; lists the lurkers of the held
/// hatches. [lurkers] per hatch is the tier's budget (FULL 3, LEAN 1);
/// [enabled] false (LITE) skips everything: the flight sprites as before.
class HatchEmergence {
  bool enabled = true;
  int lurkers = 3;

  final Map<Demon, Emergence> _active = Map.identity();
  final Set<Demon> _seen = Set.identity();

  /// Counters for tests and the review harness.
  int started = 0, finished = 0, dropped = 0;

  /// Every emergence that ran (tests), oldest first; capped.
  final List<Emergence> history = [];

  Iterable<Emergence> get active => _active.values;

  /// The frame of [d] this step, or null (not emerging: draw it as usual).
  EmergeFrame? frameOf(Demon d) => _active[d]?.frame;
  Emergence? of(Demon d) => _active[d];

  void reset() {
    _active.clear();
    _seen.clear();
  }

  /// One presentation step (after the model's).
  void update(ArcadeModel m) {
    final b = m.boss;
    final fight =
        enabled &&
        b != null &&
        b.fightReady &&
        b.chapter != CarrierChapter.transform &&
        m.launches != null;
    if (!enabled || b == null) {
      // LITE, or the fight is over: nothing emerges; the flight sprites.
      if (b == null) _seen.clear();
      for (final e in _active.values) {
        e.frame = null;
        if (!e.done) dropped++;
      }
      _active.clear();
      return;
    }
    // Newly launched creatures: entering, from a hatch, not seen before
    // (only while the fight launches; one already out keeps its sequence
    // into the transformation).
    final fresh = <Demon>[];
    if (fight) _register(m, b, fresh);
    _step(m);
  }

  void _register(ArcadeModel m, Carrier b, List<Demon> fresh) {
    for (final d in m.demons) {
      if (d.isLarge || !d.entering || d.entranceStartX == null) continue;
      if (_seen.contains(d)) continue;
      _seen.add(d);
      if (emergeRow(d.kind) == null) continue;
      fresh.add(d);
    }
    if (fresh.isNotEmpty) {
      fresh.sort((a, c) => a.entranceDelay.compareTo(c.entranceDelay));
      // A flock leaves together: its members share the start and the hatch.
      final groups = <String, List<Demon>>{};
      for (final d in fresh) {
        final h = _hatchOf(b, d);
        if (h == null) continue;
        (groups[h.id] ??= []).add(d);
      }
      for (final g in groups.values) {
        final h = _hatchOf(b, g.first)!;
        for (final (i, d) in g.indexed) {
          final e = Emergence(d, h, emergeVariantOf(i), emergeRow(d.kind)!);
          _active[d] = e;
          started++;
          history.add(e);
          if (history.length > 256) history.removeAt(0);
        }
      }
    }
  }

  /// Steps each emergence; hands off when its entrance ends.
  void _step(ArcadeModel m) {
    final gone = <Demon>[];
    for (final e in _active.values) {
      final d = e.demon;
      if (!m.demons.contains(d)) {
        gone.add(d);
        dropped++;
        continue;
      }
      if (!d.entering) {
        e
          ..done = true
          ..cut = e.progress < .9
          ..frame = null;
        finished++;
        gone.add(d);
        continue;
      }
      e.progress = d.entranceProgress;
      final t = d.entranceElapsed - d.entranceDelay;
      // Held while its entrance clock has not started (its delay). Not
      // gateWait: the fight's core-door flock keeps it set while its
      // entrance runs (the fight path does not read it).
      final f = t < 0
          ? heldFrame(e.variant, e.hatch)
          : launchFrame(e.variant, e.hatch, t);
      e.frame = f;
      if (e.shown.isEmpty || e.shown.last != f.pose) e.shown.add(f.pose);
    }
    for (final d in gone) {
      _active.remove(d);
    }
    if (_seen.length > 512) {
      _seen.removeWhere((d) => !m.demons.contains(d));
    }
  }

  /// The hatch nearest [d]'s entrance start (hull-local), from the
  /// launching hatches; null when none is within reach (a non-hatch entry).
  CarrierGate? _hatchOf(Carrier b, Demon d) {
    final lx = d.entranceStartX! - b.x, ly = d.entranceStartY - b.y;
    CarrierGate? best;
    var bestD = 30.0 * 30.0;
    // Every hatch, destroyed or not: a volley held in a hatch that falls the
    // same moment still leaves from it.
    for (final h in [for (final s in b.hatches) s.hatch, CarrierHatches.core]) {
      final dx = h.x - lx, dy = h.y - ly;
      final q = dx * dx + dy * dy;
      if (q < bestD) {
        bestD = q;
        best = h;
      }
    }
    return best;
  }

  /// Beats 1–3: the lurkers of every held hatch this step, with their
  /// atlas row, at most [lurkers] per hatch and [m.hatchFlockPreview].
  List<(CarrierGate hatch, EmergeFrame frame, int row)> lurking(ArcadeModel m) {
    final b = m.boss, l = m.launches;
    if (!enabled ||
        lurkers <= 0 ||
        b == null ||
        !b.fightReady ||
        b.chapter == CarrierChapter.transform ||
        l == null) {
      return const [];
    }
    final out = <(CarrierGate, EmergeFrame, int)>[];
    final n = math.min(lurkers, m.hatchFlockPreview);
    for (final r in l.runs) {
      if (r.state != GateState.telegraph && r.state != GateState.opening) {
        continue;
      }
      final row = emergeRow(r.tier);
      if (row == null) continue;
      for (var i = 0; i < n; i++) {
        final f = lurkFrame(emergeVariantOf(i), r.gate, r.state, r.t, l.timing);
        if (f != null) out.add((r.gate, f, row));
      }
    }
    return out;
  }
}

/// The draw-call budget of the hatches and the emergence in one frame
/// (design §5; `test/hatch_emergence_test.dart` measures it on tour 5).
abstract final class HatchBudget {
  /// Every call the upper hatches draw (slots, tusks, fields, vents,
  /// bursts, smoke and splinters).
  static const hatchCalls = 160;

  /// Emergence images: the lurkers (3 a hatch, 2 hatches busy) and the
  /// creatures still climbing out.
  static const emergeCalls = 16;
}

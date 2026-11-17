import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'carrier_breakup.dart';
import 'carrier_gates.dart';
import 'model.dart';

/// carrier-hatches §A3–§A5, §A10: the runtime drawing of the launch
/// hatches as tusk-framed slots (styleguide §3 item 8: "the dark bay
/// between the two tusk-like prongs … narrowing and demon-like"), their own
/// fields, the core door and its transformation shutter, the lead pip, and
/// the ivory splinters of a destroyed hatch (Part B bodies, procedural).
class CarrierHatchPainter {
  static const _ivory = Color(0xFFE8DCC0), _ivoryShade = Color(0xFF9C8E74);
  static const _slot = Color(0xFF0C0608), _char = Color(0xFF1A0E10);
  static const _ember = Color(0xFFFF5A36), _amber = Color(0xFFFFB24A);
  static const _field = Color(0xFF5FE3F0), _fieldDeep = Color(0xFF7A5CD6);
  final Paint _p = Paint()..isAntiAlias = true;
  final Path _path = Path();

  /// Splinters and smoke of destroyed hatches, on [clock].
  final List<BreakupBody> splinters = [];
  final List<(double x, double y, double t0, double r)> smoke = [];
  final Set<String> _broken = {};

  /// Pieces still attached to the hull (hull-local), with their release
  /// time; released into [splinters] as their time comes.
  final List<(BreakupComponent, double)> pending = [];
  bool _reduced = false;

  // --- hatch-emergence (design §1): the hatch's candy. [rich] (the tier's
  // hatchVents) adds the steam vents and the telegraph pulse rings.
  bool rich = true;

  /// Steam (and ichor drips) from the hatches: (x, y, vx, vy, t0, ichor),
  /// world space, capped at [maxVents].
  final List<(double, double, double, double, double, bool)> vents = [];
  static const maxVents = 32;

  /// A destroyed hatch's burst: (x, y, t0).
  final List<(double, double, double)> bursts = [];

  /// The last field HP seen per hatch, and the moment it last dropped (the
  /// hit ripple).
  final Map<String, int> _lastField = {};
  final Map<String, double> _rippleAt = {};
  final Map<String, double> _ventAt = {};
  final Map<String, GateState> _ventState = {};
  static const rippleSeconds = .28, burstSeconds = .45, ventSeconds = .9;
  final math.Random _rng = math.Random(0xC5B7);
  double clock = 0;
  Carrier? _carrier;

  /// Advances the splinters and notices newly destroyed hatches.
  void update(Carrier? b, double t, {bool reduced = false}) {
    clock = t;
    _reduced = reduced;
    if (!identical(b, _carrier)) {
      pending.clear();
      _carrier = b;
      _broken.clear();
      if (b == null) {
        // The fight ended: let what flies finish, nothing new.
      }
    }
    if (b != null) {
      for (final h in b.hatches) {
        if (h.destroyed && _broken.add(h.hatch.id)) {
          _shatter(b, h, reduced);
          bursts.add((b.x + h.hatch.x, b.y + h.hatch.y, t));
        }
        // --- hatch-emergence: a field hit ripples its membrane.
        final last = _lastField[h.hatch.id];
        if (last != null && h.field < last) _rippleAt[h.hatch.id] = t;
        _lastField[h.hatch.id] = h.field;
        // Ichor seeps from a cracked hatch (field down, hull hurt): a slow
        // drip, one per 0.7 s per hatch.
        if (rich &&
            !reduced &&
            !h.destroyed &&
            h.field <= 0 &&
            h.hull < h.hullMax &&
            vents.length < maxVents &&
            t - (_ventAt['i${h.hatch.id}'] ?? -9) > .7) {
          _ventAt['i${h.hatch.id}'] = t;
          final s = _rng.nextDouble() - .5;
          vents.add((
            b.x + h.hatch.x + s * 8,
            b.y + h.hatch.y + 4,
            s * 6,
            14,
            t,
            true,
          ));
        }
      }
      // World-space smoke from the sealed openings (2/s for 6 s, then 0.5/s).
      for (final h in b.hatches) {
        if (!h.destroyed || reduced) continue;
        final age = h.fallen;
        final rate = age < 6 ? 2.0 : .5;
        final last = smoke.isEmpty ? -1.0 : smoke.last.$3;
        if (smoke.length < 90 && t - last > 1 / (rate * b.hatches.length)) {
          smoke.add((
            b.x + h.hatch.x,
            b.y + h.hatch.y,
            t,
            4 + 3 * _rng.nextDouble(),
          ));
        }
      }
    }
    if (b != null) {
      pending.removeWhere((e) {
        final (c, at) = e;
        if (t < at) return false;
        splinters.add(
          BreakupPhysics.release(
            c,
            t: t,
            wx: b.x + c.px,
            wy: b.y + c.py,
            hx: b.x,
            hy: b.y,
            hvx: b.horizontalVelocity,
            rng: _rng,
            reduced: _reduced,
          ),
        );
        return true;
      });
    } else {
      pending.clear();
    }
    final grown = <BreakupBody>[];
    splinters.removeWhere((s) {
      if (s.split >= 0 && t >= s.t0 + s.tearSeconds + s.split) {
        grown.addAll(
          BreakupPhysics.fragments(
            s,
            BreakupComponent(id: -1, px: 0, py: 0, ax: 0, ay: 1, length: 10),
            rng: _rng,
          ),
        );
        return true;
      }
      return s.done(t);
    });
    splinters.addAll(grown.take(math.max(0, 96 - splinters.length)));
    smoke.removeWhere((s) => t - s.$3 > 2.2);
    vents.removeWhere((v) => t - v.$5 > ventSeconds);
    bursts.removeWhere((v) => t - v.$3 > burstSeconds);
  }

  /// --- hatch-emergence: steam jets from both tusk roots as the doors part
  /// (one pair per opening), hull-local [at] in world space.
  void _vent(String id, Offset at, double width, GateState state) {
    final was = _ventState[id];
    _ventState[id] = state;
    if (!rich || _reduced || state != GateState.opening || was == state) {
      return;
    }
    for (final s in const [-1.0, 1.0]) {
      for (var k = 0; k < 2 && vents.length < maxVents; k++) {
        final j = _rng.nextDouble();
        vents.add((
          at.dx + s * width * .45,
          at.dy - width * .4,
          s * (22 + 14 * j),
          -18 - 10 * j - 8 * k,
          clock + k * .06,
          false,
        ));
      }
    }
  }

  /// A destroyed hatch: its two tusks and rim splinter into 6 ivory
  /// pieces, released one by one over 1.2 s (the rate rule), outer first.
  void _shatter(Carrier b, HatchState h, bool reduced) {
    final g = h.hatch;
    final pieces = <BreakupComponent>[
      for (var i = 0; i < 6; i++)
        BreakupComponent(
          id: i,
          px: g.x + (i.isEven ? -1 : 1) * (6 + 2.0 * (i ~/ 2)),
          py: g.y - 6 + 5.0 * (i ~/ 2),
          ax: (i.isEven ? -1 : 1) * .5 + g.nx * .3,
          ay: -.6 + .2 * (i ~/ 2),
          length: i < 2 ? 24 : 12,
        ),
    ];
    // outer first: the tusk tips, then the rim
    final order = [0, 1, 2, 3, 4, 5];
    final times = breakupSchedule(order, seed: g.id.hashCode ^ b.variant);
    for (final c in pieces) {
      final n = math.sqrt(c.ax * c.ax + c.ay * c.ay);
      final unit = BreakupComponent(
        id: c.id,
        px: c.px,
        py: c.py,
        ax: c.ax / n,
        ay: c.ay / n,
        length: c.length,
      );
      pending.add((unit, clock + times[c.id]));
    }
  }

  /// The upper hatches (back pass, under the creatures).
  void paintHatches(
    Canvas c,
    Carrier b,
    CarrierLaunches? launches, {
    Offset Function(double x, double y)? bend,
    double clock = 0,
    bool reduced = false,
  }) {
    final center = Offset(b.x, b.y);
    final tier = b.vulnerableTier;
    for (final h in b.hatches) {
      final g = h.hatch;
      final at = center + (bend == null ? Offset(g.x, g.y) : bend(g.x, g.y));
      if (h.destroyed) {
        _sealed(c, at, g.width, g.x < 0);
        continue;
      }
      final run = _run(launches, g.id);
      final glow = run == null ? 0.0 : _glow(run, launches!.timing);
      final open = run == null ? 0.0 : _door(run, launches!.timing);
      final vulnerable = g.tier == tier && b.chapter == CarrierChapter.hatches;
      // --- hatch-emergence §1.2: the telegraph quickens the rim light and
      // the spill (2 → 5 Hz toward the opening), no ring round the hatch.
      var pulse = 1.0;
      if (run != null && !reduced && run.state == GateState.telegraph) {
        final u = (run.t / launches!.timing.telegraph).clamp(0.0, 1.0);
        final ph = (run.t * (2 + 3 * u)) % 1.0;
        pulse = 1 + (rich ? .9 : .4) * (1 - ph) * (.4 + .6 * u);
      }
      // --- hatch-emergence §1.6 staging: light falls DOWN the hull from
      // the live tier (directional, toward the core), never a disc round it.
      if (vulnerable) {
        final breathe = reduced ? 1.0 : .8 + .2 * math.sin(clock * 5);
        _spill(c, at, g.width * 1.5, .13 * breathe * pulse);
      }
      if (run != null) _vent(g.id, at, g.width * 1.5, run.state);
      _tuskSlot(
        c,
        at,
        g.width * 1.5,
        open: open,
        glow:
            (vulnerable ? math.max(glow, .35) : glow * .5) *
            math.min(1.6, pulse),
        live: vulnerable,
        dim:
            !vulnerable &&
            (run == null || !run.busy) &&
            b.chapter == CarrierChapter.hatches,
        flip: g.x < 0,
        rim: vulnerable ? math.min(1.0, .55 * pulse) : 0,
      );
      if (vulnerable && h.field > 0) {
        _hatchField(
          c,
          at,
          g.width * 1.5,
          h.field / h.fieldMax,
          clock,
          reduced,
          g.id,
        );
      }
    }
    _paintSmoke(c);
    _paintVents(c);
    _paintBursts(c);
    _paintSplinters(c);
  }

  /// Staging: a wash of warm light falling down the hull below a live
  /// hatch (three stacked bands fading down-screen, offset with the hull's
  /// grain), the directional lead to the target; no round shape.
  void _spill(Canvas c, Offset at, double width, double alpha) {
    for (var k = 0; k < 3; k++) {
      _p.color = _amber.withValues(alpha: alpha * (1 - k / 3));
      c.drawRect(
        Rect.fromLTWH(
          at.dx - width * (.42 - .06 * k),
          at.dy + width * (.3 + .38 * k),
          width * (.84 - .12 * k),
          width * .4,
        ),
        _p,
      );
    }
  }

  void _paintVents(Canvas c) {
    for (final (x, y, vx, vy, t0, ichor) in vents) {
      final age = clock - t0;
      if (age < 0) continue;
      final u = (age / ventSeconds).clamp(0.0, 1.0);
      final drag = 1 - .5 * u;
      final p = Offset(x + vx * age * drag, y + vy * age * drag);
      if (ichor) {
        _p.color = const Color(0xFF6A1430).withValues(alpha: .85 * (1 - u));
        c.drawCircle(p, 1.4 + .6 * u, _p);
      } else {
        _p.color = const Color(0xFFD8CCD8).withValues(alpha: .38 * (1 - u));
        c.drawCircle(p, 2.5 + 7 * u, _p);
      }
    }
  }

  /// A destroyed hatch's break: a white-amber flash, a shock ring and the
  /// ember spray (the splinters fly on their own bodies).
  void _paintBursts(Canvas c) {
    for (final (x, y, t0) in bursts) {
      final u = ((clock - t0) / burstSeconds).clamp(0.0, 1.0);
      final at = Offset(x, y);
      if (u < .3) {
        _p.color = const Color(0xFFFFE6B0)
            .withValues(alpha: .85 * (1 - u / .3));
        c.drawCircle(at, 10 + 14 * u, _p);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - u) + .5
        ..color = _amber.withValues(alpha: .8 * (1 - u));
      c.drawCircle(at, 12 + 38 * u, _p);
      _p.style = PaintingStyle.fill;
      if (_reduced) continue;
      for (var k = 0; k < 10; k++) {
        final a = k * 2.399 + x * .01;
        final r = 8 + 46 * u * (.6 + .4 * ((k * 37) % 10) / 10);
        _p.color = _ember.withValues(alpha: (1 - u));
        c.drawRect(
          Rect.fromCenter(
            center: at + Offset(math.cos(a) * r, math.sin(a) * r + 20 * u * u),
            width: 2,
            height: 2,
          ),
          _p,
        );
      }
    }
  }

  /// The core door (front pass): sealed in the hatch chapter, opening in
  /// the transformation (the tusks part, the dark slot widens), cycling in
  /// the core chapter; with the lead pip.
  void paintCore(
    Canvas c,
    Carrier b, {
    Offset Function(double x, double y)? bend,
    double clock = 0,
    bool reduced = false,
    Offset? pip,
  }) {
    const g = CarrierHatches.core;
    final at =
        Offset(b.x, b.y) + (bend == null ? Offset(g.x, g.y) : bend(g.x, g.y));
    final part = switch (b.chapter) {
      CarrierChapter.hatches => 0.0,
      CarrierChapter.transform => () {
        final k = (b.transformT / CarrierHatches.transformSeconds).clamp(
          0.0,
          1.0,
        );
        return reduced ? k : k * k * (3 - 2 * k);
      }(),
      CarrierChapter.core => 1.0,
    };
    final door = b.chapter == CarrierChapter.core ? b.door : 0.0;
    _coreShutter(c, at, part, door, clock);
    if (pip != null && b.chapter == CarrierChapter.core) {
      final y = at.dy + 22;
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _ember.withValues(alpha: .55);
      _path
        ..reset()
        ..moveTo(pip.dx - 5, y + 4)
        ..lineTo(pip.dx, y)
        ..lineTo(pip.dx + 5, y + 4);
      c.drawPath(_path, _p);
      _p.style = PaintingStyle.fill;
    }
  }

  GateRun? _run(CarrierLaunches? l, String id) {
    if (l == null) return null;
    for (final r in l.runs) {
      if (r.gate.id == id) return r;
    }
    return null;
  }

  double _glow(GateRun r, CarrierVolleyTiming v) => r.glow(v);
  double _door(GateRun r, CarrierVolleyTiming v) => r.door(v);

  /// The slot's outline (hull-local, width [w], height [h]): a tall,
  /// flat-ended slot narrowing down-screen, its top edge ragged and
  /// asymmetric (styleguide §3.8: "a dark slot that narrows inward"). Not a
  /// lens: no point at either end, no vertical line down its middle.
  void _slotPath(Offset at, double w, double h, bool flip) {
    final s = flip ? -1.0 : 1.0;
    _path
      ..reset()
      ..moveTo(at.dx - s * w * .5, at.dy - h * .46)
      ..lineTo(at.dx - s * w * .18, at.dy - h * .4)
      ..lineTo(at.dx + s * w * .06, at.dy - h * .5)
      ..lineTo(at.dx + s * w * .3, at.dy - h * .42)
      ..lineTo(at.dx + s * w * .5, at.dy - h * .47)
      ..lineTo(at.dx + s * w * .24, at.dy + h * .44)
      ..lineTo(at.dx - s * w * .16, at.dy + h * .46)
      ..close();
  }

  /// Two separate ivory tusks standing either side of a dark slot that
  /// narrows inward (styleguide §3.8). [open] parts the tusks and widens
  /// the slot; [glow] is warm light spilling from deep inside (uneven, low
  /// in the slot), [rim] the live tier's amber rim light on the tusks,
  /// [dim] a sealed tier sunk into the hull.
  void _tuskSlot(
    Canvas c,
    Offset at,
    double width, {
    required double open,
    required double glow,
    required bool live,
    required bool flip,
    bool dim = false,
    double rim = 0,
  }) {
    final w = width * (.5 + .35 * open);
    final h = width * 1.15;
    _slotPath(at, w, h, flip);
    _p.color = _slot;
    c.drawPath(_path, _p);
    if (glow > 0) {
      // --- hatch-emergence §1.1: light from deep inside: small warm blooms
      // low in the slot, uneven and offset, rising as the doors part. They
      // never fill the slot (no lit iris).
      final s = flip ? -1.0 : 1.0;
      final hot = Color.lerp(_ember, _amber, glow.clamp(0.0, 1.0))!;
      c.save();
      c.clipPath(_path);
      for (final (dx, dy, rw, rh, a) in const [
        (.08, .36, .55, .16, 1.0),
        (-.1, .26, .38, .12, .7),
        (.14, .12, .3, .1, .45),
      ]) {
        final rise = .12 * open;
        _p.color = hot.withValues(
          alpha: (a * (.22 + .5 * open) * glow).clamp(0.0, 1.0),
        );
        c.drawOval(
          Rect.fromCenter(
            center: at + Offset(s * dx * w, (dy - rise) * h),
            width: rw * w,
            height: rh * h,
          ),
          _p,
        );
      }
      c.restore();
    }
    // The tusks: tapered ivory blades standing beside the slot, roots out
    // past its top corners, tips curving in toward its narrow end but never
    // meeting (a gap of at least 5 units), parted further by [open]. One is
    // a touch longer: architecture, not a mirrored face.
    for (final side in const [-1.0, 1.0]) {
      final long = (side > 0) != flip ? 1.0 : .9;
      final root = Offset(at.dx + side * (w * .5 + 3.5), at.dy - h * .56);
      final tip = Offset(
        at.dx + side * (w * .3 + 2.5 + 4 * open),
        at.dy + h * (.34 * long - .06 * open),
      );
      final ctrl = Offset(at.dx + side * (w * .66 + 4.5), at.dy - h * .05);
      _path
        ..reset()
        ..moveTo(root.dx - side * 2.8, root.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(
          ctrl.dx - side * 3.6,
          ctrl.dy - 1,
          root.dx + side * 2.8,
          root.dy + 1,
        )
        ..close();
      _p.color = dim ? _ivoryShade.withValues(alpha: .7) : _ivory;
      c.drawPath(_path, _p);
      if (rim > 0) {
        // --- hatch-emergence §1.6: the live tier's rim light on the tusks.
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = _amber.withValues(alpha: .28 * rim);
        c.drawPath(_path, _p);
      }
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = live
            ? _amber.withValues(alpha: .5 + .4 * rim)
            : (dim ? _char : _ivoryShade);
      c.drawPath(_path, _p);
      _p.style = PaintingStyle.fill;
    }
  }

  /// The hatch's own field, conforming to the slot (the hull-conforming
  /// field language): an open U of membrane hung from the two tusk roots and
  /// wrapping under the slot's narrow end, never a circle round it.
  ///
  /// hatch-emergence §1.4 (the dive-shield-thinning principle, operator
  /// round 5 S1): it keeps its whole extent and wears in THICKNESS per hit,
  /// with a ripple on a hit.
  void _hatchField(
    Canvas c,
    Offset at,
    double width,
    double s,
    double clock,
    bool reduced,
    String id,
  ) {
    final w = s.clamp(0.0, 1.0);
    final breathe = reduced ? 0.0 : .5 * math.sin(clock * 2.1);
    void u(double grow) {
      final hw = width * .5 + 8 + grow, top = width * 1.15 * .6;
      final bottom = width * 1.15 * .62 + 4 + grow;
      _path
        ..reset()
        ..moveTo(at.dx - hw * .92, at.dy - top)
        ..cubicTo(
          at.dx - hw * 1.02,
          at.dy + bottom * .35,
          at.dx - hw * .55,
          at.dy + bottom,
          at.dx + hw * .06,
          at.dy + bottom,
        )
        ..cubicTo(
          at.dx + hw * .6,
          at.dy + bottom,
          at.dx + hw * 1.0,
          at.dy + bottom * .3,
          at.dx + hw * .9,
          at.dy - top * .9,
        );
    }

    u(breathe);
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = hatchFieldWidth(w) * 2.2
      ..color = _fieldDeep.withValues(alpha: .06 + .16 * w);
    c.drawPath(_path, _p);
    _p
      ..strokeWidth = hatchFieldWidth(w)
      ..color = _field.withValues(alpha: .35 + .55 * w);
    c.drawPath(_path, _p);
    final hit = _rippleAt[id];
    if (hit != null && clock - hit < rippleSeconds) {
      final t = (clock - hit) / rippleSeconds;
      u(breathe + 6 * t);
      _p
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .7 * (1 - t));
      c.drawPath(_path, _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  /// The hatch field's thickness (units) at field share [s]: 7 units full,
  /// 1.2 at its last point, linear per hit; its extent never shrinks.
  static double hatchFieldWidth(double s) => 1.2 + 5.8 * s.clamp(0.0, 1.0);

  /// A destroyed hatch sealed in char: a ragged scorch along the slot (tall,
  /// asymmetric) with two ember cracks off-centre; no round dark shape and
  /// no centred light.
  void _sealed(Canvas c, Offset at, double width, bool flip) {
    final s = flip ? -1.0 : 1.0, w = width * .9, h = width * 1.3;
    _path
      ..reset()
      ..moveTo(at.dx - s * w * .4, at.dy - h * .45)
      ..lineTo(at.dx + s * w * .1, at.dy - h * .38)
      ..lineTo(at.dx + s * w * .45, at.dy - h * .48)
      ..lineTo(at.dx + s * w * .3, at.dy + h * .05)
      ..lineTo(at.dx + s * w * .2, at.dy + h * .42)
      ..lineTo(at.dx - s * w * .25, at.dy + h * .3)
      ..lineTo(at.dx - s * w * .32, at.dy - h * .05)
      ..close();
    _p.color = _char.withValues(alpha: .9);
    c.drawPath(_path, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = _ember.withValues(alpha: .35);
    _path
      ..reset()
      ..moveTo(at.dx + s * w * .05, at.dy - h * .3)
      ..lineTo(at.dx + s * w * .18, at.dy - h * .05)
      ..lineTo(at.dx + s * w * .08, at.dy + h * .2)
      ..moveTo(at.dx - s * w * .2, at.dy + h * .08)
      ..lineTo(at.dx - s * w * .1, at.dy + h * .22);
    c.drawPath(_path, _p);
    _p.style = PaintingStyle.fill;
  }

  /// The core door: the bay between two great tusks. [part] 0 sealed (the
  /// tusks meet), 1 parted; [door] the core door's cycle.
  void _coreShutter(
    Canvas c,
    Offset at,
    double part,
    double door,
    double clock,
  ) {
    const width = 30.0;
    final open = part * (.45 + .55 * door);
    _tuskSlot(
      c,
      at,
      width,
      open: open,
      glow: part <= 0 ? 0 : (door >= .6 ? 1 : .3 + .4 * part),
      live: part >= 1 && door >= .6,
      flip: false,
    );
  }

  void _paintSmoke(Canvas c) {
    for (final (x, y, t0, r) in smoke) {
      final u = ((clock - t0) / 2.2).clamp(0.0, 1.0);
      _p.color = const Color(0xFF3A3238)
          .withValues(alpha: .35 * (1 - u) * (u < .15 ? u / .15 : 1));
      c.drawCircle(Offset(x, y - 10 * u * 2.2), r + 14 * u, _p);
    }
  }

  void _paintSplinters(Canvas c) {
    final b = _carrier;
    if (b != null) {
      for (final (p, _) in pending) {
        _splinter(c, b.x + p.px, b.y + p.py, 0, 1, 1, p.size, 0);
      }
    }
    for (final s in splinters) {
      final (x, y, a, k, alpha) = s.pose(clock);
      _splinter(c, x, y, a, k, alpha, s.size, s.fragment);
    }
  }

  void _splinter(
    Canvas c,
    double x,
    double y,
    double a,
    double k,
    double alpha,
    BreakupSize size,
    int fragment,
  ) {
    {
      final len =
          (fragment == 0 ? (size == BreakupSize.s ? 9.0 : 16.0) : 6.0) * k;
      c.save();
      c.translate(x, y);
      c.rotate(a);
      _path
        ..reset()
        ..moveTo(-1.6 * k, -len * .5)
        ..lineTo(1.8 * k, -len * .3)
        ..lineTo(.4 * k, len * .5)
        ..close();
      _p.color = _ivory.withValues(alpha: alpha);
      c.drawPath(_path, _p);
      c.restore();
    }
  }
}

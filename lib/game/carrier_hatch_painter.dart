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
        if (h.destroyed && _broken.add(h.hatch.id)) _shatter(b, h, reduced);
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
        _sealed(c, at, g.width);
        continue;
      }
      final run = _run(launches, g.id);
      final glow = run == null ? 0.0 : _glow(run, launches!.timing);
      final open = run == null ? 0.0 : _door(run, launches!.timing);
      final vulnerable = g.tier == tier && b.chapter == CarrierChapter.hatches;
      // The vulnerable tier reads at phone size: a warm halo under the
      // tusks (never white-hot), the target the hint names.
      if (vulnerable) {
        final pulse = reduced ? 1.0 : .75 + .25 * math.sin(clock * 5);
        _p.color = _amber.withValues(alpha: .16 * pulse);
        c.drawCircle(at, CarrierHatches.fieldRadius * 1.15, _p);
      }
      _tuskSlot(
        c,
        at,
        g.width * 1.5,
        open: open,
        glow: vulnerable ? math.max(glow, .35) : glow * .5,
        live: vulnerable,
        flip: g.x < 0,
      );
      if (vulnerable && h.field > 0) {
        _hatchField(c, at, h.field / h.fieldMax, clock, reduced);
      }
    }
    _paintSmoke(c);
    _paintSplinters(c);
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

  /// Two ivory tusks framing a dark, narrowing slot. [open] parts the
  /// tusks and widens the slot; [glow] lights the interior ember → amber.
  void _tuskSlot(
    Canvas c,
    Offset at,
    double width, {
    required double open,
    required double glow,
    required bool live,
    required bool flip,
  }) {
    final w = width * (.55 + .35 * open);
    final h = width * 1.15;
    // The slot: a lens narrowing to a point down-screen (demon-like).
    _path
      ..reset()
      ..moveTo(at.dx, at.dy - h * .5)
      ..quadraticBezierTo(at.dx + w * .5, at.dy - h * .1, at.dx, at.dy + h * .5)
      ..quadraticBezierTo(at.dx - w * .5, at.dy - h * .1, at.dx, at.dy - h * .5)
      ..close();
    _p.color = _slot;
    c.drawPath(_path, _p);
    if (glow > 0) {
      final hot = Color.lerp(_ember, _amber, glow)!;
      _p.color = hot.withValues(alpha: (.25 + .55 * open) * glow);
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(.6, .75);
      c.translate(-at.dx, -at.dy);
      c.drawPath(_path, _p);
      c.restore();
    }
    // The tusks: tapered ivory curves, tips bending in toward the slot's
    // narrow end, parted by [open].
    for (final s in const [-1.0, 1.0]) {
      final root = Offset(at.dx + s * (w * .5 + 3), at.dy - h * .55);
      final tip = Offset(
        at.dx + s * (1.5 + 5 * open),
        at.dy + h * (.55 - .08 * open),
      );
      final ctrl = Offset(at.dx + s * (w * .75 + 5), at.dy + h * .15);
      _path
        ..reset()
        ..moveTo(root.dx - s * 3.2, root.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(
          ctrl.dx - s * 4.5,
          ctrl.dy - 1,
          root.dx + s * 3.2,
          root.dy + 1,
        )
        ..close();
      _p.color = _ivory;
      c.drawPath(_path, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = live ? _amber.withValues(alpha: .8) : _ivoryShade;
      c.drawPath(_path, _p);
      _p.style = PaintingStyle.fill;
    }
  }

  /// The hatch's own field: a small membrane that thins with its HP
  /// (carrier-render-engine wear: width and alpha, coherent gaps).
  void _hatchField(Canvas c, Offset at, double s, double clock, bool reduced) {
    final w = .18 + .82 * math.pow(s, .8);
    const r = CarrierHatches.fieldRadius;
    final gaps = s < .7 ? .6 * math.pow((.7 - s) / .7, 1.4) : 0.0;
    const segs = 24;
    final drift = reduced ? 0.0 : clock * .35;
    _p
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < segs; i++) {
      // Coherent gaps: a smooth hash of the segment and the drift.
      final n = .5 + .5 * math.sin(i * 1.7 + drift * 2.3 + math.sin(i * .9));
      if (n < gaps) continue;
      final a0 = i / segs * 2 * math.pi, a1 = (i + .8) / segs * 2 * math.pi;
      final rect = Rect.fromCircle(center: at, radius: r);
      _p
        ..strokeWidth = 1.5 + 5.5 * w
        ..color = _fieldDeep.withValues(alpha: .04 + .14 * w);
      c.drawArc(rect, a0, a1 - a0, false, _p);
      _p
        ..strokeWidth = .7 + 1.3 * w
        ..color = _field.withValues(alpha: .3 + .6 * w);
      c.drawArc(rect, a0, a1 - a0, false, _p);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }

  void _sealed(Canvas c, Offset at, double width) {
    _p.color = _char.withValues(alpha: .9);
    c.drawOval(
      Rect.fromCenter(center: at, width: width * .9, height: width * .7),
      _p,
    );
    _p.color = _ember.withValues(alpha: .25);
    c.drawOval(
      Rect.fromCenter(center: at, width: width * .3, height: width * .2),
      _p,
    );
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
    if (part > 0 && door >= .6) {
      _p.color = _amber.withValues(alpha: .18 + .1 * math.sin(clock * 6));
      c.drawOval(Rect.fromCenter(center: at, width: 46, height: 30), _p);
    }
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

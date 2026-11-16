import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'arena_camera.dart';
import 'boss_director.dart';
import 'boss_painter.dart';
import 'carrier_field.dart';
import 'carrier_gates.dart';
import 'model.dart';

/// carrier-v3: what the scene draws for the redesigned carrier besides its
/// hull — the force field (§3), the gates (§4, runtime-drawn until the
/// re-render's door layers) and the speed cues (§7). It reads the model,
/// the director and the painter; nothing here writes to the simulation.
class CarrierPresentation {
  final field = CarrierFieldPainter();
  bool _building = false;
  int _lastShield = -1;

  /// Speed-cue run clocks (units travelled at the cue speeds).
  double _streakRun = 0, _wispRun = 0, _trailClock = 0;

  /// Builds the field's distance map for the resident hero hull once
  /// (async: the hull's alpha is read back from a picture). Never throws.
  Future<void> ensureField(BossPainter armada) async {
    final key = armada.hero?.key;
    if (key == null || !armada.carrier) return;
    if (field.mapKey == key) {
      armada.footprint ??= field.map; // carrier-render-engine: the cull
      return;
    }
    if (_building) return;
    _building = true;
    try {
      final a = armada.fieldAlpha();
      if (a == null) return;
      final img = await a.picture.toImage(a.w, a.h);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      a.picture.dispose();
      if (bytes == null) return;
      field.map = CarrierFieldMap.fromAlpha(
        bytes.buffer.asUint8List(),
        a.w,
        a.h,
        left: a.left,
        top: a.top,
      );
      field.mapKey = key;
      field.reset();
      armada.footprint = field.map;
    } catch (_) {
      field.map = null; // the arc carries the field
    } finally {
      _building = false;
    }
  }

  /// One presentation step.
  void update(
    double dt,
    ArcadeModel m,
    BossDirector d, {
    required bool reduced,
  }) {
    final b = m.boss;
    if (b == null || !b.fightReady) {
      _lastShield = -1;
      if (b == null) field.reset();
    } else {
      (double, double)? hit;
      if (_lastShield >= 0 && b.shield < _lastShield && m.blasts.isNotEmpty) {
        final bl = m.blasts.last;
        hit = (bl.x - b.x, bl.y - b.y);
      }
      _lastShield = b.shield;
      field.update(
        dt,
        cells: Carrier.shieldCells(b.shield, b.shieldMax),
        style: m.carrierScript.field,
        hit: hit,
        reduced: reduced,
      );
    }
    final speed = d.flowBoost;
    _streakRun += dt * (600 + 800 * d.cues) * speed / 2.2;
    _wispRun += dt * 90 * speed;
    _trailClock += dt;
  }

  /// The field: [lip] the front lip (after the prow), else the membrane
  /// (after the hull's back pass). False when no map is resident (the
  /// caller draws today's arc).
  bool paintField(
    Canvas c,
    Carrier b,
    BossPainter armada,
    BossDirector d, {
    required bool lip,
    required bool reduced,
  }) {
    if (field.map == null || field.mapKey != armada.hero?.key) return false;
    if (b.shield <= 0 && field.down < 0) return true;
    field.paint(
      c,
      Offset(b.x, b.y),
      s: b.shieldMax <= 0 ? 0 : b.shield / b.shieldMax,
      lipY: (x) => b.forceFieldSurfaceY(b.x + x) - b.y,
      lipHalf: b.forceFieldHalfWidth,
      bend: (x, y) => armada.bent(x, y),
      lip: lip,
      reduced: reduced,
      scan: reduced ? 0 : 1,
    );
    return true;
  }

  // --- gates (runtime placeholder until the re-render's door layers) -----

  static const _ember = Color(0xFFFF5A36), _amber = Color(0xFFFFB24A);
  static const _slit = Color(0xFF140A0C), _rimC = Color(0xFF56456C);
  static const _leaf = Color(0xFF3A2C46);
  final Paint _p = Paint()..isAntiAlias = true;

  /// Draws the gates of [launches] on a hull at [center] scaled by
  /// [scale] (1/D in the approach): [front] the prow's gates (after the
  /// front pass), else the rest. [bend] maps hull-local points.
  void paintGates(
    Canvas c,
    CarrierLaunches? launches,
    Offset center, {
    required bool front,
    double scale = 1,
    double opacity = 1,
    double clock = 0,
    Offset Function(double x, double y)? bend,
  }) {
    if (launches == null) return;
    final v = launches.timing;
    final timing = CarrierVolleyTiming(
      telegraph: v.telegraph,
      open: v.open,
      interval: v.interval,
      close: v.close,
    );
    for (final r in launches.runs) {
      final g = r.gate;
      if ((g.slot == 'prow') != front) continue;
      final local = bend == null ? Offset(g.x, g.y) : bend(g.x, g.y);
      final at = center + local * scale;
      _paintGate(
        c,
        g,
        at,
        scale,
        glow: r.glow(timing),
        door: r.door(timing),
        telegraph: r.state == GateState.telegraph,
        t: r.t,
        opacity: opacity,
        clock: clock,
      );
    }
  }

  void _paintGate(
    Canvas c,
    CarrierGate g,
    Offset at,
    double k, {
    required double glow,
    required double door,
    required bool telegraph,
    required double t,
    required double opacity,
    required double clock,
  }) {
    // The opening runs across the normal; the rail runs back along it.
    final n = Offset(g.nx, g.ny);
    final across = Offset(-g.ny, g.nx);
    final w = g.width * k * 1.4;
    final angle = math.atan2(across.dy, across.dx);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    // The slit (closed: a dark seam with a rim; telegraph: it glows).
    final hot = Color.lerp(_ember, _amber, glow)!;
    final open = door.clamp(0.0, 1.0);
    final h = math.max(2.0, 4 * k) + 9 * k * open;
    if (glow > 0) {
      // A warm halo so the gate reads at phone size (never white-hot).
      _p.color = hot.withValues(alpha: .22 * glow * opacity);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 2.2, height: h * 3.2),
        _p,
      );
    }
    _p.color = _slit.withValues(alpha: .85 * opacity);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        Radius.circular(h / 2),
      ),
      _p,
    );
    if (glow > 0) {
      // The interior light (brightest when open), never white-hot.
      final pulse = telegraph ? .55 + .45 * math.sin(t * 14) : 1.0;
      _p.color = hot.withValues(
        alpha: (.35 + .5 * open) * glow * pulse * opacity,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: w * .8,
            height: math.max(1.0, h * .6),
          ),
          Radius.circular(h / 3),
        ),
        _p,
      );
    }
    // The doors: two leaves sliding apart across the opening (leaf, sac),
    // an iris ring, or a hatch lifting along the normal.
    if (open < 1) {
      _p.color = _leaf.withValues(alpha: opacity);
      final cover = 1 - open;
      switch (g.kind) {
        case CarrierGateKind.leaf || CarrierGateKind.sac:
          final lw = w / 2 * cover;
          c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, lw, h), _p);
          c.drawRect(Rect.fromLTWH(w / 2 - lw, -h / 2, lw, h), _p);
        case CarrierGateKind.iris:
          c.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: w * cover,
              height: h * cover,
            ),
            _p,
          );
        case CarrierGateKind.hatch:
          c.drawRect(
            Rect.fromLTWH(-w / 2, -h / 2 - h * open, w, h * cover),
            _p,
          );
      }
    }
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, k)
      ..color = _rimC.withValues(alpha: .9 * opacity);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: w + 2 * k,
          height: h + 2 * k,
        ),
        Radius.circular(h / 2 + k),
      ),
      _p,
    );
    _p.style = PaintingStyle.fill;
    c.restore();
    if (glow <= 0) return;
    // The launch rail: four lights back along the normal, chasing toward
    // the opening during the telegraph, held lit while it launches.
    for (var i = 0; i < 4; i++) {
      final p = at - n * ((8 + 7 * i) * k);
      final phase = telegraph ? ((t * 5 - (3 - i) * .25) % 1) : 1.0;
      final a = telegraph ? (phase < .35 ? 1.0 : .25) : .7;
      final s = math.max(1.5, 2.4 * k);
      _p.color = hot.withValues(alpha: a * glow * opacity);
      c.drawRect(Rect.fromCenter(center: p, width: s, height: s), _p);
    }
  }

  // --- speed cues (design §7) --------------------------------------------

  static const _streakTint = Color(0xFFB9B2D6), _trailTint = Color(0xFFA79CC4);

  /// The ship's band: no cue is drawn below this row.
  static const shipBand = 420.0;

  /// Fog streaks, torn wisps and the cloud punch, drawn over the hull's
  /// back pass and under the creatures, clipped above the ship's band.
  void paintCues(
    Canvas c,
    BossDirector d,
    ArenaCamera cam, {
    required Color cloud,
    required Color cloudLight,
    required int seed,
  }) {
    final k = d.cues;
    if (k <= .01) return;
    final tl = cam.toArena(Offset.zero);
    final br = cam.toArena(const Offset(360, 520));
    final view = Rect.fromLTRB(tl.dx, tl.dy, br.dx, math.min(br.dy, shipBand));
    c.save();
    c.clipRect(view);
    // Streaks: thin, in the fog's highlight colour, streaming down; the
    // near ones longer and faster; more of them as the climb rises.
    final count = (d.script.cues.streakDensity * (.4 + .6 * k)).round().clamp(
      0,
      40,
    );
    final tint = Color.lerp(cloudLight, _streakTint, .25)!;
    for (var i = 0; i < count; i++) {
      double r(int salt) {
        final v = math.sin((seed + i * 17 + salt * 131) * 12.9898) * 43758.5;
        return v - v.floorToDouble();
      }

      final near = r(1);
      final len = 30 + 60 * near;
      final speed = .6 + .8 * near;
      final x = view.left + r(2) * view.width;
      final span = view.height + len;
      final y = view.top + (r(3) * span + _streakRun * speed) % span - len;
      final a = (.1 + .12 * near) * (.5 + .5 * k) * (1 + .3 * d.surge);
      _p.color = tint.withValues(alpha: a.clamp(0.0, .22));
      c.drawRect(Rect.fromLTWH(x, y, near > .5 ? 3 : 2, len), _p);
    }
    // Torn wisps over the off-screen hull's edges: the top band and the
    // sides, moving at 1.5–3 × the hull's flow.
    final wisps = (8 * d.script.cues.wisps).round();
    for (var i = 0; i < wisps; i++) {
      double r(int salt) {
        final v = math.sin((seed * 3 + i * 29 + salt * 71) * 78.233) * 43758.5;
        return v - v.floorToDouble();
      }

      final side = i % 3; // 0 top band, 1 left, 2 right
      final speed = 1.5 + 1.5 * r(1);
      final wx = switch (side) {
        0 => view.left + r(2) * view.width,
        1 => view.left + r(2) * 40,
        _ => view.right - r(2) * 40,
      };
      final band = side == 0 ? 90.0 : view.height;
      final span = band + 120;
      final wy = view.top + (r(3) * span + _wispRun * speed) % span - 60;
      final w = 70 + 90 * r(4), h = 10 + 14 * r(5);
      // Soft by nesting: three faint ovals, no blur (cheap on phones).
      for (final (s, a) in const [(1.0, .07), (.7, .07), (.45, .08)]) {
        _p.color = Color.lerp(cloud, cloudLight, .6)!.withValues(alpha: a * k);
        c.drawOval(
          Rect.fromCenter(center: Offset(wx, wy), width: h * s, height: w * s),
          _p,
        );
      }
    }

    // The cloud punch: a dense bank sweeping down the screen in 0.8 s.
    if (d.punch >= 0) {
      final p = d.punch;
      final y = view.top - 140 + (view.height + 280) * p;
      final band = Rect.fromLTRB(view.left, y - 110, view.right, y + 110);
      _p.shader = ui.Gradient.linear(band.topCenter, band.bottomCenter, [
        cloud.withValues(alpha: 0),
        cloudLight.withValues(alpha: .55 * math.sin(math.pi * p)),
        cloud.withValues(alpha: 0),
      ]);
      c.drawRect(band, _p);
      _p.shader = null;
    }
    c.restore();
  }

  /// Vortex trails from the prong and wing tips that are on screen:
  /// ribbons streaming down-screen (the relative wind), 120–200 units, 3 →
  /// 1 wide, pale violet-grey, alpha ≤ 0.25.
  void paintTrails(
    Canvas c,
    Carrier b,
    BossPainter armada,
    BossDirector d,
    ArenaCamera cam,
  ) {
    final k = d.cues;
    if (k <= .01 || !d.script.cues.vortex) return;
    final tl = cam.toArena(Offset.zero);
    final br = cam.toArena(const Offset(360, 520));
    c.save();
    c.clipRect(Rect.fromLTRB(tl.dx, tl.dy, br.dx, math.min(br.dy, shipBand)));
    for (final (i, (tip, module)) in armada.vortexTips().indexed) {
      final p = Offset(b.x, b.y) + armada.bent(tip.dx, tip.dy, module: module);
      if (p.dx < tl.dx - 20 || p.dx > br.dx + 20 || p.dy > shipBand) continue;
      final len = 120 + 80 * ((i * .37) % 1);
      final path = ui.Path();
      const n = 8;
      final left = <Offset>[], right = <Offset>[];
      for (var j = 0; j <= n; j++) {
        final u = j / n;
        final sway = 4 * math.sin(_trailClock * 3 + i + u * 4) * u;
        final q = p + Offset(sway, len * u);
        final w = 3 - 2 * u;
        left.add(q - Offset(w / 2, 0));
        right.add(q + Offset(w / 2, 0));
      }
      path.moveTo(left.first.dx, left.first.dy);
      for (final q in left.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      for (final q in right.reversed) {
        path.lineTo(q.dx, q.dy);
      }
      path.close();
      _p.shader = ui.Gradient.linear(p, p + Offset(0, len), [
        _trailTint.withValues(alpha: .25 * k),
        _trailTint.withValues(alpha: 0),
      ]);
      c.drawPath(path, _p);
      _p.shader = null;
    }
    c.restore();
  }
}

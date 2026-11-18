// --- mission-medals: Supply Run's in-level cues (specs/bonus-supply-run-
// clarity). Drawn on the objects themselves, never as text over the play
// area:
// - a crate wears pulsing target brackets until its first hit, then
//   cracks: one per hit taken, so "three hits" reads as progress;
// - falling cargo throws a landing marker on the ship row under it
//   ("be here to catch it");
// - a crate shot open bursts in a ring; cargo caught flashes at the ship;
// - the salvage magnet shows its reach and pulls with visible beams;
//   double score rings the ship with two gold coins;
// - the corner tally: one gold pip per crate opened.
// Reduced motion: no pulses, no orbit; the marks stay, steady.
import 'dart:math' as math;
import 'dart:ui';

import '../../model.dart';
import '../../reduced_effects.dart'; // --- reduced-effects
import '../bonus_painters.dart';

class SupplyRunPainter extends BonusPainter {
  const SupplyRunPainter();

  static const gold = Color(0xFFFFD27A);
  static const mint = Color(0xFF70F5D5);
  static const crack = Color(0xFF0B1420);

  @override
  void over(Canvas canvas, ArcadeModel model, double time) {
    final cues = model.bonusMechanic;
    if (cues is! SupplyRunCues) return;
    final reduced = ReducedEffects.calm(model.reducedMotion); // reduced-effects
    final pulse = reduced ? .7 : .5 + .5 * math.sin(time * 7);
    for (final crate in model.supplyCrates) {
      _crate(canvas, crate, pulse);
    }
    if (model.combat || model.mode == RunMode.salvage) {
      for (final p in model.pickups) {
        _landing(canvas, model, p, pulse);
      }
    }
    _magnet(canvas, model, time, reduced);
    _double(canvas, model, time, reduced);
    for (final c in cues.pops) {
      _ring(canvas, c, c.bonus ? _tint(salvageMagnet.tint) : gold, 30);
    }
    for (final c in cues.catches) {
      _ring(canvas, c, c.bonus ? gold : mint, 24);
    }
    _tally(canvas, cues, reduced);
  }

  static Color _tint(int argb) => Color(argb);

  /// Target brackets before the first hit; a crack per hit after it.
  void _crate(Canvas canvas, SupplyCrate crate, double pulse) {
    final r = Rect.fromCenter(
      center: Offset(crate.x, crate.y),
      width: 22,
      height: 20,
    );
    final taken = crate.maxHp - crate.hp;
    if (taken <= 0) {
      final grow = 5 + 3 * pulse;
      final box = r.inflate(grow);
      final paint = Paint()
        ..color = gold.withValues(alpha: .55 + .4 * pulse)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const arm = 5.0;
      for (final (corner, dx, dy) in [
        (box.topLeft, 1.0, 1.0),
        (box.topRight, -1.0, 1.0),
        (box.bottomLeft, 1.0, -1.0),
        (box.bottomRight, -1.0, -1.0),
      ]) {
        canvas.drawLine(corner, corner + Offset(arm * dx, 0), paint);
        canvas.drawLine(corner, corner + Offset(0, arm * dy), paint);
      }
      return;
    }
    final paint = Paint()
      ..color = crack
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final lit = Paint()
      ..color = gold.withValues(alpha: .9)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;
    // Fixed crack shapes: the first from the top-left, the second from
    // the bottom-right, the third splits the lid.
    const cracks = [
      [Offset(-11, -6), Offset(-4, -1), Offset(-6, 4), Offset(1, 9)],
      [Offset(11, 5), Offset(4, 1), Offset(6, -4), Offset(1, -9)],
      [Offset(-11, -1), Offset(11, -1)],
    ];
    for (var i = 0; i < math.min(taken, cracks.length); i++) {
      final path = Path();
      final pts = cracks[i];
      path.moveTo(crate.x + pts.first.dx, crate.y + pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(crate.x + p.dx, crate.y + p.dy);
      }
      canvas.drawPath(path, paint);
      // The light inside shows through the crack.
      canvas.drawPath(path.shift(const Offset(.6, .6)), lit);
    }
  }

  /// Falling cargo: a dotted drop line and a marker on the ship row.
  void _landing(Canvas canvas, ArcadeModel model, Pickup p, double pulse) {
    final row = ArcadeModel.shipY;
    if (p.y > row - 12) return;
    final color = p.bonus != null ? Color(p.bonus!.tint) : mint;
    final dots = Paint()..color = color.withValues(alpha: .35);
    for (var y = p.y + 22; y < row - 10; y += 10) {
      canvas.drawCircle(Offset(p.x, y), 1.1, dots);
    }
    final w = 16 + 4 * pulse;
    final marker = Paint()
      ..color = color.withValues(alpha: .5 + .35 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.x, row + 14), width: w, height: w * .35),
      marker,
    );
    // A small chevron above the marker: "catch here".
    final c = Path()
      ..moveTo(p.x - 5, row - 6)
      ..lineTo(p.x, row - 1)
      ..lineTo(p.x + 5, row - 6);
    canvas.drawPath(c, marker);
  }

  void _magnet(Canvas canvas, ArcadeModel model, double time, bool reduced) {
    if (!model.hasBonusPower(salvageMagnet.id) || model.shipAway) return;
    final tint = Color(salvageMagnet.tint);
    final ship = Offset(model.shipX, ArcadeModel.shipY);
    final reach = salvageMagnet.magnet;
    // The reach: a dashed arc over the ship (the pull's edge).
    final edge = Paint()
      ..color = tint.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dashes = 28;
    final turn = reduced ? 0.0 : time * .6;
    for (var i = 0; i < dashes; i++) {
      final a = math.pi + (i + turn % 1) * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: ship, radius: reach),
        a,
        math.pi / dashes * .5,
        false,
        edge,
      );
    }
    final beam = Paint()
      ..color = tint.withValues(alpha: .7)
      ..strokeWidth = 1.4;
    for (final p in [
      for (final p in model.pickups) Offset(p.x, p.y),
      for (final h in model.heartPickups) Offset(h.x, h.y),
    ]) {
      final d = (p - ship).distance;
      if (d > reach || d < 8) continue;
      // Three beads run along the pull toward the ship.
      for (var k = 0; k < 3; k++) {
        final f = reduced ? (k + 1) / 4 : ((time * 2.4 + k / 3) % 1);
        canvas.drawCircle(Offset.lerp(p, ship, f)!, 1.6, beam);
      }
    }
  }

  void _double(Canvas canvas, ArcadeModel model, double time, bool reduced) {
    if (!model.hasBonusPower(doubleScore.id) || model.shipAway) return;
    final ship = Offset(model.shipX, model.shipDrawY);
    final coin = Paint()..color = gold;
    final rim = Paint()
      ..color = const Color(0xFF8A5A12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 0; k < 2; k++) {
      final a = (reduced ? 0 : time * 3) + k * math.pi;
      final at = ship + Offset(math.cos(a) * 20, math.sin(a) * 7 - 4);
      canvas.drawCircle(at, 3.2, coin);
      canvas.drawCircle(at, 3.2, rim);
    }
  }

  void _ring(Canvas canvas, SupplyCue c, Color color, double size) {
    final k = (c.age / SupplyRunCues.life).clamp(0.0, 1.0);
    final fade = 1 - k;
    canvas.drawCircle(
      Offset(c.x, c.y),
      6 + size * k,
      Paint()
        ..color = color.withValues(alpha: .85 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * fade + .5,
    );
    if (k < .35) {
      canvas.drawCircle(
        Offset(c.x, c.y),
        8 * (1 - k / .35),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .7 * fade),
      );
    }
  }

  /// One gold pip per crate opened, beside a small crate, top left.
  void _tally(Canvas canvas, SupplyRunCues cues, bool reduced) {
    const x0 = 10.0, y0 = 10.0;
    final pop = reduced ? 0.0 : (1 - cues.tallyAge / .4).clamp(0.0, 1.0);
    final box = Rect.fromLTWH(x0, y0, 12, 10);
    canvas.drawRect(box, Paint()..color = const Color(0xCC23364A));
    canvas.drawRect(
      box,
      Paint()
        ..color = gold.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(x0, y0 + 4),
      Offset(x0 + 12, y0 + 4),
      Paint()
        ..color = gold.withValues(alpha: .8)
        ..strokeWidth = 1,
    );
    final pip = Paint()..color = gold;
    for (var i = 0; i < cues.opened; i++) {
      final row = i ~/ 10, col = i % 10;
      final last = i == cues.opened - 1;
      final s = 4.0 + (last ? 2 * pop : 0);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x0 + 20 + col * 7.0, y0 + 5 + row * 7.0),
          width: s,
          height: s,
        ),
        pip,
      );
    }
  }
}

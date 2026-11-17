// --- bonus challenges: the challenge badge (openspec/changes/
// bonus-challenges, design §3)
//
// A medal-style disc (the mission medals' gold rim over the brood
// insignia's dark socket) holding the condition's pictogram, beside an
// arcade "1UP" plate. One painter, three states:
// - live: a steady gold rim, a cream pictogram, a mint 1UP plate that
//   breathes slowly;
// - failed: a grey rim, a dimmed pictogram, a red slash across the disc
//   and a struck-through plate; at the flip a short shake and red flash;
// - earned: the gold plate and a burst of rays, a ring and sparks for
//   [ChallengeBadgePainter.burst] seconds.
// Reduced motion keeps the states and drops the shake, the breath and the
// burst's motion (a steady glow instead).
//
// Drawn with painters, not the mission-medal atlas: the badge is 14-30 px
// tall, changes state mid-level and animates; vector strokes stay crisp at
// that size and cost no art in `.git` (design §3).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'bonus_challenge.dart';

/// Draws one pictogram into [box] in [ink].
typedef ChallengeIconPainter = void Function(
  Canvas canvas,
  Rect box,
  Color ink,
);

/// The pictograms, by `BonusChallengeDef.icon`. A new level adds one
/// entry (and a function in the style of the ones below).
abstract final class ChallengeIcons {
  static const Map<String, ChallengeIconPainter> byId = {
    'cargo': paintCargo,
    'bolt': paintBolt,
    'star': paintStar,
  };

  static ChallengeIconPainter of(String id) => byId[id] ?? paintStar;

  /// A parachute crate: the canopy, two lines, the box with its band.
  static void paintCargo(Canvas canvas, Rect b, Color ink) {
    final w = b.width, h = b.height;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * .08)
      ..strokeCap = StrokeCap.round;
    final canopy = Path()
      ..moveTo(b.left + w * .12, b.top + h * .38)
      ..quadraticBezierTo(
        b.center.dx,
        b.top - h * .12,
        b.right - w * .12,
        b.top + h * .38,
      )
      ..close();
    canvas.drawPath(canopy, Paint()..color = ink);
    canvas.drawLine(
      Offset(b.left + w * .16, b.top + h * .38),
      Offset(b.left + w * .36, b.top + h * .6),
      stroke,
    );
    canvas.drawLine(
      Offset(b.right - w * .16, b.top + h * .38),
      Offset(b.right - w * .36, b.top + h * .6),
      stroke,
    );
    final box = Rect.fromLTRB(
      b.left + w * .3,
      b.top + h * .58,
      b.right - w * .3,
      b.bottom - h * .04,
    );
    canvas.drawRect(box, Paint()..color = ink);
    canvas.drawLine(
      Offset(box.left, box.center.dy),
      Offset(box.right, box.center.dy),
      Paint()
        ..color = const Color(0xFF101827)
        ..strokeWidth = math.max(1, w * .07),
    );
  }

  /// The storm's bolt, as the Stormfront tell draws it: a three-segment
  /// zigzag.
  static void paintBolt(Canvas canvas, Rect b, Color ink) {
    final w = b.width, h = b.height;
    Offset p(double x, double y) => Offset(b.left + w * x, b.top + h * y);
    final bolt = Path()
      ..moveTo(p(.62, 0).dx, p(.62, 0).dy)
      ..lineTo(p(.24, .56).dx, p(.24, .56).dy)
      ..lineTo(p(.5, .56).dx, p(.5, .56).dy)
      ..lineTo(p(.36, 1).dx, p(.36, 1).dy)
      ..lineTo(p(.8, .4).dx, p(.8, .4).dy)
      ..lineTo(p(.54, .4).dx, p(.54, .4).dy)
      ..lineTo(p(.72, 0).dx, p(.72, 0).dy)
      ..close();
    canvas.drawPath(bolt, Paint()..color = ink);
  }

  /// The arcade star (any condition without its own pictogram).
  static void paintStar(Canvas canvas, Rect b, Color ink) {
    final c = b.center;
    final r = b.shortestSide / 2;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final k = i.isEven ? r : r * .45;
      final pt = c + Offset(math.cos(a) * k, math.sin(a) * k);
      i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = ink);
  }
}

/// The badge: a disc with the pictogram and the "1UP" plate to its right.
/// Its width is [aspect] × its height.
class ChallengeBadgePainter extends CustomPainter {
  const ChallengeBadgePainter({
    required this.icon,
    required this.status,
    this.age,
    this.time = 0,
    this.reduced = false,
  });

  final String icon;
  final ChallengeStatus status;

  /// Seconds since the status last changed (null: never, a live badge).
  final double? age;

  /// A free-running clock (the live plate's slow breath).
  final double time;
  final bool reduced;

  /// Width over height.
  static const aspect = 2.15;

  /// Seconds the failure's shake and flash and the earned burst last.
  static const flip = .45, burst = 1.4;

  static const gold = Color(0xFFF4CA79), cream = Color(0xFFFFF4DC);
  static const mint = Color(0xFF70F5D5), red = Color(0xFFFF5A4E);
  static const socket = Color(0xFF101827), grey = Color(0xFF6E7C8C);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final failed = status == ChallengeStatus.failed;
    final earned = status == ChallengeStatus.earned;
    final t = age ?? 99;
    // The failure's shake: a few pixels, side to side, decaying.
    var shake = 0.0;
    if (failed && !reduced && t < flip) {
      shake = math.sin(t * 60) * h * .08 * (1 - t / flip);
    }
    canvas.save();
    canvas.translate(shake, 0);
    final r = h / 2;
    final disc = Offset(r, r);
    final rim = failed ? grey : gold;
    if (earned) _burst(canvas, disc, r, t);
    // The medal: rim, socket, pictogram.
    canvas.drawCircle(disc, r, Paint()..color = rim);
    canvas.drawCircle(disc, r * .8, Paint()..color = socket);
    final ink = failed ? grey.withValues(alpha: .8) : cream;
    ChallengeIcons.of(icon)(
      canvas,
      Rect.fromCircle(center: disc, radius: r * .5),
      ink,
    );
    // The plate: an arcade 1UP tag.
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTWH(h * .92, h * .18, size.width - h * .92, h * .64),
      Radius.circular(h * .14),
    );
    final breath = reduced || status != ChallengeStatus.live
        ? 1.0
        : .78 + .22 * (.5 + .5 * math.sin(time * math.pi * .9));
    final plateInk = failed ? grey : (earned ? gold : mint);
    canvas.drawRRect(plate, Paint()..color = socket);
    canvas.drawRRect(
      plate,
      Paint()
        ..color = plateInk.withValues(alpha: breath)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, h * .07),
    );
    final text = TextPainter(
      text: TextSpan(
        text: '1UP',
        style: TextStyle(
          color: plateInk.withValues(alpha: breath),
          fontSize: h * .46,
          fontWeight: FontWeight.w900,
          letterSpacing: h * .02,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, plate.center - Offset(text.width / 2, text.height / 2));
    text.dispose();
    if (failed) {
      final slash = Paint()
        ..color = red
        ..strokeWidth = math.max(1.2, h * .11)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        disc + Offset(-r * .62, r * .62),
        disc + Offset(r * .62, -r * .62),
        slash,
      );
      canvas.drawLine(
        Offset(plate.left + h * .1, plate.center.dy),
        Offset(plate.right - h * .1, plate.center.dy),
        slash..strokeWidth = math.max(1, h * .07),
      );
      // The flip's flash.
      if (t < flip) {
        final a = reduced ? .35 : .55 * (1 - t / flip);
        canvas.drawCircle(disc, r, Paint()..color = red.withValues(alpha: a));
      }
    }
    canvas.restore();
  }

  /// Rays, a ring and sparks around the disc, for [burst] seconds; with
  /// reduced motion a steady gold halo.
  void _burst(Canvas canvas, Offset c, double r, double t) {
    if (reduced) {
      canvas.drawCircle(
        c,
        r * 1.15,
        Paint()..color = gold.withValues(alpha: .35),
      );
      return;
    }
    if (t >= burst) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()..color = gold.withValues(alpha: .22),
      );
      return;
    }
    final k = t / burst;
    final fade = 1 - k;
    final rays = Paint()
      ..color = gold.withValues(alpha: .9 * fade)
      ..strokeWidth = math.max(1, r * .14)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + k * .6;
      final from = r * (1.05 + .4 * k), to = r * (1.35 + 1.1 * k);
      canvas.drawLine(
        c + Offset(math.cos(a) * from, math.sin(a) * from),
        c + Offset(math.cos(a) * to, math.sin(a) * to),
        rays,
      );
    }
    canvas.drawCircle(
      c,
      r * (1 + 1.6 * k),
      Paint()
        ..color = cream.withValues(alpha: .7 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * .12),
    );
    final spark = Paint()..color = mint.withValues(alpha: fade);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + .4;
      final d = r * (1.2 + 1.8 * k);
      canvas.drawCircle(
        c + Offset(math.cos(a) * d, math.sin(a) * d),
        r * .1,
        spark,
      );
    }
  }

  @override
  bool shouldRepaint(ChallengeBadgePainter old) =>
      icon != old.icon ||
      status != old.status ||
      age != old.age ||
      time != old.time ||
      reduced != old.reduced;
}

/// The badge as a widget: the HUD's pip beside the lives, or the briefing
/// card's badge (with [label], the condition in words).
class ChallengeBadge extends StatelessWidget {
  const ChallengeBadge({
    super.key,
    required this.challenge,
    this.status = ChallengeStatus.live,
    this.age,
    this.time = 0,
    this.height = 18,
    this.label = false,
  });

  final BonusChallengeDef challenge;
  final ChallengeStatus status;
  final double? age, time;
  final double height;

  /// Show the condition's words after the badge (the briefing card).
  final bool label;

  /// What a screen reader hears.
  static String describe(
    BonusChallengeDef def, [
    ChallengeStatus status = ChallengeStatus.live,
  ]) {
    final words = def.label.toLowerCase();
    return switch (status) {
      ChallengeStatus.live => 'Challenge: $words for 1UP',
      ChallengeStatus.failed => 'Challenge failed: $words',
      ChallengeStatus.earned => 'Challenge earned: $words, 1UP',
    };
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final badge = CustomPaint(
      size: Size(height * ChallengeBadgePainter.aspect, height),
      painter: ChallengeBadgePainter(
        icon: challenge.icon,
        status: status,
        age: age,
        time: time ?? 0,
        reduced: reduced,
      ),
    );
    return Semantics(
      label: describe(challenge, status),
      image: true,
      excludeSemantics: true,
      child: !label
          ? badge
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                badge,
                SizedBox(width: height * .3),
                Flexible(
                  child: Text(
                    challenge.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: status == ChallengeStatus.failed
                          ? ChallengeBadgePainter.grey
                          : ChallengeBadgePainter.gold,
                      fontSize: height * .5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

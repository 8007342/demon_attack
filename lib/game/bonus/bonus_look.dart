// --- bonus levels: the look (openspec/changes/bonus-levels design §7)
//
// Presentation only. A bonus level keeps the replaced sector's backdrop and
// grades it: a colour wash, a light at the horizon and a little haze. The
// grade follows `model.bonus`, which only changes when a level begins: at
// the Descent's first frame, inside the cloud (cover ≥ 85 %), so the change
// is never seen. It is a plain crossfade, the same with reduced motion.
import 'dart:math' as math;
import 'dart:ui';

import '../model.dart';

class BonusLookLayer {
  BonusLook? _look;

  /// 0: the sector as it is; 1: the full grade.
  double amount = 0;

  /// Seconds of crossfade.
  static const fade = .35;

  void advance(ArcadeModel model, double dt) {
    final want = model.mode == RunMode.title ? null : model.bonus?.look;
    if (want != null) _look = want;
    final target = want == null ? 0.0 : 1.0;
    final step = dt / fade;
    amount = target > amount
        ? math.min(target, amount + step)
        : math.max(target, amount - step);
    if (amount <= 0 && want == null) _look = null;
  }

  /// Over the backdrop, under the ground units, creatures, ship and shots.
  void paint(Canvas c) {
    final look = _look;
    if (look == null || amount <= 0) return;
    const all = Rect.fromLTRB(-200, -200, 560, 900);
    final wash = Color(look.tint);
    final a = (look.strength * amount).clamp(0.0, 1.0);
    if (a > 0) {
      c.drawRect(
        all,
        Paint()
          ..blendMode = BlendMode.softLight
          ..color = wash.withValues(alpha: math.min(1, a * 2.2)),
      );
      c.drawRect(all, Paint()..color = wash.withValues(alpha: a * .25));
    }
    const h = Perspective.horizonY;
    final glow = Color(look.glow);
    if (glow.a > 0) {
      c.drawRect(
        const Rect.fromLTRB(-200, h - 120, 560, h + 80),
        Paint()
          ..shader = Gradient.linear(
            const Offset(0, h - 120),
            const Offset(0, h + 80),
            [
              glow.withValues(alpha: 0),
              glow.withValues(alpha: glow.a * amount),
              glow.withValues(alpha: 0),
            ],
            const [0, .58, 1],
          ),
      );
    }
    if (look.fog > 0) {
      c.drawRect(
        const Rect.fromLTRB(-200, h - 30, 560, h + 90),
        Paint()
          ..shader = Gradient.linear(
            const Offset(0, h - 30),
            const Offset(0, h + 90),
            [
              const Color(0x00FFFFFF),
              Color.fromRGBO(255, 255, 255, look.fog * amount),
              const Color(0x00FFFFFF),
            ],
            const [0, .35, 1],
          ),
      );
    }
  }
}

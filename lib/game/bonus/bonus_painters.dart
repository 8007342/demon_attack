// --- bonus levels: what a level's mechanic draws (added for bonus level
// #2, Stormfront)
//
// The scene's side of `bonus_mechanic.dart`. A mechanic is pure Dart; its
// painter lives here, keyed by the level id, so the model never imports
// `dart:ui`. A level with a mechanic that shows something adds one entry.
// The scene calls [BonusPainters.under] right after the level's grade
// (over the backdrop, under ground units, creatures, ship and shots) and
// [BonusPainters.over] after the combat pass (over creatures and ship,
// under the transition's cloud and the HUD).
import 'dart:ui';

import '../model.dart';
import 'levels/crosswind_painter.dart';
import 'levels/stormfront_painter.dart';
import 'levels/supply_run_painter.dart';

/// Draws one level's mechanic. [time] is the presentation clock.
abstract class BonusPainter {
  const BonusPainter();
  void under(Canvas canvas, ArcadeModel model, double time) {}
  void over(Canvas canvas, ArcadeModel model, double time) {}
}

abstract final class BonusPainters {
  static const Map<String, BonusPainter> byLevel = {
    'stormfront': StormfrontPainter(),
    // --- mission-medals: Supply Run's cues on the crates and the cargo.
    'supplyRun': SupplyRunPainter(),
    // --- crosswind: the kites and their tally.
    'crosswind': CrosswindPainter(),
  };

  static BonusPainter? _of(ArcadeModel model) =>
      model.bonusMechanic == null ? null : byLevel[model.bonus?.id];

  static void under(Canvas canvas, ArcadeModel model, double time) =>
      _of(model)?.under(canvas, model, time);

  static void over(Canvas canvas, ArcadeModel model, double time) =>
      _of(model)?.over(canvas, model, time);
}

class StormfrontPainter extends BonusPainter {
  const StormfrontPainter();
  static const _storm = StormPainter();

  @override
  void under(Canvas canvas, ArcadeModel model, double time) {
    final m = model.bonusMechanic;
    if (m is! StormfrontMechanic) return;
    _storm.paintSky(canvas, m.cell, time: time, reduced: model.reducedMotion);
  }

  @override
  void over(Canvas canvas, ArcadeModel model, double time) {
    final m = model.bonusMechanic;
    if (m is! StormfrontMechanic) return;
    final reduced = model.reducedMotion;
    _storm.paintStrikes(canvas, m.cell, time: time, reduced: reduced);
    final flash = StormPainter.flashOf(m.cell, reduced: reduced);
    if (flash > 0) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, ArcadeModel.width, ArcadeModel.height),
        Paint()..color = Color.fromRGBO(255, 255, 255, flash),
      );
    }
  }
}

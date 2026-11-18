// --- weather-everywhere: a regular sector's storm on screen, and the
// flash rules every storm keeps (openspec/changes/weather-everywhere
// design §3).
//
// The bolts, tells and glows are Stormfront's painter (`StormPainter`)
// with the fainter `StormLook.regular`; the model's `StormCell` decides
// where and when. Under the play: the glow in the cloud. Over the play:
// the tells, the bolts and the faint wash.
//
// Photosensitivity (dynamic-weather research S4, WCAG 2.3.1 "Three Flashes
// or Below Threshold"): a general flash is a pair of opposing changes of
// relative luminance of 10 % or more over a large area (a quarter of a
// 10° field). Every storm here:
// - flashes at most once per bolt, bolts at least 5 s apart on any
//   difficulty, so far fewer than three flashes in any second;
// - keeps every large-area change (the wash, the cloud glow) under a 10 %
//   relative-luminance step over ANY backdrop ([FlashSafety.washStep]);
// - keeps the bright bolt itself to a narrow column, a few percent of the
//   field;
// - with reduced flashing ([FlashSafety.reduced]: the system's reduced
//   motion, or `?flash=low` in the address) draws no wash, no cloud glow,
//   a steady leader and a steady marker: the tell and the bolt stay
//   readable, nothing pulses.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../bonus/levels/storm_cell.dart';
import '../bonus/levels/stormfront_painter.dart';
import '../model.dart';
import '../reduced_effects.dart'; // --- reduced-effects

/// The flash rules and the reduced-flashing setting.
abstract final class FlashSafety {
  /// WCAG 2.3.1: no more than three general flashes in any one second.
  static const maxFlashesPerSecond = 3;

  /// A general flash is a relative-luminance change of this much or more.
  static const flashStep = .10;

  /// Tests and the console: force reduced flashing on or off (null: the
  /// system setting and the address decide).
  static bool? override;

  /// `?flash=low` (or `off`, `0`, `reduced`) in the page address.
  static bool? _query;
  static bool get queryAsks {
    final q = _query ??= _readQuery();
    return q;
  }

  static bool _readQuery() {
    try {
      final v = Uri.base.queryParameters['flash']?.toLowerCase();
      return const {'low', 'off', '0', 'reduced', 'none'}.contains(v);
    } catch (_) {
      return false;
    }
  }

  /// Reduced flashing: forced, asked for in the address, or implied by the
  /// calm look (--- reduced-effects: the player's Reduced effects setting;
  /// Auto follows the system's reduced motion). `?flash=low` holds whatever
  /// the menu says.
  static bool reduced({required bool reducedMotion}) =>
      override ?? (ReducedEffects.calm(reducedMotion) || queryAsks);

  /// WCAG relative luminance of an sRGB channel value (0-1).
  static double linear(double c) =>
      c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();

  static double luminance(double r, double g, double b) =>
      .2126 * linear(r) + .7152 * linear(g) + .0722 * linear(b);

  /// The largest relative-luminance step that blending [color] at [alpha]
  /// over any grey backdrop (0-255) makes: the worst case of a wash or a
  /// glow. Must stay under [flashStep].
  static double washStep(Color color, double alpha) {
    var worst = 0.0;
    for (var i = 0; i <= 255; i++) {
      final b = i / 255;
      final r = b + (color.r - b) * alpha;
      final g = b + (color.g - b) * alpha;
      final bl = b + (color.b - b) * alpha;
      final step = luminance(r, g, bl) - luminance(b, b, b);
      worst = math.max(worst, step.abs());
    }
    return worst;
  }
}

/// A regular sector's storm on screen. Stateless: everything is read from
/// the model's `StormCell` and the presentation clock.
class StormLayer {
  static const _painter = StormPainter();

  /// The LITE tier drops the bolt's branches (phone-performance tiers).
  bool lite = false;

  /// Reduced motion (the system's) and reduced flashing.
  bool reducedMotion = false, reducedFlash = false;

  StormLook get look => lite ? StormLook.regular.lite() : StormLook.regular;

  StormCell? _cell(ArcadeModel model) =>
      model.bonusMechanic == null ? model.stormCell : null;

  /// Under the play, after the rain and the wind: the bolt's glow in the
  /// cloud (none with reduced motion or reduced flashing).
  void paintSky(Canvas canvas, ArcadeModel model) {
    final cell = _cell(model);
    if (cell == null || cell.strikes.isEmpty) return;
    _painter.paintSky(
      canvas,
      cell,
      time: model.visualClock,
      reduced: reducedMotion,
      look: look,
      noFlash: reducedFlash,
    );
  }

  /// Over the play: the tells, the bolts and the faint wash.
  void paintOver(Canvas canvas, ArcadeModel model) {
    final cell = _cell(model);
    if (cell == null || cell.strikes.isEmpty) return;
    final steady = reducedMotion || reducedFlash;
    _painter.paintStrikes(
      canvas,
      cell,
      time: model.visualClock,
      reduced: steady,
      look: look,
    );
    final wash = washOf(cell);
    if (wash > 0) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, ArcadeModel.width, ArcadeModel.height),
        Paint()..color = Color.fromRGBO(255, 255, 255, wash),
      );
    }
  }

  /// The whole-screen wash now (0 with reduced flashing or motion).
  double washOf(StormCell cell) => StormPainter.flashOf(
    cell,
    reduced: reducedMotion || reducedFlash,
    look: look,
  );
}

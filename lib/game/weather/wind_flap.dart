// --- weather-everywhere: the brood fighting the wind on screen
// (openspec/changes/weather-everywhere design §5).
//
// Presentation only: reads the model, never writes it. A creature holding
// its place in a crosswind (not telling a dive, not diving, not firing,
// not stunned) swaps its flight frames for the wind-flap set
// (`assets/images/wind-flap.png`, tools/generate_wind_flap.py): the upwind
// wing beats deeper and reaches higher, the downwind wing beats shallow
// and swept back, the body leans into the wind and the tail streams
// downwind. It beats faster than in still air (18 frames a second against
// 16). Divers use their dive frames; a smart diver riding a tailwind is
// already gliding on it.
//
// The wind-flap cells are addressed as *virtual rows* of the combat atlas,
// from [WindFlap.rowBase] on, so the scene's sprite, rim, glow, elite
// overlay and insignia passes take them unchanged.
library;

import 'dart:ui' show Offset;

import '../model.dart';
import '../sprite_atlas.dart';
import '../wind_flap_atlas.dart';

abstract final class WindFlap {
  /// Virtual combat-atlas row of the wind-flap atlas's row 0 (combat.png
  /// has 40 rows).
  static const rowBase = 64;

  /// Lateral wind strength (share of full) at which a creature starts
  /// fighting it, ± [stagger] by creature so a swarm does not switch all at
  /// once.
  static const threshold = .3, stagger = .06;

  /// Flap frames per second while fighting the wind (16 in still air).
  static const beat = 18.0;

  static bool isWind(int row) => row >= rowBase;

  /// 0 for a wind blowing to the left, 1 to the right.
  static int sideOf(double lateral) => lateral < 0 ? 0 : 1;

  /// Whether [d] is fighting a wind of signed strength [lateral].
  static bool fighting(Demon d, double lateral) {
    if (d.telegraph > 0 || d.dive > 0 || d.stunned || d.isLarge) return false;
    final h = ((d.seed * 7919).floor() & 0xff) / 255;
    return lateral.abs() >= threshold + stagger * (2 * h - 1);
  }

  /// [base] (from `CombatAtlas.creature`), or its wind-flap counterpart
  /// when [d] is flying in place in a wind of [lateral] (a flight or
  /// flight-flash cell only: fire and dive cells win).
  static CreatureCell cell(
    Demon d,
    CreatureCell base,
    double clock, {
    required double lateral,
  }) {
    final b = CombatAtlas.base(d.kind);
    final r = base.row - b;
    if (r < 0 || r > 6 || !fighting(d, lateral)) return base;
    final k = d.kind.clamp(0, 3);
    final side = sideOf(lateral);
    final f = (clock * beat + d.seed * 2).floor() % WindFlapAtlas.frames;
    final level = (4 - d.hp).clamp(0, 3);
    return (
      row: rowBase + k * WindFlapAtlas.speciesRows + CombatAtlas.variant(d),
      col: side * WindFlapAtlas.frames + f,
      tintFlash: d.flash > 0,
      eliteRow: rowBase + WindFlapAtlas.eliteRow + k,
      eliteCol: side * 4 + level,
      lift: WindFlapAtlas.lift[f],
    );
  }

  static final List<List<int>> _anchors = [
    for (final row in WindFlapAtlas.headAnchors)
      [
        for (final v in row.split(','))
          if (v.isNotEmpty) int.parse(v),
      ],
  ];

  /// The skull top of a wind-flap cell (virtual [row], [col]), art px from
  /// the cell centre.
  static Offset headAnchor(int row, int col) {
    final r = row - rowBase;
    final k = (r ~/ WindFlapAtlas.speciesRows).clamp(0, 3);
    final a = _anchors[k];
    final i = (col.clamp(0, 2 * WindFlapAtlas.frames - 1)) * 2;
    return Offset(a[i].toDouble(), a[i + 1].toDouble());
  }
}

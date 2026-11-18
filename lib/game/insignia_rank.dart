// insignia-ranks (openspec/changes/insignia-ranks; docs/styleguide/
// alien-troops.md §4): which mark a creature wears above its head. Pure
// Dart (it imports only the model), so tools/insignia_share.dart can count
// the marks headless.
import 'model.dart';

/// The marks of the insignia ladder, lowest first. The behaviour ranks
/// (drone .. sentinel, `lightningRank`, `ArcadeModel.tierOf`) are
/// unchanged; the mark is rarer than the rank, so most of a wave wears
/// nothing and a mark always means a creature above the grunts.
enum RankMark {
  /// Grunts: drones and the ordinary skirmishers and veterans.
  none,

  /// Elite grunt of the brood: a simple pair of bone wings, no fang, no
  /// ember (the elites' wings, simplified).
  winglet,

  /// Elite grunt of a sentinel's escort, and the spear-bearers: a small
  /// bone crown of three points, no fang, no ember (the sentinel's crown,
  /// simplified). Same notch as the winglet; the crown says "guard".
  crownlet,

  /// Hunters (elites): "Fang and Wings!", the brood's battle emblem, a
  /// fang hanging between bat wings, ember core.
  fangWings,

  /// Sentinels: the winged crown, three fangs rising between wide wings,
  /// ember core.
  wingCrown,
}

abstract final class InsigniaRanks {
  /// One grunt of the tough species in [eliteGruntOneIn] is an elite grunt
  /// (design §3: the measured shares in plan/render-runs/insignia-ranks.md).
  static const int eliteGruntOneIn = 5;

  /// The Weyl step of the roll: a roster's seeds step by 1.7 (model.dart
  /// `_buildRoster`), and 1.7 x this is the golden ratio's fraction, so a
  /// roster's rolls fall evenly over 0-1 and its elite grunts come evenly
  /// spaced instead of in random clumps (design §3).
  static const double weyl = .6180339887 / 1.7;

  /// The creature's fixed roll (0-1) for the elite-grunt pick, from its
  /// seed only: the same creature always wears the same mark.
  static double roll(Demon d) {
    final v = d.seed * weyl;
    return v - v.floorToDouble();
  }

  /// An elite grunt: an ordinary creature of the tough species (kind 2-3,
  /// so always skirmisher-tier: the skirmisher's brain and an extra hit
  /// over its tour's weakest grunt) picked one in [eliteGruntOneIn] by its
  /// seed. Species, not hit points, so a late tour (where every grunt has
  /// 3+ hit points) is not marked wholesale. Drones never are.
  static bool eliteGrunt(Demon d) =>
      !d.isLarge && !d.elite && d.kind >= 2 && roll(d) < 1 / eliteGruntOneIn;

  /// The mark [d] wears. A pure read of existing fields: damage, anger and
  /// position never change it.
  ///
  /// spear-bearers (the parallel change): when they add their archetype,
  /// map it to [RankMark.crownlet] here, before the `isLarge` line (their
  /// archetype would otherwise read as a sentinel).
  static RankMark markOf(Demon d) {
    if (d.isLarge) return RankMark.wingCrown;
    if (d.elite) return RankMark.fangWings;
    if (eliteGrunt(d)) {
      return d.isEscort ? RankMark.crownlet : RankMark.winglet;
    }
    return RankMark.none;
  }

  /// Whether [mark] carries a fang (the higher ranks only).
  static bool hasFang(RankMark mark) =>
      mark == RankMark.fangWings || mark == RankMark.wingCrown;
}

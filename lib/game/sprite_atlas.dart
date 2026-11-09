import 'model.dart';

/// Cell coordinates of `assets/images/combat.png`, the 64x64-logical-grid
/// combat atlas (stored 1x). The authoritative contract is
/// plan/sprite-atlas.md; tools/generate_sprites.py writes the image.
abstract final class CombatAtlas {
  static const double cell = 64;
  static const int speciesRows = 7;
  static const int strokeFrames = 8;

  /// One full wing stroke lasts 0.5 s (the old four-frame cadence), so each
  /// of the eight poses holds 1/16 s.
  static const double strokeFps = 16;

  static int base(int kind) => kind.clamp(0, 3) * speciesRows;
  static const int explosionRow = 28;
  static const int effectRow = 29;
  static const int pickupRow = 30;
  static const int fallbackRow = 31;

  // Columns inside a species' action row (base + 4).
  static const int anticipationCol = 0, diveCol = 4, fireCol = 8;
  static const int angryFireCol = 12;
  // Columns inside a species' flash/death row (base + 5).
  static const int deathCol = 8;
  // Columns inside a species' elite row (base + 6).
  static const int eliteArmorCol = 8;

  // Effect row columns.
  static const int sparkCol = 0, impactCol = 4, enemyMuzzleCol = 8;
  static const int mintSparkCol = 12;

  /// Pickup badge column for each power (row [pickupRow]); 3 is the heart.
  static int badge(Power power) => switch (power) {
    Power.spread => 0,
    Power.rapid => 1,
    Power.shield => 2,
    Power.powerful => 4,
    Power.large => 5,
  };

  /// The cell for an ordinary creature this frame. Presentation only: it
  /// reads simulation state and never changes it.
  static ({int row, int col, bool tintFlash}) creature(
    Demon d,
    double clock, {
    double? fireAge,
  }) {
    final b = base(d.kind);
    final seed = d.seed;
    if (d.telegraph > 0) {
      // Anticipation: wings cocked high, eyes flaring, a short hunch.
      return (
        row: b + 4,
        col: anticipationCol + ((clock * 12 + seed).floor() % 4),
        tintFlash: d.flash > 0,
      );
    }
    if (d.dive > 0) {
      return (
        row: b + 4,
        col: diveCol + ((clock * 12 + seed).floor() % 4),
        tintFlash: d.flash > 0,
      );
    }
    if (fireAge != null && fireAge < firePoseSeconds) {
      final f = (fireAge / firePoseSeconds * 4).floor().clamp(0, 3);
      return (
        row: b + 4,
        col: (d.angry ? angryFireCol : fireCol) + f,
        tintFlash: d.flash > 0,
      );
    }
    final f = ((clock * strokeFps + seed * 2).floor() % strokeFrames);
    if (d.angry) return (row: b, col: 8 + f, tintFlash: d.flash > 0);
    final molt = (d.maxHp - d.hp).clamp(0, 3);
    if (molt > 0) {
      return (row: b + molt, col: f + (d.flash > 0 ? 8 : 0), tintFlash: false);
    }
    return (row: d.flash > 0 ? b + 5 : b, col: f, tintFlash: false);
  }

  static const double firePoseSeconds = 0.28;
  static const double deathSeconds = 0.56;
}

/// A creature's authored death sequence, spawned by the scene when an
/// ordinary demon leaves the simulation destroyed.
class DeathFx {
  DeathFx(this.kind, this.x, this.y, this.bank);
  final int kind;
  final double x, y, bank;
  double age = 0;
  int get frame =>
      (age / CombatAtlas.deathSeconds * 8).floor().clamp(0, 7);
}

/// Scene-side bookkeeping for presentation that the simulation does not
/// record: which creature just fired (to play its weapon-mount frames) and
/// which just died (to play its species death sequence). Reads the model;
/// never writes it, so gameplay is unchanged.
class CreaturePresentation {
  final _fireAge = Expando<double>('fireAge');
  final _seenShot = Expando<bool>('seenShot');
  final _suppressedBlast = Expando<bool>('suppressedBlast');
  final List<DeathFx> deaths = [];
  List<Demon> _previous = const [];

  double? fireAge(Demon d) => _fireAge[d];
  bool suppressed(Blast b) => _suppressedBlast[b] ?? false;

  void update(ArcadeModel model, double dt) {
    final live = dt > 0 && model.mode != RunMode.paused;
    if (live) {
      for (final d in model.demons) {
        final age = _fireAge[d];
        if (age != null) _fireAge[d] = age + dt;
      }
      for (final fx in deaths) {
        fx.age += dt;
      }
      deaths.removeWhere((fx) => fx.age >= CombatAtlas.deathSeconds);
    }
    for (final s in model.shots) {
      if (!s.hostile || (_seenShot[s] ?? false)) continue;
      _seenShot[s] = true;
      final fromSentinel = s.kind == ShotKind.sentinel;
      final muzzleDy = fromSentinel ? 14.0 : 12.0;
      for (final d in model.demons) {
        if (d.isLarge != fromSentinel) continue;
        if ((d.x - s.x).abs() < 6 && (s.y - (d.y + muzzleDy)).abs() < 10) {
          _fireAge[d] = 0;
          break;
        }
      }
    }
    final current = model.demons.toSet();
    for (final d in _previous) {
      if (current.contains(d) || d.hp > 0 || d.isLarge) continue;
      deaths.add(DeathFx(d.kind, d.x, d.y, d.bank));
      for (final b in model.blasts) {
        if (b.age < 0.12 && (b.x - d.x).abs() < 1 && (b.y - d.y).abs() < 1) {
          _suppressedBlast[b] = true;
        }
      }
    }
    _previous = List.of(model.demons);
  }
}

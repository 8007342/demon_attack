import 'creature_motion.dart';
import 'model.dart';

/// One creature draw: the atlas cell, whether to tint it white (action
/// frames without an authored flash), and the elite armour overlay cell with
/// the body lift (logical px) it must be offset by to stay on the body.
typedef CreatureCell = ({
  int row,
  int col,
  bool tintFlash,
  int eliteRow,
  int eliteCol,
  int lift,
});

/// Cell coordinates of `assets/images/combat.png`, the 64x64-logical-grid
/// gargoyle combat atlas (stored 1x, 32 columns). The authoritative contract
/// is plan/sprite-atlas.md; tools/generate_sprites.py writes the image.
abstract final class CombatAtlas {
  static const double cell = 64;
  static const int columns = 32;
  static const int speciesRows = 9;

  /// Flight set per direction: 8 flap poses (0-3 downstroke, 4-7 upstroke)
  /// and 2 glide poses (8-9). Directions left, neutral, right occupy
  /// columns 0-9, 10-19, 20-29 of each damage-variant row.
  static const int flightFrames = 10;
  static const int flapFrames = 8;

  /// Whole-body lift (logical px, negative = up) of each flight frame, as
  /// authored in tools/generate_sprites.py (FLAP_LIFT + GLIDE_LIFT).
  static const List<int> flightLift = [0, -1, -2, -2, -1, 0, 1, 1, 0, 1];
  static const List<int> fireLift = [0, 0, -1, 0];
  static const List<int> anticipationLift = [0, 0, -1, -1];

  static int base(int kind) => kind.clamp(0, 3) * speciesRows;
  static const int explosionRow = 36;
  static const int effectRow = 37;
  static const int pickupRow = 38;
  static const int fallbackRow = 39;

  // Columns inside a species' action row (base + 7).
  static const int anticipationCol = 0, fireCol = 4, angryFireCol = 8;
  static const int deathCol = 12, diveCol = 20, diveFlashCol = 30;
  static int actionRow(int kind) => base(kind) + 7;
  static int deathRow(int kind) => actionRow(kind);

  // Elite overlay row (base + 8): direction * 4 + level, dive 12 + level.
  static int eliteRow(int kind) => base(kind) + 8;
  static const int eliteDiveCol = 12;

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

  /// Damage variant row offset: 0 intact, 1-3 molts, 4 angry.
  static int variant(Demon d) => d.angry ? 4 : (d.maxHp - d.hp).clamp(0, 3);

  /// Fallback motion when no tracker state exists (e.g. a single painted
  /// frame in a test): direction from the simulation's smoothed bank,
  /// stroke from the clock.
  static ({int dir, int frame}) _fallback(Demon d, double clock) {
    final dir = d.bank <= -0.45
        ? -1
        : d.bank >= 0.45
        ? 1
        : 0;
    final f = ((clock * 16 + d.seed * 2).floor() % flapFrames);
    return (dir: dir, frame: f);
  }

  /// The cell for an ordinary creature this frame. Presentation only: it
  /// reads simulation state and never changes it. Priority: dive warning
  /// (anticipation) > dive > weapon fire > flight (direction, stroke or
  /// glide) with damage variant and hit flash.
  static CreatureCell creature(
    Demon d,
    double clock, {
    double? fireAge,
    CreatureMotion? motion,
  }) {
    final b = base(d.kind);
    final seed = d.seed;
    final e = eliteRow(d.kind);
    final level = (4 - d.hp).clamp(0, 3);
    final neutralElite = 4 + level;
    if (d.telegraph > 0) {
      // Anticipation: wings cocked high, eyes flaring, the body rising.
      final f = (clock * 12 + seed).floor() % 4;
      return (
        row: b + 7,
        col: anticipationCol + f,
        tintFlash: d.flash > 0,
        eliteRow: e,
        eliteCol: neutralElite,
        lift: anticipationLift[f],
      );
    }
    if (d.dive > 0) {
      final f = (clock * 8 + seed).floor() % 2;
      final flash = d.flash > 0;
      return (
        row: b + 7,
        col: flash ? diveFlashCol + f : diveCol + variant(d) * 2 + f,
        tintFlash: false,
        eliteRow: e,
        eliteCol: eliteDiveCol + level,
        lift: 0,
      );
    }
    if (fireAge != null && fireAge < firePoseSeconds) {
      final f = (fireAge / firePoseSeconds * 4).floor().clamp(0, 3);
      return (
        row: b + 7,
        col: (d.angry ? angryFireCol : fireCol) + f,
        tintFlash: d.flash > 0,
        eliteRow: e,
        eliteCol: neutralElite,
        lift: d.angry ? 0 : fireLift[f],
      );
    }
    final fb = motion == null ? _fallback(d, clock) : null;
    final dir = motion?.dir ?? fb!.dir;
    final frame = motion?.frame ?? fb!.frame;
    final di = dir + 1;
    final v = variant(d);
    final elite = di * 4 + level;
    if (d.flash > 0) {
      final pose = frame < flapFrames ? frame ~/ 2 : 1;
      final slot = v * 12 + di * 4 + pose;
      return (
        row: b + 5 + slot ~/ columns,
        col: slot % columns,
        tintFlash: false,
        eliteRow: e,
        eliteCol: elite,
        lift: flightLift[pose * 2],
      );
    }
    return (
      row: b + v,
      col: di * flightFrames + frame,
      tintFlash: false,
      eliteRow: e,
      eliteCol: elite,
      lift: flightLift[frame],
    );
  }

  static const double firePoseSeconds = 0.28;
  static const double deathSeconds = 0.56;
}

/// A creature's authored death sequence, spawned by the scene when an
/// ordinary demon leaves the simulation destroyed.
class DeathFx {
  DeathFx(this.kind, this.x, this.y, this.bank, {this.scale = 1});
  final int kind;
  final double x, y, bank;

  /// The demon's perspective scale when it died (see Demon.scale).
  final double scale;
  double age = 0;
  int get frame => (age / CombatAtlas.deathSeconds * 8).floor().clamp(0, 7);
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
  final motion = CreatureMotionTracker();
  List<Demon> _previous = const [];

  double? fireAge(Demon d) => _fireAge[d];
  bool suppressed(Blast b) => _suppressedBlast[b] ?? false;

  void update(ArcadeModel model, double dt) {
    final live = dt > 0 && model.mode != RunMode.paused;
    if (live) {
      motion.update(model, dt);
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
      for (final d in model.demons) {
        if (d.isLarge != fromSentinel) continue;
        if ((d.x - s.x).abs() < 6 && (s.y - (d.y + d.muzzleDy)).abs() < 10) {
          _fireAge[d] = 0;
          break;
        }
      }
    }
    final current = model.demons.toSet();
    for (final d in _previous) {
      if (current.contains(d) || d.hp > 0 || d.isLarge) continue;
      deaths.add(DeathFx(d.kind, d.x, d.y, d.bank, scale: d.scale));
      for (final b in model.blasts) {
        if (b.age < 0.12 && (b.x - d.x).abs() < 1 && (b.y - d.y).abs() < 1) {
          _suppressedBlast[b] = true;
        }
      }
    }
    _previous = List.of(model.demons);
  }
}

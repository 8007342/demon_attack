part of 'model.dart';

// ===========================================================================
// spear-bearers (openspec/changes/spear-bearers): an armoured gargoyle
// variant, a hunter (elite) that carries a small round shield (the
// BUCKLER) and a SPEAR.
//
// - WHERE: from the third tour (route 2; Easy from route 3), sectors 2-4
//   (Easy 3-4), never on a bonus level or in the carrier sector. Half the
//   wave's elite births become bearers: the elite whose (wave + elite
//   ordinal) is even. It REPLACES a hunter, it never adds one, and the
//   choice draws nothing from the run's random.
// - THE SPEAR: it dives with the spear levelled; a third of the way down
//   it winds up (the spear drawn back, a glint on its head) for
//   [SpearTuning.windup] hostile-rate seconds, then throws: one hostile
//   [ShotKind.spear] aimed at where the ship is now. The spear is an
//   ordinary hostile shot, so the wind drifts it like any other. A throw
//   too close to the ship row is withheld. A bearer re-arms once it is
//   back on its station. It never fires the hunter's triple spread.
// - THE BUCKLER: raised in front of the body while it dives, it blocks
//   shots from the front (the player's gun; never a homing missile, which
//   comes round the side), one point per point of damage, and it does NOT
//   refresh: [SpearTuning.buckler] points for the creature's whole life,
//   then it is KNOCKED AWAY (it tumbles off) and the bearer dives bare
//   for good. While the buckler is up it replaces the thermal dive
//   shield; the dive it is knocked off in gets no thermal shield, later
//   dives get the hunter's ordinary one.
// - LIGHTNING: a stunned bearer drops its guard (the buckler blocks
//   nothing) and the stun cancels a wind-up (lightning-rework's rule:
//   a stunned creature's shield and armour are down).
//
// Pure Dart. The model only; the gear is drawn by
// lib/game/spear_bearer_painter.dart.
// ===========================================================================

/// Every spear-bearer tunable in one place (hostile-rate seconds, arena
/// units).
abstract final class SpearTuning {
  /// Tools only (tools/ordinary_wave_probe.dart `spears=off`): no bearer
  /// is born while false. The game never changes it.
  static bool enabled = true;

  /// First route (0-based) with bearers: Normal and Hard, then Easy.
  static const firstRoute = 2, firstRouteEasy = 3;

  /// Sectors with bearers (the carrier sector 5 never has them).
  static const firstSector = 2, firstSectorEasy = 3, lastSector = 4;

  /// Buckler points for the creature's whole life (the hunter's dive
  /// shield is 2 per dive).
  static const buckler = 2;

  /// The wind-up starts once the bearer has come this share of the way
  /// from where its dive began to the ship's row ("mid-dive")...
  static const windupAt = .3;

  /// ...and lasts this long (hostile-rate seconds: 0.61 s real on Easy,
  /// 0.55 on Normal, 0.52 on Hard): the throw's telegraph lead.
  static const windup = .55;

  /// No throw is released closer than this above the ship's row (u).
  static const minRelease = 120.0;

  /// The spear's fall speed (u/s, × the tour's speed; on the hostile
  /// grid) and the largest sideways aim (u/s).
  static const spearSpeed = 255.0, maxAim = 90.0;

  /// The share of the ship's motion over the spear's flight it leads by
  /// (0: at where the ship is). Tools may change it (the probe's
  /// `lead=`); the game never does.
  static double lead = 0;

  /// Where the spear leaves the claw, from the creature's centre (u, at
  /// scale 1): the levelled spear's head, low on the right.
  static const releaseDx = 7.0, releaseDy = 16.0;

  /// The fallen buckler's tumble (presentation): its life (s) and gravity.
  static const fallLife = 1.4, fallGravity = 260.0;

  /// The release pose holds this long after a throw (presentation).
  static const releasePose = .35;

  /// A buckler hit flashes this long (presentation).
  static const hitFlash = .14;
}

/// A bearer's gear and its state.
class SpearKit {
  SpearKit();

  /// Whether it holds a spear (false between a throw and its re-arm).
  bool armed = true;

  /// Buckler points left (0: knocked away, for good).
  int buckler = SpearTuning.buckler;
  bool get hasBuckler => buckler > 0;

  /// Hostile-rate seconds of wind-up left (0: not winding up).
  double windup = 0;
  bool get windingUp => windup > 0;

  /// Wind-up progress 0..1 (0 when not winding up).
  double get windupProgress =>
      windingUp ? (1 - windup / SpearTuning.windup).clamp(0.0, 1.0) : 0;

  /// The y its current dive began at (-1: not diving).
  double diveFromY = -1;

  /// Whether this dive has thrown (or withheld) its spear.
  bool spentThisDive = false;

  /// Model clock of the last release and the last buckler hit
  /// (presentation: the release pose and the hit flash).
  double releasedAt = -1e9, hitAt = -1e9;

  /// Throws made, buckler hits taken (tests, the gallery).
  int throws = 0, blocks = 0;
}

/// A knocked-away buckler tumbling out of the sky (presentation only).
class FallenBuckler {
  FallenBuckler(this.x, this.y, this.vx, this.vy, this.spin, this.scale);
  double x, y, vx, vy, rotation = 0, age = 0;
  final double spin, scale;
}

/// The spear-bearers of one run: the next birth's flag and the fallen
/// bucklers.
class SpearRun {
  /// Set by `_ordinaryProfile` for the birth it describes.
  bool next = false;

  /// Bearers born this run (tests, the probe).
  int born = 0;
  final List<FallenBuckler> fallen = [];
}

/// The appearance schedule (pure: tests and the gallery call it): whether
/// the elite birth with wave-elite ordinal [eliteOrdinal] (1-based) of
/// wave [wave] is a spear-bearer.
bool spearBearerScheduled({
  required Difficulty difficulty,
  required int route,
  required int sector,
  required int wave,
  required int eliteOrdinal,
  bool bonus = false,
}) {
  if (bonus || eliteOrdinal < 1) return false;
  final easy = difficulty == Difficulty.easy;
  if (route < (easy ? SpearTuning.firstRouteEasy : SpearTuning.firstRoute)) {
    return false;
  }
  final first = easy ? SpearTuning.firstSectorEasy : SpearTuning.firstSector;
  if (sector < first || sector > SpearTuning.lastSector) return false;
  // Easy's budget is one elite a wave: every other wave's is a bearer.
  return (wave + eliteOrdinal).isEven;
}

extension ArcadeSpearBearers on ArcadeModel {
  /// Whether [d] carries the bearer's kit.
  static bool isBearer(Demon d) => d.spear != null;

  /// The flag `_ordinaryProfile` sets for an elite birth.
  bool _spearFor(bool elite, int forWave) =>
      elite &&
      SpearTuning.enabled &&
      spearBearerScheduled(
        difficulty: difficulty,
        route: cycle,
        sector: level,
        wave: forWave,
        eliteOrdinal: _eliteBirths,
        bonus: bonus != null,
      );

  /// Gives the birth [d] its kit when `_ordinaryProfile` flagged it.
  Demon _spearUp(Demon d) {
    if (spearRun.next && d.elite && !d.isLarge) {
      d.spear = SpearKit();
      spearRun.born++;
    }
    spearRun.next = false;
    return d;
  }

  /// Once a frame: the fallen bucklers tumble.
  void _spearFrame(double dt) {
    final fallen = spearRun.fallen;
    if (fallen.isEmpty || dt <= 0) return;
    for (final b in fallen) {
      b.vy += SpearTuning.fallGravity * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.rotation += b.spin * dt;
      b.age += dt;
    }
    fallen.removeWhere(
      (b) => b.age > SpearTuning.fallLife || b.y > ArcadeModel.height + 24,
    );
  }

  /// A bearer's step, before its flight: the wind-up and the throw while
  /// diving, the re-arm on its station. A no-op for anything else.
  void _spearStep(Demon d, double dt) {
    final kit = d.spear;
    if (kit == null || dt <= 0) return;
    if (d.dive <= 0 || d.stunned) {
      // Out of the dive (or struck by lightning): no wind-up survives.
      kit
        ..windup = 0
        ..diveFromY = -1
        ..spentThisDive = false;
      if (!kit.armed && !d.stunned && !d.entering) {
        kit.armed = true; // back on its station: a fresh spear
      }
      return;
    }
    if (kit.diveFromY < 0) kit.diveFromY = d.y;
    if (!kit.armed || kit.spentThisDive) return;
    if (kit.windingUp) {
      kit.windup -= dt * policy.hostileRate;
      if (kit.windup <= 0) {
        kit.windup = 0;
        _throwSpear(d, kit);
      }
      return;
    }
    final from = kit.diveFromY;
    final reach = from + SpearTuning.windupAt * (ArcadeModel.shipY - from);
    if (d.y >= reach) {
      kit.windup = SpearTuning.windup;
      events.add('spearGlint'); // the glint's ting (lib/main.dart audioSfx)
    }
  }

  void _throwSpear(Demon d, SpearKit kit) {
    kit.spentThisDive = true;
    final x = d.x + SpearTuning.releaseDx * d.scale;
    final y = d.y + SpearTuning.releaseDy * d.scale;
    // Too close to the ship row, or the ship is away: withheld (it keeps
    // the spear levelled for the rest of the dive).
    if (shipAway || ArcadeModel.shipY - y < SpearTuning.minRelease) return;
    final vy = SpearTuning.spearSpeed * speed;
    final rate = policy.hostileRate > 0 ? policy.hostileRate : 1.0;
    final t = (ArcadeModel.shipY - y) / ArcadeModel.hostileVy(vy);
    final aimX = (shipX + shipVx * t * SpearTuning.lead).clamp(
      18.0,
      ArcadeModel.width - 18.0,
    );
    final aim = ((aimX - x) / t / rate).clamp(
      -SpearTuning.maxAim,
      SpearTuning.maxAim,
    );
    _hostile(Shot(x, y, aim, vy, hostile: true, kind: ShotKind.spear));
    kit
      ..armed = false
      ..throws += 1
      ..releasedAt = clock;
    events.add('spearRelease'); // the whoosh (lib/main.dart audioSfx)
    // --- spear-bearers → fang-and-wings-comms: the throw's war cry. One
    // structured event (fang-and-wings-comms §API); the director voices
    // `spearThrow.d0`-`d5` on it (brood lane, chance 0.6, cooldown 5 s).
    // No raw string of the same name, so the radio speaks once.
    _queueGameEvent(GameEventNames.spearThrow, {
      'x': x,
      'y': y,
      'kind': d.kind,
      'throws': kit.throws,
    });
  }

  /// The bearer's thermal dive shield: none while the buckler is up (it
  /// is the shield), and none for the rest of the dive it was knocked off
  /// in. Returns true when it handled the ignition.
  bool _spearIgnite(Demon d) {
    final kit = d.spear;
    if (kit == null) return false;
    if (kit.hasBuckler) {
      // Spent but present: the hit test skips it, the scene draws nothing.
      // Set once, at the dive's start, so the dive the buckler is knocked
      // off in keeps this (no thermal shield); the next dive ignites one.
      d
        ..diveShieldMax = 1
        ..diveShield = 0;
      return true;
    }
    return false;
  }

  /// A hit on a diving bearer's buckler. Returns true when the buckler
  /// took it (the creature is unharmed).
  bool _bucklerHit(Demon d, int damage, {required bool homing, double? atY}) {
    final kit = d.spear;
    if (kit == null || !kit.hasBuckler || d.dive <= 0 || d.stunned) {
      return false;
    }
    // From the front only: a homing missile comes round the side, and a
    // splash landing above the body's middle passes behind the buckler.
    if (homing || (atY != null && atY < d.y - d.hitHalfHeight * .5)) {
      return false;
    }
    kit
      ..buckler = math.max(0, kit.buckler - damage)
      ..blocks += 1
      ..hitAt = clock;
    d.flash = SpearTuning.hitFlash;
    if (kit.buckler == 0) {
      score += (25 * policy.enemyPoints).round();
      spearRun.fallen.add(
        FallenBuckler(
          d.x - 6 * d.scale,
          d.y + 8 * d.scale,
          -40 - 30 * (d.seed % 1),
          -70,
          9 * (d.seed.floor().isEven ? 1 : -1),
          d.scale,
        ),
      );
      events.add('bucklerOff');
    } else {
      events.add('bucklerClang');
    }
    return true;
  }
}
// --- end spear-bearers

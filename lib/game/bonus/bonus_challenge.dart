// --- bonus challenges (openspec/changes/bonus-challenges, design §API)
//
// One perfect-run condition per bonus level that pays a 1UP: "catch all
// the cargo", "take no lightning hit". A condition is data: the NOTES that
// break it at once ([BonusChallengeDef.failOn]) and the notes it needs by
// the level's clear ([BonusChallengeDef.atLeast]). A note is a short
// string the model or the level's mechanic reports with
// `model.challengeNote(name)` the moment the thing happens; the model
// notes [ChallengeNotes.shipLost] and [ChallengeNotes.shipHit] itself.
//
// Adding a condition to a new level is a few lines:
//
//   const crosswind = BonusLevelDef(
//     ...,
//     challenge: BonusChallengeDef(
//       id: 'noGustHit',
//       label: 'RIDE EVERY GUST',
//       icon: 'gust',             // a pictogram in ChallengeIcons.byId
//       failOn: {'gustHit'},      // the mechanic: m.challengeNote('gustHit')
//     ),
//   );
//
// Pure Dart, no `dart:ui`: the model runs headless in `dart run` tools.
// The badge's painter is `lib/game/bonus/challenge_badge.dart`.

/// The notes the framework reports by itself, and the shared vocabulary of
/// the shipped levels. A level may use any other string of its own.
abstract final class ChallengeNotes {
  /// A ship was lost (any cause) inside the level.
  static const shipLost = 'shipLost';

  /// The ship was hit: a ship lost or a shield knocked off (any cause).
  static const shipHit = 'shipHit';

  /// Supply Run: a crate fell past the ship's row unopened.
  static const crateMissed = 'crateMissed';

  /// Supply Run: falling cargo passed the ship's row uncaught.
  static const cargoMissed = 'cargoMissed';

  /// Supply Run: cargo reached the ship.
  static const cargoCaught = 'cargoCaught';

  /// Stormfront: a bolt struck the ship (a ship lost or a shield knocked
  /// off; a bolt the lightning rod grounds is not a hit).
  static const boltHit = 'boltHit';

  /// Stormfront: a bolt landed with the ship inside its bright column
  /// (the band the tell draws) but outside the lethal core: a graze.
  static const boltGrazed = 'boltGrazed';

  /// Stormfront: a bolt aimed at the ship landed and missed it.
  static const boltDodged = 'boltDodged';
}

/// One level's perfect-run condition. `const` data on `BonusLevelDef`.
class BonusChallengeDef {
  const BonusChallengeDef({
    required this.id,
    required this.label,
    required this.icon,
    this.failOn = const {},
    this.atLeast = const {},
    this.lives = 1,
  });

  /// camelCase, unique among the levels' challenges (tests, the ledger).
  final String id;

  /// The condition in at most 18 upper-case characters, beside the badge
  /// on the briefing card ("CATCH ALL CARGO"). Never drawn over the arena.
  final String label;

  /// The badge's pictogram, a key of `ChallengeIcons.byId`; an unknown key
  /// draws the arcade star.
  final String icon;

  /// Any of these notes fails the challenge the moment it is reported.
  final Set<String> failOn;

  /// Notes the level must have reported at least this often by its clear
  /// (a challenge that could otherwise be won by doing nothing).
  final Map<String, int> atLeast;

  /// Ships paid on success (the 1UP).
  final int lives;
}

/// Where a challenge stands. A live challenge is in progress and still
/// possible; [failed] and [earned] are final for the visit.
enum ChallengeStatus { live, failed, earned }

/// The live state of one level's challenge, one per visit of the level.
/// Deterministic: it changes only on [note] and [settle].
class BonusChallenge {
  BonusChallenge(this.def);
  final BonusChallengeDef def;

  ChallengeStatus status = ChallengeStatus.live;

  /// Every note reported in this visit, by name.
  final Map<String, int> tally = {};

  /// The note that failed it (null: not failed, or failed at the clear for
  /// a missing [BonusChallengeDef.atLeast]).
  String? failedBy;

  /// The model's clock when [status] last changed (the badge's flip and
  /// burst are timed from it); null while live.
  double? changedAt;

  bool get live => status == ChallengeStatus.live;
  bool get failed => status == ChallengeStatus.failed;
  bool get earned => status == ChallengeStatus.earned;

  /// Still winnable: live (in progress, nothing has broken it).
  bool get possible => live;

  /// Every [BonusChallengeDef.atLeast] is met so far.
  bool get onTrack =>
      def.atLeast.entries.every((e) => (tally[e.key] ?? 0) >= e.value);

  /// Counts [name]. Returns true when this note failed the challenge now
  /// (only once: a settled challenge ignores every later note).
  bool note(String name, {required double at, int count = 1}) {
    if (!live) return false;
    tally[name] = (tally[name] ?? 0) + count;
    if (!def.failOn.contains(name)) return false;
    status = ChallengeStatus.failed;
    failedBy = name;
    changedAt = at;
    return true;
  }

  /// The level's clear: earned when still live and on track, else failed.
  /// Returns true when it was earned by this call (only once).
  bool settle({required double at}) {
    if (!live) return false;
    status = onTrack ? ChallengeStatus.earned : ChallengeStatus.failed;
    changedAt = at;
    return earned;
  }
}

/// The run record's id of a won challenge on level [levelId]: the level's
/// perfect-run medal (`supplyRunOneUp`).
String oneUpRecordId(String levelId) => '${levelId}OneUp';

/// The level id of a perfect-run record id, or null for any other id.
String? oneUpLevelOf(String recordId) =>
    recordId.length > 5 && recordId.endsWith('OneUp')
    ? recordId.substring(0, recordId.length - 5)
    : null;

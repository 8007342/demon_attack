# Design: bonus-challenges

## 1. What a challenge is
One perfect-run condition per bonus level that pays a 1UP. It is data on the level (`BonusLevelDef.challenge`), and
the model keeps one live `BonusChallenge` per visit of the level. The condition is expressed as **notes**: short
strings the model or the level's mechanic reports the moment something happens. A note named in `failOn` breaks the
challenge at once; `atLeast` names notes the level must have reported by its clear (so a challenge cannot be won by
doing nothing). The level's last kill settles a live challenge: earned if `atLeast` is met, else failed.

States (`ChallengeStatus`): `live` (in progress and still possible), `failed`, `earned`. Failed and earned are final
for the visit. The state never draws a random number and changes only on `note` and `settle`, so a seeded run
replays it exactly, and the calibrated campaign (no run seed, no bonus level) is untouched.

| Level | Id | Label | Pictogram | Fails on | Needs by the clear |
|---|---|---|---|---|---|
| Supply Run | `catchAll` | CATCH ALL CARGO | parachute crate | `crateMissed`, `cargoMissed` | `cargoCaught` ≥ 1 |
| Stormfront | `noBoltHit` | DODGE EVERY BOLT | bolt | `boltHit` | none |

Checked against the rules in code:
- Supply Run: a crate is shot from below, so once it passes the ship's row (`ArcadeModel.shipY`) no shot can reach
  it: `crateMissed`. Cargo is caught inside ±23 of the ship's row (`_updatePickups`), so cargo below `shipY + 23`
  can no longer be caught: `cargoMissed`. `SupplyRunCues` (the level's existing cue tracker) reports both in combat
  only, so the crates the clear bursts open fall through the salvage window without failing anything. Kills drop
  nothing in a Supply Run, so every falling pickup is cargo.
- Stormfront: `StormfrontMechanic._land` already decides `hitShip` (a ship lost, or a shield knocked off); a bolt
  the lightning rod grounds is not a hit, and a bolt on a ship still invulnerable from a respawn is not either. A
  ship-aimed bolt that lands and misses reports `boltDodged` (counted, not required).

## API
For a new bonus level (the `crosswind` agent's wind level is the first user). Everything is in
`lib/game/bonus/bonus_challenge.dart` (pure Dart, exported through `bonus_types.dart` and `model.dart`).

```dart
const crosswind = BonusLevelDef(
  id: 'crosswind',
  // ...
  challenge: BonusChallengeDef(
    id: 'noGustHit',            // camelCase, unique among challenges
    label: 'RIDE EVERY GUST',   // ≤ 18 upper-case characters, shown beside the badge on the card
    icon: 'gust',               // key of ChallengeIcons.byId; unknown keys draw the arcade star
    failOn: {'gustHit'},        // any of these notes fails it at once
    atLeast: {},                // notes needed by the clear (default none)
    lives: 1,                   // the 1UP (default 1)
  ),
);

// In the level's mechanic (BonusMechanic.step), the moment it happens:
m.challengeNote('gustHit');
```

Model surface (extension `ArcadeBonus` in `lib/game/model_bonus.dart`):
- `void challengeNote(String name, [int count = 1])`: reports a note. Ignored outside a bonus level, without a
  challenge, or after it settled. A `failOn` note queues `bonusChallengeFailed` (variant: level id; data
  `challenge`, `by`).
- `BonusChallenge? get bonusChallenge`: the live state (`status`, `possible`, `onTrack`, `tally`, `failedBy`,
  `changedAt` on the model clock). The HUD and the tests read it.
- `List<String> get bonusOneUps`: the levels whose 1UP this run won.
- Built-in notes, reported by the model for every level: `ChallengeNotes.shipHit` (a ship lost or a shield knocked
  off, any cause) and `ChallengeNotes.shipLost`. A "no damage" level only needs `failOn: {ChallengeNotes.shipHit}`.

Presentation (Flutter side, `lib/game/bonus/challenge_badge.dart`): add the pictogram as a function
`void paintGust(Canvas canvas, Rect box, Color ink)` and one entry in `ChallengeIcons.byId`. Draw it filled, in
`ink`, inside `box` (the disc's inner square); it is shown at 7-15 px, so keep it to a few bold shapes.

Radio (`art/comms/lines.json`, then `python3 -I tools/comms_pipeline.py dart`): append
- `bonusChallenge.<level>`: exactly one line, one sentence, naming the 1UP (the card speaks it);
- `bonusChallengeFailed.<level>`: the quip, optionally with a `demon` block;
- optionally `bonusChallengeEarned.<level>` (otherwise the generic `bonusChallengeEarned` cheer plays).
Mark them `"pending": "text"` until voices exist (tillandsias#1103). Tests in `test/bonus_challenges_test.dart`
iterate `bonusLevels`, so a new level is checked for its call, quip and pictogram automatically.

## 2. The reward
At the level's last kill (`_bonusClear`), before the clear award: `settle`. Earned pays `def.lives` with `lives +=`,
the extra-life path's own increment, and the raw event `bonusOneUp`, which `lib/main.dart` plays as the
`extraLife` fanfare. It does not raise the heart card ("HEART ASSEMBLED"), and the radio's `extraLife` lines ("Heart
assembled …") are not triggered; the cheer is the challenge's own. The game has no life cap (checked: no
`maxLives` in the model or `DifficultyPolicy`), so none applies; if one is added, it belongs at this one increment.

Paid once: `settle` returns true only on the live → earned transition, and the challenge object is replaced at the
next level's start. `bonusCleared` carries `challenge: <status>`.

Run record: `runModifierIds` replaces a level's id by `<level>OneUp` when its 1UP was won (`supplyRunOneUp`,
`stormfrontOneUp`: within the score worker's `^[a-z][A-Za-z0-9]{0,31}$`, so no worker change). `runTagLabel` reads
it as "SUPPLY RUN · 1UP"; `MissionMedal` draws the level's own medal (atlas layers of the base id) with a gold
earned 1UP plate across its foot. An older build shows an unknown medal labelled "SUPPLY RUN ONE UP". The
checkpoint saves `bonusOneUps` (a list of level ids), so a restored run keeps the medal.

## 3. The badge
`ChallengeBadgePainter`: a medal disc (the mission medals' gold `0xFFF4CA79` rim over the brood insignia's dark
socket `0xFF101827`) holding the pictogram in cream, and an arcade "1UP" plate to its right (mint `0xFF70F5D5`, the
title's colour, breathing slowly while live). Width 2.15 × height.

| State | Disc | Plate | Motion (none with reduced motion) |
|---|---|---|---|
| live | gold rim, cream pictogram | mint, slow breath | breath |
| failed | grey rim, dim pictogram, red slash | grey, struck through | 0.45 s shake and red flash at the flip (reduced: a steady red tint for 0.45 s) |
| earned | gold rim | gold | 1.4 s burst: 8 rays, a ring, 6 mint sparks; then a steady gold halo (reduced: the halo at once) |

Where it shows:
- **Urgent-mission card:** under the how-to line, 20 px tall (15 px on a short card), followed by the label in
  gold. Its accessibility label is "Challenge: catch all cargo for 1UP". The card's reading time is unchanged: the
  badge is read at a glance, and adding its words would lengthen the hold at the flight's end (cinematic-flow).
- **HUD pip:** 16 px, in the lives row between "♥ ×N" and the heart inventory, while the bonus level is the current
  sector (live, then failed or earned through the Rout and Pursuit). No floating text in the arena: cinematic-flow
  §10.3 removed the "+1UP" text, so the earned moment is the pip's burst, the fanfare and the radio cheer.

**Pipeline: painters, not the mission-medal atlas.** The badge is 7-20 px tall, changes state mid-level and
animates (shake, flash, burst, breath). Vector strokes stay crisp at that size on every pixel ratio, the three
states are one painter, and nothing new is committed to `.git` (CLAUDE.md §9). The atlas pipeline (rigkit + ComfyUI
+ rigsheet) fits the end-of-run medal, which is why the perfect-run medal reuses the level's atlas medal and only
adds the painted 1UP plate.

## 4. Radio
- **The call is the card's one line.** bonus-briefing-clarity allows exactly one radio line per bonus level on the
  card, with the squad hushed while it is up. The challenge call takes that place: `BonusBriefing.call` prefers
  `bonusChallenge.<level>` when the level declares a challenge, else `bonusCall.<level>` (which keeps its clip id).
  So nothing new plays over or beside the card, and a level without a challenge behaves as before.
- **Quip** (`bonusChallengeFailed.<level>`, priority 4, ttl 3, cooldown 30): queued by the failure event; it plays
  between ordinary chatter, never cuts a line. A brood taunt follows half the time (`demon.chance` .5).
- **Cheer** (`bonusChallengeEarned` generic, plus `.supplyRun` and `.stormfront`; priority 6, ttl 5): queued at the
  last kill before `bonusCleared`, so the cheer is the clear's headline and the level's own clear line (priority 5)
  follows or expires. A brood retort follows 60 % of the time.

| Trigger | Speaker | Line |
|---|---|---|
| `bonusChallenge.supplyRun` | Pip (excited) | Don't let a single prize hit the ground, and the fleet throws in a 1UP! |
| `bonusChallenge.stormfront` | Sunny (teasing) | Don't let one bolt tickle you, and there's a shiny 1UP in it! |
| `bonusChallengeFailed.supplyRun` | Rook / Sparrow / Kestrel | Dropped one! No 1UP, but every prize still counts. · Butterfingers! Keep popping, the points are still good. · That one got away. Forget the bonus ship and keep catching. |
| (brood) | Skritch / Nibb | Dropped it! No spare ship for you! · Crunchy prize, my prize! |
| `bonusChallengeFailed.stormfront` | Wisp / Anvil / Sunny | Zapped! The 1UP's gone, but the storm still works for us. · Took a jolt. No bonus ship, so just fly the storm. · Well, that was shocking! Bonus ship's off, fun's still on. |
| (brood) | Vexxa / Skarn | See? The sky picked a side. · Crackle crackle! Ha! |
| `bonusChallengeEarned` | Rook / Sparrow / Pip / Admiral | Not one miss! That's a 1UP, pilot! · Perfect run! Spare ship on the line! · One up! One up! You actually did it! · Flawless work. The fleet sends you a spare ship. |
| (brood) | Gorrak / Morth / Nibb | Not one slip? Who trained that pilot?! · Enjoy your spare ship. We have spares too. · Hey! That has to be cheating! |
| `bonusChallengeEarned.supplyRun` | Sunny / Rook | Every prize caught! Here's your 1UP, gift wrapped! · Clean sweep of the crates! That's a 1UP! |
| (brood) | Skritch | All of them? Not even one for me? |
| `bonusChallengeEarned.stormfront` | Sparrow / Kestrel | Not a single zap! The storm owes you a 1UP! · Clean through the lightning. Spare ship earned. |
| (brood) | Sliss | It danced through the lightning! Rude! |

All are written lines (`"pending": "text"`): no borrowed clip, so the borrowed count stays 55.

## 5. Balance and earn rates
<!-- filled from the measurement -->

## 6. Cinematic-flow check
No new screen, card, modal step or control; no floating text in the arena (the pip is in the HUD band). The card's
reading time and hold are unchanged, and it still speaks one line. The quip and cheer are ordinary queued radio
lines (no urgent flag), so they never cut a warning and wait out the card's quiet window.

# Design: cinematic flow

Research: `plan/swarm-research.md` §2.2 (cannonball), §2.3 (macron.dev) and §4 (juice, Tetris Effect, attract
mode), plus `plan/transition-research.md` (one normalized clock, bar-aligned music, immediate feedback). This
design builds on `continuous-swarm` §6.4 (`drain`, `rout`, `preload`).

## 1. `FlowDirector` (`lib/game/flow_director.dart`)

The macron.dev pattern in game form:

```dart
double bump(double a, double b, double c, double d, double u) =>
    smoothstep(a, b, u) * (1 - smoothstep(c, d, u));

class FlowBeat { final String id; final double a, b, c, d; }          // on the normalized clock u ∈ [0, 1]
class FlowPlan { final double seconds; final List<FlowBeat> beats; }  // per transition kind and motion setting
class FlowDirector {
  FlowPlan plan; double u;                                            // one clock
  double env(String beat) => …;                                       // the beat's envelope at u
  void advance(double dt); void skipToDescent();
}
```

- **One plan per transition kind:** sectorChange, bossArrival, bossVictory, campaignOutro, gameOverOutro, attract.
  Each has a full-motion and a reduced-motion variant.
- **Actors read envelopes.** Nothing keeps its own timer:
  - ship pose and screen y (`env('climb')`);
  - camera tilt (`env('tilt')`);
  - fog cover sent to W2 (`env('cloud')`);
  - palette crossfade (`env('swap')`, which lives only while `env('cloud') ≥ 0.85`, so the swap is hidden);
  - flock heading;
  - the caption slot and the radio slot;
  - music cue moments.
- **Each swarm member adds its own phase offset** (`seed`), as macron's instances do, so the flock never moves in
  lockstep.
- **Gameplay timing** stays in `ArcadeModel`: phase lengths, pickups and invulnerability. The director is driven
  by the model's `transitionProgress` and owns presentation only. One clock cannot drift from the model's because
  it *is* the model's clock, normalized.

## 2. Sector change

| Beat | Model phase (event) | Seconds (full / reduced) | What happens |
|---|---|---|---|
| hit | last kill (`levelclear` stinger) | instant, then 0.06 hit-stop | immediate music stinger (as today), juice on the last blast; shake ≤ 2 px (none reduced) |
| rout | `salvage` (`salvage`) | 2.0 / 2.0 | pickup grace unchanged; `stream.rout(dir)`: reserve and stragglers flash-expand, then stream away into the fog along the ship's future climb direction; the ground war resolves (existing); `demonRout` brood line |
| pursuit | `levelClear` (`levelclear`) + `travel` (`travel`) | 2.0 + 4.0 (+ ≤ 2.0 reading) / 1.0 + 2.5 | ship climbs nose-up (screen y −40), camera tilts up 0 → 1 through the layers; `env('cloud')` rises to 1 (W2 renders full cloud cover: soft, bright, **never opaque black**); the fleeing flock stays ahead in silhouette; in the cloud's peak (≥ 0.85) the palette and sector backdrop swap; one radio or caption slot |
| descent | the next sector's wave-1 transition (`level`) | the existing arrival hint, 4.5 / 3.0 | ship drops out of the cloud to its play row; `stream.preload(next cohort)` places the pursued flock as the new species' reserve, already in the fog **in the same screen direction it was flying** (Cianciolo: preserve direction and position); it wheels into the first wave; sector title at the top edge for 1.5 s |

- **Total:** about 12.5 s against about 15.2 s today (salvage 2 + 4⅓ + 4⅓ + 4.5). It is shorter, and the brood is
  on screen the whole time.
- **Durations:** `RunMode.levelClear` and `RunMode.travel` keep their meaning and events, with lengths 2.0 s and
  4.0 s (+ reading). `storyReadingTime` applies only when a radio line or caption is scheduled.
- **The route jump** (sector 5 → the next tour's sector 1) uses the same plan. The tour-escalation story becomes
  the radio slot's line (`transmissionMission.<n>`), and the caption names the new tour.
- **Superseded in part by `transition-ascent` (R3, 2026-11-15).** The Pursuit's motion is now a monotonic `speed`
  ramp (×8 peak inside the cloud, replacing the travel `1 + 9 sin(πp)` bump), a camera `pitch` about the horizon
  (horizon drop 96·q, ground stretch 1 + 0.35q) and a ≤ 3° world `roll`, with fog `streaks`; the ship rises only
  24 units (was 40) and the flat 46-unit `tilt` remains on the campaign outro only. On a revisit the radio slot is a
  front-line call from the destination (`frontCall.<sector>`, then `frontCall`). See
  `openspec/changes/transition-ascent/design.md` §1–§4 and §7 (deviations).

### 2.1 Continuity rules (tested on rendered frames)
- **No black.** Every frame's mean luminance is ≥ the sector's night floor (0.06 in linear sRGB), and no frame is
  ≥ 95 % a single opaque colour. Cloud cover is bright, translucent layering (W2), not a wipe.
- **Ship continuity.** The ship's screen position changes by ≤ 6 u per frame at 60 fps. Its heading is nose-up or
  level, never flipped.
- **Direction continuity.** The swarm centroid's screen velocity has the same sign of x before and after the
  palette swap (the motivated cut).
- **Seams in quiet beats.** The swap happens only under cloud ≥ 0.85. Radio and caption slots never start within
  0.5 s of the swap (cannonball: never an art beat and an instruction at the same instant).

### 2.2 Messages: one at a time, no cards

> **Superseded in part by §10.3 (playtest-fixes):** transitions now speak only by radio. The caption slot, the
> Descent's sector/tour title and the "+1UP" text are gone; every slot is a radio line.

- The fluid-transitions interlude alternation (tip ↔ radio, seeded) is kept, but **as slots, not cards**.
  - **Radio slot:** the line plays on the comms dock (the existing in-play transmission, not a full-size card),
    with its normal subtitle.
  - **Caption slot:** one tip sentence (from `hints.dart`, the text only) as a single line at the bottom edge, with
    a 0.5 s fade and a reading time from its word count (`readSeconds`).
- The storyboard banner, the interlude card and the sector pips leave sector transitions.
- **Medals and +1UP:** a short flourish beside the ship during Pursuit (the existing medal glyph, no panel).
- **Illustrated hints** (the pixel scenes) show only during the run's opening arrival, the existing first-load
  tip, and in the pause menu's tips pane.
- **Skip:** tap, Space or Enter during Rout or Pursuit calls `skipToDescent()` within one frame (Swink's 100 ms
  budget). The skip ends any caption and lets the radio line finish on the dock. The pickup grace is not skipped:
  a skip during Rout takes effect at Rout's end.

### 2.3 Music
- The stinger is immediate (today's `levelclear` behaviour).
- `travel` starts on the next 4-beat boundary of the 120 BPM grid (today).
- The Descent's `level` cue is requested at the beat boundary nearest the Pursuit's end. The director rounds the
  Pursuit length to whole beats (0.5 s) so the cue lands on the grid.
- Speech ducks music (the existing comms duck). No change to `web/audio/demon-audio.js` is expected. Verify it in
  `test-worker`.

## 3. Boss transitions

### 3.1 Arrival (sector 4 → carrier sector 5)
- Pursuit as in §2. In the Descent, the pursued flock does **not** become a wave.
- It streams into a ring formation (a mill) around the arrival point, then opens a **vacuole** (Storms 2019). The
  carrier's existing orbital retro-burn arrival comes down into that hole.
- When the carrier settles, the flock pours into its two hangar bays, ordered by distance and staggered 40 ms.
  This is presentation only: the creatures are simply removed, and carrier gameplay is unchanged.
- The `bossArrival` radio line fills the radio slot.

### 3.2 Victory
- The existing chain detonation (wing pylons, bays, core) plays.
- From its first blast, `stream.rout` sends a scattered remnant (cosmetic reserve silhouettes, at most 18) out of
  the fog behind the carrier and away, as a flash expansion.
- The 5.5 s victory is the Rout, then Pursuit into the next tour.

## 4. Outros

### 4.1 Campaign complete (`finalBoss`, `RunMode.completed`)
- After the victory's Rout, `env('thin')` drives W2's `fogThin` 0 → 1. Creature and cloud shadows lift (alpha → 0
  over 2 s) and the light warms.
- The ship climbs above the clouds (the Pursuit climb with no swap). The existing ending page (beach ending) fades
  *up* from the cloud tops: a crossfade between two lit scenes, never through black.
- The radio slot carries the existing `flawlessRun` or `levelClear` final line.

### 4.2 Game over
- The existing defeat celebration and skyward pan stay. Before the pan, the swarm (present members plus reserve
  silhouettes) converges into a slow torus (mill, ω 0.5) over the wreck for 2.0 s, with brood `broodTaunt` lines,
  and then breaks upward with the pan.
- Reduced motion: no torus rotation, a static ring that fades.

## 5. Attract mode (title)
- **Behind the title:** two or three mill and ribbon squads of the current sector's species in the fog (using
  `swarm_patterns.dart` without a model run), the sentinel silhouette on its Gerono path (`SentinelForeshadow`),
  shadows on the ground. The cost is that of a light combat frame.
- **Optional demo** (task group 6): after 30 s without input, a demo flight runs sector 1 with the deterministic
  real-shot pilot from `test/campaign_playtest_test.dart`, moved to `lib/game/demo_pilot.dart`. Scores are not
  recorded, and any input returns to the title. This is the classic attract loop (Lendino 2020; NES attract
  write-up).

## 6. Fog-restoration (W2) interface
This change needs two inputs from W2's layers:
- `Atmosphere.cloudCover` (0–1): every layer thickens toward a bright, soft full-frame cover. At 1 the layers sum
  to at most 92 % opacity over a bright cloud colour, never black.
- `Atmosphere.fogThin` (0–1): the layers recede for the outro.

If W2 has not exposed them when this change starts, add them in `atmosphere.dart` as thin pass-throughs, flagged
for W2's review. This change does not decide how the layers look.

## 7. Validation
- **`test/cinematic_flow_test.dart`** (model-level):
  - phase sequence and lengths per plan (full and reduced);
  - the skip lands in Descent within one step and never shortens the pickup grace;
  - pursuit lengths are whole beats;
  - the caption and radio slots never overlap and never start within 0.5 s of the swap;
  - medal and +1UP state are unchanged;
  - pause freezes the director;
  - the route-jump plan;
  - the boss plan removes the flock before carrier combat;
  - the outro plan ends in `completed`.
- **`test/cinematic_flow_review_test.dart`** (rendered, phone portrait, to `.cache/cinematic-flow-review/`). It
  takes 30 frames per transition kind and computes:
  - mean and min luminance (the no-black rule);
  - the ship displacement per frame (≤ 6);
  - the swarm centroid direction across the swap;
  - the macron smoothness metric, the mean frame-to-frame change of the ship and the swarm centroid, recorded
    against today's transition frames.

  It writes a contact sheet per kind.
- **Updated tests:**
  - `test/fluid_transitions_test.dart`: interludes are now slots;
  - `test/transition_loadout_test.dart`: the ship loadout is still drawn in transitions;
  - `test/cinematic_scene_test.dart`;
  - `test/ending_progression_test.dart`: the outro enters the ending;
  - `test/campaign_run_test.dart` and `test/campaign_playtest_test.dart`: phase chain and total time;
  - `test-worker` music cues.
- **Preview:** a phone-portrait capture of a sector change, a boss arrival, the outro (console route) and game
  over, for the operator.

## 8. Decisions taken on the operator's behalf
1. **The mode names and events stay,** so music, saves and the ground war keep working. Only lengths and
   presentation change.
2. **No cards in sector transitions.** The radio line goes to the dock, and tips become one caption line.
   Illustrated hints remain at the opening and in the pause menu, because they teach. This supersedes parts of
   `fluid-transitions` (see the tasks for the archive order).
3. **Shorter sector changes** (about 12.5 s instead of 15.2 s), with the brood on screen throughout.
4. **The demo pilot is optional,** behind the attract task group. It is not needed for the operator's ask.
5. **The cloud cover is bright, never black.** This is cannonball's hard rule, adopted as a test.

## 9. Implementation notes and deviations (2026-11-15)

Recorded during implementation on `work/cinematic-flow`. Each is the reversible option; the operator can override.

1. **Archive order.** `fluid-transitions` was archived first (`archive/2026-11-15-fluid-transitions`; its task 4.3,
   the by-ear playtest, is still open, blocked on audio). This change's deltas were rebased onto the synced text and
   also MODIFY "One primary transition message", "Alternating transition interludes", "Silent tips and radio
   cards", "Readable, skippable, fluid cards" and the storyboard requirement in `arcade-progression`.
2. **Night floor.** §2.1's 0.06 linear luminance is above these sectors' own combat frames (about 0.03; about 0.02
   in the Rout, when the lit swarm is gone). The review test's floor is half the darker sector's own combat frame, and
   never under 0.010. Every plan passes it; the cloud frames sit at 0.3-0.35.
3. **Preload direction.** Turning the next cohort's gates toward the flock (even a gameplay-neutral mirror of the
   alternation) changed the deterministic hard campaign's ground-missile tally past its bound. So the model does
   the inverse: at the rout, `stream.preload` predicts the next sector's lead gate from the same seeded draws, and the
   pursued flock flies to that side. The cohort's gates (gameplay) are untouched; the continuity holds (tested over
   18 sector changes in `cinematic_flow_test`).
4. **Descent length with reduced motion** stays 4.5 s in the model (the arrival's entrance timing is gameplay); the
   reduced plan's beats fit in its first 3.0 s.
5. **The stinger** stays on `levelclear` at the Pursuit's start (immediate); the last kill itself gets the existing
   `salvage` SFX, the 60 ms presentation hit-stop and the hit flash. The music grid then needs no change in
   `music_director.dart` or `web/audio/demon-audio.js`.
6. **Victory skip.** A carrier's fall (not the final one) is skippable from its first frame; the medal and +1UP are
   already granted. The campaign's final victory is not skippable here (the ending page has its own skip).
7. **Outro tilt.** The campaign outro does not tilt the camera (a flat band over the thinning sky read badly in the
   sheets); the ship climbs 150 u instead of 40 and the cloud lies below it, with warm light above.
8. **Tour name.** The route jump names the new tour in the Descent's sector title (`TOUR n`), not in a caption, so the
   one slot stays free for the radio line or tip.
9. **Removed widgets.** `lib/widgets/storyboard_banner.dart` (with its route-progress pips) and the radio interlude card
   had no other users and were deleted; `test/transition_loadout_test.dart` lost its storyboard-glyph test.
10. **Commits.** Groups 3 and 4 share `main.dart`, the overlay and their tests, so they landed as one commit.
11. **Attract (6.1)** is done; the demo pilot (6.2) is left open.
12. **Preview (7.2)** is left for the operator: the repo's notes publish the preview after W4 and W5b both merge. The
    contact sheets stand in for it until then.
13. **Fog-restoration pass-throughs.** `Atmosphere.cloudCover`, `fogThin` and `cloudScroll` (and `paintCloudCover`)
    are flagged for W2's review (§6).

### Progress-bar audit (operator W5)

- The thin green line growing across the top of `art/contact/continuous-swarm-*.png` is the **review harness**, not
  the game: `test/continuous_swarm_review_test.dart` `_strip()` draws a "progress tick: frame i of count" on each tile.
  This change's sheets have no tick.
- In the game, two progress-like elements remained after `ux-declutter`, both in sector transitions, and both are gone:
  the storyboard banner's 5-stage route chart (sector pips joined by a line that fills with progress), and the arrival's
  scan line sweeping down the arena with the transition's progress. The letterbox bars and their accent line went with
  them. `ux_declutter_test` and `fluid_transitions_test` assert no bar or strip through a whole sector change.

## 10. Playtest revisions (work/playtest-fixes, 2026-11-15)

Operator playtest: the very last wave still showed demons waiting in the fog, which then flew away at the level's end;
and bare caption and title texts still floated over the play area.

1. **The final wave leaves the fog empty** (`ArcadeModel.finalWave`, `fogStaged`). During a sector's last wave (and
   the carrier) the drawn reserve is empty: the wave's later roster skeins and reinforcement groups are still born at
   its start with the same seeded draws (determinism and calibration are untouched, nothing is born or timed
   differently), but they wait unseen and appear only when admitted, swooping out of their deep-fog point. No cohort is
   sighted after the last wave (unchanged). The wave's own sentinel keeps its foreshadow silhouette; it is admitted.
2. **The rout scatters only fighters.** `_flowRout` no longer tops the flock up to 12 stand-ins "out of the fog"
   around the last kill and no longer pulls in reserve silhouettes. A sector ends when every fighter fell, so a sector
   change has no pursued flock: §2's pursuit, §3.1's mill and pour and the direction-continuity rule now apply only when
   a flock exists (a carrier's live minions at its fall, §3.2). The next cohort's lead side (`_preloadSide`) is still
   computed, so the first wave leaves the cloud where `flowDirection` points.
3. **Transitions communicate only via radio.** The operator: the cards' leftover texts "still show up just floating
   randomly without windows or toasts". Removed from in-game and transition presentation: the caption slot (the tip
   sentence at the bottom edge, `lib/widgets/flow_caption.dart`, deleted), the Descent's sector title
   (`SECTOR n · <NAME>`) with its `TOUR n` subtitle and the plan's `title` beat, the `♥ +1UP` text of the carrier-fall
   flourish (the medal glyph stays, the HUD counts the life), and the model's unused `banner` strings (`COLLECT
   SALVAGE`, `<NAME> SECURED`, `APPROACHING <NAME>`, `CARRIER DESTROYED`, `WAVE n / m`, `LEVEL nn · <NAME>`).
   `InterludePlanner.planRadio` gives every transition slot a recorded line (seeded category, then any fresh line,
   then the shortest one), so no transition is silent; the tip ↔ radio alternation now applies only to the opening.
   Kept (in a window or a real UI): the opening tip card, the carrier alert, the heart notice toast, the HUD band, the
   comms dock (its subtitles and `NO SIGNAL` inside the portrait frame), the game-over leaderboard card, the title,
   pause and ending pages. The tour escalation rides on the radio briefing. No audio was generated
   (tillandsias#1103).

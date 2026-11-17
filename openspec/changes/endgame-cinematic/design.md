# Design: endgame-cinematic

Research and sources: `plan/endgame-cinematic-research.md` (Part A craft, Part B pipeline). This file records the
decisions. A conclusion about the outside world here points to a section of that file, where its source sits beside
it. Details: `plan/endgame-reveal-ledger.md`. Look: `docs/styleguide/endgame-cinematic.md`. Shots:
`art/storyboards/endgame/README.md`.

## 1. The story

The last carrier falls and lands as a plastic toy on a board game. The camera rises: five kids and a board on the
patio of Krybor, a burger place on a San Diego beach. The waitress pours free refills and whispers "Don't tell the
General". The owner, beaming, calls an order for table five. Mom says it is time to go home, and then allows one
more turn. The sign KRYBOR lights up over the sea. Credits. After them, a shelf of plastic brood officers and one
glint.

Three rules shape it (research A1, A3):

1. **Nothing is taken back.** The victory is scored and celebrated before S1 starts, and the kids celebrate the
   same win. The frame adds a meaning; it does not delete one.
2. **The scene shows parts, never the sum.** No line or caption says it was a game.
3. **Every voice keeps its relationship to the player** across the cut.

## 2. Who is who

The kids cast their own families as the fleet and the restaurant's staff as the brood. The full table of 25
speakers is in the ledger §1.3 and the guide §4.

| Brief | Decision | Evidence |
|---|---|---|
| The Admiral is the mom | Fleet Adm. Imani Hale | her "home" lines (ledger C3) |
| The grumpy General is the smiling owner | GORRAK, Brood Marshal; the fleet calls him "the General" | no cast member is a General; he is the only grumpy voice, wears the only peaked cap, and is the officer of sector 1, Krybor (ledger §1.1) |
| The sassy purple cadet is the waitress | VEXXA, proposed rank label WING CADET, present in every sector from now on | the only sassy violet voice; "Enjoy it. I know the way back!" (ledger §1.2) |
| Krybor is the restaurant | the sign reads KRYBOR | the title, the Top 10 and sector 1 already say it (ledger P1, P2, U1) |

The brood speaks in glyphs with a gloss, and its audio is a reversed performance. In the cinematic the waitress,
the owner and the brood-side kids are heard forwards and unprocessed for the first time. That is a reveal in sound:
the "demon tongue" was kids doing monster voices (ledger C16, C17).

Runner-ups, should the operator mean humans: a new ground-forces General, and Ens. Wisp re-ranked to cadet or a new
violet cadet. Only the speaker ids in the mapping and the proposal file change; the shots and the ledger hold.

## 3. Shots

Seven shots in 29.0 s, then the credits, then a 3.0 s button (S8). The shot list with cameras, transitions and
lines is the storyboard README; the committed shot script (task 2.1) is the source of truth once it exists.

| Shot | Time (s) | Idea | Transition out |
|---|---|---|---|
| S1 The last piece falls | 0.0–3.5 | the carrier is a toy | match cut at 2.0, then the camera starts to rise |
| S2 The board | 3.5–8.5 | the war is a board game | cut on movement |
| S3 The players | 8.5–12.5 | the two sides are friends | cut on the pitcher |
| S4 Free refills | 12.5–17.0 | the cadet is the waitress | rack focus, cut in |
| S5 The General | 17.0–20.0 | the marshal is the smiling owner | cut on the bell |
| S6 Overwatch | 20.0–24.5 | the Admiral is Mom; one more turn | cut on her smile |
| S7 Krybor | 24.5–29.0 | Krybor is this place; next round | fade to credits |
| S8 The button | after credits, 3.0 | the pieces wait; a wink | cut to black |

The operator asked for "at least a few seconds"; 29 s is the shortest length that gives each of the five named
reveals (figures, waitress, owner, mom, Krybor) one shot and one idea (research A5). Every second can be skipped.

## 4. Runtime form: an in-engine layered scene

**Decision:** layered still plates moved by a data-driven timeline in the game engine. Not a video file.

Why (research B6):

- **Portrait and landscape from one scene.** The game runs on phones in portrait and on desktops in landscape. A
  video is one aspect ratio. The player frames each shot per aspect from 4:3 master plates.
- **The table remembers the run** (§6). A video cannot show this player's score.
- **Subtitles are text**, so they scale, stay sharp and can be translated.
- **Reduced motion** is the same scene with its motion switched off.
- **Size and loading.** About 7 MB of WebP and audio, fetched during the last fight. `video_player` is not a
  dependency today, and royalty-free codecs do not play everywhere.
- **Tests.** The timeline is pure Dart and can be evaluated without rendering.
- **Consistency.** Generated video is weakest exactly where this scene is sensitive: faces that must stay the same
  people, board pieces that must stay still, a sign that must be spelt right (research B4).

Parts:

- `assets/cinematic/endgame.json`, packed from `art/cinematic/endgame/shots.json`: per shot the duration, camera
  keys for both aspects, the subject box, layers (image, depth, anchor, payoff ledger ids), pose swaps, focus keys,
  subtitle and audio cues.
- `lib/ending/cinematic_timeline.dart` (pure Dart): `stateAt(t, aspect)` returns the shot, the camera, each layer's
  transform, blur and opacity, and the active cues.
- A player widget in `lib/ending/`: draws the layers back to front, blurs at most two layers at once, swaps poses,
  draws flames, smoke, surf glints and the neon in the painter, shows subtitles, plays clips through the game's
  audio bridge.
- The existing still reveal stays as the fallback when the assets have not loaded in 3 s.

Budgets (research B10; the plate sizes are estimates until the first pack): images ≤ 7 MB, audio ≤ 1.5 MB; at most
two shots' plates decoded at once; plates decoded at 1024 wide on small screens.

A single pre-rendered video cut is a possible later upgrade for large screens. It would be a separate change,
lazy-loaded, in royalty-free codecs only, with this scene as its fallback.

## 5. When it plays, skipping, replay

- It opens where the ending opens today: during the victory scene after the carrier of route 5, also on a resumed
  run. Earlier carriers are unchanged. Closing the credits leads to the completed result and score entry, with
  score, lives and medals untouched.
- Skip is visible from the first frame and leads to the credits. On the first viewing a first press arms the
  control for 2 s and a second press skips. On replays one press skips. Escape, Enter and the gamepad's back button
  do the same. The outcome of skipping is identical to watching (research A10).
- It pauses in the background and resumes where it stopped.
- Replay: the title's control (existing) and a new control on the medal screen, both only after the fifth carrier
  has fallen once. Before that neither screen names the cinematic. A replay changes nothing in the run or the
  saved record.
- S8 plays after the credits end or are closed after a full viewing. It is skippable like the rest.
- Console runs keep today's rule: the ending opens on the route-5 carrier.

## 6. The table remembers the run

Seven details come from data the game already keeps (ledger §2.11): R1 the score on the order ticket, R2 bottle
caps for medals, R3 heart tokens for lives, R4 the box lid's edition for the difficulty, R5 the chalkboard with the
player's initials and the last Top 10 fetched, R6 only this run's radio lineup on the patio, R7 one brood officer
on the S8 shelf per campaign finished on the device. They are typeset or toggled layers, so they cost no extra
images beyond the optional patrons. The spec requires at least three; the rest may land later.

This is the direct answer to "I wanna finish it again so I can see if…": a harder run, a cleaner run and a fifth
run each show something the last one did not.

## 7. Plants

- **Already in the game:** most ledger rows quote an existing line, label or art detail that the scene pays
  off with no change at all.
- **New lines** (`art/comms/endgame-lines.proposal.json`): 18 in the first set, 8 in the second. A first-set line
  must work as plain battle chatter. The director speaks at most one plant per sector. The second set becomes
  eligible once the ending has been seen on the device, and may wink at the room.
- **Schema:** two optional fields on a line, `plant` (ledger ids) and `set`. The `voice-stack` change owns the
  schema, the tone check and the recording; task 7.1 and 7.2 are done with it. The tone check rejects a plant line
  that states the frame.
- **The check** (task 7.6): every payoff layer in the shot script has a ledger row; every ledger row's shot, layer
  and line id exists. It keeps the ledger true as the game changes.
- **Art plants** are few and small (ledger §4.2): the teal chevron first.

## 8. Pipeline

**Decision:** no new pipeline or container. A new family type, the shot family, on the existing one (research B1,
B7). Every model the baseline needs is on the studio's disk (research B2).

| Stage | Tool | GPU | Checkpoint |
|---|---|---|---|
| Shot script and animatic | by hand; the player with grey plates | no | CP0, CP1 |
| Layout: blockout, cameras, clay, depth, normal, id | `tools/cinematic/layout.py` on `rigkit.py` (bpy, CPU) | no | sheet |
| Toy tip poses | `rigkit/bake.py` on the game's carrier mesh | no | sheet |
| Cast and figure sheets | committed Qwen-edit workflows | yes | CP2 |
| Keyframe stills from clay and depth, sheets as references | committed Qwen-edit workflows | yes | CP3 |
| Type layers: sign, menu, chalkboard, tickets, lid | typeset, never generated | no | CP3 |
| Layer plates and mattes | Qwen edit, BiRefNet | yes | sheet |
| Pose swaps; optional inserts | Qwen edit; Fun VACE, cropped | yes | CP4 |
| Grade, grain, pack | a new `rigsheet` verb (Go) | no | – |
| Voices and sound | `voice-stack`, tillandsias#1103 | yes | blocked |

Rules: run GPU stages through `lua tools/production/run.lua`, one studio job at a time; free VRAM with
`gpu.unload_model`; never `studio.restart`; commit picked raws, seeds and job files at every checkpoint; log each
pick with its reason in `plan/render-runs/endgame-cinematic.md`. Estimated GPU time is about 8 hours, 3.5 lean
(research B10).

Licences: every baseline model is Apache-2.0, MIT or OpenRAIL (research B2, B11). The pipeline check rejects a
workflow that names a model whose licence forbids commercial use of its outputs, because the repo is GPL-3.0 and
others may reuse it commercially. Prompts describe traits and never name a studio, film or artist.

Why not the other routes (research B3, B4): the repo has no character modelling, skinning, face rig or acting, and
Blender here is CPU-only, so an all-Blender scene is weeks of new craft. All-generated video drifts in identity,
moves the board pieces, misspells signs and does not splice across 5 s clips.

## 9. Canon

This change supersedes the earlier ending canon where they differ:

| Earlier | Now |
|---|---|
| On a San Diego beach | On the patio of Krybor, a beachfront restaurant in San Diego. Sand, sea, cooler and umbrella lines all still hold |
| Teenage human and demon friends | Kids of nine to twelve. The brood side wears horned hoodies. The waitress is the teenager |
| Nobody in the radio seems to know | Still true of the first set of plants. The second set, after the ending, may wink |
| Bonus missions as event cards: open | Canon: URGENT MISSION cards lie on the board in S2 |
| Do the players map onto call signs: open | Yes: ledger §1.3 |
| After the reveal, does a second campaign acknowledge it: open | Yes, through the second set of plant lines |

`plan/story-hooks.md` and the "Beach reveal and credits" requirement of `battle-metal-radio-rework` are reconciled
in task 1.4, after the operator's review.

## 10. Open questions for the operator

1. **The General and the cadet.** Gorrak and Vexxa (brood officers as the restaurant's staff), or human
   characters? If Vexxa: is WING CADET the rank label, and may the brood be voiced more plainly so players can
   follow a prominent character who speaks in glyphs?
2. **Length.** 29 s plus a 3 s button, or shorter? Cutting S3's second line and S5's push-in gives 25 s.
3. **Literal demons.** The current still shows two demon teenagers at the table. The new scene has only kids, and
   keeps one wink in S8. Agreed?
4. **The sign.** KRYBOR, as the UI spells it, or KRYBOR'S? And the small line under it: the boards try "burgers ·
   shakes · since 1982", a nod to the year of the game that inspired this one.
5. **Mom's age.** Forties with a silver streak (the kids imagine her as a sixty-year-old admiral), or a
   grandmother?
6. **The pilot.** Never shown and never voiced, so every player stays the pilot. Agreed?
7. **Second-run lines.** May lines that unlock after the ending wink at the room ("Back again? I kept your
   corner.")?
8. **Video.** If a video cut is ever made, royalty-free codecs only (AV1 or VP9), never H.264 in the repo?
9. **Kids' voices.** Two child voice identities are needed. If the admitted engine cannot make convincing ones,
   are subtitled kids with laughs and groans acceptable?
10. **Optional downloads.** RealESRGAN x4plus (66.9 MB, BSD-3-Clause) and Qwen-Image 2512 (20.4 GB, Apache-2.0)
    would raise the quality of the wide stills and the sets. Each needs a consent token when
    the work reaches it.

## 11. What we need

| From | What | When |
|---|---|---|
| Operator | CP0 review of the storyboard, guide and ledger; answers to §10 | now |
| Operator | CP1 to CP5 reviews | per stage |
| Operator | a consent token per optional model, only if a stage asks (`consent_required`) | stages 4 to 5 |
| Coordinator | studio time on the shared A5000: about 8 GPU hours, one job at a time | stages 4 to 5 |
| Coordinator | `voice-stack` admissions: an expressive TTS engine, the cast identities, two child identities, a "room" chain | stage 7 |
| Coordinator | tillandsias#1103: ambience and the ukulele bars | stage 7 |
| Coordinator | the reset-proof bpy toolchain image already requested (`plan/round2-research.md` §2.3) | stage 3 |
| `voice-stack` owners | the `plant` and `set` fields, the ration and the second-set gate, the plant tone check | task 7.1, 7.2 |
| `carrier-v3` owners | the final carrier mesh and the wreck's last frame for the match cut | task 3.2 |
| Nobody | no new model, node pack or container for the baseline | – |

## 12. Operator decisions (2026-11-17)

The operator approved the recommendations as written ("I approve of your recommendations for the end scene"). CP0
passes, and the §10 answers are the agent's picks:
1. The General is Gorrak and the waitress is Vexxa (WING CADET), so the brood are the restaurant's staff. Her lines may
   be voiced plainly.
2. 29 s plus a 3 s button.
3. Kids only at the table, with the one wink in S8.
4. The sign reads KRYBOR, with "burgers · shakes · since 1982" under it. The caption "San Diego · after the last turn"
   stays.
5. Mom is in her forties with a silver streak.
6. The pilot is never shown and never voiced.
7. Second-run lines may wink at the room.
8. A video cut, if ever made, uses royalty-free codecs only.
9. Subtitled kids, with laughs and groans, are the fallback for child voices.
10. The optional downloads still go through a consent token each, when a stage asks.

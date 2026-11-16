# Research: the carrier hatch cascade and component break-up (C4, C5, `carrier-hatches`)

This research backs round 3c, C4 and C5 in `plan/operator-feedback-2026-11-16.md`. The decisions it supports are in
`openspec/changes/carrier-hatches/design.md`, which cites the row IDs below (`[H1]`, `[B2]` …):
- **C4:** launch hatches on the carrier's top surface, knocked out tier by tier, down to a hatch the player can
  shoot;
- **C5:** spikes, plates and modules breaking off one by one, never as a whole layer.

## How to read the sources
Provenance follows CLAUDE.md §8:
- `[source: …, read 2026-11-16]`: the page was fetched on 2026-11-16 and the quote came from that fetch. The fetch
  tool returns pages through a summarising model, so re-check a quote on the live page before using it in
  user-facing text.
- `[source: …, unread: snippet only]`: seen only as a search-result snippet. **It does not make a claim sourced**, and
  the design uses such rows as context only.
- `[R]`: this repository (path given), read on 2026-11-16.
- `[UNSOURCED: plan/provenance-audit.md#CH-n]`: our own reasoning or engineering choice. See "Part CH" in
  `plan/provenance-audit.md`.

Game titles are references for technique only. The styleguide's originality rules apply
(`docs/styleguide/alien-capital-ships.md` §1).

## Access (2026-11-16)
- **Reached and read:**
  - `raw.githubusercontent.com`, `github.com`, `api.github.com`;
  - `patents.google.com`;
  - `scoutski.github.io`, `molbv.github.io`, `nvidia-omniverse.github.io`.
- **Refused (ECONNRESET, one attempt each):**
  - shmup wikis and guides: `strategywiki.org`, `shmups.wiki`, `shmups.system11.org`, `hardcoregaming101.net`,
    `tcrf.net`;
  - talks and audio middleware: `gdcvault.com`, `blog.audiokinetic.com`, `audiokinetic.com`, `fmod.com`;
  - game sites: `gamesradar.com`, `giantbomb.com`, `noobfeed.com`, `videogameschronicle.com`,
    `arcadethrowback.blogspot.com`;
  - engine docs: `gameprogrammingpatterns.com`, `unity.com`, `box2d.org`, `docs.flame-engine.org`,
    `docs.omniverse.nvidia.com`, `developer.unigine.com`;
  - other: `arxiv.org`, `lizengland.com`.
- **Not routed around.** No mirror, archive or host browser tool was used to reach a refused host.
- **Nothing verifiable found for:**
  - Treasure (Radiant Silvergun, Ikaruga), Cave (DoDonPachi, Mushihimesama), Raiden and Thunder Force hatch bosses;
  - Winifred Phillips' writing on adaptive music;
  - the official FMOD and Wwise documentation;
  - the Disney principles in their original form.

  carrier-v3's G8 row (`plan/carrier-v3-research.md`) recorded the same gap for Treasure and Cave.

---

## H. Launch hatches on a giant ship
| ID | Takeaway | Source | Quote |
| --- | --- | --- | --- |
| H1 | **A carrier boss whose launch hatches are targets in their own right.** Each hatch has its own hit points and opens to release enemies. Destroying every hatch summons the core phase, with a timer as the fallback. This is the closest precedent for "launch hatches, then the core". This change differs: its hatches fall to shield damage, and its last ones are the core's own openings. | [source: sonicdcer et al., sf64 decompilation (rebuilt from the Star Fox 64 cartridge, not Nintendo's own documentation), "src/overlays/ovl_i4/fox_ka.c", https://raw.githubusercontent.com/sonicdcer/sf64/master/src/overlays/ovl_i4/fox_ka.c, read 2026-11-16] | "Summon core if all hatches are destroyed or after 3 minutes from KaSaucerer appearance." · `this->swork[BOSS_HATCH_1_HP] = 100;` … `this->swork[BOSS_CORE_HP] = 400;` |
| H2 | **Knocking out one hatch is an event of its own**: smoke and an explosion at that hatch, a sound, a counter and a bonus, all placed at the hatch. So a hatch drop gets its own local effect and its own event (`bossHatchDrop`). | same file, `Katina_Hatch_Destroy`, read 2026-11-16 | `this->swork[BOSS_HATCH_DESTROY_COUNT]++;` · `BonusText_Display(pos.x, pos.y - 300.0f, pos.z, 5);` |
| H3 | Gradius II: hatches release squadrons until they are destroyed or scroll off. Context only. | [source: StrategyWiki, "Gradius II: Gofer no Yabou/Stage 2", https://strategywiki.org/wiki/Gradius_II:_Gofer_no_Yabou/Stage_2, unread: snippet only] | "several hatches which release squadrons of enemies until they are destroyed or scroll off the screen" |
| H4 | Gradius hatches are deliberately tough. Context only. | [source: StrategyWiki, "Gradius/Enemies", https://strategywiki.org/wiki/Gradius/Enemies, unread: snippet only] | "Hatches have a great deal of defense, and it take quite a lot of artillery to destroy them" |
| H5 | **Why the creatures vanish today.** The fight's flocks leave the deck bays (y 21) or the prong gates (y 52) and settle at `b.y + 70`. The prow spans hull-local y −78 … +66, and it is drawn after the creature loop. | [R] `lib/game/model.dart` `_updateBoss` (flock spawn), `lib/game/carrier_gates.dart`, `lib/game/boss_atlas.dart` (`prow.thorn` sprite: anchor −218.5, −78; 874 × 289 px at 2 px/unit), `lib/game/scene.dart` (the boss block after the creature loop) |
| H6 | **The shootable hatches already exist.** The deck bays at ±46 are the core's side hatches on the non-final forms, and the last form seals them, leaving the centre door. | [R] `openspec/specs/arcade-combat/spec.md`, "Carrier shield and door"; `lib/game/model.dart` `hitBoss`, `Carrier.sideHatchesLocked` |

## P. Progressive destruction
| ID | Takeaway | Source | Quote |
| --- | --- | --- | --- |
| P1 | R-Type's stage-3 battleship is taken apart piece by piece, not through one weak spot (the "battleship raid"). Context only. | [source: Arcade Throwback, "Bossfight: Gigantic Warship (R-Type)", https://arcadethrowback.blogspot.com/2012/07/bossfight-giganticwarship-r-type.html, unread: snippet only] | "this monstrosity needs to be taken apart piece by piece -- not just to defeat it, but in order to survive" |
| P2 | The same boss: the level is spent picking it apart, one emplacement at a time. Context only. | [source: GamesRadar, "The Top 7... Big Bosses", https://www.gamesradar.com/the-top-7big-bosses/6, unread: snippet only] | "picking apart, gun emplacement by burner rocket" |
| P3 | **Losing parts shows progress better than a health bar.** So the tiers dropping, and components breaking away, are the progress the player reads. | [source: Cooptayto, "Week 1 - Boss design!", https://scoutski.github.io/posts/boss-design/, read 2026-11-16] | "It's important for a player to feel like they're making progress with something other than watching a health bar go down." |
| P4 | **Damage breaks links, and each loose island becomes its own body.** In a pre-fractured destruction library, breaking the support graph's links creates new actors from the groups that come loose. So a component that releases is a new body, while the rest stays with the hull. | [source: NVIDIA, "Blast SDK: Introduction", https://nvidia-omniverse.github.io/PhysX/blast/docs/api/introduction.html, read 2026-11-16] | "Blast performs island detection on the support graph to find all groups of support chunks" · "any new islands found result in new actors." |

## A. Staging adds (minions) in a boss fight
| ID | Takeaway | Source | Quote |
| --- | --- | --- | --- |
| A1 | **Cap the adds and warn when the hatches open.** The Katina mothership opens its hatches only while fewer than 30 enemies are alive (or when a timer runs out), closes them after a fixed window, and plays a hatch-open sound and a radio line. So the existing caps stay, and the hatches telegraph, with the cascade chase pointing to the next tier. | sf64 `fox_ka.c` (as H1), read 2026-11-16 | `if ((enemyCount < 30) \|\| (this->timer_056 == 0)) {` … `AUDIO_PLAY_SFX(NA_SE_KA_UFO_HATCH_OPEN, ...)` · "Close hatches after 10 seconds." |
| A2 | **Spawn the adds as part of the boss's readable routine, and telegraph them.** So the launches come from the boss's own hatches on its readable cycle, and the creatures are seen before they are in play. | [source: Cooptayto, "Week 1 - Boss design!", https://scoutski.github.io/posts/boss-design/, read 2026-11-16] | "the additional enemies spawn as part of the bosses move rotation and then act independently of the boss." · "Telegraphs are universally useful" |
| A3 | **Every attack advertises itself, and difficulty rises through density or speed, not randomness.** So the pop-up, a path never aimed at the ship's row, and escalation by tier position and timer rather than by surprise. | [source: Aviar, "Boss phases: readable, learnable, beatable" (2025-07-08), https://molbv.github.io/blog/2025-07-08-boss-phases.html, read 2026-11-16] | "Every attack advertises itself." · "If you fail, you should know why." |
| A4 | Check the minion count before summoning more. Context only; A1 is the read source. | [source: Unity / Rubber Duck Games, "How Rubber Duck Games developed a boss fight in Evil Wizard", https://unity.com/blog/games/how-rubber-duck-games-developed-evil-wizard-boss-fight, unread: snippet only] | "there aren't too many minions already on the battlefield, then summons the minions" |

## J. Game feel
| ID | Takeaway | Source | Quote |
| --- | --- | --- | --- |
| J1 | **Break-up as separate, switchable effects**: shatter, rotation, push, gravity and darkening, with shake as its own tunable setting. So a component's tear, spin, kick, fall and fade are separate terms, each one constant, and reduced motion drops some of them. | [source: Martin Jonasson & Petri Purho, "juicy-breakout" `Settings.as`, https://raw.githubusercontent.com/grapefrukt/juicy-breakout/master/src/com/grapefrukt/games/juicy/Settings.as, read 2026-11-16] | `static public var EFFECT_BLOCK_SHATTER :Boolean = false;` · `static public var EFFECT_SCREEN_SHAKE_POWER :Number = .5;` |
| J2 | The demo was made for a talk at Nordic Game Indie Night. (GDC Vault also lists a "Juice It or Lose It" session; its page was refused.) Cite the venue as the README gives it. | [source: Martin Jonasson & Petri Purho, "juicy-breakout" README, https://github.com/grapefrukt/juicy-breakout, read 2026-11-16] | "An example that we made for a talk at Nordic Game Indie Night" |
| J3 | **Restrained shake**: a 0–1 trauma that decays, with small caps. So a hatch drop adds no shake, and the shake stays on carrier-v3's four trauma beats. | [source: Bevy Engine, `examples/camera/2d_screen_shake.rs`, https://raw.githubusercontent.com/bevyengine/bevy/main/examples/camera/2d_screen_shake.rs, read 2026-11-16] | "Trauma automatically decays over time." · "20.0 px is a low enough displacement to not be distracting." |
| J4 | Jan Willem Nijman's "The Art of Screenshake" (Vlambeer) is the reference talk. Only a recreation's README was read, not the talk. | [source: Colin Bellino, "screenshake" README, https://github.com/colinbellino/screenshake, read 2026-11-16] | "This project is a recreation (clone?) of the demo presented in the video "The art of screenshake"" |
| J5 | Swink's definition of game feel. Context only. | [source: Liz England, "Review: Game Feel by Steve Swink", https://lizengland.com/blog/review-game-feel-by-steve-swink/, unread: snippet only] | "real-time control of virtual objects in a simulated space, with interactions emphasised by polish" |
| J6 | Overlapping action: parts move at different rates, and it can be done procedurally. Context only. | [source: Jonathan Cooper, "The 12 principles of animation in video games", https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games, unread: snippet only] | "follow-through, overlapping action, and drag on nonanimated objects ... can be performed procedurally in the game engine" |

## B. Per-piece break-up and debris
| ID | Takeaway | Source | Quote |
| --- | --- | --- | --- |
| B1 | **Pre-fractured, hierarchical chunks.** Breaking a chunk creates its children, and pieces still bonded leave together. So components (and their fragments) are pre-computed at install, never cut at runtime, and a clump of thorns may leave as one. | [source: NVIDIA, "Blast SDK: Introduction", https://nvidia-omniverse.github.io/PhysX/blast/docs/api/introduction.html, read 2026-11-16] | "Blast is currently designed to support rigid body, pre-fractured destruction." · "Chunks are defined hierarchically, so that when a chunk is fractured its child chunks are created." |
| B2 | **A released piece starts with its parent's velocity at its own point**: linear velocity plus angular velocity × offset. It is the same formula as carrier-render-engine X1. | [source: Erin Catto, Box2D v2.4.1 `b2_body.h`, https://raw.githubusercontent.com/erincatto/box2d/v2.4.1/include/box2d/b2_body.h, read 2026-11-16] | `return m_linearVelocity + b2Cross(m_angularVelocity, worldPoint - m_sweep.c);` |
| B3 | **Every simulated body costs CPU**, so keep the pieces few: the 48-per-transition and 64/96 live caps. | [source: Erin Catto, Box2D `docs/simulation.md`, https://raw.githubusercontent.com/erincatto/box2d/main/docs/simulation.md, read 2026-11-16] | "Well it is expensive to simulate bodies, so the less we have to simulate the better." |
| B4 | **Allocate once, at the cap**: Flame's particle storage is fixed at its maximum, and a running effect allocates nothing. So the body and fragment pools are allocated at their caps. | [source: Flame Engine, `doc/flame/rendering/particles.md`, https://raw.githubusercontent.com/flame-engine/flame/main/doc/flame/rendering/particles.md, read 2026-11-16] | "Storage is allocated once, at maxParticles; a running effect performs no allocations." |
| B5 | **Smoke in world space** from each released piece, so it trails behind and never sticks to the piece. | [R] `plan/carrier-render-engine-research.md` X10, which is read (the Godot `GPUParticles2D` reference and the 2D particle docs) |
| B6 | **What breaks as a layer today.** A form change makes one `BossWreck` per module instance (`BossDirector._detach`). The spines are one sprite holding two `array` prims (7 great and 2 × 8 row spines). The S2 stage sheds every `plate` and `shard` tag in one re-compose. | [R] `lib/game/boss_director.dart` (`_detach`, the `plate` wrecks), `art/families/alien-carriers.json` (`slots.spines.sets.ridge`, `stages.S2.shed`) |
| B7 | **What the bake knows.** `build_hull` makes one object per prim, so an array is one object, and the `id` pass colours per instance (`instance_ids`). The array's path, count, drop and child frame define every element's root and direction, but nothing per element is rendered or exported. | [R] `tools/rigkit/rigkit.py` (`build_hull`, `render_pass`), `tools/rigkit/rig.py` (`instance_ids`) |
| B8 | **What the re-render adds**: heights, field data, fracture chunks (30–40 per hull, about 110 units apart, for the collapse), hinges, vortex points, door states, a gate map, clearings and overscan. Nothing is per component. | [R] `plan/render-runs/carrier-v3.md` K0 on `origin/work/carrier-v3-render` (ac9e31c5) |

## M. Adaptive music: tiers as song sections
| ID | Takeaway | Source | Quote |
| --- | --- | --- | --- |
| M1 | **Horizontal re-sequencing**: clips plus a transition table, with section changes triggered by the game and timed to the next beat or bar. So `bossHatchTier` is a section boundary, and the engine moves at its own next bar. The game never waits for the music. | [source: Godot Engine, `AudioStreamInteractive.xml`, https://raw.githubusercontent.com/godotengine/godot/master/modules/interactive_music/doc_classes/AudioStreamInteractive.xml, read 2026-11-16] | "Audio stream that can playback music interactively, combining clips and a transition table." · "Transition when the clip playback position reaches the next bar." |
| M2 | **Vertical layering**: stems in sync, added or removed by intensity. So `depth` is a continuous parameter. | [source: Godot Engine, `AudioStreamSynchronized.xml`, https://raw.githubusercontent.com/godotengine/godot/master/modules/interactive_music/doc_classes/AudioStreamSynchronized.xml, read 2026-11-16] | "Stream that can be fitted with sub-streams, which will be played in-sync." |
| M3 | Prior art: iMUSE's decision points branch the music on the game's state. | [source: Michael Z. Land & Peter N. McConnell, "Method and apparatus for dynamically composing music and sound effects using a computer entertainment system", US5315057A, https://patents.google.com/patent/US5315057A/en, read 2026-11-16] | "The decision points within the database comprise a composing decision tree" |
| M4 | Wwise's names for the two families. Context only. | [source: Audiokinetic, "About Dynamic Music Design Part 1: Design Classification", https://blog.audiokinetic.com/about-dynamic-music-design-part-1-design-classification/, unread: snippet only] | "vertical remixing (also called layering) and horizontal re-sequencing" |

---

## Conclusions and where they go
1. **Hatches on the top surface, in tiers, the topmost first.** The launch hatches are the targets and the boss's
   readable routine `[H1]` `[A2]`. Dropping them shows progress without a health bar `[P3]`. The tier counts and
   positions are ours: CH-1. → design §A2.
2. **Drops on the shield cells; then the core's own openings.** The cells are the decay the player already sees; the
   shootable openings exist `[H6]`; escalation comes from position and density, not randomness `[A3]`. The
   thresholds are ours: CH-2. → design §A3.
3. **Each drop is its own local event**, with effects at the hatch and an event `[H2]`. The next tier is telegraphed
   by the chase `[A1]` `[A2]`, which is ours: CH-3. No shake `[J3]`. → design §A8, §A10.
4. **Caps and arrival times unchanged.** The caps stay `[A1]`. Arrival invariance and the levers are ours: CH-4.
   → design §A4–§A6, §A11.
5. **Components, not layers.** Pre-fractured pieces become their own bodies when released `[P4]` `[B1]`, inherit
   `v + ω × r` `[B2]`, smoke in world space `[B5]`, and their effects are separate terms `[J1]`. Budgets come from
   `[B3]` `[B4]`. The transient memory estimate is CH-5, the schedule and rate rule CH-6, and the body constants CH-8. → design §B2–§B7.
6. **The art data does not exist yet** `[B7]` `[B8]`. The component pass and manifest are specified in design §B9;
   the size estimate is CH-7.
7. **Tiers are song sections** `[M1]` `[M2]` `[M3]`. → design §A8.

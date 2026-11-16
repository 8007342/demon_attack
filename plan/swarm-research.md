# Swarm, demon intelligence and cinematic flow: research (W3, W4, W5b)

Research date: 2026-11-15. Input: `plan/operator-feedback-2026-11-15.md` (W3 continuous swarm, W4 demon intelligence,
W5b cinematic flow). Output: the OpenSpec changes `continuous-swarm`, `demon-intelligence` and `cinematic-flow`.
This builds on `plan/atmosphere-research.md` §6–§11 (flocking into formation, arriving from depth) and
`plan/transition-research.md`. Those sources are not repeated here.

Citation status. The web pass ran with a sandbox that reset most page fetches (red3d.com, gameaipro.com and
steamstatic.com failed). Every URL below came back from search with a matching title, but only some were opened.
Formulas marked **‡** come from general knowledge of the cited work, not from a page read in this session. Check
them against the original before quoting them as the source's numbers. Values chosen for this game are our
tuning decisions. The sources support the principles, not the numbers.

## 1. What the code does today (baseline)

| Concern | Where | Today |
|---|---|---|
| Wave ladder | `lib/game/model.dart` `_spawnWave`, `_completeWave` | One roster per wave. Wave N+1 starts after wave N is cleared, with a `RunMode.transition` release of 1.4 s + reading time between them. |
| Early approach | `model.dart` `--- wave pressure` block | At ≤ 2/3/4 enemies (Easy/Normal/Hard) the next roster holds in the horizon fog, untargetable. It merges when the stragglers die, or after 10/8/6 s. |
| Reinforcements | `_updateReinforcements`, `_spawnReinforcementGroup` | 0–2 finite groups per wave, released by casualties or a 4.5 s fallback, with occupancy admission (initial roster + largest group). |
| Arrival motion | `lib/game/flock.dart` `ArrivalFlock` | Presentation only. 2–4 squadrons per batch, each on a cubic Bézier from the horizon. k=7 topological boids, offset pursuit, a parabolic altitude arc. Hands off to the model's slot with a β blend. A parity test proves the fight is identical with or without it. |
| Fighting motion | `_targetFormationPosition`, `_boidsOffset` | A fixed home slot (6-column grid) plus sinusoidal bob (±29 px x, ±14 px y), plus a ±8 px boids offset. This is the "hovering / little figure-eights" the operator complained about. |
| Dodging | `_evadeSmall`, `_evade`, `lib/game/swarm_policy.dart` | Ordinary creatures from sector 2 on: a 10→16→4 MLP (244 parameters) imitating a hand-written lookahead teacher (`scripts/train-policy.mjs`). One creature evades at a time, with a 3.2/2.4/1.8 s cooldown. Sentinels sidestep by rule. |
| Dives | `_updateDemons`, `_prepDive` | A global dive clock, concurrency caps 1–3, a 0.5 s radio beat (`divePrep`), a 0.55–0.9 s tell. The dive aims once at the ship's x (with lead for policy dives) and does not track. |
| Sentinel final rush | `hitDemon` (`lastStand`), `_updateDemons` | Chance 0.15 Easy / 0.25 otherwise, rolled at birth. Triggers at ≤ 25 % hull: a 0.9 s tell, then a straight 600 u/s line at the ship's x, then a sacrifice off screen. Its dive shield is **zeroed**. No radio line of its own (music has `lastStandTell`). |
| Facing | `lib/game/creature_motion.dart` | Bank-left/neutral/bank-right flight sets (rig yaw ±38°, roll ±12°, `plan/sprite-atlas.md`). Banked frames show only while |vx| ≥ 55 u/s and stop below 24, so slow hover is almost always neutral 3/4. |
| Shadows | `lib/game/scene.dart` `_swarmShadows`, `_arrivalShadow`; `flyover_background.dart` `paintShadow` | Arrivals cast a blurred silhouette shadow that fades out over entrance progress 0.75→1. In formation the shadow is a faint 3-rect smudge (alpha 0.5·near·low), almost invisible under the high formation. The ship's shadow is 3 grey rects. |

What this means for W3: everything the operator called a "ladder" lives in the model (transition phases, the
merge, the hover). The swarm look lives in presentation (`flock.dart`). A continuous swarm has to move the swarm
into the simulation, because once creatures circle, sweep and mill while fighting, the swarm decides where the
hitboxes are. That makes W3 a gameplay change, so it must be recalibrated (§7).

## 2. Sibling projects

### 2.1 atrapa: what it is, and what it is not

The operator expected "a small JEPA-style model trained to play snake". A full-text search of the clone (jepa, jev,
lecun, energy, latent, vicreg, world model, arxiv) finds **nothing**. atrapa is:

- **Game:** multi-snake "Tron" on a 16×16 grid, 2–4 snakes, last alive wins
  (`openspec/changes/grid-game-and-local-ai/design.md`).
- **Model:** a plain policy MLP, 252 → 64 → 32 → 3 (coast/left/right), 18,371 parameters, 73 KB float32
  (`packages/atrapa_train/lib/src/pipeline.dart`, `assets/policies/default/manifest.json`). The input is a
  hand-built egocentric 9×9×3 window, heading, speed and 4 ray distances (`packages/atrapa_rules/lib/src/observation.dart`).
  There is no encoder/predictor pair, no latent rollout and no energy head.
- **Training:**
  - Imitation of a flood-fill teacher (`FreeSpaceBot`, `packages/atrapa_rules/lib/src/bot.dart`): 702 k samples,
    AdamW, 8 epochs, 81 % held-out agreement, about 70 s.
  - Then REINFORCE self-play against a teacher/snapshot pool: 40 min on 16 Dart isolates. A checkpoint is adopted
    only if it does better on held-out selection seeds.
- **Runtime:** a hand-written dense evaluator in pure Dart (`lib/policy/local_policy.dart`). It decides only at
  grid-cell boundaries, about 2 Hz per snake. Measured p50 is 13–25 µs per forward pass on desktop VM or Chromium
  (`docs/measurements/forge-play.md`). Phones have not been measured.
- **Planning:** none. One forward pass, argmax.
- **Results:** 79.5 % wins against one teacher bot and 100 % against random bots.

The "JEV" name in this repo is unrelated to JEPA. `plan/policy.md` defines it as *Joint Evasion & Vectoring*, a
synthetic-imitation prior modelled on sibling `ranitas`'s `scripts/train-policy.mjs`. Our `SwarmPolicy` is already
the atrapa recipe at a smaller scale: imitate a scripted teacher, ship constant weights in Dart. The two ideas the
operator hoped for are latent prediction of the player and energy-based scoring of actions. They come from LeCun's
JEPA programme, not from atrapa:

- LeCun, *A Path Towards Autonomous Machine Intelligence* (2022), https://openreview.net/pdf?id=BZ5a1r-kVsf
- Assran et al., I-JEPA (2023), https://arxiv.org/abs/2301.08243
- Bardes et al., V-JEPA (2024), https://arxiv.org/abs/2404.08471

**Assessment for Dart at 60 fps on phones (10–60 creatures).**

| Option | Cost | Verdict |
|---|---|---|
| atrapa-size MLP (18 k MACs) per creature per frame | 40 × 18 k ≈ 0.7 M MACs/frame, roughly 1–4 ms on a phone (estimated at 3–5× slower than desktop) [UNSOURCED: plan/provenance-audit.md#R-16] | Too much every frame. Fine staggered at 10 Hz (about 0.2–0.6 ms). |
| Learned latent world model + planning (JEPA-like), top tier only | K=5 candidates × 8 steps × a 2 k-MAC predictor ≈ 80 k per decision | Affordable for 3–6 elites at 10 Hz. But it needs human play data we do not have, and it adds parity, versioning and retraining work. |
| Hand-written forward model + energy scoring | 30 bullets × 8 candidates × 15 steps ≈ 3.6 k distance checks per creature | Well under 1 ms for 40 creatures. We have the *true* state, so an exact closed-form forward model beats a learned one. |

**Recommendation (adopted in `demon-intelligence`):** do not train a JEPA. Distil its two ideas into hand-written,
deterministic behaviours:

1. **"Latent prediction of the player" becomes a `PilotModel`.** It predicts the ship's x at t + τ as a mean and a
   spread. The inputs are a short history (10 Hz ring buffer, 3 s), constant velocity with decay, and mean
   reversion to the lane the player habitually holds. This is a state-space forecast, which is what a JEPA
   predictor would learn to approximate here.
2. **"Energy-based action scoring" becomes a `DemonPlanner`.** For each candidate manoeuvre (hold, small or large
   sidestep left/right, climb, thread-dive), it rolls the exact kinematics forward over a short horizon against
   every live player shot. It sums an energy:

   E = w_d · danger(time-to-collision) + w_w · walls + w_c · crowding + w_l · leash − w_a · attack alignment
       + w_s · change

   It then picks by softmin with a tier temperature. This is exactly what our existing synthetic teacher
   (`scripts/train-policy.mjs`, `evaluateTeacherUtility`) already does for 4 actions and 1 shot. The top tiers run
   the teacher *directly* at runtime, extended to all shots and more candidates. The lower tiers keep the cheap
   MLP prior.

**What to reuse from atrapa:**
- Its *workflow*, if the MLP is ever retrained: a single rules package that the trainer and the app both use. For
  us, the Dart teacher becomes the source of truth and `train-policy.mjs` reads fixtures it generates. Also a
  checksummed weights manifest with parity fixtures (we have `assets/policy/manifest.json`), and checkpoint
  selection on held-out seeds.
- Its budget discipline: decide at a fixed rate, not every frame. Cap parameters (100 k) and per-decision time
  (2 ms).
- Self-play RL is **not** reused. Nothing in our game needs a learned strategy that a lookahead cannot compute.

### 2.2 cannonball: cinematic transitions and pacing

cannonball has no attract mode and no bosses. Its outro is still a candidate ("finish reveal → possible Top100
initials → return to box with new key", `docs/research/design.md`). What transfers:

- **Continuous transitions** (`openspec/specs/racing/spec.md`, "Continuous transitions"): preload the next region
  and blend scenery, music and radio while play continues. Story and hints SHALL NOT block. There is no compulsory
  loading screen. A stage change "SHALL clear stale input/lighting history, preserve prepared assets and carry
  speed" (review-levels spec).
- **Continuity editing** (`docs/garage-continuity.md`), citing Dominic Cianciolo, *The Cinematics of…*
  (NetherRealm, GDC Europe 2011, slides 10–20,
  https://media.gdcvault.com/gdceurope2011/slides/Dominic_Cianciolo_VisualArts_TheCinematicsOf.pdf):
  - Preserve subject direction, proportions and screen position through short motivated cuts. A fade alone is not
    continuity.
  - **No full-screen opaque wipe and no all-black frame.** Layers clear to the already-loaded live scene.
  - Skip completes immediately.
  - Reduced motion keeps the same semantic beats (7.6 s → 1.8 s, no camera translation or sway).
  - Duplicate beat events within 250 ms are ignored. Sound leads picture on its own bus.
- **Music** (`docs/platform.md`, `openspec/specs/audio/spec.md`): region music changes on the next bar. Immediate
  feedback is kept separate from scheduled musical handoffs ("no forced bar wait for a hazard cue"). Speech ducks
  music and never overlaps another actionable announcement.
- **Pacing** (`docs/research/design.md`), citing Booth's L4D Director (build-up, sustained peak, peak fade, relax),
  which changes "threat frequency/pacing rather than difficulty amplitude", and GameFlow (Sweetser & Wyeth 2005).
  Rule: never present a unique art beat, a complex junction and a radio instruction at the same instant.
- Its own source for "one normalized transition clock, overlapping visual/audio envelopes and immediate event
  feedback" is our `plan/transition-research.md`. The idea has come back round to us.

### 2.3 macron.dev: the ink-dot-loop animation job

There is no OpenSpec change for it. It is documented in `public/notes/2026-11-14-forge-seed-the-animation-from-canon-art.md`,
`art/animations/ink-dot-loop/recipe.json` and `art/tools/blockout_canon.py` (a Blender blockout whose depth pass
drives Wan 2.2 VACE; 72 frames at 12 fps). The techniques that transfer to a swarm choreographer:

1. **One beat clock.** Every actor is a pure function of (clock, its own phase offset). There are no per-actor
   timers.
2. **Overlapping envelopes.** `bump(a, b, c, d)` eases in over a–b and out over c–d. Reactions start before the
   lead action ends (the hand lifts at 12 while the stroke ends at 8–12), so motion never stalls.
3. **Per-instance phase offsets** (`sin(ph·3 + k·0.9)`), so a crowd never moves in lockstep.
4. **Continuous by construction.** The end state equals the next start state, so no reset frame pops. Seams are
   hidden in quiet beats, and only identical poses are blended.
5. **Measure, don't eyeball.** Smoothness is the mean frame-to-frame change (seam jolt 0.62 against 1.79 max), and
   collisions are checked in every frame (it caught two sign errors).
6. `public/lessons/keep-the-playfield-open.md`: one message per phase, near an edge, short and temporary.

## 3. Swarm behaviour (W3)

### 3.1 Flocking primitives
- **Reynolds 1987** (*Flocks, Herds, and Schools*, SIGGRAPH; https://www.cs.princeton.edu/courses/archive/spr01/cs598b/papers/reynolds87.pdf):
  separation, alignment and cohesion over perceived neighbours. ‡Separation gets the highest priority.
- **Reynolds 1999** (*Steering Behaviors For Autonomous Characters*, GDC; mirror
  https://ics-websites.science.uu.nl/docs/vakken/mcrws/papers_new/Reynolds%20-%201999%20-%20Steering%20behaviors%20for%20autonomous%20characters.pdf):
  - action selection / steering / locomotion layers;
  - seek, flee, pursue/evade, arrive, wander, path following, flow fields, leader following, unaligned collision
    avoidance.
  - ‡`steer = truncate(desired − v, maxForce)`. Pursue seeks `p_t + v_t·T` with `T ≈ d / maxSpeed`. Arrive uses
    `speed = maxSpeed · min(1, d / r_slow)`.
  - Implementation reference: Shiffman, *The Nature of Code* ch. 5, https://natureofcode.com/autonomous-agents/.
- **Topological neighbours** (Ballerini et al., PNAS 2008, https://www.pnas.org/doi/10.1073/pnas.0711437105):
  starlings track about 6–7 nearest neighbours regardless of distance, which keeps a stretched flock together.
  We already use k = 7. Keep it when the swarm stretches across fog depths.
- **Vicsek 1995** (PRL 75:1226, https://arxiv.org/abs/cond-mat/0611743): constant speed plus the neighbours' mean
  heading plus noise η. Order emerges below a critical noise level. ‡`θ(t+1) = ⟨θ⟩_r + U(−η/2, η/2)`. The noise
  is a per-species "discipline" dial: imps are noisy, elite squads are crisp.

### 3.2 Collective states we want on screen
- **Couzin et al. 2002** (*Collective Memory and Spatial Sorting*, J. Theor. Biol. 218:1–11,
  https://www.cs.princeton.edu/courses/archive/fall24/cos597C/bib/couzinKJRF.pdf): nested zones of repulsion,
  orientation and attraction.
  - ‡Widening the orientation zone moves the group **swarm → torus (milling) → dynamic parallel → highly
    parallel**.
  - The state reached depends on the previous one (collective memory).
  - This gives **one parameter** to animate a squad from a mill (holding, fighting) to a parallel stream
    (arriving, sweeping). Hysteresis makes the switch look decided rather than random.
- **StarDisplay** (Hildenbrandt, Carere & Hemelrijk 2010, Behav. Ecol. 21:1349, https://arxiv.org/abs/0908.2677):
  cruise speed, banking into turns and roost attraction reproduce murmuration shapes. Hemelrijk & Hildenbrandt 2011
  (PLoS ONE 6:e22479, https://pmc.ncbi.nlm.nih.gov/articles/PMC3150374) found that a wide, flat flock becomes long
  and narrow after a 90° turn. This is why a sweeping squad should *stretch* along its path, and why banking (our
  side renders) is the visual signature of a turn.
- **Lévy flight** (Viswanathan et al., Nature 401:911, 1999,
  https://havlin.ph.biu.ac.il/wp-content/uploads/Publications/vabhlrs426.pdf): for sparse targets the best search
  has steps with `P(l) ∝ l^−μ`, μ ≈ 2. ‡Sample with `l = l_min · u^(−1/(μ−1))`. We use it for scouts and for
  far-fog skeins "searching" before they lock onto a station. Later studies dispute how general Lévy foraging is [UNSOURCED: plan/provenance-audit.md#R-17];
  we use it as an aesthetic, not as biology.

### 3.3 Reacting to a predator (the player's fire)
- **Procaccini et al. 2011** (*Propagating waves in starling flocks under predation*, Anim. Behav. 82:759):
  agitation waves start near the falcon and travel outward faster than the flock. Waves go with lower predation
  success.
- **Storms et al. 2019** (*Complex patterns of collective escape in starling flocks under predation*, Behav. Ecol.
  Sociobiol. 73:10, https://link.springer.com/10.1007/s00265-018-2609-0): 182 hunts, six patterns: **flash
  expansion, blackening, wave, vacuole, cordon, split**. Flash expansion often leads to a split, and escapes grow
  more frequent as attacks increase. This is a menu for escalating the swarm's reaction to heavier fire.
  Plain-language summary: https://bou.org.uk/blog-hemelrijk-waves-of-terror-in-starling-flocks/.
- The fountain effect (split around the predator and rejoin behind it) is from fish-school studies (Pitcher &
  Parrish), not checked here. [UNSOURCED: plan/provenance-audit.md#R-18]
- **Adopted split:** the *look* of evasion (an agitation wave as a wing-tilt and position ripple smaller than a
  third of the hitbox, a vacuole closing after a kill) is presentation for every creature. The *gameplay* of
  evasion (moving the hitbox out of a shot) stays gated and calibrated, and belongs to W4. Otherwise "swarm
  realism" would silently make every creature dodge.

### 3.4 Arrival without batches
- **Galaga** (Namco 1981): no primary source for its paths was found. Clones (e.g.
  https://github.com/macuzza/python-galaga) rebuild them as chained cubic Béziers: entry path → formation slot →
  dive. The "ladder" we are replacing is this formation-grid convention.
- **L4D AI Director** (Booth, Valve 2009, https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf;
  already in `plan/difficulty-calibration.md`): spawn rate follows a build-up / peak / fade / relax cycle, not a
  wave counter. This is the model for a **continuous inflow whose rate is the pacing variable**.
- **Rubber-banding / DDA:**
  - Hunicke 2005 (*The Case for Dynamic Difficulty Adjustment in Games*, ACE '05) and Hunicke & Chapman's Hamlet
    (https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf): treat difficulty as supply and demand and
    intervene quietly.
  - Zanac's ALC (Compile 1986; secondary source https://en.wikipedia.org/wiki/Zanac): aggression rises with skill
    and drops on a lost life or a new area.
  - Battle Garegga rank (https://shmups.wiki/library/Battle_Garegga/Advanced_Rank) is the **warning**: hidden,
    unbounded and raised by scoring and power-ups, so experts suicide to lower it.
  - RE4's hidden performance rank (https://www.engadget.com/2015-06-03-resident-evil-4-difficulty.html) is an
    example of rank done invisibly and kindly.
- **Applied:** the inflow *accelerates* (less wait, shorter approach) when the player clears faster, as the
  operator asked. It never adds HP or births (our calibration rule). It relaxes after a lost life, as ALC does, and
  is capped per difficulty. Speed-up is the only lever, which is the Booth reading: timing, not amplitude.

### 3.5 Bullet-aware steering (W4)
- **Context steering** (Fray, *Game AI Pro 2* ch. 18, 2015,
  http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter18_Context_Steering_Behavior-Driven_Steering_at_the_Macro_Scale.pdf;
  GDC 2013 *The Next Vector*, https://gdcvault.com/play/1018230): an interest map and a danger map over N
  direction slots. ‡Mask the slots with more than minimum danger, take the best remaining interest, and
  interpolate. In our game the "directions" are a handful of manoeuvres, so this becomes the candidate set of the
  planner.
- **Utility AI** (Mark & Dill, GDC 2010, https://gdcvault.com/play/1012410; Mark, *Behavioral Mathematics for Game
  AI*, 2009): response curves normalised to [0, 1], then weighted-random choice. The tier temperature is our
  weighted-random knob.
- **ORCA** (van den Berg et al. 2011, https://gamma.cs.unc.edu/ORCA/): velocity obstacles over a horizon τ. A
  bullet is a non-reciprocal obstacle, so the demon takes all of the avoidance.
- **Time-to-collision energy** (Karamouzas, Skinner & Guy, PRL 113:238701, 2014, https://arxiv.org/abs/1412.1082):
  interaction energy depends on time-to-collision, not distance. ‡`E(τ) = k/τ² · e^(−τ/τ0)`. We use τ0 as the
  per-tier **foresight** (how far ahead a creature "sees" a shot coming). This is the danger term of the planner.
- Bullet-hell bots: nothing peer-reviewed was found. The student A*/D* dodgers and TouhouCV are weak sources and
  are not used.

## 4. Cinematic transitions and outros (W5b)

- **Juice** (Jonasson & Purho, *Juice It or Lose It*, GDC Europe 2012, https://gdcvault.com/play/1016487/Juice-It-or-Lose):
  feedback layered one at a time (tweening, squash, particles, shake, sound). Counterpoint: Kelly, *Don't Juice It
  or Lose It* (GDC 2014, https://gdcvault.com/play/1020861). Applied: the last kill of a sector gets an immediate
  stinger and a short hit-stop. Shake stays at ≤ 2 px and is off under reduced motion.
- **Game feel** (Swink 2008, *Game Feel*, Morgan Kaufmann): ‡a response budget of about 100 ms. A skip or a tap
  during a transition answers within one frame.
- **Tetris Effect** (Mizuguchi, MacDonald & Ishihara, GDC 2019; Famitsu report
  https://www.famitsu.com/news/201903/21173589.html): stage changes are timed to moments of mental slack, and
  stages flow "like an album". Applied: **the old sector's swarm becomes the new sector's swarm.** The flock the
  ship chases into the clouds is the flock that comes out of them in the next sector.
- **Boss transitions** (Keren, boss battle design, GDC 2018, via
  https://gamedeveloper.com/design/video-boss-battle-design-fundamentals): phases, telegraphs, patterns. Applied:
  the carrier's arrival is *announced by the swarm*. The brood parts (a vacuole), and the carrier descends into
  the hole.
- **Attract mode** (Lendino, *Attract Mode*, 2020; "Creating an Attract Mode for NES Games",
  https://www.gamedeveloper.com/programming/handsome-meat-creating-an-attract-mode-for-nes-games): a demo loop
  driven by recorded input or an AI. We already own a deterministic AI pilot (the real-shot campaign pilot in
  `test/campaign_playtest_test.dart`). It is a ready attract-mode demo, left as optional work.
- **Gaps:** no primary technical write-ups of the stage transitions in Rez, Ikaruga or Space Invaders were found.
  GMTK has no video specifically on endings. Neither is cited.

## 5. Decisions taken from the research

| # | Decision | Basis |
|---|---|---|
| R1 | A wave becomes an accounting **cohort** (roster, finite groups, escort, elite budget, checkpoint). On screen it is a continuous stream of **skeins** (3–6 creatures) on parabolic swoops out of the fog. | Booth; operator W3; `plan/difficulty-calibration.md` (budgets unchanged) |
| R2 | The inflow rate is the pacing variable. It speeds up when cohorts clear faster than expected, relaxes after a lost life, and is capped per difficulty. It never adds HP or births. | Booth, Hunicke, Zanac ALC; Garegga as the warning |
| R3 | Squads fight in Couzin states (mill, sweep/parallel, ribbon, cloud) driven by one orientation-zone dial with hysteresis. The rigid hover is retired except as onboarding and in fixtures. | Couzin 2002; StarDisplay; operator W3 |
| R4 | Visible evasion (agitation wave, vacuole, flash expansion) is presentation and bounded below a third of the hitbox. Gameplay dodging is W4's tiered planner. | Procaccini 2011; Storms 2019 |
| R5 | Sustained lateral motion and squad-shared heading make banked (side) renders the common case: hysteresis 38 / 16 u/s, 0.28 s hold. | Hemelrijk 2011 (banking signature); `plan/sprite-atlas.md` |
| R6 | Every airborne creature keeps a silhouette shadow from its altitude. The ship gets a silhouette shadow too, and shadows interact (a diver's shadow converges on the ship's). | operator W3; `plan/atmosphere-research.md` §3 |
| R7 | Intelligence tiers = what each creature runs: an MLP prior (T0/T1); an energy planner over exact kinematics with a `PilotModel` forecast (T2 elites); a scripted sentinel rush that uses the same forecast (T3). Skill raises precision and timing within caps. | atrapa assessment §2.1; Fray; Karamouzas; Mark |
| R8 | Transitions are swarm events on one normalized clock, built from `bump` envelopes, with no opaque wipe or all-black frame, skip in one frame, reduced-motion beats, and music on bars. | cannonball; Cianciolo; macron.dev; Tetris Effect; `plan/transition-research.md` |

## 6. Art available for sideways facing (W3)

- **Ordinary gargoyles** (`assets/images/combat.png`, `plan/sprite-atlas.md`):
  - every flight set has three directions: columns 0–9 bank left, 10–19 neutral 3/4, 20–29 bank right;
  - these are real rig renders (yaw ±38°, roll ±12°), not mirrors;
  - each comes in five damage variants (rows base+0…base+4) with hit-flash slots (base+5, base+6);
  - elite overlays exist per direction (base+8, `direction × 4 + level`).

  **Everything W3 needs is already drawn.** The renders are simply shown too rarely, because the hover rarely
  exceeds the 55 u/s turn threshold.
- **Sentinels** (`sentinel-effects.png`): no directional sets. The bank is a canvas rotate (±0.08 rad) and squash.
  The silhouette sheet (`sentinel-silhouettes.png`) has banking frames for the foreshadow.
- **Optional art follow-up** (not in W3 scope, operator to decide): a true profile set (yaw ±70°) would need a new
  sheet (`combat.png` has only 2 spare columns per row). `tools/gargoyle_rig.py` already takes a yaw parameter. A
  sentinel bank set could be rendered the same way.

## 7. Calibration and validation stance

The current guards:
- `test/difficulty_calibration_test.dart` (318 generated waves, shared HP and budgets);
- `test/campaign_playtest_test.dart` (a real-shot pilot completing the campaign in every mode);
- `test/wave_pressure_test.dart`, `test/reinforcement_pressure_test.dart`;
- `test/combat_balance_test.dart`, `test/swarm_policy_test.dart`, `test/perspective_difficulty_test.dart`;
- the comms pacing simulation (`test/comms_pacing_sim.dart`).

How each change keeps them valid:

- **Budgets** (roster, groups, escort, HP, elites, occupancy) must stay bit-identical. The 318-wave audit runs
  unchanged.
- **Timing and motion change** (W3 patterns, W4 dodging). Validate with the campaign pilot extended to record, per
  sector and mode: wave clear time, hit ratio, peak active, hostile bullets and lives lost under a non-invulnerable
  "average pilot" variant. The existing review triggers apply: an ordinary-wave clear-time jump above 25 % within a
  sector, and a reinforcement needing more hits than its parent. Add a hit-ratio drop above 15 % against the
  baseline recorded before W3 lands (`plan/calibration-current.md`).
- **Human play remains the acceptance** for "properly scary and fast" and "feels like one swarm". Review frames and
  the preview playtest are listed in each change's tasks.

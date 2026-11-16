# Design: demon intelligence and the sentinel final rush

Research: `plan/swarm-research.md` §2.1 (atrapa assessment) and §3.5 (bullet-aware steering). This design builds
on `continuous-swarm`. Rates are at hostile rate. s is the skill level (§4).

## 1. Approach: distil, do not train

| Option | Decision | Why |
|---|---|---|
| Ship a JEPA-like latent world model | **No** | No human play data. We have the exact state, and an exact forward model beats a learned one. It would add parity, versioning and retraining work. |
| Retrain a bigger MLP (atrapa scale) | **No (for now)** | 40 × 18 k MACs per frame is 1–4 ms on a phone. [UNSOURCED: plan/provenance-audit.md#C-07] It is not needed when a lookahead is this cheap. |
| Hand-written forecast + energy planner | **Yes** | It is the teacher we already trust (`scripts/train-policy.mjs`), made exact and multi-shot. It costs < 0.3 ms per frame and is deterministic and testable. |
| Keep `SwarmPolicy` | **Yes** | It is the T0/T1 prior, already calibrated and tested (`test/swarm_policy_test.dart`). |

The atrapa *workflow* is adopted for the day the MLP is retrained:
- the Dart planner (§3) becomes the teacher of record;
- `train-policy.mjs` reads planner-generated fixtures instead of its own JS copy of the teacher;
- weights keep a checksummed manifest with parity fixtures (`assets/policy/manifest.json`);
- checkpoints are selected on held-out seeds.

This is optional, and task 7 only records it.

## 2. `PilotModel`: forecasting the player (`lib/game/pilot_model.dart`)

This is the distilled "latent prediction". It forecasts the ship's x at t + τ as a Gaussian.

- **History:** a ring buffer at 10 Hz of (shipX, shipVx), 30 samples (3 s). The lane mean m is an EWMA of x with a
  6 s time constant. The jitter j is the standard deviation of x about a 1 s moving mean.
- **Forecast:**
  - mean: `μ(τ) = x + v·τ·e^(−τ/0.5) + (m − x)·(1 − e^(−τ/1.2))`
  - spread: `σ(τ) = 8 + 0.5·|v|·τ + j`

  This is constant velocity with decay, plus mean reversion to the lane the player habitually holds.
- **Use:**
  - aim points for T2 dives and the T3 rush;
  - `P_hit(x, τ) = Φ((x + w − μ)/σ) − Φ((x − w − μ)/σ)`, with w the ship's contact half-width, for scoring.
- **Selection by skill.** Below s 0.4, aim uses today's `shipX + shipVx·0.22`. At or above 0.4 it uses
  `argmax_x P_hit`, which is μ(τ) for a Gaussian, at τ = the dive's time to the ship row.
- **Cost:** O(1) per query.

## 3. `DemonPlanner`: energy-based action scoring (`lib/game/demon_planner.dart`)

Candidate manoeuvres are displacements over a duration D (0.32 s, as the teacher):

| id | Δx | Δy | tiers |
|---|---|---|---|
| hold | 0 | 0 | all |
| sideL / sideR | ∓22 · scale | 0 | T1, T2, T3 (T3 uses ∓54 · scale) |
| wideL / wideR | ∓40 · scale | 0 | T2 |
| climb | 0 | −18 | T2 |
| thread | toward the aim, ±36 | +44 | T2 dive commit only |

**Energy** of candidate a. The path is approximated as constant velocity `v_a = Δ/D` from the creature's
position.

- **Danger.** For each visible player shot, compute the time-to-collision τ_c between the candidate path and the
  shot. Treat it as circle versus point, with radius `hitHalfWidth + 3`, which has a closed-form quadratic. Then
  `E_danger = Σ 1/τ_c² · e^(−τ_c/τ0)` for τ_c ≤ H (Karamouzas et al. 2014). Here τ0 is the tier's **foresight**
  and H = 1.5 τ0.
- **Walls:** `E_wall = 1.9 · max(0, 34 − x_end, x_end − 326)`, as the teacher.
- **Crowding:** `E_crowd` is the teacher's crowd-balance penalty, from the k = 7 neighbours.
- **Leash:** `E_leash = 0.002 · (x_end − T_x)²`. It stays with the squad's pattern target T.
- **Attack:** `E_attack = −w_a · P_hit(x_aim, τ_dive)`. Thread candidate only.
- **Change:** `E_change = 0.3` if a differs from the last action. This is hysteresis against dithering.

Weights start from the teacher's: danger 1, wall 1, crowd 0.4, leash 1, attack 0.8, change 1. Task 2.4 tunes
them.

**Choice:** softmin `p(a) ∝ exp(−E(a)/T)`, sampled from the planner's own seeded PRNG (separate from
`model.random`). As T → 0 it is argmin.

**Perception delay δ.** The planner ignores shots younger than δ, and sees older shots where they were δ ago
(`pos − vel·δ`). This models reaction time with no extra memory.

**Rate and budget.** Each creature decides at 10 Hz, staggered by seed: about 6 decisions per frame at most. Per
decision the cost is 7 candidates × ≤ 24 shots × 1 quadratic, under 2 µs in the VM. Total < 0.3 ms per frame.

**Implementation notes (as built).**
- The candidate path is piecewise: constant velocity Δ/D for D, then at rest at the end point (exact kinematics
  of the manoeuvre, two quadratics per shot). The end point is clamped to the formation's arena (x 20–340).
- The time-to-collision floor is 0.01 s (0.05 s made every candidate equal when a shot was already close).
- Walls charge only a move toward the edge (as the teacher, which never charges *hold* for where it is).
- The planner decides only when *hold* is threatened (some shot contacts it within H). With no threat the
  creature holds without a draw, so the softmin never makes a safe hunter twitch.
- Measured cost (test/demon_planner_test.dart): 6 decisions × 24 shots × 7 candidates ≈ 17 µs (VM median).

**Teacher parity (task 2.2).** `node scripts/train-policy.mjs --fixtures` exports the 4 000 held-out states
(`test/fixtures/policy_heldout.json`, raw state + teacher label; training is untouched and still reproduces the
committed weights byte for byte). With one shot, the T1 candidates and the teacher's geometry (no perception
delay, its 24-u clearance = 16 + 8, its 26-u evade span, its 0.85 vertical distance scale), the planner's
argmin agrees with the teacher on **98.2 %** of the 2 082 states that some action escapes, and on 94.7 % of all
3 140 non-dive states. The systematic disagreement is the other 1 058 states, where *no* action escapes: the
teacher then minimises penetration depth, the planner maximises the time to contact. Both are hit; the planner is
the exact version. (`dive_commit` labels are left out: T1 has no thread candidate.)

**Weight tuning (task 2.4).** `test/planner_sweep_test.dart` (`--dart-define=PLANNER_SWEEP=true`) scores 90
weight sets on teacher parity (escapable states), survival of 2 000 seeded synthetic multi-shot states (1–6 shots,
a third angled; survival = the chosen T2 manoeuvre meets no shot, among the states some manoeuvre escapes) and calm
(holds when hold is safe). The danger weight is the only strong lever: survival 53 % at 1, 85 % at 3, 89 % at 8,
90 % at 12; parity rises with it (95.7 → 98.2 %). Leash 0.5 beats 1 (the hunter may leave its slot a little
further); crowd and wall barely matter. A near-miss clearance term was tried and lost everywhere, so it was
removed. **Chosen: danger 8, wall 1, crowd 0.4, leash 0.5, attack 0.8, change 1** (8 rather than 12: the same
survival within 1.7 points, and smaller energies keep the hunter softmin meaningful between safe moves).

## 4. Tiers

| | T0 drone | T1 skirmisher | T2 hunter | T3 sentinel |
|---|---|---|---|---|
| who | `!elite && kind < 2 && maxHp < 3` | `!elite && (kind ≥ 2 \|\| maxHp ≥ 3)` | `elite` | `isLarge` |
| evade brain | `SwarmPolicy` (today) | `SwarmPolicy` proposes; planner {hold, sideL, sideR} vetoes a proposal whose E_danger exceeds hold's | planner, 6 candidates (no thread) | planner {hold, sideL, sideR} with T3 spans |
| δ (s) | n/a | 0.22 | 0.30 → 0.12 | 0.25 |
| τ0 (s) | n/a | 0.32 | 0.45 → 0.65 | 0.55 |
| temperature T | n/a | 0.25 | 0.5 → 0.15 | 0.2 |
| cooldown (s) | 3.2 / 2.4 / 1.8 (today) | same as T0 | 1.6 → 1.1 | 1.4 (today) |
| concurrency | one T0/T1 evader at a time (today) | ← shared | one hunter evading at a time, its own slot | — |
| dive aim | today | today | `PilotModel` from s ≥ 0.4 | rush (§6) |
| dive path | today (straight to the fixed aim) | today | **thread dive** (§5) | rush |

"a → b" means interpolated by s ∈ [0, 1]. Gating stays as today: no evasion in sector 1 on route 0
(`level < 2 && cycle == 0`), and none while a sentinel waits for its escort. Elites exist only on route ≥ 1
(`eliteBudget` is 0 on route 0), so hunters arrive with the second tour. Nothing is added to route 0.

## 5. Thread dives: "dive between player fire"

A hunter's dive keeps today's contract. The aim point x* is fixed when the tell starts, and the dive does not
track the ship (`plan/game-design.md`). Only the *path* to x* changes.

- Every 0.1 s during the dive, choose a lateral velocity from {−110, 0, +110} · tempo by minimising
  `E_danger + 0.004 · (x(t + 0.3) − x*_line(t + 0.3))²`. Here `x*_line` is today's straight dive line toward x*.
- |x − x*_line| ≤ 60 at all times. Lateral acceleration is ≤ 900 u/s².
- At the player's fire interval (0.23 s) and shot speed (385 u/s), consecutive shots are about 88 units apart in
  y. A diver with a body of about 40 can pass between them, and the planner finds that gap.
- The dive shield (tier 2–3 thermal, existing) is unchanged. The dive's vertical speed is unchanged.
- **Pincer** (s ≥ 0.5, probability 0.35 · (s − 0.5)/0.5). When the dive clock picks a hunter and a second hunter
  is ready inside `_maxConcurrentSmallDives`, both get a tell. Their aims are `μ ± 34`, either side of the
  forecast. Two tells and two radio beats are shown: nothing hidden, still capped.

## 6. Sentinel final rush (`lib/game/sentinel_rush.dart`)

### 6.1 When
- **Eligibility.** The birth roll stays one draw of `model.random`, `u = random.nextDouble()`, stored on the
  demon, so the random sequence is unchanged. The demon is eligible when
  `u < p_base + 0.10 · s`, with p_base = 0.20 / 0.35 / 0.45 (Easy / Normal / Hard). Today's values are
  0.15 / 0.25 / 0.25. This is "a little more often".
- **Trigger:**
  - `hp / maxHp ≤ 0.25` (unchanged); **or**
  - alone: escort spawned and dead, no ordinary creature present, and `hp / maxHp ≤ 0.5`.
- It still overrides divePrep, telegraph and dive (as today).

### 6.2 Rush shield
- `rushShieldMax` = 3 / 4 + cycle ~/ 2 / 5 + cycle ~/ 2. It is raised at the trigger, and the dive shield stays 0.
- Every player hit damages it by the breaker damage
  `damage + (powerful ? 1 : 0) + (large ? 1 : 0)`, and homing hits count. Unlike the sentinel dive shield, it does
  **not** require an offensive power: the rush must be answerable with the base gun.
- While it holds, hull, shield and armour take nothing.
- **Breaking it mid-rush:**
  - score `400 · (cycle + 1) · enemyPoints`;
  - a 0.45 s stagger (speed × 0.4, tumble frames);
  - the event `rushShieldBroken`.

  The hull then takes normal damage. There is no damage multiplier, and HP math is unchanged.

### 6.3 Sequence per pass

| Phase | Time | Behaviour |
|---|---|---|
| rally | 0.60 s | rises 28 u and pulls back in depth (nearness −0.05); eyes flare; the escort flash-expands (cosmetic); `sentinelRushTell` fires with `rushIn = rally + lock`; music `lastStandTell`, intensity 4 |
| lock | 0.50 s (Hard 0.45) | shudders ±2 px; aim `x* = PilotModel.μ(τ_rush)`; its shadow snaps over the ship's shadow; brood `sentinelRush` war cry |
| rush | until it leaves the arena | speed ramps 0 → v_max over 0.22 s, v_max = 640 / 780 / 880 (× hostile rate). It homes toward `μ(τ_remaining)` with turn rate ≤ 0 / 50 / 75 °/s while `y < shipY − 150`, then is committed straight. Scale grows to the 1.25 cap. Shake ≤ 2 px, none with reduced motion. |
| recover | 1.2 s | after a miss: it exits the bottom, comes around through the fog (the `reentering` path from W3), and reappears from depth at the top; `sentinelRushAgain`. Untargetable while off screen. |

- **Passes:** 1 / 2 / 3 (Easy / Normal / Hard). After the last pass it sacrifices off screen, as today: no reward,
  the large blast.
- **Contact:** a lost life unless shielded (the existing contact rule). A hit with the ship's shield up breaks the
  shield and ends the pass.
- **Total tell** before any motion toward the ship: 1.10 s (Hard 1.05 s; at 1.05 hostile rate, 1.0 s real). This
  is never shorter on later passes.

### 6.4 Fairness and scariness, as tests
- **Escape guard.** A scripted dodger starts moving away from x* at lock end, at the ship's 360 u/s acceleration
  profile. Over 200 seeds per difficulty and route, it survives ≥ 99 % of passes. The homing limit is the lever if
  this fails.
- **Threat guard.** A stationary ship at the aim is hit on ≥ 90 % of passes.
- **Corridor guard.** The homing lateral reach over the homing window is less than the dodge reach
  (360 u/s × remaining time − ship half-width). This is checked analytically per difficulty in the test.
- **Readability.** Rally plus lock is ≥ 1.0 s real at every difficulty. The radio tell ends within 0.3 s of the
  rush start.

### 6.5 Presentation
- **Berserk aura:** a procedural crimson-to-black thermal bow, larger than the dive shield (about 128 px), a smoke
  trail, and a ring that shrinks with the rush shield. It is drawn in `scene.dart` next to
  `_sentinelDiveShield`.
- **Frames:** the existing last-stand rows (6 + species), with rush frames 4–7.
- **Shadow:** at its largest; converges on the ship (W3 §8).

## 7. `SkillMeter`: reacting to skilful play (`lib/game/skill_meter.dart`)

- **Inputs,** updated each second of combat:
  - accuracy a: hits / shots over a 20 s window;
  - tempo p: the last cohort's `T_expected / T_actual` (W3);
  - dodges d: hostile shots passing within 16 u of the ship without contact, per minute.
- **Target:** `ŝ = clamp(0.4·n(a; 0.25, 0.65) + 0.4·n(p; 0.8, 1.6) + 0.2·n(d; 2, 10), 0, 1)`, where n is linear
  normalisation between the two bounds.
- **Update:** `s += (ŝ − s) · (1 − e^(−1/20))`, then clamp to the cap: Easy 0.5, Normal 0.8, Hard 1.0.
- **Lost life:** `s ← max(0, s − 0.35)`, and the target is frozen for 10 s (Zanac ALC relaxation).
- **Deterministic:** derived from state only. Restored checkpoints reset s to 0.3.
- **Deliberately excluded:** score, power-ups and time survived. This is the Battle Garegga warning: skill, not
  greed, raises it. Suicide therefore gains nothing beyond what dying costs.
- **Effects:** T2 δ, τ0, T and cooldown (§4); PilotModel aim at s ≥ 0.4; pincers at s ≥ 0.5; rush chance
  +0.10·s.
- **Never affects:** HP, births, the dive cap, the bullet cap, fire intervals, roster or groups.
- **Diegetic surfacing:** when s rises through 0.65 (once per sector), brood `broodAdapting` chatter. Nothing on
  the HUD (`ux-declutter`).

## 8. Radio chatter (lines to record)

`art/comms/lines.json` gets new triggers. Each line gets `"placeholder": "<existing clip id>"` where a truthful
borrowed line exists.

**Pipeline** (`tools/comms_pipeline.py dart`):
- When `web/audio/comms/<own id>.ogg` is missing and a placeholder is set, the pipeline emits the line with its own
  `id`, `clip: <placeholder id>`, and the **placeholder's text or gloss, mouth, open, vis and duration**. The
  subtitle therefore always matches the audio.
- Lines with neither their own clip nor a placeholder are left out of the bank. Their trigger is silent until
  recorded.
- The pipeline writes the list of pending lines (id, speaker, emotion, text) to
  `plan/audio-studio/voice-batch-pending.md`, for the audio studio batch blocked on tillandsias#1103.
- `CommsLine` gains `clip` (default `id`). `comms-audio.js` loads `clip`.

| Trigger | Class / priority | Lines to record (speaker, emotion: text) | Placeholder |
|---|---|---|---|
| `sentinelRushTell` | urgent 10, ttl 1.2, cooldown 6; end-aligned to `rushIn` | admiral, urgent: "It's going berserk! Get out from under it!" · kestrel, panicked: "Sentinel's locked on you. Break hard, now!" · anvil, urgent: "That shield won't crack in time. Dodge it!" · sparrow, panicked: "It's charging! Move, move, move!" · lindqvist, urgent: "Eyes are locked. Sidestep on the flash!" | `sentinelDive.h0`–`h4` ("It's diving! Move!", "Sentinel dive! Get clear!", "Big one's committing. Sidestep now!", "Incoming! Dodge, dodge, dodge!", "Dive! Break left or right, now!"), matched by speaker where the lineup allows |
| `sentinelRush` (demon, exchange: demon first) | useful 9, delay 0 | gorrak, warcry, gloss "For the brood!" · vexxa, warcry, "Wings to the throat!" · skarn, warcry, "Burn with me!" · morth, roar, "The hollow takes you!" | `divePrep.d0`–`d3` ("Wings in!", "Down we go!", "Watch this!", "My turn!") |
| `sentinelRushAgain` | urgent 9, ttl 1.5 | kestrel, urgent: "It's coming around again!" · rook, panicked: "Second pass! Watch the fog!" · admiral, stern: "It's not done. Here it comes again!" | `sentinelDive` lines not used by the tell this pass |
| `rushShieldBroken` | useful 8 | anvil, excited: "Its shield's down! Pour it on!" · sparrow, triumphant: "Cracked it! Hit it while it reels!" · lindqvist, urgent: "Shield's gone. Finish it!" | none truthful, so silent until recorded |
| `rushSurvived` | flavour 5, chance 0.6 | sparrow, excited: "Whoa. Still in one piece?" · rook, teasing: "That was way too close!" · admiral, calm: "It missed. Now make it pay." | none, so silent until recorded |
| `sentinelRushMissed` (demon) | flavour 4, delay 0.3 | gorrak, snarl, gloss "Again! AGAIN!" · vexxa, alarm, "Slippery little ship!" | `demonRout.d1` ("Hold on, hold on!"), `demonRout.d2` ("Not part of the plan!") |
| `broodAdapting` (demon) | flavour 4, once per sector | gorrak, order, gloss "This one bites. Send the hunters." · morth, gloat, "It learns. So do we." | `broodTaunt` lines whose gloss is a generic taunt (pick by reading the bank) |

Append only. Clip ids follow the bank rule `<trigger>.h<n>` / `.d<n>`, and existing lines are never reordered.

## 9. Calibration plan

- **Baseline.** W3's post-change metrics plus `AveragePilot` lives lost per sector (`plan/calibration-current.md`,
  "Post-W3").
- **New metrics,** recorded in `test/support/swarm_metrics.dart`:
  - per tier: hit ratio and evasions per minute;
  - dive outcomes: hit ship / dodged / shot down;
  - rush outcomes: pass hit / dodged / shield broken / sacrificed;
  - the s trajectory for the invulnerable real-shot pilot (as the "expert") and for `AveragePilot`.
- **Acceptance** (Normal, against Post-W3):
  - every campaign completes (invulnerable pilot);
  - per-sector ordinary-wave clear time ≤ +10 %;
  - T2 hit ratio drop ≤ 25 % (they are meant to be harder), T0 and T1 ≤ 5 %;
  - `AveragePilot` lives lost per sector ≤ +0.3, the rush included;
  - expert s reaches ≥ 0.7, average s stays within 0.25–0.55;
  - every rush fairness guard (§6.4) passes;
  - bullets ≤ 120;
  - dive concurrency never above `_maxConcurrentSmallDives`.
- **Easy route 0** must show *no* change in metrics beyond W3's: there are no elites and no sentinels there.
- **Human acceptance:** an operator playtest of a route-1 sentinel wave on Normal, judged by the operator's words
  "properly scary and fast", with a capture from the preview.

## 10. Decisions taken on the operator's behalf
1. **No JEPA and no new training.** atrapa holds no JEPA. Its ideas are distilled (§1). The MLP stays for T0/T1.
2. **"Top enemies" = elites** (hunters), plus sentinels. The budget is unchanged, so they first appear on route 1.
3. **Dives keep a fixed aim.** Weaving reacts to bullets, not to the ship. This keeps the existing "dives do not
   continuously track" fairness rule. Only the sentinel rush homes, and only with a bounded turn rate before a
   commit line.
4. **Skill changes precision and timing only,** is capped per difficulty, and is surfaced diegetically by the
   brood, not on the HUD.
5. **The rush shield is breakable by the base gun.** It is a skill reward, not a power gate.
6. **"A little more often"** = +0.05 / +0.10 / +0.20 base, plus up to +0.10 with skill, plus the alone-trigger.
7. **Placeholder voice lines show their own (borrowed) subtitle.** Lines with no truthful placeholder stay silent
   until recorded.

## 11. As built: deviations and judgment calls

Each is reversible (a constant or a gate) and recorded in the code next to it.

1. **Route 0 is untouched.** The skirmisher veto, like the hunters and sentinels, runs only from route 1
   (`ArcadeModel._intel`; `intelligence = false` turns the tiers off as a fixture and calibration flag). The design
   applied the veto everywhere, but also required "no change on route 0"; route 0 is now bit-identical (tested).
2. **PilotModel persistence.** μ(τ) scales its velocity decay and mean reversion by (1 − p), where p is the
   persistence of the last second's velocity (1 for a steady glide or standstill, 0 when weaving). The design
   formula is the p = 0 case; without p, the "constant velocity within 2 u at τ 0.3" check is impossible
   (e^(−0.6) alone loses 45 % of the glide).
3. **Planner (§3) as built:** piecewise exact paths (move for D, then hold) plus the creature's own drift; contact
   floor 0.01 s; walls charge moves only; arena clamp 20–340; horizon 2.5 τ0 instead of 1.5 τ0 (with the perception
   delay a 1.5 τ0 cut made an 18-u climb look perfectly safe); decisions only when *hold* is threatened (no softmin
   twitching when safe). Tuned weights: danger 8, leash 0.5 (sweep in §3).
4. **Hunters hold their sidestep** until the threat's contact time + 0.15 s, then ease back (today's jink fades over
   0.32 s and walked hunters straight back into the shot). The dive commit (thread candidate) also pays the leash and
   is offered only when the ship is likely under the dive (P_hit ≥ 0.25), as the teacher's `interceptErr < 68`.
5. **Thread dives see shots extrapolated.** Shots younger than δ stay unseen, but the rest are not back-projected:
   at a closing speed of ~540 u/s, δ of lag is a body length and no weave was possible. Danger weight 8 and a 0.3
   hysteresis apply as in the planner.
6. **Rush rally 0.8 s** (not 0.6): the squad warning borrows recorded sentinel-dive clips (shortest 1.46 s) and must
   end within 0.3 s of the charge; tell = 1.3 s Normal, 1.19 s Hard, 1.44 s Easy (all ≥ 1.0 s). The rise is capped
   so the apex stays at y ≥ 32 (a sentinel at y 44 reared half out of the arena in the review frames).
7. **Homing limit.** Turn rates 0 / 50 / 75 °/s as designed, plus a cap on how far the heading strays from the
   lock's aim: 0 / 14 / 16°. Without it the forecast-led homing caught 20 % (Normal) and 63 % (Hard) of dodging
   ships; with it the whole worst-case homing reach (Normal 104 u, Hard 124 u) stays inside the smallest dodge room
   (162 u) less the widest contact (24 u), and the escape guard holds (≥ 99.8 % of passes on Hard).
8. **Rush contact.** A contact that costs a life ends the rush (the old sacrifice); a shield or protection ends only
   that pass's contact, and the pass flies on (and comes around if passes remain).
9. **Rush scale.** The rushing sentinel grows from its rally size to the 1.25 cap by the ship row (it read too
   small in the review frames); its hitbox and contact grow with it, inside the fairness margins.
10. **Radio.** cinematic-flow (merged meanwhile) added no comms `clip` field and its message slots are for transitions,
    so the rush uses this change's `CommsLine.clip`. A placeholder line takes the borrowed line's speaker too (the
    portrait must match the voice). The single-voice channel cannot fit the brood war cry before a 1.46 s warning in
    a 1.2–1.4 s tell: the warning (urgent) keeps the slot and the war cry follows on the charge (ttl 2.5 s). Shorter
    recorded warnings in the voice batch will let both land before it. `rushShieldBroken` and `rushSurvived` stay
    silent until recorded (no truthful placeholder).
11. **Calibration harness.** The Average pilot runs all eight seeds (four were too noisy for a +0.3 lives bound), and
    the recorder attributes each shot to the tier of the creature the pilot aims at when it fires.

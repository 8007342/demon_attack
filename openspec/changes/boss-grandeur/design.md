# Design: boss grandeur

Inputs: the R4 operator intent (`plan/operator-feedback-2026-11-15b.md`), the research in `plan/round2-research.md`
§3 and §4, `cinematic-flow` §3 (boss transitions), `fog-restoration` (layered fog), `terrain-shadows` (casters) and
the art contract of `boss-hero-assets`.

## 0. Ownership
- `BossDirector` (`lib/game/boss_director.dart`) owns the boss level's phases, the presentation altitude, the camera
  (zoom and follow) targets and the view selection. It reads the model and never writes gameplay state, except
  through the two hooks below.
- **Gameplay hooks (deterministic, own PRNG stream `seed ^ 0xB055`):**
  - (a) the level-5 wave plan (how many loom waves);
  - (b) the carrier's bounded vertical glide (§5).

  Everything else is presentation.

## 1. Phases
| Phase | When | What the player sees | Gameplay |
|---|---|---|---|
| **Overflight** | the boss arrival Descent (replaces mill/vacuole/pour) | The boss's dark belly enters from the bottom edge, huge and soft, passes over the ship and shrinks toward the horizon in 3.2 s (2.0 s reduced). The pursued flock streams after it. It sinks into the far fog. Its shadow (terrain-shadows caster) sweeps the ground first | Transition: no gameplay. Never covers the ship at more than 0.55 opacity |
| **Loom** | 1 ordinary wave (tour 1) or 2 (tour ≥ 2), from the continuous stream | A dark mass under the fog layers, drawn in the fog-restoration slot *between* the far layers, rising one layer per ~8 s. Its lights blink through the fog. The lurking shadow crawls to the front | Ordinary waves only. The boss has no hitbox and fires nothing. Cap: 75 s, then Rise regardless |
| **Rise** | the loom waves are cleared (or the cap) | Emerges from under the front fog over 4–6 s: nose first, then the hull. Fog sheds off it (the sentinel fade-in recipe). Klaxon and `bossArrival` radio | Fight-ready rule: the hitbox enables only when fully out. The stream's stragglers are routed (R1's no-straggler rule) |
| **Engage** | the boss settles at the front | Today's strafe begins at altitude A = 1 | Today's carrier gameplay |
| **Climb** | 1.5 s after Engage, and again at each form change | The fight climbs: A eases to 1.45 (1.6 on tours 4–5) over 3 s; zoom and follow wake up | Unchanged |
| **Collapse** | core 0 | Staged break-up (§6), then the victory Rout | Today's victory |

The stream (`continuous-swarm`) treats Loom like any level. The only addition is that the level's last loom wave does
not chain into a next wave: its clear triggers Rise.

## 2. Altitude and ground parallax
`GroundCamera` gains `altitude` (A ≥ 1, presentation only). With camera height × A, a ground point at depth z
projects at `y = horizon + g·z0 / (z·A)`.
- Sizes at a given depth scale by 1/A, and the scroll speed at a given screen row by 1/A. These are exactly "the
  ground falls farther away: smaller, slower parallax".
- Every ground layer reads A through `GroundCamera.yOf`, `zOf` and `texel`: the terrain mesh, vegetation, ground
  units, ground fx, the atmosphere's ground fog and shadows.
- Ground-war gameplay keeps logical depths, so ranges, fronts and breakthroughs are unchanged (`TerrainView` already
  states "gameplay is decided by logical depth and lane").
- Shadows from terrain-shadows also soften: caster height above the surface grows with A.
- A eases with a critically damped spring (ω = 1.2), never a step.
- Reduced motion: A changes by crossfade between two cached ground renders (1.0 and the target) over 1 s.

## 3. Dynamic camera zoom (`lib/game/arena_camera.dart`)
**Transform.** `screen = pivot + Z·(arena − pivot) + follow`, where:
- `pivot = (180, shipY)`;
- `Z ∈ [0.86, 1]`;
- `follow` applies to background layers only (§4).

The ship row stays put, so a thumb on the ship does not drift.

**Target zoom** combines three terms:
- `Z* = 1 − 0.06·range − 0.05·swerve − 0.03·(A − 1)/0.6`;
- `range` is the boss's horizontal travel span over the last 3 s (0 to 1);
- `swerve` is the |yaw| view index (0 or 1).

It is clamped to [0.86, 1], with a rate limit of 0.05/s and ease-in-out. It zooms *back in* when the boss slows, and
during any dive tell or sentinel rush lock (§3.1, rule 4).

### 3.1 Gameplay-safety rules (tested)
1. **Hitboxes are arena units.** Collision, homing, fire and spawn logic never see Z. A test runs a fixed boss fight
   at Z = 1 and Z = 0.86 and compares the event logs: they must be identical.
2. **Input.** Touch and pointer positions map through the inverse transform. Keyboard, tilt and yoke are unaffected.
   A round-trip test covers the four corners and the ship.
3. **Phone readability floors at the minimum Z** (360 CSS px wide arena):
   - creature ≥ 34 CSS px;
   - enemy bullet ≥ 3 CSS px with its glow;
   - ship ≥ 36 CSS px.

   Insignia (`alien-insignia`) are drawn after the zoom at a fixed CSS size, so they never shrink.
4. **No zoom change while the player must read a threat.** During a dive tell, a rush lock or a ground-missile
   warning the zoom holds (and eases back toward 1 if it was moving out).
5. **Overscan.** Zooming out shows up to 8 % more on each side. Sky, flyover ground and fog are drawn to a 1/0.86
   overscan rect (the widescreen assets already exceed 360 wide). Outside the arena bounds a soft 12 % vignette marks
   the edge. The ship's clamp is unchanged.
6. **Never zoomed:** HUD, comms dock, pause, the cockpit panel and touch controls.
7. **Reduced motion.** No dynamic zoom. One static framing of Z = 0.94 is crossfaded in at Climb and out at Collapse.
8. **Wide screens (1280 × 720).** The same Z about the same pivot. The extra width is the existing widescreen
   backdrop.

## 4. Camera follow (ground perspective)
The background layers (sky, terrain, ground units, ground fog, shadows) get a follow offset that tracks the boss:
- lateral pan `fx = 24·clamp((bossX − 180)/100, −1, 1)`;
- horizon shift `fy = 20·glide`, where `glide` is the boss's vertical glide phase from −1 to 1;
- both lerped over 0.8 s.

Because far layers scale by depth, the pan is applied per layer with parallax weights: horizon 0.3, far ground 0.6,
near ground 1.0. The ground perspective visibly shifts under the fight.

The gameplay layer (creatures, ship, bullets, boss) is never offset by follow. Only Z touches it. Reduced motion: no
follow.

## 5. Swerve and pitch views
**View set.**
- Pitch P ∈ {38°, 45°, 52°}: the camera's elevation above the boss's hull plane.
- Yaw Y ∈ {−12°, 0°, +12°}: heading relative to the screen-down axis.
- This makes 9 views. The art contract is in `boss-hero-assets` §2.

**Vertical glide (gameplay hook b).** `Carrier.y = 205 + 16·sin(φ)`, where:
- φ advances at 0.35 rad/s × `movementRate`, seeded;
- the force field surface follows `y` (it is already defined relative to `y`).

Bounds: y ∈ [189, 221]. That is far from the ship row (477), and turret fire origins move with the art anchors.
Calibration must show boss endurance and survival within ±5 % of today (`test/campaign_playtest_test.dart`).

**Pitch selection.**
- Higher on screen (y < 197) → P = 38°; near the centre → 45°; lower (y > 213) → 52°.
- Hysteresis of 4 units; a held view lasts at least 0.4 s.

**Yaw selection.**
- From horizontal velocity: |vx| above 40 % of the current max picks ±12° toward the motion. As the boss reverses, it
  passes through 0° ("swerves slowly").
- A held view lasts at least 0.35 s.

**View change.** A 2-frame (≈ 120 ms) crossfade between the two cached views. Both share the simulation geometry's
anchors (core window, bays, turret pivot, solid body) to within ±3 units, which is the `boss-hero-assets` acceptance
gate. Reduced motion: the same views, cut on the 45°/0° hold rules with a 200 ms crossfade.

Until R5 art lands, every view resolves to today's frontal atlas, so this logic ships without art.

## 6. Staged damage and collapse
Stages are presentation, derived from existing state. No HP changes.

| Stage | Trigger | Visuals |
|---|---|---|
| S0 shielded | shield > 0 | Hex shield cells over the hull. `ceil(12·shield/shieldMax)` lit cells, each going dark with a white flash and two shards. The same cyan force-shield language as `alien-insignia` |
| S1 scorched | shield ≤ 50 % | Scorch overlay (today's `damage[0]`), flickering running lights |
| S2 exposed | shield = 0 | Plates peel off as `FallingPart`s (2 per door cycle, capped at 6 alive); fires at `fire` points; overlay `damage[1]` |
| S3 breaking | each form change (`phase` ↑) | The module at the front of the detach order breaks off: a wreck sprite falls with its own shadow, sparks, and a hull list of +4° biases yaw views. Smoke trail. Overlay `damage[2]`, then breaches |
| S4 collapse | core = 0 | Today's chain (wing pylons, bays, core) runs on modules. Each module's wreck falls into the fog over 4–6 s, with shadows, inside the victory Rout. The spine goes last, through the fog |

Module wrecks are cosmetic and never collide. The live falling parts stay ≤ 8.

## 7. Composable boss grammar (`lib/game/boss_grammar.dart`)
**Catalogue** (one art set per hull family, from `boss-hero-assets`):
- `spine`: hull core, holds the functional windows;
- `bow` (jaws);
- `tower`;
- `pylon` (pair);
- `engine` (pair);
- `turret` (blister);
- `bayPod` (pair);
- `sail` (dorsal fin);
- `keel` (ventral);
- `broodSac` (pair).

**Module record.** `{id, slot, mount (dorsal | ventral | lateral | bow | stern), mirror, size (S | M | L), stages: 4,
wreck, lights, fires, detachOrder, gameplay: none | turret | bay}`.

**Slots.** Defined on the spine in arena units relative to the carrier centre. Mirrored modules occupy symmetric
slots.

**Tour assembly** (fixed, so the five tours are authored):

| Tour | Hull | Modules | Extent scale |
|---|---|---|---|
| 1 | Frigate | spine, bow, tower, engine ×2 (5) | 1.00 |
| 2 | Cruiser | + pylon ×2, turret (8) | 1.15 |
| 3 | Battlecruiser | + bayPod ×2, sail (11) | 1.30 |
| 4 | Battleship | + turret ×2, keel (14) | 1.45 |
| 5 | Dreadnought | + broodSac ×2, tower 2 (17) | 1.60 |

**Seeded assembly beyond tour 5** (repeat cycles). Start from the dreadnought set and swap or add modules from the
catalogue under these constraints:
- symmetry;
- silhouette area ≤ 1.7 × frigate extent;
- ≤ 19 modules;
- each module's atlas cost within the R5 budget;
- the functional windows unobstructed.

The seed is the run seed and the cycle.

**Gameplay invariants.**
- Every assembly uses the shared simulation geometry: core window, bay window, turret pivot, solid body, force field,
  side hatches.
- Module `gameplay: turret` maps onto the existing turret pivots only.
- No module changes HP, shield or fire budgets; balance stays in `DifficultyPolicy`.
- Larger visual extent never widens the solid body: shots that miss the solid body pass visually *behind* outer
  modules (drawn darker, the "extra size is darker" rule `BossPainter` already follows).

## 8. Validation
- **Pure tests:**
  - director phases and caps;
  - glide bounds;
  - view selection hysteresis;
  - zoom target clamps and holds;
  - inverse touch mapping;
  - grammar assembly (counts per tour, symmetry, seeded determinism, budgets).
- **Equivalence:** identical simulation event logs at Z = 1 and Z = 0.86 on a scripted fight.
- **Calibration:** boss endurance and campaign playtest metrics within ±5 % of baseline.
- **Review strips** (`test/boss_grandeur_review_test.dart` → `art/contact/boss-grandeur-*.png`, 360 × 780 and
  1280 × 720):
  - overflight (8 frames);
  - loom (6);
  - rise (6);
  - climb and zoom (6);
  - the view set (9);
  - stages S0–S4;
  - reduced motion.
- Operator phone playtest.

## 9. Risks
- **Zoom vs readability.** The floors in §3.1 are tested at Z = 0.86. If the operator finds even that too small, raise
  the floor to 0.9 (one constant).
- **Loom fatigue.** A 75 s cap; the loom waves are ordinary waves, so the boss level stays playable.
- **Cost.** The view crossfade draws the boss twice for 2 frames. Overscan draws ≤ 17 % more background. The altitude
  crossfade (reduced) caches two ground renders only at Climb.

## 10. Decisions taken on the operator's behalf
- **"Flies in from behind"** is read literally: an overflight from behind the camera in the arrival Descent, which then
  sinks into the far fog. **"Emerges slowly from under the fog"** is the Rise after the loom waves. Both phrases are
  honoured; the overflight can be dropped by one flag if it reads as too much.
- **The camera follow moves the ground, never the gameplay layer.** The zoom touches the gameplay layer only as a
  uniform scale about the ship's row.
- **Glide amplitude ±16 units** in simulation. It is the only gameplay-visible motion change, bounded and calibrated.
- **View set 3 × 3.** The operator's 38/45/52° are the pitches, and ±12° yaw covers the swerve. More yaw steps are a
  budget call in R5.

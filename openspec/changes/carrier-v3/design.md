# Design: The Carrier, redesigned (carrier-v3)

## Inputs and citations
- **Inputs:**
  - the operator's C1 intent (`plan/operator-feedback-2026-11-16.md`);
  - `boss-grandeur`, design §1–§13: phases, altitude, zoom, follow, stages and the v2 wiring;
  - `boss-hero-assets` §8: the Thornwake art contract, the envelope and texel classes;
  - `docs/styleguide/alien-capital-ships.md`;
  - the v2 ledger `plan/render-runs/boss-carrier-v2.md`.
- **Research:** every decision cites `plan/carrier-v3-research.md` by source ID (`[C5]`, `[W4]` …). That document holds
  each source's author, title, URL, read date, quote and access mark: **[F]** fetched, **[S]** search snippet,
  **[R]** this repository, or UNSOURCED. Numbers marked *ours* are engineering choices with no external source; the
  review strips and the operator's playtest tune them.
- **Re-render:** `plan/render-runs/carrier-v3.md`.

## 0. What stays
The operator praised these, so they are kept as they are:
- the ship's look;
- the zoom-out;
- the spill off-screen (`[P4]`);
- the altitude transform;
- the fog-bank shadows;
- the decay stages and their events;
- the set combinations per run;
- the faceless deck.

The Overflight (the belly passing over the ship, `[C1]` `[I2]`) stays as the intro's first beat.

**Ownership (unchanged from boss-grandeur §0).**
- `BossDirector` owns the presentation.
- The model keeps every gameplay decision.
- New gameplay hooks run on their own PRNG streams (§4.4, §9), so the earlier streams (glide, variant) do not move.

## 1. The core idea: a heavy ship in a fast world
The ship should feel "large as fuck" and move "ultra fast". Film VFX solves this pair by keeping the giant's own motion
slow and heavy, and carrying speed with the world around it:
- Pacific Rim's team cheated physically correct speeds (about 1/7) upward only for fights, and carried scale with
  other cues `[C5]`.
- Godzilla moved slowest in shots with people in frame `[C4]`.

Animation's weight rules say the same: heavy things take longer to start, stop and turn `[M1]` `[M2]`. So:
- **The hull's own moves are slow, eased and small.** Lean, bank and pitch are a few degrees, on critically damped
  springs, with the wings lagging (§2).
- **The world rushes past.** Streaks, differential cloud flow, vortex trails, torn wisps, a low buffet, the ground
  dropping away and the zoom-out all carry the speed (§7) `[S1]` `[S5]` `[P1]`.
- **Its small parts are fast.** Gate doors snap open, launches eject quickly, and turrets fire as today. This is the
  contrast that sells the mass `[M5]` `[C6]`.

## 2. One pitch, bent at runtime (replaces the 3 × 3 view set)

### 2.1 Decision
The carrier is drawn from **one stored view, (45°, yaw 0)**, plus the belly for the Overflight. The 38° and 52° pitch
views and the ±12° swerve views are retired from selection now, and from the bake at the re-render. The operator found
the discrete changes far too large for the ship's size. They were 14° of pitch and 24° of yaw, crossfaded in 120 ms
(`[R4]`).

Turning is faked by a continuous, analytic **bend** of that one view, on the model of Live2D's parametric head turn:
small warp deformers keyed to an angle parameter, plus a separate tilt rotation `[W19]`.

### 2.2 The bend
**Coordinates.** Each vertex has hull-local coordinates `(x, y)` in arena units from the carrier centre (x to the
right, y down-screen) and a height `h` above the hull's reference plane.
- After the re-render, `h` is sampled from the baked height grid (§2.5, `[R6]`).
- Until then, `h` is a constant per module mount: bow 0, ventral −20, lateral 10, dorsal 60 units.

**Parameters.**
- The view's pitch is `p₀ = 45°`.
- The pivot `Q = (0, 25)` is the core window.
- The bend parameters are the lean ψ (heading), the bank φ (roll about the long axis) and the pitch change θ.

**Displacement** (small angles, in radians):

```
lean   ψ:  dx = −ψ·(y − Qy + h·cos p₀) / sin p₀      dy = ψ·(x − Qx)·sin p₀
bank   φ:  dx = −h·φ                                 dy = −x·φ·cos p₀
           and x scales by (1 + x·φ/600)             (near/far size difference)
pitch  θ:  dy = (y − Qy)·(sin(p₀+θ)/sin p₀ − 1) − h·(cos(p₀+θ) − cos p₀)
P' = P + w(r)·(dx, dy),   r = |P − Q|,   w = smoothstep(40, 160, r)
```

What each term does:
- **The lean** is a rotation in the hull's plane, projected to the screen. It includes height parallax, so tall
  modules (spines, crown) slide more than the slab.
- **The bank** drops one flank and lifts the other, tips tall modules sideways, and makes the near side slightly
  larger. These are two cues for one rotation: foreshortening, plus parallax between layers `[W21]` `[W22]`.
- **The pitch** is a Mode-7-style row scale `[W16]` `[W17]` plus height parallax. At ±2° the row scale's error is
  about a third of the error that was rejected in v2 for the full ±7° (`[R5]`), and the height term corrects most of
  it.
- **The deck lock `w(r)`** keeps the hangar deck rigid. The core window, bays and turret pivots move less than 1 unit
  at the limits. Near the deck the bend fades smoothly to zero, so the mesh never tears. This is the "fixed hero
  plane" rule of the art contract, enforced at runtime.

**Wing lag (follow-through, `[M3]` `[M4]`).** Wing, arm and sail vertices are bent with parameters passed through a
first-order lag of 0.25 s at 1.25 × amplitude. The weight ramps from 0 at the module's root to 1 at its tip, so the
root never separates from the carapace.

**Light sweep (`[W23]`).** An additive band, 90 units wide and drawn as its own pass (not vertex colours, `[W4]`),
slides across the hull at `x = 400·ψ/ψmax`. It is clipped to the hull's pixels with `srcATop`, at a strength of 0.10.
It is the third cue for the turn on a hull mostly off-screen `[W22]`.

### 2.3 Limits and drivers
| Parameter | Max | Driver | Spring |
| --- | --- | --- | --- |
| Lean ψ | **3°** | smoothed horizontal velocity, `ψ* = ψmax·clamp(vx / vmax)` (leans into its travel) | critically damped, ω = 1.4 (settles in ≈ 3 s) |
| Bank φ | **2.5°** | lateral acceleration, `φ* = φmax·clamp(ax / amax)` (banks into the turn) | ω = 1.8 |
| Pitch θ | **2°** (3° in the take-off) | glide velocity, plus the take-off pulse (§5.4) | ω = 1.2 |
| Buffet | ±0.25° on φ and θ | smooth noise at 1.5–3 Hz × climb × speed (§7) | none |

- These maxima are a quarter to a fifth of the retired views' range.
- No source gives a threshold where a warp starts to read as distortion `[W24]`. The research agent's starting
  suggestion was ±4° yaw and ±2° roll. Our limits sit at or under it, and are one constant each.
- Shadow of the Colossus's team found that small camera-angle changes moved perception, and kept tuning them `[G4]`.
  These limits are tuned on the phone at the playtest.

The largest displacement in the visible envelope is about 30 units, at the top edge of the screen at full lean. That is
4 % of the 720-unit span, where it reads as the far hull swinging. The springs have no overshoot (critical damping:
slow in, slow out, `[M1]`).

### 2.4 Drawing
**One `drawVertices` per pass** (back and front) from the hull page's `ImageShader` `[W1]`–`[W3]`, the same technique
as the terrain mesh `[R1]`.
- **Grid.** A hull-local grid with a 20-unit step over the envelope: 37 × 35 nodes on tour 1. Each layer emits the
  grid cells that overlap its sprite rectangle, clipped to it, with texture coordinates into the page (`[W2]`: image
  pixels).
- **Cost.** With cells wholly off-screen culled, a tour-1 hull is ≈ 2,000–3,000 triangles. That is the order of the
  terrain mesh already on phones (≈ 4,800 × 2, `[R2]`). No source gives a triangle budget `[W13]`.
- **Buffers.**
  - Positions, texture coordinates and indices are typed lists, allocated once per hull and stage.
  - Only the positions are rewritten, and only when a bend parameter has moved more than 0.02° since the last frame
    `[W2]`.
  - There are no vertex colours, which keeps Impeller's fast path `[W4]`.
- **Edges.** `drawVertices` does not anti-alias `[W5]`. The mesh border lies 4 texels inside each sprite's transparent
  margin, so the silhouette comes from the texture's alpha.
- **Filtering.** `FilterQuality.low` (bilinear) on the shader, set explicitly `[W7]`. Nearest would shimmer on a
  moving warp. Mipmaps (`medium`) would cost about 33 % more texture memory `[W7]`, so they are not used.
- **Order.**
  - Triangles are emitted in today's layer order.
  - If a backend blends overlapping triangles of one call out of order (to be checked in task 3.5), the fallback is
    one call per layer group (carapace, then the rest).
  - The decay overlay keeps its `saveLayer`. Colour filters go on a `saveLayer`, never on the image-shader paint
    `[W6]`.
- **Renderers.** One page per hull fits WebGL's safe 4096 `[W12]`. Profile both CanvasKit (Safari and iPhones) and
  skwasm (Chromium) `[W11]`, plus native Impeller with its offscreen pass `[W6]`. The target is ≤ 2 ms of raster for
  the carrier at DPR 2 (task 3.5).
- **Rejected:**
  - one homography per layer: no bulge, and its rasterisation is unverified `[W9]`;
  - `drawAtlas`: it cannot warp `[W8]`;
  - Coons patches: not in `dart:ui` `[W10]`;
  - a per-pixel warp shader over a hull larger than the screen: the fill-rate risk `[W13]`.

### 2.5 Until the re-render, and after
- **Until the re-render.** The bend runs on today's packed (45, 0) view, with per-mount heights. The height-parallax
  term is capped at 4 units, because the v2 layers are cut with holdouts and a larger shift would open slivers at the
  occlusion edges.
- **After the re-render** (`plan/render-runs/carrier-v3.md`):
  - each layer is under-painted beneath its occluders by a margin of 12 units, at least the largest parallax shift;
  - a height grid (20-unit cells, per layer) comes from the rig's z pass;
  - with both, the cap is lifted.

## 3. The hull-conforming force field (replaces the arc)

### 3.1 What it looks like
The field is a membrane that follows the hull's whole silhouette, including the parts off-screen.
- **Shape.** The membrane lies at a signed distance `d(s) = 6 + 18·s` units outside the hull's alpha edge, where
  `s = shield / shieldMax`. As the shield wears, the field tightens onto the hull: today's "comes inward" idea, kept.
- **Rim.** A thin, bright line where the signed distance equals `d(s)`, Gaussian, 2.5 units wide. It brightens toward
  the contour, the 2D analogue of Fresnel `[F4]`.
- **Fill.** A faint violet fill (alpha 0.06) between the hull and the rim.
- **Colours.** The cyan, teal and violet force-shield family `[F8]`. Cyan is an overlay only, never baked into the
  hull (styleguide §7.4).
- **Hex lattice.** Shown only:
  - in rings around hits: `smoothstep` on (distance from the hit − age × 160 units/s), masked by the band and
    multiplied by the lattice, so cells near the hit light first `[F5]`;
  - in a slow **scan**, a band that sweeps from the prow to the stern every 4 s at alpha 0.15. On a hull mostly
    off-screen, the scan says "the field is up".

### 3.2 Depletion on a huge shape
- **Regions.** The field is divided into **12 regions**, one per shield cell (today's 12, `alien-insignia`):
  - wing tips L/R;
  - wing roots L/R;
  - aft flanks L/R;
  - prong outers L/R;
  - prong inners L/R;
  - the citadel;
  - the prow.
- **Order.** As cells are lost, regions go dark **from the outer arms inward**, alternating sides, so the prow's region
  fails last. Each loss shows a white flash, shards from that region's emitter crystal, and then a rim with a ragged,
  flickering gap. Destructible armour over the weak point doubles as the progress gauge `[F7]`.
- **The compact meter.** Most of the hull is off-screen, so the 12 insignia cells stay as an on-screen meter on the
  field's front lip `[F7]`. Their lit set (`InsigniaPainter.litCells`) maps onto the regions through a fixed table.
- **Low shield.** At ≤ 25 % shield, the remaining regions flicker (today's critical flicker).
- **Shield down.** The membrane snaps inward over 0.4 s and is gone. The emitter crystals shatter, as the styleguide
  §6 S2 step specifies.

### 3.3 The gameplay intercept is unchanged
Player shots are still stopped by today's analytic surface: half-width 110 and depth `43 + 32·s`
(`Carrier.forceFieldSurfaceY`, `[F9]`).
- **Inside the band** `|x − bx| ≤ 110`, the shader draws the rim exactly on that surface, the field's "front lip".
- **Outside the band**, the rim follows the hull's contour, blended over 20 units at the band's ends.

Shots outside the band pass behind the outer hull, as they do today (boss-grandeur §7's "extra size is darker"). The
shield-hit log is identical before and after the redraw (task 2.4), so balance does not move.

### 3.4 How it is drawn
**The fragment shader `shaders/carrier_field.frag`.** It is the project's second shader, after `fog.frag` (`[R7]`).
- It is drawn as one rectangle over the hull's on-screen bounds, under the gameplay layer's zoom, after the hull's
  back pass and before the creatures.
- Inputs `[F3]`:
  - **one data texture per hull**: R the signed distance (±32 units), G the region id, B the height. It is stored at
    0.5 px/unit over the envelope, 0.48 MB on tour 1;
  - uniforms for the shield `s`, 12 region states and flash ages, 4 impacts (x, y, age), the scan phase, and the
    carrier's screen transform and bend parameters.
- **The bend.** The shader inverts the analytic bend of §2.2 with one fixed-point step. The error is under 0.5 unit at
  the limits, so the field bends with the hull.
- The `FragmentShader` object is reused across frames `[F3]`.
- **Where the distance comes from.**
  - From the re-render on, `rigsheet` bakes the distance offline: an exact Euclidean distance transform on the CPU,
    with jump flooding as the fast option `[F1]` `[F2]`.
  - Until then, the game computes it once at load time from the S0 alpha, at 0.5 px/unit, in Dart.
- **Fallback.** Without shader support, today's arc is drawn.

## 4. Gates and compartments: the launch system

### 4.1 The gates are simulation geometry
Gate positions are **gameplay data**, like the core window: `CarrierGates.forTour(tour)` in `carrier_gates.dart`, in
hull-local arena units, each with an outward normal. The art conforms to them through the anchor gate of the
rig (±3 units), never the reverse, so the simulation stays art-free and deterministic.

| Tour | Gates (instances) | Where | Kind |
| --- | --- | --- | --- |
| 1 | 4 | the two deck bays (the deck's side hatches at ±46) and two prong gates (under the prongs at ≈ ±150, +60) | leaf doors |
| 2 | 6 | + flank maws ×2 (the existing `maw` slot) | iris |
| 3 | 8 | + dorsal compartments ×2 on the citadel terrace (creatures rise, then swoop) | hatch |
| 4 | 10 | + brood sacs ×2 (the existing `sac` slot; they split open) | sac |
| 5 | 12 | + aft prong gates ×2 | leaf doors |

### 4.2 The volley: telegraph, open, eject, close
Precedents: a carrier releases its fighters one at a time `[L1]`; a burst forms up before it attacks `[L2]`; a hangar
launches in stages `[L3]`; a shmup hatch releases squadrons `[L5]`; and a mothership's hatches release fighters before
its core opens `[G3]` `[L6]`. The volley:

| Step | Time | Shown | Gameplay |
| --- | --- | --- | --- |
| Telegraph | 1.2 s | the gate's lights pulse ember to amber, and its launch rail lights chase toward the opening `[L7]` | nothing leaves; `bossGateTelegraph` |
| Open | 0.5 s | the doors open (baked door states after the re-render, runtime-drawn leaves before) | `bossGateOpen` |
| Launch | 0.12 s per creature | each creature ejects along the gate's normal at 90 units/s, drops on a 0.4 s arc, then flies its normal entrance to the formation | entering creatures cannot be hit and do not fire until the arc ends; `bossLaunch` (gate, count) |
| Close | 0.8 s after the last | the doors close | `bossGateClose` |

- The 0.12 s spacing is ours; StarCraft's carrier uses 0.5 s `[L1]`. At most two gates are open at once.
- **Fairness `[L7]`:**
  - a gate whose position is outside the arena (x ∉ [16, 344]) when its telegraph would start does not launch, and its
    skein moves to the next gate;
  - ejection is never aimed at the ship's row: the gates are above y = 300, and the ship's row is 477;
  - the 1.2 s telegraph is ours: long enough to read, short enough not to drag `[L7]`.

### 4.3 The waves that come off the carrier (the approach)
- The boss level's opening waves (today's loom waves) keep their rosters and the stream's composition. **Only their
  origin changes**: each skein is assigned a gate, and its members enter from that gate's position projected through
  the approach distance (§5.2). The starting nearness is that of a deep gate (0.12–0.2, the existing `SwarmGate.deep`
  nearness, `[L8]`).
- **Counts:**
  - two launch waves on tours 1–3 (tour 1 was one loom wave);
  - three from tour 4 (tours 2+ were two).
- The cap rises from 75 s to 90 s.
- Run modifiers that act on ordinary waves act on these (bonus levels), because they are ordinary waves.

### 4.4 The fight's minion flocks
Today's flocks (up to 3 creatures every 2.4–5.6 s, capped at 6, 8 or 10 by tour, all from `b.y + 52`, `[L8]`) keep
their timer and cap. They now come out of a gate:
- the gate is chosen round-robin, from a seeded start, among the gates that are on-screen at the carrier's current x;
- the gate's telegraph starts 1.2 s before the timer fires, so **the spawn moments do not move**;
- only the spawn positions change.

The PRNG stream is `seed ^ 0xB055 ^ 0x6A7E`. Calibration gates: boss endurance pooled within 5 % and each difficulty
within 10 % (boss-grandeur §12), plus the boss level's clear time within 10 %.

## 5. The intro: Overflight → Approach → Close → Take-off → Climb

### 5.1 The phases
| Phase | Replaces | Length | Gameplay |
| --- | --- | --- | --- |
| Overflight | (kept) | 3.2 s (2.0 s reduced) | transition |
| Approach | Loom | until the launch waves are cleared, or the 90 s cap | launch waves; no hitbox, no fire |
| Close | Rise | 4 s, eased in and out | no hitbox; stragglers routed (R1 rule) |
| Take-off | Engage | 2.4 s | the fight is on: hittable from its first frame |
| Climb | Climb | while it fights | unchanged |
| Collapse | (kept) | (kept) | (kept) |

The beat order applies the reveal research:
- the shadow and belly first `[I2]`;
- part before whole, indirect and in atmosphere `[I3]` `[I4]`;
- the genre's "a huge battleship is approaching fast" `[I1]`;
- the hatches that release fighters before the core is exposed `[G3]`;
- a beginning, a middle and an end held together by beats `[G6]`.

### 5.2 The approach: distance, scale, haze
The approach distance factor is D, and the carrier's scale on screen is 1/D (`[V5]`).

| | Tours 1–3 (2 waves) | Tours 4–5 (3 waves) |
| --- | --- | --- |
| Start D₀ | 4.0 (tour 1) · 4.5 (tours 2–3) | 5.0 |
| After wave 1 is cleared | 2.4 | 3.2 |
| After wave 2 is cleared | 1.35 (Close) | 2.0 |
| After wave 3 is cleared | — | 1.35 (Close) |
| Close | 1.35 → 1.0 over 4 s | 1.35 → 1.0 over 4 s |

- **Between steps** D creeps down at 0.012/s, never past the next step. Each step after a clear eases over 3 s (slow
  in, slow out; a heavy thing takes time to start and stop, `[M2]`).
- **Screen placement.** `y(D) = 205 − 87·(D − 1)/3`, clamped to ≥ 100. So the carrier starts high, near the far banks,
  and descends to its fight row as it closes. Its x drifts as the loom's did (`180 + 46·sin(0.13 t)`), scaled by
  `(1 − 1/D)` so the drift dies out in range.
  - At D = 4 the hull is ≈ 180 units wide on screen. It is already half the arena, and still "far".
  - At D = 2.4 it spills off the top.
- **Aerial perspective** `[V1]`–`[V4]`. The fog mix is `1 − e^(−0.55·(D − 1))`: 0.81 at D = 4, 0.54 at 2.4, 0.18 at
  1.35, and 0 in range. It acts on contrast and value toward the fog colour, never blur `[V1]`. The running lights
  blink through it (the loom's lights).
- **Fog slots.** The draw slot moves nearer as D falls:
  - behind the far banks for D ≥ 3;
  - between the mid banks for 1.8 ≤ D < 3;
  - under the near sheets below 1.8;
  - the fight slot from the Close on.

  The banks the carrier passes give it occlusion and parallax `[P2]`.
- **Zoom.** It stays at 1 during the approach (the waves are ordinary waves), and eases to 0.86 during the Close
  (today's "rise eases to 0.86").
- **The hittable threshold** is D = 1.0, reached at the end of the Close. There `fightReady` turns true, the shield
  starts full, and `bossInRange` is emitted. Before it, shots cross the hazed image and fly on (the Rise's rule today).

### 5.3 The cap
If the launch waves are not cleared by 90 s, the Close starts anyway. What is left of the waves breaks away into the fog
(today's `_beginRise` rule: nothing stays in the fog).

### 5.4 The take-off (2.4 s, from `bossInRange`)
| t (s) | What happens |
| --- | --- |
| 0 | `bossTakeoff`. Shake trauma 0.35 (one of the four beats, §7). The altitude target jumps to the climb's target at once: the boss-grandeur Engage wait (1.5 s) is dropped, so the take-off *is* the start of the climb |
| 0–0.8 | Nose-up pitch bend θ → +3° (pivoted on the deck, §2.2). The world pitches on the background only (the transition-ascent pitch, `[R3]`): the horizon drops by `pitchDrop·q`, with q rising to 0.6 |
| 0.8 | The fog rush peaks: flow boost 3.0, streak density at its maximum (§7) |
| 0.8–2.4 | θ eases back to 0 (slow out), q to 0. The flow boost settles to the climb's value |
| 0–4.8 | The zoom eases from 0.86 toward the tour's minimum at the existing 0.05/s rate limit (0.70 is reached in ≈ 3.2 s, 0.62 in ≈ 4.8 s) |
| altitude ≥ 98 % of target | `bossClimbPeak` |

The carrier fights from the first frame of the take-off: its fire and door cycles run from `readyAt` as today. The
take-off is presentation only.

## 6. Climb camera and per-carrier zoom

### 6.1 The follow camera
These rules extend boss-grandeur §4:
- **Lateral follow and horizon follow** are unchanged: ±24 units of pan and ±20 of horizon, with per-layer weights of
  0.3 at the horizon to 1.0 at the near ground.
- **Follow strength** ramps from 0 to 1 over the 2.4 s take-off, rather than with the climb.
- **"The ground battle drops lower."** The horizon also sinks by `18·climb` units below its normal place. The band it
  uncovers is cloud (the fight is in the clouds). The ground is already smaller and slower by 1/A.
- **The gameplay layer is never moved by the follow.** Only the zoom touches it, about the ship's row, so the ship stays
  under the finger.

### 6.2 Per-tour zoom, floors and envelope
"Each later carrier zooms out a little more." Tour 1 keeps today's 0.70, which the operator praised.

The table below gives draw scales and the visible region for each tour. Native sizes are 48.4 units for the creature,
48 for the ship and 5 for a bullet, on a 360-CSS-px-wide arena.

| Tour | Min Z | Max altitude | Creature: CSS px → draw scale | Ship: CSS px → draw scale | Bullet CSS px | Visible arena x | Visible arena top y | Envelope (carrier-relative) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0.70 | 1.60 | 33.9 → ×1.00 | 33.6 → ×1.07 | 3.5 | −77 … 437 | −204 | x ±360, y −430 … +240 (today) |
| 2 | 0.68 | 1.65 | 32.9 → ×1.03 | 32.6 → ×1.10 | 3.4 | −85 … 445 | −225 | ±370, −450 |
| 3 | 0.66 | 1.70 | 31.9 → ×1.07 | 31.7 → ×1.14 | 3.3 | −93 … 453 | −246 | ±375, −470 |
| 4 | 0.64 | 1.75 | 31.0 → ×1.10 | 30.7 → ×1.17 | 3.2 | −101 … 461 | −268 | ±380, −490 |
| 5+ | 0.62 | 1.80 | 30.0 → ×1.13 | 29.8 → ×1.21 | 3.1 | −110 … 470 | −292 | ±390, −520 |

- **The mobile limit is 0.62.** It is where the bullet floor (3 CSS px) has 0.1 px left, and where the drawn creature
  outgrows its hitbox by 13 %.
- **The floors are draw-size floors**, as today: the hitbox never changes.
- **The camera band** is `[0.86, minZ(tour)]`, at the same rate limit and pivot, with holds easing back to 0.86.
- **The envelope** is computed by the same rule as `boss-hero-assets` §8.3: carrier x ∈ [82, 278], glide y ∈ [189,
  221]. Later carriers are rendered with the larger envelope (the re-render), so the extra view shows more ship, never
  an empty edge.

The zoom-out also reads as speed: a wider field of view feels faster `[S5]`.

## 7. Ultra-fast motion cues
Each cue is chosen from the research. Its intensity is the script's, scaled by `climb`. The common rules:
- every cue is drawn under the gameplay layer, or outside the ship's band (y > 420 excluded);
- no cue uses white-hot or cyan (styleguide §7.4);
- none of them is drawn under reduced motion.

| Cue | What | Why |
| --- | --- | --- |
| **Fog streaks** | Thin streaks, 30–90 units long and 1–2 wide, at alpha 0.08–0.22 in the fog's highlight colour. They stream down-screen at 600–1,400 units/s × climb, between and on the fog banks; the near ones are longer and faster. Density is 12–40 per screen | speed lines streak the *background* and leave the subject sharp; more and closer lines read faster `[S1]` |
| **Differential cloud flow** | Each fog layer's flow is `base·(1 + (boost − 1)·(0.5 + nearness))`; the boost reaches 2.2, or 3.0 in the take-off and surges | parallax: near layers faster than far `[P1]` `[P2]` |
| **Vortex trails** | Ribbons streaming down-screen (the relative wind) from the prong and wing tips that are on-screen: 120–200 units long, 3 → 1 wide, pale violet-grey, alpha ≤ 0.25. The anchor points come from the rig's new `vortex` points; until then, the frame's extreme points of those slots | UNSOURCED `[S6]`; judged on the strips |
| **Torn wisps** | Cloud wisps drawn *over* the off-screen hull's edges (the top band and the sides), moving at 1.5–3 × the hull's flow and torn around the prongs | occlusion and parallax put the hull behind something `[P2]`; the arrival reads first as weather `[C3]`; "it goes on into the cloud" (styleguide §8) |
| **Buffet** | ±0.25° of noise on bank and pitch, at 1.5–3 Hz, in the bend (§2.3); the hull's centre never moves | a slow, heavy body in a fast airflow `[C5]` `[M2]` |
| **Surges** | Every 12–20 s (seeded): the flow boost rises by 0.6 for 1.5 s with the streaks; one in three is a **cloud punch**, a dense bank sweeping down the screen over 0.8 s that the hull bursts through (`bossCloudPunch`) | rhythm and variety `[G5]` |
| **Shake** | Trauma-based (`shake = trauma²·4 units`, smooth noise per axis, decay 0.8/s, no rotation). Only on four beats: take-off 0.35, module lost 0.30, core exposed 0.25, collapse 0.50. The HUD and controls never shake | trauma model `[S2]`; used sparingly and switchable `[S3]` `[S4]` |
| **Not used** | Motion blur on the hull | it can *lower* perceived speed `[S5]`, and the hull must stay sharp `[S1]` |

The existing cues stay:
- the ground dropping away and slowing (altitude);
- the shadow racing over the fog banks;
- the zoom-out `[S5]`.

## 8. Reduced motion
- **The carrier:**
  - no bend: the hero view is drawn rigid;
  - no buffet, light sweep, streaks, vortex trails, torn wisps, surges, shake or world pitch.
- **The intro:**
  - the Overflight is 2.0 s;
  - the approach steps are 1 s ramps;
  - the take-off is the altitude and framing ramp of today (1 s), at 0.78 + (minZ − 0.70) for later tours.
- **The fog** keeps its normal speed.
- **The force field:** the scan is off, and a hit shows one flash with no ripple.

## 9. Composable per run and per tour: `CarrierScript`
Every number above is data in `lib/game/carrier_script.dart`:

```
CarrierScript {
  tour, launchWaves, approach {d0, steps[], creep, closeSeconds, cap},
  gates[] (from CarrierGates.forTour), volley {telegraph, open, interval, close, maxOpen},
  camera {minZoom, maxAltitude, horizonDrop}, bend {leanMax, bankMax, pitchMax, takeoffPitch, wingLag, buffet},
  cues {streakDensity, flowBoostMax, surgeEvery, punchShare, vortexPoints, wisps},
  field {regionOrder[12], offsetMin, offsetMax, scanPeriod}
}
```

- **Tours 1–5 are authored** (the tables in §4–§7). An unseeded run (tests, the calibrated campaign) uses them as they
  are.
- **Seeded variation per run** comes from the run seed and the tour (`CarrierScript.forRun`):
  - which gates launch first;
  - the volley order;
  - the surge timing;
  - ±10 % on the cue intensities.

  The gameplay numbers (waves, distances, gates' existence, cadences) stay authored. The visual set combination still
  comes from `BossGrammar.variantFor` (boss-grandeur §13).
- **Beyond tour 5:** seeded scripts within tour 5's limits:
  - min Z 0.62;
  - bend maxima;
  - 12 gates;
  - 3 launch waves.
- **New hulls and families** declare their gates and vortex points in the rig family JSON (`gates`, `vortex`), checked
  by the anchor gate. A family without gates launches from the deck bays only.
- **Flags** for review and fallback:
  - `overflight` (on);
  - `approach` (on; off restores today's Loom and Rise);
  - `bend` (on; off draws the rigid hero view);
  - `fieldShader` (on; off draws the arc).

## 10. Audio events (for the future epic and doom-metal score)
The music director already reads the decay events from the game event queue (styleguide §6). This change adds the
events below. Every event carries `route`, `tour` and `set`. The score itself waits on tillandsias#1103; until then,
`music_director.dart` maps only `bossApproach`, `bossInRange` and `bossTakeoff` onto existing cues.

| Event | When | Data | For the score (suggested) |
| --- | --- | --- | --- |
| `bossApproach` | the approach starts (step 0), and each step closer | `step`, `distance` | a low drone that rises a step each time |
| `bossGateTelegraph` | a gate's telegraph starts | `gate`, `slot`, `side` | a riser, panned by `side` |
| `bossGateOpen` | its doors open | `gate` | a mechanical hit |
| `bossLaunch` | a volley leaves | `gate`, `count`, `tier` | a percussion burst sized by `count` |
| `bossGateClose` | its doors close | `gate` | — |
| `bossInRange` | the hittable threshold (D = 1) | `distance: 1` | the drop into the fight |
| `bossTakeoff` | the take-off beat | `minZoom`, `altitude` | the epic lift: choir or brass swell |
| `bossClimbPeak` | the altitude reaches 98 % of its target | `altitude` | full arrangement |
| `bossFieldImpact` | a shot is stopped by the field, **at most 4 per second** | `region`, `x` | metal hits on the beat |
| `bossSpeedSurge` | a surge starts | `intensity` | a tempo or filter push |
| `bossCloudPunch` | the hull bursts through a cloud bank | — | a crash |

- The decay events keep their names and order.
- `bossShieldCellLost` gains `region`.
- `bossRise` keeps its meaning: the carrier's wave starts, now at the Close.
- `bossOverflight` is unchanged.

## 11. Validation
- **Pure tests:**
  - script determinism, and the limits beyond tour 5;
  - the director's approach steps, creep, cap, hittable threshold and take-off timing;
  - bend anchor invariance (core, bays and turret pivots within ±3 units at every combination of maxima);
  - gate volleys (the telegraph ≥ 1 s, determinism, off-arena gates skipped);
  - zoom floors per tour, down to 0.62.
- **Equivalence:**
  - a scripted fight's event log is identical at Z = 1 and at each tour's minimum;
  - the shield-hit log is identical before and after the field redraw.
- **Calibration:**
  - boss endurance pooled within 5 % and each difficulty within 10 %;
  - the boss level's clear time within 10 %;
  - campaign playtest metrics;
  - all logged in `plan/calibration-current.md`.
- **Review strips** (`test/carrier_v3_review_test.dart` → `art/contact/carrier-v3-*.png`, at 360 × 640 and
  1280 × 720):
  - the approach (8 frames, D = 4 → 1);
  - a volley (telegraph, open, eject, close);
  - the take-off (6 frames);
  - the bend at the limits (lean ±, bank ±, pitch ±);
  - field depletion (12 → 0);
  - the speed cues;
  - per-tour framing at each minimum Z;
  - reduced motion.
- **Profiling and playtest:**
  - profiling on phones (task 3.5);
  - the operator's phone playtest.

## 12. Risks
| Risk | Mitigation |
| --- | --- |
| Overlapping triangles in one `drawVertices` call blend out of order on some backend | one call per layer group (task 3.5 decides) |
| Impeller's offscreen pass for textured vertices (native apps) `[W6]` | measure; cull off-screen cells; the web, the primary target, uses CanvasKit or skwasm `[W11]` |
| Seams at layer occlusion edges before the re-render | parallax capped at 4 units (§2.5); the re-render's under-paint lifts the cap |
| The playable area shrinks on screen at 0.62 (the arena is 62 % of the phone's width) | one constant per tour; stop the ladder at 0.64 if the operator finds tour 5 too small |
| Two launch waves on tour 1 lengthen the boss level | calibration gate on the clear time; `launchWaves` is one script field |
| Gate spawn positions change difficulty | spawn moments are unchanged (§4.4); calibration gates |
| The field shader costs fill over a large rectangle | it is drawn only over the hull's on-screen bounds; the arc fallback; one pass, as `fog.frag` already is |

## 13. Decisions taken on the operator's behalf, and open questions
**Decisions** (each is one constant or flag):
1. One stored view, plus a bend at ≤ 3° lean, ≤ 2.5° bank and ≤ 2° pitch (3° in the take-off) `[W19]` `[W21]` `[G4]`.
2. The Overflight is kept as the first beat `[I2]`.
3. The tour-1 boss level gets two launch waves (it had one loom wave).
4. The zoom ladder runs 0.70 / 0.68 / 0.66 / 0.64 / 0.62.
5. The field's gameplay surface is unchanged; only its look is new.
6. The take-off merges boss-grandeur's Engage wait into the climb.
7. Tour-1 heroes are kept, with regional edits for the gates and fixes (the re-render plan).

**Open questions for the operator:**
- Is 0.62 at tour 5 too small to play on your phone?
- Should the Overflight stay before the approach, now that the approach itself shows the ship coming?
- Should a gate be **destructible** in the fight (a Gradius-style open hatch as an opportunity, `[L5]`)? This change
  keeps the gates indestructible, so balance stays put.

## 14. Runtime notes (the runtime on today's art, `work/carrier-v3-runtime`)
These are the picks the runtime made where the art or the phone was missing. Each one is a constant or a flag.

**Bend mesh cost (task 3.2).**
- Tour 1 (`carrier1-thorn`): 1,858 vertices and 3,288 triangles per frame, on one page, in two `drawVertices`
  calls (back and front). `carrier1-lattice` has 1,983 and 3,496; tour 5 (`carrier5-thorn`) has 3,045 and 5,324.
- Rewriting the positions takes about 70 µs on the desktop Dart VM (`test/carrier_bend_test.dart`). It runs only
  when the bend has moved more than 0.02°, and the `Vertices` object is reused until then. There are no vertex
  colours.
- Frame-time reasoning:
  - this is below the terrain mesh already drawn every frame on phones (about 4,800 × 2, `[R2]`);
  - the cells off-screen are not culled. They cost vertex work only, and the clip discards them before
    rasterisation;
  - the raster cost is the hull's own fill, which the old `drawImageRect` layers paid too;
  - so the carrier should stay well inside the 2 ms target at DPR 2.
- Task 3.5 (the phone measurement) is still open.

**Force field (tasks 4.1–4.2).**
- The distance map is an exact EDT of the S0 alpha at 0.5 px/unit (about 400 × 360 px for tour 1), built once
  when the hull is installed.
- The membrane is the map's iso-contour at the shield's offset, quantised to 2 units, as line segments per region,
  bent per point. It is drawn with `drawRawPoints`, one call per lit region and pass (glow, then core).
- About 360 segments are drawn per frame on tour 1. There is no full-screen fragment pass, so the shader is
  deferred.
- The lip is drawn unbent on `Carrier.forceFieldSurfaceY` and blended into the contour over 70 units (smoothstep).
  The lip (`|x| ≤ 110`) is drawn over the prow; the rest is drawn after the hull's back pass.

**Gates.**
- The authored round-robin crosses sides and rings (bayL, prongR, bayR, prongL, …), so the two deck bays never
  glow as a pair under the dome: no eye reading.
- Until the door layers exist, each gate is runtime-drawn: a dark slit with a rim, an ember-to-amber interior and
  halo, doors (two leaves, an iris, a lifting hatch, or a split sac), and a four-light rail.
- Launch-wave members wait in their gate (`Demon.gateWait`: parked, undrawn and untargetable) until their slot in
  the volley. The approach's reserve is not drawn in the fog: it is inside the carrier.

**Approach.**
- The hull is drawn one fog bank nearer than §5.2 (between the far banks at D ≥ 3, between the veils at
  1.8 ≤ D < 3). Behind every bank it read as a pale ghost on the review strip.
- The haze mixes 0.85 × `fogMix(D)` toward the carrier's shade lightened by 30 % toward the fog.

**Take-off.**
- The world pitch drops the background's horizon (60 units × q, so 36 at the peak) through the arena camera.
- The transition's uncovered cloud band and its feather were drawn over the hull, so they are not used here.

**Not drawn yet.**
- The light sweep (§2.2) needs a `saveLayer` over the hull, so it waits for the phone profile.
- Vortex trails use the outer-lower extreme of each wing, emitter and tendril layer until the rig's `vortex`
  points exist.
- Under reduced motion the approach steps keep their 3 s ease: D is simulation state.

**Easy's second launch wave (calibration, after the runtime).**
- Every tour keeps two launch waves on every difficulty: the operator asked for "the first couple of waves".
- On Easy, the second launch wave leaves the gates in one go: all its skeins at once, none held in reserve, so
  there are fewer volley leads. It keeps half its roster and half its reinforcement flocks
  (`CarrierScript.easySecondWave`).
- With this, Easy's boss-level clear time is +5.7 % (the gate is 10 %) and Normal and Hard are unchanged
  (`plan/calibration-current.md`, "Carrier v3 tune").

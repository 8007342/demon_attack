# Swarm perspective: depth, scale and hitboxes

Round `work/gargoyle-perspective` (2026-11-10). Operator: gargoyles were too small; they should be small far away, breathe a little larger and smaller as they fly, and be larger as they dive. Decided: **hitboxes scale with the visible size** (what you see is what you hit), and overall difficulty stays within about ±10%.

Code: `lib/game/perspective.dart` (pure functions), the depth pass in `lib/game/model.dart` (`Demon.nearness`, `Demon.scale`, `_updatePerspective`, `_placeEntering`), drawing in `lib/game/scene.dart` (`_byDepth`, `_scaleAbout`, `_swarmShadows`). Tests: `test/perspective_difficulty_test.dart` (before/after bot) and `test/perspective_review_test.dart` (frames under `.cache/perspective-review/`).

## 1. What the flyover camera already implies

The background (`flyover_background.dart`) is one pinhole camera over a flat ground plane, looking forward and down:

- Horizon line y = 172 of 520: the vanishing line of the ground, where z → ∞.
- A ground point at forward distance z projects to y = 172 + 348 · z0/z, with scale **n = z0/z** (z0 = 174 texels; y = 520 is n = 1, the ship at y = 477 stands on n ≈ 0.876).
- So on the ground, screen y and scale are the same number: n = (y − 172) / 348. Props and creatures emerge tiny at the horizon and grow and speed up as they approach.
- Vanishing point: the screen centre (x = 180) on the horizon; everything recedes toward it (x − 180 ∝ n).

A flying demon at altitude h above that ground, at depth z, projects to y = 172 + 348 · n · (1 − h/H) for camera height H: higher than the camera means *above* the horizon, and for any altitude the screen offset from the horizon grows linearly with n. Two consequences for a believable swarm:

1. A demon arriving from far away appears **near the horizon**, close to the vanishing point, tiny and hazed, and moves *outward* from the horizon as it approaches. Dropping in from the top edge reads as "from behind and above the camera", which suits re-entry after a dive but not an arrival.
2. Its scale must match the terrain at the same depth: a demon whose shadow falls at ground y must have the ground's scale n there.

## 2. Pseudo-3D sprite scaling (Space Harrier / After Burner style)

Sprite-scaler games keep a virtual z per object and draw it at scale ∝ 1/z, with a shadow on the ground at the same z. We do the same with one number per demon, the nearness n (∝ 1/z), owned by the simulation:

- **Flight sheet.** The game is screen-space, so instead of a full 3-D position the swarm flies on an inclined sheet: n rises linearly with screen y from 0.62 at y = 40 to the ship's own 0.876 at y = 477 (`nearnessAtY`). Lower on screen is nearer, as on the ground.
- **Arrival.** An entrance moves depth *linearly* (z, i.e. 1/n) from n = 0.30 to the formation slot's n, and the screen position follows n (offset ∝ n), so arrivals creep out of the haze and rush the last stretch, exactly like a sprite-scaler's approaching object. They start at x = 180 + (homeX − 180) · 0.38 and y ≈ 154 + row stagger, just above the horizon.
- **Breathing.** n gains 0.035 · sin(bob phase), in phase with the formation's vertical bob (sinking = toward the camera = larger), plus a slow 0.02 wander per demon. About ±1 size step: gentle.
- **Dive.** +0.08 while diving, eased in (rate 5/s) on top of the sheet's own growth as the diver drops toward the ship.

### Scale curve chosen

| Situation | n | Ordinary scale (× the old 40-unit sprite) | Drawn size |
| --- | --- | --- | --- |
| Arrival, far | 0.30 | 0.5 | 20 |
| Formation top row, y 70 | 0.64 | 1.1–1.2 | 44–48 |
| Formation, y 118–214 | 0.67–0.72 | 1.2–1.3 | 48–52 |
| Reinforcement rows, y 300–412 | 0.77–0.84 | 1.4–1.5 | 56–60 |
| Diving at the ship | 0.95 | 1.5 (cap) | 60 |

Ordinary scale = 1.8 · n (× 1.1 when angry), rounded to 0.1 (4-unit sprite steps), clamped 0.5–1.5. Sentinels: n / 0.622 in 1/16 steps (8-unit steps of the 128-unit cell), clamped 0.75–1.25, so a hovering sentinel keeps its size and a diving one grows 25%. The carrier keeps its own presentation.

## 3. Readability at 360 px and on wide screens

- The arena is always the 360 × 520 column scaled to fit (1× on a 360-px phone, about 1.38× in a 1280 × 720 window), so the curve is the same everywhere; only device pixels change.
- The formation now averages about 48 units (+20%); the dive cap of 60 units is 17% of a phone's width, big enough to feel close without hiding the ship or the hostile shots.
- Arrivals at 20 units stay recognisable as gargoyles (silhouette and eyes survive); they are invulnerable while entering, so small size never costs the player a shot they could see.

## 4. Depth cues

- **Draw order by depth:** far to near every frame (stable for ties), so divers pass in front of the formation and arrivals tuck behind it.
- **Distance haze:** a second draw of the frame tinted dusk violet (#454A74) at up to 60%, fading out between n 0.30 and 0.56: arrivals emerge from the horizon's murk, formation demons are clear.
- **Ground shadow:** a three-row stepped pixel ellipse on the flyover ground at y = 172 + 348 · n, width ∝ n, opacity rising with nearness and falling with altitude. It stays nearly invisible under the high formation (the ground is very dark, luminance ≤ 0.13, and a row of blobs would clutter the shot lane) and darkens under a diver as it closes in. Shadows meet the ship plane only for the nearest divers, which is the altitude cue that matters.
- **Waiting arrivals** are parked, undrawn, at their far start point until their entrance begins, so the opening hint still has an empty sky.

## 5. Pixel-art scaling pitfalls and the choice

- Nearest-neighbour at a continuously changing fractional scale shimmers: the sampled pixel pattern changes every frame. Scale is therefore **quantised in the simulation** (4-unit steps for 64-px cells, 8-unit steps for the sentinel), so a demon changes size in discrete pops, like the scale tables of sprite-scaler hardware, and holds a stable pixel pattern between pops.
- Integer scale is impossible at phone size (64 px drawn at 20–60 units), so cells are drawn with `FilterQuality.none` at the quantised size; at 3× device pixels every logical pixel lands on 1–3 device pixels and stays square. Smooth filtering would blur the 1-px outline and eyes, which the style guide forbids. Pre-baked scale steps were not needed: 64 × 64 sources downsampled by nearest neighbour keep the outline, eyes and horns at every step down to 0.5, and the haze hides the roughest steps.
- The decorations (elite halo, hp pips, dive shield, tell chevrons, muzzle flash, death sequence) are drawn under the same canvas scale about the creature, so they stay attached and proportional.

## 6. Hitboxes and difficulty

The simulation owns n and the quantised scale, so collisions and pictures always agree:

| Box | Flat (before) | Perspective |
| --- | --- | --- |
| Shot hitbox, ordinary | ±16 × ±14 | ±13 × ±10 · scale (the measured opaque silhouette of the flight frames is 44 × 31 of 64 px, ±13.9 × ±9.7 at 40 units) |
| Shot hitbox, sentinel | ±27 × ±18 | ±27 × ±18 · scale (body box; membranes excluded) |
| Ship contact | 21 | 10 + 11 · scale (ship 10 + body 11) |
| Blast reach | radius + 14 | radius + 14 · scale |
| Hostile muzzle | +12 / +14 | (+12 / +14) · scale |
| Evade sidestep | 22 / 54 when within 18 / 38 | × scale, when within the hitbox + 2 |

The old box was larger than the drawn 40-unit sprite; the new one hugs the silhouette, which compensates most of the size gain. `ArcadeModel.perspective = false` restores the flat game exactly, for calibration.

Measured with `test/perspective_difficulty_test.dart`: a deterministic, non-prescient pilot (re-plans every 0.12 s or 0.2 s, aims with a lead at the nearest demon, sidesteps shots, divers at their visible size and ground missiles; lives refunded so every run finishes) plays each sector to its clear, 96 seeds × 2 pilot temperaments per mode, Normal difficulty:

| Sector | Route | Hit rate flat → depth | Clear s flat → depth | Lives lost/run flat → depth |
|---|---:|---|---|---|
| 1 | 0 | 42.6% → 41.6% (−2%) | 35.4 → 36.4 (+3%) | 0.72 → 0.73 (+1%) |
| 3 | 0 | 59.5% → 59.8% (+1%) | 79.9 → 81.3 (+2%) | 4.15 → 4.20 (+1%) |
| 5 (carrier) | 0 | 88.0% → 88.6% (+1%) | 51.8 → 49.6 (−4%) | 7.18 → 6.92 (−4%) |
| 1 | 1 | 56.4% → 57.9% (+3%) | 110.1 → 105.2 (−4%) | 9.65 → 9.05 (−6%) |
| 3 | 1 | 58.4% → 59.7% (+2%) | 164.7 → 161.8 (−2%) | 16.59 → 16.07 (−3%) |
| 5 (carrier) | 1 | 85.5% → 86.2% (+1%) | 112.9 → 112.7 (0%) | 16.73 → 16.58 (−1%) |

All within ±6%. Two lessons from tuning: a single pilot's quirks swing lives by ±20% between configurations (the sign flipped with the pilot's reaction time), so the test pools two temperaments; and lives lost are overdispersed, so the test accepts a lives difference within 10% or two standard errors of the measured run-to-run spread. Earlier tunings, for the record: silhouette box ±14 × ±11 and contact 8 + 13 · scale with a 1.6 dive cap made the depth game 3–8% easier to hit and up to 24% more contact-lethal near the ship; narrowing the box to the silhouette less the outline and capping the dive at 1.5 brought both back.

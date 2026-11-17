# Design: dive shields that thin, not narrow

Builds on `playtest-fixes-3` §1 (one crescent per shield), `alien-insignia` §4 (shield readouts) and
`carrier-render-engine` §4 (the carrier field "thins in place": `CarrierField.paint`, `wear`).

## 1. Causes (what the operator saw)
Found in `lib/game/scene.dart` (`_thermalBow`, `_diveBow`, `_smallOrMediumDiveShield`, `_sentinelDiveShield`,
`_sentinelBerserk`, `_rushShieldRing`) and the atlases, on `game` at 70095a1f:

- **Narrowing.** `_diveBow` cut the bow into one segment per point and switched them off with
  `InsigniaPainter.litCells`, which spends the outermost cell first. A 3-point elite at one point kept only the middle
  third; a sentinel's 5-point shield at one point kept a stub under its belly. That is the "from the sides to the
  middle" wear.
- **Segmented.** Segments were separated by 1.6-unit notches, spent ones were drawn as dark sockets at 0.7 thickness
  without the flame, and the tip embers were separate particles: several parts, not one asset.
- **Zooming independently.** Several parts of the shield moved on their own clocks and transforms, and none of them
  followed the body's:
  - the flame lick added up to 2.5–6 units (40–60 % of the thickness) to the trailing edge with two sines at 17 and
    29 rad/s, so the bow throbbed in size while the body did not;
  - the bow turned with the dive heading (`bowTurn`, ±0.45 rad) while the sprite is drawn upright (its banking is in
    its frames);
  - ordinary divers' bows were drawn after the wing-roll transform was restored, so the body rolled and the shield did
    not; sentinels' bows were drawn outside the bank transform (a roll and a horizontal squash of up to 8 %), and off
    the body's pixel-snapped centre (`effectSprite` rounds the sprite's corner to whole local units);
  - the rush's crimson bow was scaled 0.55 → 1 about the body through the rally and lock (it zoomed while the body
    held still), and the rush shield also had a second readout, `_rushShieldRing`: a fixed-size cell arc in screen
    units (`max(scale, 0.8)`, drawn after the camera zoom is undone), which did not scale with the sentinel at all;
  - the bows' sizes were not tied to the body: the small bow (32 units) was no wider than the diving gargoyle
    (≈ 31–34 units), and the angry gargoyle is drawn 44 units wide instead of 40 while the bow kept its size.
- **Not a shield cause, for the record.** The ordinary divers' two dive frames (combat.png row base+7, cols 20–29)
  alternate at 8 Hz between ±25 and ±23 px wide: the authored wing flutter of the dive. The shield is sized for the
  wider frame and does not pulse with it (a pulsing thickness would blur the readout).

## 2. The thinning shield (`lib/game/dive_shield.dart`)
- **One arc.** A shield is an arc about the creature's centre with half-angle `DiveShield.halfAngle` = 62° from
  straight down (124° in all), the same for every species, level and zoom. Every layer is a stroke of that same arc
  with butt caps (radial ends, so the angular width is exact): a glow, the body (the thickness), an inner heat core,
  and a white-hot leading edge on the outer side. A slow shimmer runs along it (brightness only; none with reduced
  motion). No segments, notches, sockets or particles.
- **In the body's transform.** The ordinary diver's shield is drawn inside the same save as its sprite, after the
  wing roll; the sentinel's inside `_bankAbout` (shared by the body and the rush shield) on the sprite's snapped
  centre (`_sentinelCentre`). The scale is the creature's (`d.scale × _creatureFloor`), so the shield moves and zooms
  exactly with the body.
- **Sized from the silhouettes.** `DiveShieldSpec(coverHalfWidth, coverBottom)` is the widest half-width and the
  lowest point of every pose the shield is drawn over, measured from the committed atlases (alpha > 96):
  ordinary dive cells ±25 px, 14 px below the centre of a 64 px cell drawn 40 units wide (×44/40 when angry); the
  sentinel's dive cells (sentinel-effects rows 8–9, cols 4–7) ±29 and 28 below; its berserk cells (rows 6–7, every
  column: the rally poses and the reeling tumble) ±49 and 20 below, at 1 unit per px. The inner radius clears the
  lower corners by 3 units (4 for the rush); the centre line `mid = inner + full / 2` is fixed. Its ends reach
  `mid · sin 62°` sideways, past the widest pose (unit test re-measures the atlases).
- **Thinning.** `thickness(points, max) = hairline + (full − hairline) · (points − 1) / (max − 1)`: full when whole,
  one equal step per spent point, `hairline` = 1.25 units on the last point; a one-point shield is drawn full. The band
  stays centred on `mid` (the carrier membrane's fixed offset), so it thins from both edges toward its centre line and
  never moves. `heat` (the same fraction) cools the glow (alpha 0.32 → 0.12) and the colours (white-hot → orange →
  ember); the last point flickers at 11 rad/s (1.75 Hz, under WCAG 2.3.1's three flashes); `ShieldFx.hitFlash` whitens
  the whole arc for 0.12 s after each hit, and a breaking shield flashes out as a hairline.
- **Full thickness per class** (local units): one-point divers 5, two-or-three-point divers and elites 8, the
  sentinel's dive shield 11, the rush shield 15 (the thickest). Palettes: thermal (main spec: dive shields are
  thermal), crimson for the rush.
- **Rush.** Through the rally and lock the rush shield forms in place: opacity 0.3 → 1 and thickness hairline → full
  with the tell's progress, never a change of size. In the rush it thins with `rushShield / rushShieldMax`; a stagger
  dims it to half. The fixed-size cell ring is removed.

## 3. Gameplay
Unchanged. `hitDemon` spends dive and rush shield points for any hit on the creature's hitbox; no hit test reads the
drawn shield, so the old narrowing never narrowed a hitbox and the new arc does not widen one. Points, breaker
damage and scores are untouched; no calibration number moves (`plan/calibration-current.md` unchanged).

## 4. Tests and review
- `test/dive_shield_thinning_test.dart`: thickness strictly increasing with the points for every spec and point count
  (and full / hairline / 0 at the ends), the rush the thickest; the specs cover the silhouettes re-measured from
  combat.png and sentinel-effects.png; rendered at zooms 0.45–1.6, the centre line spans exactly ±62° at every level
  and the shield's x-extent covers the body's; the drawn thickness at the nose falls with every spent point; every
  level at every zoom is one 8-connected shape.
- `test/dive_shield_thinning_review_test.dart` (review tag): `.cache/dst/{before,after}` tiles of twelve cases at
  zooms 0.6 / 1.0 / 1.5, laid out as `art/contact/dive-shield-thinning.png` (rows: small 1/1; not-so-small 2/2, 1/2;
  elite 3/3, 2/3, 1/3; sentinel 5/5, 3/5, 1/5; rush 8/8, 4/8, 1/8; columns: before | after per zoom, a grey strip under
  before and a gold one under after), and the frames of a dive with hits for
  `art/contact/dive-shield-thinning-dive.gif`.

## 5. Revision: the old form, the new wear (operator, 2026-11-17)
After playing §2: "Those are some thick shields lol and they 'thin out' to nothing :P and too round, the previous
form and size was right, it's just the way in which they were getting worn out that was weird. This is the correct
way to wear the shields down, but an ugly geometry."

§2's 124° arc, its sizes and its hairline are replaced; its principle stays. `DiveShieldSpec` is again the
playtest-fixes-3 crescent: half span, nose drop, leading edge and nose thickness (small 16 / 5.5 / 7.5 / 6, medium
24 / 7.5 / 5.5 / 7.5, sentinel 52 / 15 / 3 / 10, rush 64 / 18 / 2 / 13, the thickest), its tapering profile
`thick · (1 − u²)^0.55 + 0.6`, its four colour bands (1 / 0.7 / 0.42 / 0.2 of the thickness), the thermal and crimson
palettes and the ember tips. What made it segmented or independent stays removed: the shape is drawn whole (no
per-point pieces, notches or sockets); the flame lick is a fixed profile (its old mean, 0.55 of `lick`) instead of a
17 / 29 rad/s animation; no heading turn; it is drawn inside the body's transform (wing roll, sentinel bank, snapped
centre); the rush shield fades in at full size instead of growing. The embers still rise from the two tips (attached
to them; none with reduced motion).

Wear: the leading edge and the span never change; the trailing side scales by
`wear = 0.4 + 0.6 · (points − 1) / (max − 1)` (1 for a one-point shield), so every spent point is an equal step and
the last point keeps 40 % of the full thickness. The envelope dims slightly with the wear, the last point flickers
(1.75 Hz) and each hit flashes the whole crescent white for 0.12 s.

The sheet `art/contact/dive-shield-thinning.png` now pairs the old segmented crescent (rendered from c7b5ffde, the
commit before this change) with the restored, thinning one. Tests: `test/dive_shield_thinning_test.dart` (span
constant within 1.5 px at every level and zoom and covering the measured silhouettes, wear strictly increasing with the
points, the drawn thickness non-increasing and never under the floor, one connected shape).

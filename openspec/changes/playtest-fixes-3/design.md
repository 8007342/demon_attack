# Design: playtest fixes, round 3

Builds on `alien-insignia` §4 (segmented dive shields), `demon-intelligence` §6 (the rush), `terrain-shadows` §2–§4
(projector, lurk, hand-off), `transition-ascent` §1–§2 (beats, pitch) and the mobile top trim (the arena sits on the
pilot dock: `paintArena(alignY: 1)`).

## 1. Diving shields: one crescent
**Root cause.** Each bow was assembled from 3-unit columns. Every column had its own rounded y
(`(pos.dy + 11 + curve).roundToDouble()`), its own sine-driven tongue height and ±1 jitter, segments were cut by
6-unit holes, and the wingtip sparks sat at fixed offsets unrelated to the arc's ends. The rounding happened in the
creature's local units *before* the creature's scale transform, so neighbouring columns stepped by whole scaled
units: at scale 1.25–1.6 the arc broke into vertically offset blocks with gaps, and the sparks floated free.

**Fix.** `DemonScene._thermalBow` draws a bow from one crescent function: leading edge
`lead + nose·(1 − u²)`, thickness `thick·(1 − u²)^0.55 + 0.6`, and one smooth two-harmonic flame lick along the
trailing edge (continuous across segments). The four colour bands (outer envelope → white-hot nose) are polygons of
that same function at 1.0 / 0.7 / 0.42 / 0.2 of the thickness, sharing the leading edge, so they scale and turn
together. Segments are separated by 1.6-unit notches; a spent segment is a dark ember outline (the shape stays whole);
a segment burning off flashes white. Embers rise from the two tips (attached to them). The bow turns toward the dive
heading (`bowTurn`, `−atan2(vx, vy)·0.8`, ±0.45 rad). Sizes: small 16 / 5.5 / 6, medium 24 / 7.5 / 7.5, sentinel
52 / 15 / 10, rush 64 / 18 / 13 (half span / nose / thickness). The rush's crimson bow uses the same function with
the crimson palette.

## 2. Sentinel rush
- **Transformation.** `berserkTransforming(d)` (rally, lock): `_rushShieldHit` absorbs every hit, powered or homing,
  and records a `Deflect` (impact point and the body's centre). No damage, and the white hit flash is cleared. The
  crimson bow condenses (0.55 → 1 of its size) through the tell.
- **Super diving shield.** In the rush, the bare gun deflects; offensive powers and homing hits wear the rush shield
  by damage + 1 Powerful + 1 Large (as the sentinel's ordinary dive shield already did).
- **Deflect spark.** `_deflectSparks`: a white-and-gold star at the impact and five sparks ricocheting away from the
  body, 0.28 s (star only in reduced motion).
- **Numbers.**

| | Easy | Normal | Hard |
|---|---:|---:|---:|
| Rush chance (was) | 0.28 (0.20) | 0.45 (0.35) | 0.55 (0.45) |
| Rush shield (was) | 6 (3) | 8 + cycle÷2 (4 + cycle÷2) | 10 + cycle÷2 (5 + cycle÷2) |

  Per (cycle + 1) × enemy points: a dodged pass 300 (new), a break 150 (was 400), and a burn-out after a dodged last
  pass pays the sentinel's kill value (was nothing; no drop, no kill count).
- **Why these.** A rush pass lasts about 0.5–0.7 s from lock to the ship row; the shots in the air meet it at
  ~1200 u/s closing speed, so a pilot sitting under it lands about 5 base-cadence or 10 Rapid hits in one pass. With
  Powerful (3 breaker per hit) the Normal shield breaks in 3 hits and Hard's 12 in 4; Rapid alone needs 8–12 hits, a
  pass or two; the bare gun never. Breaking needs the pilot in the charge's line (a lost life without a shield), and
  pays less than the dodge it gives up, so dodging is always the better play.

## 3. Sentinel shadow
**Root cause.** A sentinel that has arrived publishes no altitude (`Demon.altitude` 0; only the rise had an eased
value), and `_shadowOf` returns nothing for `h ≤ 0`: in the fight the sentinel had no shadow, except the rush
lock's snap. The hand-off also contracted the lurk (2.5 × 1.3 of the in-play size at the front) to the in-play ink
shadow in 0.8 s while cross-fading from the occluder look to blurred ink, which on the dark grounds reads as nothing.

**Fix.**
- `sentinelShadowAltitude`: the flight sheet's altitude (`SwarmFlock.fightAltitude(homeY)`), falling toward the
  ship's 40 as a rush comes down. Presentation only.
- One size rule, `sentinelShadowScale(n, h) = 1.6 · n · (1 + 0.3·k) · (1 + 1.2·max(0, h − 90)/130)`, `k = h/300`,
  `n` the ground's nearness under the shadow (≥ 0.2). In the fight (n ≈ 0.62, h ≈ 85) it is ≈ 1.1, the sentinel's own
  drawn size; the lurk far and high (n 0.2, h 220) is 0.86 (was 0.8), at the front (0.43, 120) 0.98 (was 2.24). The
  lurk, the rise, the fight and the rush all use it.
- Every sentinel shadow is drawn as the lurk's occluder (`_paintLurk`: desaturate + cool multiply on the draped mesh),
  so the look never changes; the hand-off is one occluder gliding (position, size, alpha) for 0.8 s.
- Measured on the review run (seed 7, Normal, sector 2): lurk 0.91 → 1.02, rise 0.86 → 0.91, fight 1.14, rally 1.13,
  lock / rush 1.6 (on the ship's nearer ground).

## 4. The band above the arena
`paintArena` computes `headroom` = spare height above the arena in arena units and clips the background to
`(0, −headroom, 360, 520 + headroom)`:
- **Sky.** `FlyoverBackground._sky` bakes with `skyRoom(headroom)` (8-unit steps): the painting's sky is anchored at
  the viewport's top; when the band is taller than the painting's sky above its own horizon (58 % of its rows), it
  zooms to cover, cropping the sides evenly. With no band the bake is unchanged.
- **Parallax.** The sector's particulates wrap over `520 + headroom` rows at the same density.
- **Fog.** The layers reaching the arena's top (upper veil, sky sheet 1) continue through the band at their top-edge
  strength, thinning by a third toward the viewport's top (`Atmosphere.paintBand`); inside the arena every layer is
  unchanged. The transition's cloud cover and the pitch band fill it too.
- **Gameplay** (creatures, shots, ground air units, bonus mechanics, the carrier) is drawn under a hard clip to the
  arena; both clips are aliased so the seam has no hairline.
- 360 × 640: headroom 120; 390 × 844: 259 (sky zoom 1.38); desktop 1280 × 720 and 1920 × 1080 are height-limited
  (no band; the widescreen backdrop fills the sides).

## 5. Ascent
What read as sideways: the world's 3° bank toward the pursuit side, and the pursued flock streaming 14 u/s toward that
side for the whole Pursuit (plus a 70-unit sideways rout). Changes:
- `roll` beat gain 0 in the sector change (the beat stays for the API; the outro never had it).
- `pitch` starts at p0 + 0.2 with the climb, not with the cloud, so the horizon and ground fall away below the ship in
  clear air; the band it uncovers is deep sky (`#070B16`) until the cloud comes in.
- The flock gathers over the ship's lane (half-way from the centre) and climbs 46 units into the high cloud; the rout
  flees mostly upward (24 sideways, 64 up). `dir` only drives the Descent's wheel, where the next cohort comes out.

## 6. Validation
- `test/playtest_fixes_3_test.dart`: transformation invulnerability and deflects, the rush shield's breaker rules,
  the tuning, dodge ≥ break + kill for every difficulty, the shadow size rule and an in-play sentinel's shadow, the
  bow's continuity and turn, the band (background in every row, nothing of gameplay in it), no bank and an early pitch,
  the flock's straight climb.
- `test/playtest_fixes_3_review_test.dart` writes `art/contact/playtest-fixes-3-{shields-before,shields-after,rush,
  band,band-wide,ascent}.png` with `--dart-define=PF3_CONTACT=true`.
- Calibration: §7.

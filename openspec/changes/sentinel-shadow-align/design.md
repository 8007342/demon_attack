# Design: the looming sentinel's shadow follows its silhouette

## 1. Root cause
Two unrelated paths drew one sentinel:

| | Silhouette (`SentinelForeshadow.place`) | Lurking shadow (before this change) |
|---|---|---|
| x | `180 + a·cos(tp)`, a = 96 + 24·growth (a 10 s figure-eight) | `LurkTrack.x0` (180 ± 54, seeded) + 30·sin(2πt/9) |
| depth | nearness `0.08 + 0.2·growth ± 0.03` | flat y walking from z = 9 z0 to the front at 10–16 u/s |
| altitude | none | virtual, 220 → 120 along the walk |

The shadow was never projected from the silhouette, so it wandered on its own ("an independent minded shadow"). The
swarm and the fighting sentinel were fine because `_shadowOf` projects from the caster's own `x` and `nearness`.

## 2. The projection (the demons' rule)
`_shadowOf` places every flyer's shadow the same way: the flat-ground point under the caster is
`(x, Perspective.groundY(nearness))`; the sun ray from altitude `h` meets the ground at
`base + h·tan 32°·0.22·(cos az, 0.25 + sin az)` (flat), or the relief's hit from `ShadowProjector.hit` (draped),
with the sun azimuth drifting ±4°.

The looming shadow now uses exactly that, through the same `_flyerHit`:
- **base** `DemonScene.foreshadowBase(f) = (f.x, groundY(f.nearness))`, the silhouette's drawn x (it is drawn at
  `f.x` rounded) and the ground under its depth;
- **altitude** `SentinelForeshadow.shadowAltitude = 120`. It is the altitude the rising sentinel's shadow starts from
  (`_shadowOf` eases from it to the fight altitude over the rise), so the projection is the same one on both sides of
  the hand-off. The former 220 → 120 virtual altitude belonged to the walk and goes with it;
- **size** the existing one sentinel rule `sentinelShadowScale(n, h)` with `n` the ground nearness at the hit
  (`groundNearness(hit.flat.dy)`), the rule the rising and fighting sentinel already use.

No other factor. The operator first suggested 7–8 % smaller at the back and 1–2 % per layer, then withdrew it
("Don't use my percentages lol just make it smaller at a distance, and track the centinel as it approaches. Once its
shadow maps correctly it should behave correctly for size and perspective as well."), so the size is whatever the
projection gives.

## 3. The nearness floor
`sentinelShadowScale` clamped the ground nearness to at least 0.2 (`lurkMinNearness`, lurk-visibility) so the old
lurk was a broad patch as soon as it appeared. Under the silhouette the ground nearness is about 0.06–0.33, so the
floor held the shadow at one size for the two-waves-ahead stage and most of the one-wave-ahead stage: the projection
would have shown no size change there. The floor is removed (the fighting sentinel is always above 0.2, so the fight is
unchanged). With it gone the far shadow is small, which is the request.

## 4. Hand-off
Unchanged code: when the silhouette goes, the last looming spec blends over 0.8 s into the rising sentinel's own. The
rising sentinel starts at `entryX = f.x`, `entryN = f.nearness` and altitude 120, so its own spec at the first frame is
the looming spec, and the blend now only covers one frame of motion.

## 5. Measured (`test/sentinel_shadow_align_test.dart`, sector 2, seed 7)
| Stage | Silhouette nearness | Shadow scale (of the 128 × 64 strip) |
|---|---|---|
| two waves ahead | 0.05–0.11 | 0.134–0.283 |
| one wave ahead | 0.15–0.21 | 0.363–0.512 |
| arriving (waiting for its escort) | 0.27–0.31 | 0.633–0.732 |
| rise start → arrived (n 0.27 → 0.64) | | 0.633 → 1.099 |
| fight (n 0.62, h 85, reference) | | 1.1 |

- **Alignment.** At every sampled frame the shadow's x leads the silhouette's x by the flyers' sun lead at h 120,
  120 · tan 32° · 0.22 = 16.5 units times cos(drift) (16.46–16.5), within 1 unit; on flat ground its y is the ground
  under the silhouette's nearness plus 16.5 · (0.25 ± sin 4°), within 1 unit. Draped, the relief catches it sooner, so
  the lead is 0–16.5.
- **Size.** Nearer is never smaller (pairs more than 0.01 apart in nearness), and each stage is larger than the one
  before. The size comes from the projection alone: no fixed factor, as the operator asked.
- **Rise.** The one sentinel rule includes a penumbra spread from altitude (`1 + 1.2 · max(0, h − 90) / 130`). Over
  the rise the altitude falls from 120 to the fight altitude while the nearness climbs, so the shadow narrows by
  about 2 % around the rise's midpoint before it grows on (0.874 → 0.856 → 1.099). That rule and its altitude ease
  predate this change (playtest-fixes-3); the test bounds the dip below 3 %.
- **Hand-off.** At most 2.7 units of movement and 1.3 % of size per frame from the looming shadow through the rise.
  The last looming scale and the first rising scale are both 0.633.

## 6. Not changed
- The silhouette's drawing, its path and its size; the swarm's and the fighting sentinel's shadows.
- The occluder look, alpha (`lurkAlpha`), the fog pass and the ground hesitation footprint (`lurkCover`, which now
  lies under the silhouette).
- The simulation: `LurkTrack` had its own PRNG stream and fed nothing back, so removing it moves no calibration number.
- Review: the existing `terrain_shadows_review_test.dart` lurk and hand-off strips cover this (now sampled every 4 s of
  the silhouette instead of by track progress); no new contact sheet.

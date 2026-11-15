# Design: fog restoration

Operator feedback 2026-11-15, W2 (plan/operator-feedback-2026-11-15.md). Arena coordinates: 360 x 520,
horizon at y 172, nearness n = z0/z (arrivals from n .30, formation n .62 and nearer); see
openspec/changes/atmosphere-and-swarms/design.md for the layer model this restores.

## 1. Archaeology: what was better, what regressed

History of the fog (`git log -- lib/game/atmosphere.dart lib/game/ground_atmosphere.dart lib/game/scene.dart
shaders/fog.frag lib/game/perspective.dart`), with review frames rendered from old revisions in throwaway
worktrees (`test/atmosphere_review_test.dart` at 6953b98f) and from the base of this branch
(`test/fog_restoration_review_test.dart`, `FOG_REVIEW_TAG=before`):

| Commit | Fog | Ship coupling |
|---|---|---|
| d6c1f868 wave pressure | 9 blurred ovals of "smoke and low cloud" on the horizon, per-creature mist wisps, a second haze draw | none |
| df170d0d / e2be77a2 / 6953b98f atmosphere-and-swarms | horizon band (y 112-236), far banks A/B (120-238, 130-252) as domain-warped fBm (shader, tiles as fallback), **interleaved with the creatures by nearness** (.26/.335/.43); ground fog on the terrain to the bottom row; two thin sky sheets. The foreshadow silhouette drawn after the horizon band, **behind both banks**; the sentinel then flew in from it through banks A and B. Frame-time guard (6953b98f). | every layer shifted by `(shipX-180) x parallax x .1` (up to 19 units for the sky sheets); the silhouette's path by `(shipX-180) x .12` |
| 3fb472b8 ground atmosphere atlas | `Atmosphere.groundArt` **takes over** the horizon band and both far banks (`artSlots`): `paint()` returns early for them. What replaces them: the art's 40-row low cloud deck at y 140-180 in the horizon slot, and 24-48-row stepped pixel strips (horizon fog 178-226, mist banks 206-243) drawn in the *ground* sort, i.e. before every air creature | art bands shift by `(shipX-180) x parallax` with parallax .04-.3 per unit, **ten times** the old factor: mist bank B moves 42 units when the ship goes from the centre to an edge |
| 582e0cf5, cb141549 (silhouette sheet, unit fog by depth, smoke, flock draw order) | kept the 3fb472b8 composition | unchanged |

What the operator liked (6953b98f): fog in depth over a large part of the field, soft fBm billows that evolve,
creatures crossing banks as they come in, and the silhouette circling *behind* drifting banks so it appeared
and disappeared in the cloud; the sentinel's own flight from that spot passed through two banks before it was
clear.

What regressed, and why:
1. **Ship-bound fog.** Present in a small way since df170d0d (layer parallax x .1, silhouette x .12), made
   obvious by 3fb472b8, whose art bands use the generated per-unit parallax without the .1 factor. The flyover
   ground does not move with the ship, so the fog visibly slid against the terrain whenever the player
   steered: "the controller drags the fog". There is no camera that follows ship x, so any parallax is wrong.
2. **Narrow band.** Once the atlas loads (always, in the game) 3fb472b8 removed the three soft air layers and
   put 24-48-row pixel strips between y 140 and 243 in their place: the fog became a stepped band across the
   middle of the screen, with nothing above it and only the thin ground fog below.
3. **Simpler sentinel reveal.** With banks A/B gone from the air pass, nothing was drawn in front of the
   silhouette except the thin sky sheets (the art's mists are in the ground sort, under all air creatures), and
   nothing lay between the arriving sentinel and the camera: it simply faded with its tint.

Kept from later work: the atlas art (as an addition), unit depth tint, battlefield smoke, the silhouette sheet,
the flock draw order, the frame-time guard, reduced atmosphere and reduced motion.

## 2. Composition

Draw order (unchanged structure): background; ground sort (units, allies, the art's horizon fog, cloud
shadows, mist banks, dust veil); ground fog; flyers; arrival shadows; air depth sort with the fog layers;
sky sheets; tells, bullets, ship, HUD.

Air layers, far to near, each a wide soft profile (top, peak, bottom, alpha):

| Slot | n | Profile | Renderer |
|---|---|---|---|
| horizonBand (+ art low cloud at .45 under it) | .26 | 92 / 172 / 258, .70 | shader / tiles |
| *foreshadow silhouette* | .08-.31 | its figure-eight, y ~125-160 | silhouette sheet |
| farBankA | .335 | 84 / 176 / 262, .48 | shader / tiles |
| farBankB | .43 | 96 / 198 / 286, .40 | shader / tiles |
| upperVeil (new) | .50 | -40 / 92 / 214, .30 | tiles |
| midVeil (new) | .565 | 112 / 226 / 350, .30, clears lane | tiles |
| groundFog (not depth-sorted, under the air) | — | 180 / 262 / 540, .38, clears lane | tiles |
| sky sheets | — | as before (<= 12 % over the ship) | tiles |

- Profiles overlap so that every row from y 40 to 340 has fog and three or more layers overlap in the mid
  field (120-260): the body of fog has no edges, only density.
- All five air layers lie between the arrival depth and the formation, so an arrival from n .30 crosses four
  of them, one at a time, while it rises toward its slot; formation creatures are in front of all of them.
  A wave holding in the fog (n ~.30-.4) sits behind three to four layers.
- The silhouette is drawn right after the horizon band: farBankA, farBankB, both veils (and the sky sheets)
  drift across it at different winds and scales, so it shows through moving gaps instead of under one flat
  veil. Its fade-in is 3 s (was 1.5 s). When its wave comes, the sentinel sets out from that spot and is drawn
  at its own nearness, crossing every layer.
- Soft compositing: each layer is noise x profile, src-over at low alpha; their sum builds the density. The
  shader's wisp cut is wider (stretch 1.8, smoothstep .18+threshold .. .86, then smoothed again) so warped
  billows lose the hard sheet-like edges they had.

## 3. World anchoring
`Atmosphere.advance` no longer takes the ship; `FogLayer` lost `parallax`; the shader's lateral-offset uniform
is 0; `GroundAtmosphereArt.offset` is the wind drift alone (the generated `parallax` column stays in the
atlas file, unused, to avoid regenerating it); `SentinelForeshadow.place()` has no ship argument. The
silhouette's position seeds the entering sentinel's path (`entryX/Y/N`), which is untargetable and ends at its
formation slot, so no simulation outcome changes.

## 4. Near lane
`clearsLane` layers (mid veil, ground fog) are thinned by 62 % over x 96-264 below y 300 with a 36-unit soft
ramp (`Atmosphere.laneMask`, applied with a dst-out mask inside the layer's own save-layer). The analytic peak
`Atmosphere.combinedAlphaAt` of all fog layers stays at or under 0.30 everywhere in the lane (tested), and a
rendered frame of every layer, art included, stays under it on the shader and the tile path (tested).

## 5. Cost
Two more tile layers (two textured rects each) and two extra save-layers for the lane mask: well inside the
existing 2 ms fog budget on the tile path (`test/atmosphere_perf_test.dart` ceilings unchanged). The shader
still draws only three slots; the frame-time guard still drops it to tiles.

## 6. Review
`test/fog_restoration_review_test.dart` renders, per sector (2, 3, 4) at 360 x 780 portrait with every atlas
loaded, (a) the wave before a sentinel's, thinned so the next wave holds in the fog while the silhouette
circles, and (b) the sentinel flying in; plus 2x close-ups and the tile / reduced variants (not on the sheet).
`art/contact/fog-restoration.png`: rows are sectors 2, 3, 4; columns are (a) before, (a) after, (b) before,
(b) after (red bar = before, green = after).

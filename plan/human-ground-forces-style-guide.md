# The Ground Fleet: human ground forces style guide

The **Ground Fleet** is the human convoy that drives up the flyover's ground plane under the player's ship: rovers, carriers, half-tracks, tanks, guns, walkers and infantry squads. This guide sets their futuristic look: silhouette language, materials, palette, readability at the game's sprite size, and how hull and turret move apart. Headings and frame layout are in [ground-unit-animation.md](ground-unit-animation.md). OpenSpec change: `openspec/changes/ground-forces-rework/`.

It extends, and never overrides:
- [style-guide.md](style-guide.md), "Ground war presentation": allies never die (totalled, limp off, crew pod), cyan IFF chevron, 1.3× ally scale;
- [perspective.md](perspective.md): the flyover camera;
- [gargoyle-army-style-guide.md](gargoyle-army-style-guide.md): the Undercroft Host, the enemy that this army must never be confused with;
- [ground-troops-terrain-style-guide.md](ground-troops-terrain-style-guide.md): terrain poses (climb, descend, ford);
- `art/families/ground-forces.json`: the reserved colour sets `ally_hull`, `ally_cyan`, `ally_crew`.

Every design is original. No unit, name or shape comes from another game, film or toy line, and no prompt names a franchise, studio or artist.

---

## 1. Identity in one sentence

> **Survey gear that learned to fight.** The Fleet's ground arm is frontier engineering: low faceted plate, right angles and 45° chamfers, cyan light lines, and one long thin gun on a compact turret.

The three factions on screen, with this guide's column filled in:

| | Ground Fleet (this guide) | Brood swarm (air) | Undercroft Host (ground enemy) |
| --- | --- | --- | --- |
| Tech language | **Built**: flat faceted plate, chamfers, panel seams, rivet rows | **Living**: membrane, hide, horns | **Carved**: dressed stone, iron bands, hooks and spires |
| Dominant lines | Horizontal and 45°, straight | Curves | Pointed arches, hooks, verticals |
| Light | **Cyan lines** (strips along edges) | Warm shots | **Warm dots** (eyes, spout mouths) |
| Rank cue | Antenna and sensor mast height | Species | Spire height and gilt |
| Propulsion | Hidden tracks under skirts, big wheels, hover pads, piston legs | Wings | Exposed iron tracks, stone wheels, arched buttress legs |
| Seen from | Behind and above, driving up the plane (all headings in this guide) | 3/4 above | High 3/4 side, coming down the plane |
| Defeat | Never dies: totalled, smoking, limps off; crew pod | Cracks into stone | Rubble heap, or breaks into pieces |

The one-line read at phone size: **cyan lines on grey-blue boxes are friends; warm dots on dark stone are enemies.**

## 2. Design pillars

1. **Straight and chamfered.** Every hull edge is horizontal, vertical or a 45° chamfer. No hooks, no pointed arches, no curves larger than a wheel or a turret ring. The Host owns curves and points; the Fleet owns the cut corner.
2. **Low hull, compact turret, long gun.** The hull is wide and flat. The turret is a smaller separate block set **forward of centre**, so the turret reads even when it points the same way as the hull. The barrel is the longest thin line on the unit (2 texels thick, never 1, so it survives the far scale).
3. **Light is a line.** Fleet lights are 1-texel cyan **strips**: a glacis edge strip, a turret visor slit, wheel-hub rings, the hover-pad glow. The Host's lights are dots, so a strip at any distance says "friend". Lamps never use warm colours.
4. **Hidden machinery.** Tracks sit under side skirts and show only as a 1–2 texel sliver of moving links at the bottom; wheels are big and few. That is the "futuristic" read, and it keeps the move cycle cheap (only the sliver animates).
5. **Rank is the mast.** A command or sensor vehicle carries a taller antenna or a folded sensor mast at the rear of the turret. Masts are thin vertical lines with a cyan tip pixel. Never a point or spire shape (that is Host rank).
6. **Sector kit, one family.** All sectors share one hull vocabulary. Sector differences are camouflage panels and kit (snow skids, patch plates, heat tiles, mire snorkels), never a new shape language.

## 3. Roster

Sizes are visible content boxes in texels at heading 0 (driving straight up the plane) and at heading 90 (side-on). The drawn size in arena units is `texels × GroundCamera.texel(z) × 1.3` (the ally scale): allies hold at z 250–302 (×1.5–1.8) and advance to at most z 620 (×0.73). A 360-px phone shows about 1 arena unit per CSS pixel.

The table maps onto the existing ally slots (`GroundAtlas.allyRow(sector, variant)`), so the gameplay contract does not move. The Carrier sector gets its own slot (today it reuses the Hollow rows).

| # | Unit | Role | Slot (sector, variant) | Today | Propulsion | Size h0 / h90 (texels) | Near z 276 / far z 620 (units, h0 width) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F-1 | **Sleet** | Light scout rover | Krybor 0 | rover | 6 big wheels | 22 × 18 / 30 × 16 | 36 / 16 |
| F-2 | **Cairn** | Armoured carrier (carries the rifle squad) | Krybor 1 | apc | 8 wheels | 24 × 22 / 34 × 18 | 39 / 17 |
| F-3 | **Tether** | Half-track with recovery winch | Ringfall 0 | halftrack | front wheels, rear tracks | 24 × 20 / 34 × 17 | 39 / 17 |
| F-4 | Militia squad | Rifle infantry (squad) | Ringfall 1 | militia | feet | see Section 4.3 | |
| F-5 | **Lodestar** | Main battle tank (the hero tank) | Ember 0 | mbt | skirted tracks | 26 × 24 / 36 × 19 | 43 / 19 |
| F-6 | **Sextant** | Self-propelled long gun (artillery) | Ember 1 | spg | skirted tracks, outrigger spades | 26 × 26 / 38 × 20 | 43 / 19 |
| F-7 | **Stilt** | Two-legged walker | Hollow 0 | mech | 2 straight piston legs | 22 × 28 / 26 × 28 | 36 / 16 |
| F-8 | Heavy squad | Rocket infantry (squad) | Hollow 1 | heavy | feet | see Section 4.3 | |
| F-9 | **Skiff** | Hover tank | Carrier 0 (new slot) | (Hollow rows) | 4 hover pads | 26 × 20 / 34 × 16 | 43 / 19 |
| F-10 | Rifle and rocket troopers | Infantry escorts | every sector | `ground-troops.png` rows 3–4 | feet | 13 × 21 | |

Every vehicle fits a **48 × 40 texel cell** at every heading (the diagonal headings are the widest: about 36 × 26 for Lodestar at h45).

### 4.1 Vehicles

**F-1 Sleet: light scout rover.**
- *Silhouette:* a short flat **wedge** that is lower at the front, on six big wheels that stick out past the body (the wheel row is the cue). A tiny pod turret with a short twin coil gun sits at the front third.
- *Kit:* a whip antenna at the rear, a roof light bar (3-texel cyan strip), snow skids on the front wheels in Krybor.
- *Motion:* the fastest ally; a 1-texel body bounce on alternate move frames.
- *Phone read:* a small box with six dark dots around it and a cyan bar on top.

**F-2 Cairn: armoured carrier.**
- *Silhouette:* the tallest wheeled box: a **flat roof with a stepped rear** (two steps, like a loading ramp) on eight wheels. A small remote gun pod on the roof. The rear ramp is visible from behind, which is the camera's usual view.
- *Special:* **deploy**, 3 frames: the rear ramp drops, the cabin light spills cyan-white, and a rifle squad walks out. This is the human counterpart of the Host's Reliquary unload, with the opposite language (a ramp down, not wings up).
- *Phone read:* the boxiest ally, with a lit rectangle at its back when deploying.

**F-3 Tether: half-track and recovery vehicle.**
- *Silhouette:* a long chassis, **wheels at the front and a skirted track at the rear**, with a short **A-frame crane and cable drum** at the back. A twin autocannon sits on a ring mount over the cab.
- *Special:* **tow**: when an ally falls back to repair, a Tether nearby lowers its A-frame (2 frames) and a 1-texel cyan cable line draws to the battered ally. Presentation only; the repair rule is unchanged.
- *Phone read:* the only ally with an A-frame triangle at the back.

**F-5 Lodestar: main battle tank (the hero).**
- *Silhouette:* a **low faceted wedge hull** with a long chamfered glacis and side skirts that hide the tracks except for a 2-texel sliver. The turret is a **flat hexagonal slab**, set forward, with a long **rail barrel** carrying two 1-texel coil rings and a squared muzzle brake. A short sensor mast at the turret's rear.
- *Light:* a cyan strip along the glacis edge, a visor slit on the turret front, a cyan muzzle ring that glows for one frame on each shot.
- *Motion:* the track sliver crawls (4 frames); the hull dips 1 texel at the front on each shot (recoil), and the barrel slides back 2 texels and returns.
- *Phone read:* the longest gun on the ground, on a flat hex turret over a low wedge. If one ground unit is shown on a store page, it is this one.

**F-6 Sextant: self-propelled long gun.**
- *Silhouette:* the Lodestar hull with a **tall boxy casemate** at the rear instead of a turret, and a very long barrel that **elevates** (3 elevation steps). Two outrigger spades fold down at the back when it fires.
- *Special:* **brace**, 2 frames: the spades drop; then the barrel elevates; then fires with a long cyan flash and a dust ring.
- *Phone read:* the barrel angled up. Artillery on both sides is "a thing that aims up", but the Fleet's is a single straight barrel and the Host's are open bells.

**F-7 Stilt: two-legged walker.**
- *Silhouette:* a **boxy cab** with a wide cyan visor strip, on **two straight telescoping legs** with flat square feet. Gun pods on both sides of the cab. Straight legs are the cue: the Host's walkers stand on arches.
- *Motion:* a 6-frame stepped stride with a 1-texel cab bob; feet plant flat with a dust puff; stride-over (terrain guide) on ravine ends.
- *Phone read:* a box held up by two sticks, cyan slit across the front.

**F-9 Skiff: hover tank.**
- *Silhouette:* a **flat lozenge** with chamfered corners, no wheels and no tracks: **four hover pads** at the corners, each a short cyan line on the underside. The hull floats 2 texels over its shadow. A low turret with a short, wide barrel.
- *Motion:* a 2-frame 1-texel hover bob instead of a move cycle (cheapest unit to animate); a dust ring under the pads at speed; when it turns, the hull keeps level (no banking: pixel rule) but its dust ring smears to the outside of the turn.
- *Use:* the Carrier sector, whose ground is alien hull plating where tracks would read wrong.
- *Phone read:* a shape with a gap of ground and four cyan lines under it.

### 4.2 Totalled states (never death)

Allies keep the existing rule: an ally at 0 HP is **totalled**, never destroyed:
- **dented** (1 frame per heading via overlay): two chips in the plate shown as darker value steps, one skirt panel hanging;
- **track thrown / wheel lost** (2 frames, at the nearest primary heading): the vehicle slews, a short track run lies behind it;
- **limp** (2 frames): smoke from the engine deck (shared smoke fx), lights flickering cyan at 2 fps;
- **crew pod** (2 frames, the existing pod): odd-numbered crews eject.

Allied vehicles never break into pieces. Armour shards (Section 6) are small plate flakes on a hit, never a breakup.

### 4.3 Infantry

Fleet troopers wear light **exo-frames**: a squared helmet with a 1-texel cyan visor strip, shoulder plates as flat blocks, a backpack battery with a 1-texel cyan tell, and straight rifles.
- **Rifle trooper:** a long straight rifle with a squared stock.
- **Rocket trooper:** a box launcher on the shoulder (a rectangle, never a tube with a face).
- **Seen from behind**, as now, at three headings (0, 45, 90 mirrored): back, back three-quarter, side.
- The squad leader has a whip antenna on the backpack (the mast rule at trooper scale).
- Victory dance and other flourishes: [ground-easter-eggs.md](ground-easter-eggs.md).

## 5. Materials

| Material | Where | How it reads in pixels |
| --- | --- | --- |
| Faceted armour plate | Hull, turret | Flat value planes, one ramp step per facet; chamfers are a 1-step lighter edge on the lit side (upper left) |
| Panel seams | Hull tops | Value steps (one step darker), never black interior outlines (they break the silhouette at far scale) |
| Rivet rows | Skirt tops, turret ring | Every other texel one step lighter, only at near scale (the far scale drops them) |
| Track sliver | Under skirts | 2 texels of `ally_hull[0..1]` links that shift 1 texel per move frame |
| Rubber wheels | Sleet, Cairn, Tether | `ally_hull[0]` disc with a `ally_hull[2]` hub and a cyan hub ring pixel |
| Glass and visors | Cabs, turret front | `ally_cyan[1..2]` slit with one `ally_cyan[3]` glint pixel |
| Light strips | Edges, pads | `ally_cyan[3]` (#70F5D5) lines, 1 texel |
| Camouflage panels | Sector kit | Whole facets recoloured within `ally_hull`; never a pattern finer than 3 texels |

## 6. Palette

Allied hulls use the existing reserved sets only. Values (Rec. 709 luma) are approximate.

| Set | Colours | Use |
| --- | --- | --- |
| `ally_hull` | #232D3B #364355 #4E5E73 #6E8299 #98ABC0 #C4D2E0 | Hull and turret ramp. Body pixels use steps 0–4; step 5 (#C4D2E0) is for 1-texel speculars and chamfer highlights only |
| `ally_cyan` | #0C3A40 #16626A #2AA59A #70F5D5 #D2FFF4 | Lights, visors, IFF and teal camouflage bands (steps 0–1 only for bands). Step 4 is the muzzle core and the pod light only |
| `ally_crew` | #2F5A60 #7FC2B8 | Crew figures in hatches and troopers' fatigues |
| `smoke`, `scorch` | as reserved | Dust, exhaust and totalled smoke |

**Sector camouflage** (facets recoloured within `ally_hull`, plus kit):

| Sector | Camouflage | Kit |
| --- | --- | --- |
| Krybor | Snow: the top facets one step lighter (steps 3–4), the skirts dark | Ski skids, a frost-rimed antenna |
| Ringfall | Patch plates: alternating facets one step apart, as if replaced in the field | Spare wheel on the rear, cable bundles |
| Ember | Heat-shield: the lower hull and skirts at steps 0–1, a band of square heat tiles on the turret | Exhaust stacks capped flat |
| Hollow | Teal bands: one `ally_cyan[0..1]` band across hull and turret | Snorkel and mud flaps |
| Carrier | Fleet grey: the plainest ramp, with the brightest cyan strips | Hover pads (Skiff), magnetic feet (Stilt in the Carrier) |

**Never on a Fleet unit:**
- any `demon_warm` colour, red, orange or amber lamp (warm is the threat signal; it belongs to the Host and to shots);
- `demon_gilt` or any gold;
- a warm muzzle flash (Fleet muzzles are cyan, as now: `GroundAtlas.muzzleCyanCol`);
- curved hooks, pointed arches, horns, faces on the hull.

**Luminance caps.** The hull's brightest body pixel stays at `ally_hull[4]` (luma about 0.65). Cyan strips are the brightest thing on an ally and may reach `ally_cyan[3]`. Nothing on an ally is brighter than a hostile shot except its own muzzle core for one frame. Allies are lighter than the Host (whose hull caps at luma 0.40 and rim 0.56): that value gap is the faction read in greyscale.

## 7. Readability at sprite size and camera angle

The camera looks forward and down over the ground. The near band where allies hold (z 250–302) shows them large, from behind and above. When they advance to engage (up to z 620) they shrink to about half.

| Distance | Ally scale | What must survive |
| --- | --- | --- |
| Hold (z 276) | ×1.64 | Everything: facets, panel seams, rivets, crew, mast, cyan strips, turret visor |
| Engaged (z 450) | ×1.0 | Hull wedge, turret block, barrel, cyan strips, wheels or skirt sliver, mast |
| Farthest advance (z 620) | ×0.73 | Turret vs hull separation, barrel direction, one cyan strip, the IFF chevron |

Rules:
1. **Turret vs hull.** The turret is always at least **2 ramp steps** brighter or darker on its top face than the hull top around it, and has a 1-texel dark ring (`ally_hull[0]`) where it meets the hull. Without that, turret rotation is invisible at ×0.73.
2. **Barrel thickness.** 2 texels for every main gun. Rail and coil rings are 1-texel bumps on top of that.
3. **Black-fill test.** At ×0.73, each vehicle's solid black fill at heading 0 and heading 45 must name its role: wheels sticking out (Sleet), stepped box (Cairn), A-frame (Tether), long gun on hex (Lodestar), gun pointed up (Sextant), box on two sticks (Stilt), floating lozenge (Skiff).
4. **Greyscale test.** In greyscale, Fleet hulls sit one value band above Host hulls, and the cyan strips stay the brightest pixels.
5. **Lane.** Allies stay in the near band, below and beside the ship. Nothing on them blinks except the distress cross and lights flickering when totalled. Their muzzle flashes are smaller than a hostile shot.
6. **Phone frame.** In a 360 × 780 frame with three allies, five Host units and the swarm, a reviewer names every ally role in under 2 s.

## 8. Hull and turret articulation

Every Fleet vehicle is **two layers that share one anchor**: the hull and an articulated layer (turret, casemate barrel, gun pod or cab). The frame spec is in [ground-unit-animation.md](ground-unit-animation.md); the art rules are:

- **Hull headings.** Five authored headings, 0° (straight up the plane), 22.5°, 45°, 67.5° and 90° (side-on, facing right), mirrored for the left. A turn always plays through the intermediate headings, one step at a time, so the vehicle visibly rotates.
- **Turret angles.** The same five screen angles as today (`GroundAtlas.allyTurretAngles`), mirrored. The turret is drawn **independently of the hull heading**: a Lodestar can drive at 45° right while its gun tracks a target at 22.5° left.
- **Turret pivot.** Each hull heading records where its turret ring centre sits in the cell (`turretPivot[h]`). The turret cell is authored centred on its pivot, so placing it is one offset.
- **Turret reads as round.** Because the turret is drawn the same at every hull heading, its plan shape is close to rotationally neutral (a hexagon or a rounded box), and its direction is carried by the barrel and the visor slit. Square turrets that look wrong when the hull turns under them are not allowed.
- **Recoil.** The barrel slides back along its own angle by 2 texels and returns over 0.14 s (as now); the hull dips 1 texel at the front for heavies.
- **Elevation** (Sextant only): three authored barrel elevations at turret angle 0 and 90; the in-between angles use the nearest.
- **No rotation in code.** Neither layer is ever rotated or smooth-scaled at runtime. Headings and angles are authored cells; the 0/90/180/270° rotations used by debris are the only exception (they are lossless).

## 9. Animation summary

| State | Frames | Notes |
| --- | --- | --- |
| Move | 4 per heading (Skiff: 2 hover bob; Stilt: 6 stride) | Track sliver or wheel spokes shift 1 texel per frame |
| Turn | (headings) | One heading step per ≥ 0.12 s (light) or ≥ 0.20 s (heavy) |
| Turret traverse | 5 angles | Rate-limited; turret leads, hull follows |
| Fire | 1 muzzle frame + 2-texel barrel recoil | Cyan muzzle ring glow |
| Hit | 1 overlay | Plate flakes (armour shards) and a spark; the hit flash is a light-ramp step |
| Dented | 1 overlay per heading | Darker chips, hanging skirt |
| Special | 2–3 | Cairn deploy, Tether tow, Sextant brace |
| Totalled | 2 + 2 + pod | Section 4.2 |
| Terrain | pitch ±1 at headings 0–45, ford | Per the terrain guide |
| Flourish | 0 new frames | Turret twirl (sweeps all five angles) and a 1-texel hull hop on victory |

Timing: 0.10–0.14 s per frame for light units, 0.16–0.20 s for heavies and walkers.

## 10. Prompt guidance for refinement renders

The Fleet uses the approved refinement pipeline (`plan/render-runs/ground-forces-rework.md`): a rig render on the texel grid at each heading is the reference image for Qwen-Image-Edit-2511, then BiRefNet matting, then palette finishing onto the grid silhouette.

```
[STYLE]    pixel art, 16-bit arcade game sprite, crisp square pixels, limited palette, original artwork, centered, isolated, plain flat background
[VIEW]     single vehicle seen from behind and above, three-quarter top view, driving away from the viewer, <heading phrase>, night lighting, rim light from upper left
[SUBJECT]  <subject line>
[MATERIAL] flat faceted grey-blue armour plates with chamfered corners, panel seams, rivet rows, side skirts
[LIGHT]    thin glowing cyan light strips along the edges, cyan visor slit, no warm lights
[TONE]     clean frontier military engineering, chunky readable silhouette
```

Heading phrases: h0 `driving straight away`, h22 `turned slightly to the right`, h45 `turned diagonally to the right`, h67 `turned mostly to the right`, h90 `seen from the side facing right`.

**Negative (family plus Fleet):**

```
text, letters, watermark, logo, signature, ui, frame, border, blurry, photo, photorealistic, smooth gradient, multiple views, character sheet, grid, sky, horizon, ground, landscape, scenery, crowd, many objects,
red lights, orange lights, warm glow, gold, fire, horns, face, teeth, spikes, hooks, pointed arch, stone, organic, insect, camouflage pattern, flags, national insignia, real military vehicle
```

**Per-unit subject lines:**

| Unit | Subject line |
| --- | --- |
| Sleet | a small fast six wheeled scout rover, low wedge shaped body lower at the front, big wheels sticking out past the body, tiny pod turret with a short twin barrel, whip antenna, roof light bar |
| Cairn | an eight wheeled armoured personnel carrier, tall flat roofed box with a stepped rear loading ramp, small remote gun pod on the roof, square vision blocks |
| Tether | a half-track recovery vehicle, wheels at the front and a skirted track at the rear, short A-frame crane and cable drum at the back, twin autocannon on a ring mount over the cab |
| Lodestar | a futuristic main battle tank, low faceted wedge hull with a long chamfered front, side skirts hiding the tracks, flat hexagonal turret set forward, very long thin rail cannon with two coil rings and a square muzzle brake, short sensor mast at the turret rear |
| Sextant | a self-propelled long range gun on a low tracked wedge hull, tall boxy casemate at the rear, very long barrel angled up, folding spade outriggers at the back |
| Stilt | a two legged walker, boxy armoured cab with a wide visor slit, two straight telescoping legs with flat square feet, gun pods on both sides of the cab |
| Skiff | a hover tank, flat lozenge hull with chamfered corners, no wheels and no tracks, four hover pads glowing underneath, low turret with a short wide barrel, floating above its shadow |
| Rifle trooper | a soldier in a light exoskeleton frame seen from behind, squared helmet with a visor strip, flat shoulder plates, battery backpack, long straight rifle |
| Rocket trooper | the same soldier carrying a box shaped rocket launcher on the shoulder |

**Sector modifiers** (append one): Krybor `snow camouflage, ski skids`; Ringfall `field-replaced patch plates of slightly different greys`; Ember `soot dark lower hull, square heat-shield tiles`; Hollow `one dark teal band, snorkel, mud flaps`; Carrier `plain fleet grey, bright cyan strips`.

**Seeds.** Fleet keyframes use the 78xxxx range: 7801xx scouts and carriers, 7802xx tanks and guns, 7803xx walkers and hover, 7804xx infantry. Provenance goes in `art/families/ground-fleet-runs.json`.

**Selecting a candidate.** Pick for **shading on the authored silhouette**: clean facets, a readable turret top, cyan strips where the rig put them. Reject candidates with warm lights, faces, curves on the hull, insignia or anything resembling a real-world vehicle or a known game unit.

## 11. Review checklist

- [ ] Black-fill test at ×0.73, headings 0 and 45, names every role (Section 7) in a blind sort.
- [ ] Greyscale contact sheet: Fleet hulls one band above Host hulls; cyan strips brightest.
- [ ] No warm or gold pixel on any Fleet cell (automated palette check).
- [ ] Turret separation: 2 ramp steps and a dark ring at every hull heading.
- [ ] Heading turntable (5 headings + mirrors) plays as a smooth rotation at 1× and 3×.
- [ ] Turret at every angle over hull at every heading (5 × 9 grid) looks seated: no floating, no clipping into skirts.
- [ ] Originality: names and silhouettes checked against well-known game, film and toy vehicles; no prompt names one.
- [ ] Totalled states show no death imagery; no breakup.

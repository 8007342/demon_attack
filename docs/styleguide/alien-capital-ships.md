# Styleguide: alien capital ships (the Thornwake carriers)

Direction: R8 in `plan/operator-feedback-2026-11-15b.md`, which supersedes the frigate's gargoyle face. Design and
pipeline: `openspec/changes/boss-hero-assets/design.md` §8. Kit: `art/families/alien-carriers.json`. Ledger:
`plan/render-runs/boss-carrier-v2.md`. Sheets: `art/contact/boss-carrier-v2-*.png`.

This guide sits beside `docs/styleguide/alien-troops.md` (the fliers' rank and shield language) and
`plan/gargoyle-army-style-guide.md` (the ground Host). Where they disagree on the **boss hull**, this guide wins.

## 1. The direction in one paragraph
The boss is not a creature with a face. It is a **ship**, so large that the camera pulls back to hold it and it still
spills off the top and both sides of the phone: a flat, terraced crescent of lacquered chitin that thrusts two
prongs forward around the arena and hides its launch gallery in the throat between them. It is grown, not
built: its armour is overlapping scale, its weapons are bone and ember, and its mind shows as violet crystal. Each tour
it returns larger and more armed, and every fight takes it apart in four named steps: the shield fails, the scales
shed, modules tear away, and the hull collapses into the fog.

References for **scale, silhouette language and detail density only**: high-resolution alien capital ships of
StarCraft (Protoss and Zerg carriers), Star Wars and Star Trek. What we take from them:
- the read of mass through *layered decks and terraces*, not through outline alone;
- detail density that rises toward the business end (the prow) and calms toward the hull's mass;
- the silhouette that never fits the frame.

What we never take: any recognisable design, hull plan, name, emblem or livery. `rig.py --check` refuses franchise
words in titles, slot and set names, notes and prompts (`originality.forbidden_words`).

## 2. Material language
| Material (kit tag) | Look | Value band | Why |
|---|---|---|---|
| **Chitin** (`chitin`) | Lacquered violet-black carapace, a faint oily sheen, no panel lines | dark-mid (`#1A1422`–`#56456C`) | The hull mass. Dark, so the gameplay layer (fliers, bullets, the ship) always reads over it. The violet keeps the Host family's slag hue |
| **Scale armour** (`plate`) | Overlapping chitin scales and wing cases, a lighter edge | mid (`#3E3150`–`#72608A`) | The armour that *sheds* at S2. A shape the eye counts, so losing it reads |
| **Sinew** (`sinew`) | Wine-red living tissue between and under the scales | dark red; ember once exposed | What the shedding reveals. It glows hot from S2 on, so damage reads as a wound, not as dirt |
| **Bone** (`bone`) | Ivory spines, ribs, thorns, gun-thorns, struts | light (`#CDBB92`–`#F4E8C8`) | The family link to the gargoyle Host's horns, and the brightest neutral: spikes and danger read first |
| **Membrane** (`membrane`) | Dark wine sails stretched between ribs | dark (`#2E1220`–`#6E2A44`) | Scale through thinness: a wide, light-catching span that tears in S3 |
| **Psionic crystal** (`crystal`, `shard`) | Faceted violet growths that glow from within | glow (`#7A38C8`–`#F4E6FF`) | The ship's mind. The shield emitters are `shard` crystals and shatter when the shield falls |
| **Ember** (`ember`) | Hot orange ports, vents and weak points | hot (`#E8501A`–`#FFF0B8`) | Danger and target. **Only** gun ports and weak points are ember, so "where it shoots from" and "where to hit" share one colour |
| **Openings** (`dark`) | Deep black hangar mouths: the core maw and both bays | black | The scene draws the core glow and the launch light there. No AI pass may paint fire into them |

**Why this set.**
- **Alien, not riveted.** There is no metal, panel line, rivet or window anywhere. The surfaces are grown (scale,
  sinew, bone, membrane, crystal), which is the fastest read of "alien" at phone size.
- **Readable.** Each material owns a value or hue band: chitin dark, bone light, crystal violet glow, ember hot orange.
  A 2 × 2 texel blob still says what it is.
- **Continuous with the game.** The bone, the violet and the ember come from the gargoyle Host and the Brood. The cyan
  force-shield language of `alien-insignia` stays an overlay and is never baked into the hull (`palettes.overlay_only`).
- **It decays legibly.** Scale (mid) peels off to sinew (red, then ember). Crystal (violet) goes dark and shatters.
  Bone snaps. The value of each region changes as it is damaged, so the stages read even at 1 CSS px per unit.

## 3. Silhouette at giant scale
1. **Never fits.** At the carrier camera (zoom Z 0.70–0.86 about the ship row; see the design §8.3) the hull is wider
   than the screen and taller than the space above the boss row. The top and both sides spill off by design. The
   **visible envelope** (`render.envelope`: carrier-relative x ±360, y −430…+240, from the strafe range x 82–278, the
   glide y 189–221 and Z ≥ 0.70) bounds what is rendered and stored. Nothing outside it is ever drawn.
2. **The prow is always on screen.** The launch gallery (core maw and bays) and the two gun blisters sit on the hero
   plane at the simulation windows, so they hold at every pitch and swerve (the anchor gate, ±3 units).
3. **A crescent, not a body.** The plan view is a flat, terraced slab with two forward prongs that embrace the
   arena, plus outer arms (the wing slot) that run off the sides. This is a ship's plan, not a creature's.
4. **Head-reading guard** (from the first v2 pass, which read as a mouth with teeth on a round head; see the ledger):
   - no thin, bright, repeated vertical bars across the openings: bulkheads are solid chitin;
   - no rows of beads or small domes under the openings;
   - no arcs over the openings (brows) and no radiating crowns around them (manes);
   - no paired bright or round features above or beside the gallery (eyes): the gun blisters sit in **batteries** along
     the prongs, never as a single pair near the prow;
   - no paired hooks beside the gallery (mandibles);
   - prompts and negatives exclude "face, eyes, mouth, teeth".
5. **Mass is layered.** Terraces stack up the screen: slab → citadel → keel or crown → spines. Each step is a
   silhouette edge, so the eye reads height and distance even in flat light.
6. **Detail density falls with distance from the prow.** The densest grain sits in the prow and the prong tips. The
   hull mass carries a coarser rhythm of scales, and the far aft is quiet and mostly off-screen.
7. **Spikes point away from the player's lane or straight at it.** Bone thorns sweep aft (danger, speed). Gun-thorns
   point down-screen at the player (threat). Nothing points sideways into the flier band.

## 4. Module grammar
A hull is a list of **slots**. Each slot has several interchangeable **sets** (visual variants), and each set is a
recipe of kit prims (shell, horn, lathe, shard, web, box, ellipsoid) and generators (arrays along a path, an arc or
a grid, optionally dropped onto another module's surface). All of it is data in `alien-carriers.json`.

| Slot | Mount | Detach rank | Sets (tour 1) | Gameplay |
|---|---|---|---|---|
| `prow` | bow, hero plane, fixed | never (S4 only) | `thorn` (swept thorn hedge) · `lattice` (crystal colonnade) · `shroud` (layered wing-case hood) | carries the core maw, bays and both turret pivots |
| `carapace` | the slab, citadel and prongs | last (its S3 layer sinks in S4) | `ridged` (keel and jagged scales) · `lobed` (three low lobes veined with crystal) · `shroud` (long wing cases, thorn rows) | none |
| `wing` ×2 | lateral, off-screen | 3 | `scythe` (thorned blade arm) · `fan` (bone ribs and membrane) · `lobe` (armoured lobe chain and claw) | none |
| `spines` | dorsal | 1 (first to go) | `ridge` (great keel spines) · `crown` (crystal crown) · `forest` (thorn field) | none |
| `emitter` ×2 | dorsal shoulders | 4 | `spire` · `lattice` · `veil` | shield source (visual): crystals shatter at S2 |
| `blister` ×2 | prongs, as batteries | 2 | `thorn` (gun-thorns) · `crystal` (lens) · `hive` (ember ports) | none (visual guns) |

Later tours add slots (§5): `maw` (flank hangar maws), `barrier` (spiked armour walls), `tendril`, `sac` (brood sacs),
`crown` (psionic crown), and more `blister` batteries.

**Sets per run.** A run picks one **set combination** per tour (seeded by the run seed and the tour). Sets are visual
only: gameplay never reads them.

**Combinations, not free mixing, at runtime.** Each module layer is rendered with the other modules held out, so its
silhouette already contains the occlusion by its neighbours of *that* combination. Mixing layers from different bakes
would show holes and overlaps. Each combination is therefore baked as its own hull (`carrier1-thorn`,
`carrier1-lattice`, `carrier1-shroud`). Authoring stays per slot: a new set is one JSON entry, and a new combination is
one hull line plus one bake (≈ 15 min of CPU, about 20–40 min of GPU).

**Rules for a new set.**
- Mirror-symmetric (checked). Jitter is mirror-safe by construction (`rigkit.array_geometry`).
- Its materials come only from §2, and only gun ports and weak points are ember.
- It keeps the head-reading guard of §3.
- It stays inside the envelope and the slot's region (an overlap with another slot's region is allowed only behind it).
- Its names and notes pass the originality check.

## 5. Per-tour escalation
"Later runs show more cannons, guns, spikes and barriers, and the boss looks and feels far scarier each run." The rig
carries the size; the sets and the prompts carry the menace.

| Tour | Hull | Extent | Slots added (instances) | Look added in the prompt |
|---|---|---|---|---|
| 1 | Thornwake Carrier | ×1.00 | prow, carapace, wing ×2, spines, emitter ×2, blister ×2 (9) | the base materials |
| 2 | Thornwake Broodmother | ×1.08 | + maw ×2 (flank launch maws), + an aft blister battery ×2 (13) | brood light in the maws, more crystal veins |
| 3 | Thornwake Siege-Ark | ×1.16 | + barrier ×2 (spiked wall plates flanking the prow), + tendril ×2 (17) | heavier, layered armour; ember seams |
| 4 | Thornwake Bastion | ×1.24 | + sac ×2 (brood sacs under the prongs), + a third blister battery ×2 (21) | scarred, thicker plating; crowns of spikes |
| 5 | Thornwake Hive-Crown | ×1.32 | + crown (psionic crown on the citadel), + emitter spires ×2 (24) | the darkest chitin, molten seams, a blazing crown |

- Extent grows less than the frigate plan did (×1.32, not ×1.60). The ship already spills, so more extent buys
  little on screen. Escalation shows as **density**: more batteries, barriers and spines inside the same envelope.
- The prow (hero plane, fixed) never scales. The simulation windows are shared by every tour.
- Each tour has at least two set combinations, so two runs of the same tour rarely look alike.
- Beyond tour 5 (repeat cycles), the seeded assembly draws extra sets per slot under the same budget.

## 6. Damage and decay vocabulary
Every step is a named event for the game event queue (`lib/game/game_events.dart`, owned by `boss-grandeur`) so the
future dynamic music engine can score it. The art for each step is listed beside it.

| Step | Event (proposed name) | Trigger | What the player sees | Art |
|---|---|---|---|---|
| Shield hit | `bossShieldCellLost` (data: cell, remaining) | each shield point lost | one cyan hex cell flashes white and splits into shards | overlay (`alien-insignia` §5.1) |
| Shield failing | `bossShieldFailing` | shield ≤ 50 % (S1) | the crystals flicker and dim, soot and ember hairline cracks spread | S1 stage look |
| Shield down | `bossShieldDown` | shield = 0 | the last cell pops; the emitter crystals **shatter** | S2 geometry (`shard` shed) + emitter shard debris |
| Armour shedding | `bossArmourShed` (data: slot) | S2 entry, then each door cycle (≤ 6 alive) | scales peel off as falling parts and expose ember sinew | S2 stage look + falling-part sprites from the S0−S2 difference |
| Module loss | `bossModuleLost` (data: slot, set, rank, form) | each form change (S3) | the next detach group tears away: wreck falls with its shadow, smoke from the breach | S3 geometry, wreck frames |
| Core exposed | `bossCoreExposed` | the last form | the gallery's frame breaks; the core glow intensifies | S3 look (the core window stays dark in the art) |
| Collapse | `bossCollapseStart`, `bossWreckFalls` (data: slot), `bossCollapseEnd` | core = 0 (S4) | every remaining module falls into the fog in detach order; the carapace sinks last | wrecks + the carapace's S3 layer |

Order is fixed: **shield → armour → modules → collapse**. Nothing skips a step visually, even when damage is fast.
The events fire once per step and per module, with the module's slot, so the music engine can tell a spine
breaking from a wing tearing away.

## 7. Phone readability
The hull fills the screen, so it must never hide the game.
1. **Value ceiling.** The hull mass (chitin, sinew, membrane) stays at or below `#56456C`. Only bone, crystal and
   ember go brighter. Fliers, bullets and the ship are drawn over a dark ground.
2. **Weak points and gun ports are ember, and big enough.** At the smallest zoom (0.70) on a 360-CSS-px phone, one
   arena unit is 0.70 CSS px:
   - a gun port is ≥ 5 units across (≥ 3.5 CSS px, with its glow ≥ 6);
   - a weak point (exposed sinew from S2 on) is ≥ 9 units (≥ 6 CSS px);
   - ember is never used for decoration.
3. **The gallery reads first.** It has the deepest black, framed by the lightest chitin edges. The simulation's core
   and bay windows sit exactly on it at every view (the anchor gate).
4. **No cyan, no white-hot in the hull.** Cyan is the shield overlay; white-hot is the player's fire. Both are excluded
   from the hull palette and the hero prompts.
5. **Ink outline.** Every finished sprite has a 1-texel `#07050C` outline on its silhouette, so the hull separates
   from the fog and sky.
6. **Detail scale.** The smallest painted detail that must read (thorn, port, scale edge) is ≥ 2 texels at the
   stored density.
7. **The test is the mock.** `rigsheet mock` draws the finished hull at 360 × 520 CSS (DPR 2) at Z 0.86, 0.76 and
   0.70, with the ship, the 34-CSS-px creature floor and the force-field rim
   (`art/contact/boss-carrier-v2-phone-mock.png`).

## 8. Shadow and atmosphere (for the runtime owner)
- The carrier casts a soft shadow onto the intermediate fog layers, not onto the far ground (R8: "shadows thrown on
  the intermediate fog layers"). The mock offsets it down-right at 45 % opacity.
- Fog drifts *over* the off-screen parts of the hull: the spill reads as "it goes on into the cloud".

## 9. The kit (for the next family)
The same tools serve any family (R10): `tools/rigkit` (bpy kit, rig, bake), `tools/rigsheet` (finish, budget,
sheets), `tools/rigkit/bake_family.lua` (the no-GPU rebuild). The family JSON schema is documented in the design §8.5.

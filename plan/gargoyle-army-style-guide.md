# The Undercroft Host: gargoyle ground army style guide

The **Undercroft Host** is the Brood's ground army: the gargoyle swarm's legions on the terrain below the flyover. This guide covers the faction's identity, its castes, the unit roster, silhouette and palette rules, animation and the prompt guidance for refinement renders. Research and sources: [gargoyle-army-research.md](gargoyle-army-research.md). OpenSpec change: `openspec/changes/gargoyle-ground-army/`.

It extends, and never overrides:
- [style-guide.md](style-guide.md): creature direction, the "friendly-scary, no gore" rule, palette luminance caps and the ground war presentation;
- [perspective.md](perspective.md): the flyover camera;
- `art/families/ground-forces.json` and `ground-troops.json`: the reserved colour sets.

Every design here is original. No unit, name or shape is taken from another game or franchise, and no prompt names one.

---

## 1. Identity in one sentence

> **A cathedral that walks to war.** The Host is carved, not built and not grown: living stone on cast-iron frames, every gun a gargoyle's mouth, every rank a higher spire.

Three factions share the screen and must never be confused:

| | Allies (convoy) | Brood swarm (air) | Undercroft Host (ground) |
| --- | --- | --- | --- |
| Tech language | **Built**: welded grey-blue plate, rivets, right angles | **Living**: membrane wings, hide, horns | **Carved**: dressed stone, chisel facets, iron bands, lead flashing, chains |
| Signature colour | Cyan, teal, grey-blue, IFF chevron | Four species hues (teal, violet, coral, gold) | Dark sector-tinted stone, warm ember light, dull gilt rank |
| Seen from | Behind and above, driving up the plane | 3/4 above, banking | High 3/4 side view facing right (mirrored for left), as the existing demon ground units |
| Weapon light | Cyan muzzle flash | Warm shots | Warm **spout** glow fed by a back-channel |
| Defeat | Totalled: sparks, limps off, crew pod | Cracks into tumbling stone | Crumbles into a rubble heap with glowing seams |

## 2. Design pillars

1. **The spout rule.** A true gargoyle is a waterspout: water runs along a channel on its back and out of its mouth. Every Host weapon follows this. A carved mouth is the muzzle, and a **channel (gutter) along the back or barrel** carries molten slag to it. The attack telegraph is the channel **filling** toward the mouth: 2–3 stepped warm segments lighting rear to front, then the eyes flare, then the mouth flashes. It is original, it sits in the faction's own fiction, and it reads at every distance because only the warm accent moves.
2. **Architecture is anatomy.** Each role takes its body from one building part:
   - flying buttresses → walker legs;
   - pinnacles and crockets → horns and spikes;
   - rose window → rotary launcher;
   - belfry → siege tower;
   - reliquary casket → troop carrier;
   - chapter house → command post.

   Every unit also keeps at least one **gargoyle face** (eyes, brow, fanged maw) and at least one **membrane element** (folded wing-mantlet, a sail, a tattered banner). That ties it to the flying swarm.
3. **Rank is height and gilt.** The castes follow the masons' lodge: **Rubble → Ashlar → Tracery → Spire**. The higher the caste, the taller its vertical ornament (finial, pinnacle, spire) and the more **gilt** it wears. Line units are squat and horizontal; command is the tallest pointed thing on the field. Rank is never text and never colour alone.
4. **One dominant shape per role.** Every role owns one silhouette cue no other role uses (Section 5). A black-fill thumbnail at mid-field size must name the role.
5. **Corruption gradient.** The Host gets more cathedral-like and more demonic deeper into the campaign:
   - Krybor fields captured, defaced human machines with stone carved over them;
   - Ringfall's are stitched from salvage and stone;
   - Ember's are kiln-forged basalt and iron;
   - the Hollow's are full cathedral masonry;
   - the Carrier's are obsidian elite with the most gilt.
6. **Friendly-scary, never gory.** The faces are cartoonish and the menace comes from mass and glow. Damage is cracked stone with glowing fissures and chipped horns. Death is a rubble heap with cooling seams. There is no blood, no flesh and no wounds. No real religious symbols appear: the faction uses architecture (arches, spires, tracery, bells), never crosses, saints or scripture. A cross silhouette is also already taken by the allies' cyan distress cross.

## 3. Castes

| Caste | Lodge analogue | Who | Silhouette rank cue | Gilt |
| --- | --- | --- | --- | --- |
| **Rubble** | unskilled labour | Rubblings: expendable swarm infantry | No helmet, no ornament: a bare horned head | none |
| **Ashlar** (dressed stone) | journeyman | Line infantry and the crews of tanks and carriers | An iron helmet over the horns, one short finial | none |
| **Tracery** | master craftsman | Specialists: bell-ringers, gunners, menders | A tall hood or yoke, a carved collar | a gilt collar or rim (1–2 px) |
| **Spire** | master of the works | Officers and command machines | The tallest point on the unit: spire, banner pole, crown of pinnacles | a gilt crown and finial (the most) |

Every vehicle shows its crew caste through the hatch figure or the head-ornament on its prow. The **mason's mark** is the unit's insignia: a small carved glyph of 3 × 3 to 5 × 5 px on the flank, original to the faction, one per caste:
- Rubble: a single notch;
- Ashlar: a chevron-arch;
- Tracery: a trefoil;
- Spire: a lancet (pointed arch) with a dot.

These glyphs echo, but do not copy, the air species' rank marks.

---

## 4. Unit roster

Sizes are the visible content box in **texels** (the ground atlases have 1 texel per pixel). The drawn size in arena units is `texels × 435 / z` (`GroundCamera.texel(z) × unitScale`): ×0.31 at the horizon (z 1400), ×0.62 mid-field (z 700) and ×1.09 at fire range (z 400). Skirmish units hold at z ≥ 430, so ×1.0 is the nearest most Host units are ever seen; threat units approach to z 205 (×2.1). A 360-px phone shows about 1 arena unit per CSS pixel.

**Tier A** is the first production set. **Tier B** is the stretch set. **Existing** units keep their atlas rows and gameplay. This guide names them and sets the direction for an optional art refresh.

| # | Unit | Caste | Role | Tier | First sector | Size (texels) | z 700 → z 400 (units) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| I-1 | **Rubblings** (pack of 5–6) | Rubble | Swarm screen infantry | A | Krybor | 10 × 12 each | 6 × 7 → 11 × 13 |
| I-2 | **Ashlar Guard** (squad of 3–4); existing `demon-grunt` | Ashlar | Line rifle infantry | Existing | Krybor | 19 × 23 | 12 × 14 → 21 × 25 |
| I-3 | **Corbel Brutes** (pair); existing `demon-rocketeer` | Ashlar | Anti-armour rockets | Existing | Ringfall | 22 × 21 | 14 × 13 → 24 × 23 |
| I-4 | **Knell-bearers** (pair) | Tracery | Rally support | A | Ember | 16 × 22 | 10 × 14 → 17 × 24 |
| I-5 | **Prior** (with 2 Ashlar escorts) | Spire | Field officer | A | Hollow | 14 × 24 (banner included) | 9 × 15 → 15 × 26 |
| T-1 | **Crocket** | Ashlar crew | Light raider tank | A | Krybor | 30 × 16 | 19 × 10 → 33 × 17 |
| T-2 | **Tympanum**; existing `demon-tank` | Ashlar crew | Main battle tank | Existing | Ember | 31 × 20 | 19 × 12 → 34 × 22 |
| T-3 | **Narthex** | Spire crew | Super-heavy siege tank | B | Hollow route 4+ / Carrier route 3+ | 44 × 28 | 27 × 17 → 48 × 31 |
| C-1 | **Reliquary** | Ashlar crew | Armoured personnel carrier | A | Ringfall | 32 × 24 | 20 × 15 → 35 × 26 |
| A-1 | **Carillon** | Tracery crew | Bell-mortar battery (indirect fire) | A | Ember | 34 × 28 | 21 × 17 → 37 × 31 |
| A-2 | **Rosegun** | Tracery crew | Rotary rocket artillery | B | Hollow | 30 × 30 | 19 × 19 → 33 × 33 |
| W-1 | **Buttress Strider** | Ashlar crew | Bipedal assault walker | A | Hollow | 28 × 34 | 17 × 21 → 31 × 37 |
| W-2 | **Belfry**; existing `demon-hollow` | Tracery crew | Walking siege-launch tower (threat) | Existing | Hollow | about 26 × 30 | 16 × 19 → 28 × 33 |
| S-1 | **Hodcrawler** | Tracery crew | Field repair | A | Ringfall | 32 × 26 | 20 × 16 → 35 × 28 |
| S-2 | **Thurible** | Tracery crew | Smoke screen | B | Ember | 26 × 32 | 16 × 20 → 28 × 35 |
| S-3 | **Cistern** | Ashlar crew | Slag (ammunition) tanker | B | Ember | 32 × 20 | 20 × 12 → 35 × 22 |
| K-1 | **Chapterhouse** | Spire | Mobile command walker | A | Hollow (rare), Carrier | 44 × 40 | 27 × 25 → 48 × 44 |

The existing threat vehicles get Host names and an art direction, with the same rows and frame contract (`lib/game/ground_atlas.dart`):
- **Gutter-runner**: the Krybor rocket buggy, a captured human buggy with a carved gargoyle hood and a gutter-fed launcher;
- **Scrapmason Crawler**: the Ringfall missile crawler, salvage hull plates mortared with stone;
- **Kiln Ox**: the Ember artillery beast, four-legged basalt with a kiln-mouth mortar;
- **Belfry**: the Hollow walking siege tower.

### 4.1 Infantry

**I-1 Rubblings: Rubble caste, swarm screen.**
- *Silhouette:* tiny, hunched, all head. Oversized ram horns on a bare stone skull, stubby folded wing-nubs, a chisel-spear held low. They move in a loose clump of 5–6, so the **pack** is the silhouette: a speckle of horned bumps.
- *Materials:* rough unfinished rubble stone, lighter at the knuckles; no armour.
- *Palette:* the sector stone ramp, steps 2–4 only. Eyes are 1 × 1 px `demon_warm` #FF8A2A (2 × 1 when angry).
- *Animation:* 4-frame scurry with alternating horn bob, 1 jab, 1 hit, 2 crumble. They flee in the run frames when their leader falls.
- *Phone read:* at the horizon a trickle of warm dots. Mid-field, a cluster of horned specks. Near, imps with chisels. The read is "many, weak".

**I-2 Ashlar Guard (existing grunt): line infantry.** Keep the current sprite. Direction for a refresh:
- the rifle becomes a **spout-musket**: a long iron gutter-barrel ending in a small carved mouth, with the back-channel glowing on fire;
- the iron helmet gets one short finial;
- the chevron-arch mason's mark goes on the vest.

**I-3 Corbel Brutes (existing rocketeer): heavy infantry.** Keep the current sprite. Refresh direction: the launcher tube ends in a **corbel head** (a squat carved face), and the brute's shoulders carry a stone yoke like a corbel bracket.

**I-4 Knell-bearers: Tracery caste, rally.**
- *Silhouette:* tall, narrow, hooded, with a **wooden yoke across the shoulders and a heavy bell** hanging at one end. The bell is the cue: a dark dome with a bright warm clapper slit.
- *Materials:* a draped hood of dark cloth over stone, an iron bell, a wooden yoke, a gilt rim on the bell.
- *Animation:* 4-frame trudge; a 3-frame **ring** (the bell swings out, strikes, returns) with a stepped warm ripple ring on the ground; 1 hit; 2 crumble (the bell drops and rolls).
- *Phone read:* the only infantry with a pendulum swing, so even at mid-field the motion names it.

**I-5 Prior: Spire caste, field officer.**
- *Silhouette:* the only infantry with a **vertical banner-spire** rising from its back above its head. The banner is a slim pole crowned by a gilt pinnacle, with a tattered membrane pennant cut from a wing.
- *Materials:* a carved stone body, a gilt crown of three small pinnacles, a long iron-banded coat and a staff with a lantern-mouth.
- *Animation:* a 4-frame stride with the pennant fluttering out of step, 1 point (the staff aimed), 1 hit, and a 3-frame topple in which the spire falls first.
- *Phone read:* the tallest small figure, with a gilt glint at the top. Its pennant flutters even when it stands still.

### 4.2 Tanks

**T-1 Crocket: light raider tank.**
- *Silhouette:* low, long, forward-raked. The hull is a **slab with a row of hooked crockets** (curled stone hooks) along its spine, and a short spout gun under a snarling prow face. It is the lowest vehicle.
- *Materials:*
  - Krybor: a captured human scout hull with stone hooks bolted on;
  - Ember and later: all stone, on fast iron tracks.
- *Animation:* 4-frame track crawl, spine hooks shimmering one at a time; 2-frame channel fill; fire; recoil; 3-frame damage (hooks snap off); 2-frame wreck.
- *Phone read:* a low dark dash with a toothed top edge, the fastest thing on the ground.

**T-2 Tympanum (existing heavy tank): main battle tank.** Keep the current sprite. Refresh direction:
- the glacis carries a **tympanum**, a big carved face in a pointed-arch panel, which is the tank's face;
- the turret is a horned mantlet;
- one long spout barrel with a gutter along its top;
- the longest horizontal line on the battlefield is its barrel, and that is the MBT cue.

**T-3 Narthex: super-heavy siege tank (Tier B).**
- *Silhouette:* a two-storey wedge. The lower hull is a **portal**, a deep pointed archway at the prow with a ram-face inside it. The upper deck has two small turrets flanking a short bell-tower. Two tracks show per side.
- *Phone read:* the biggest tracked mass, with a dark arch "mouth" at the front.

### 4.3 Carrier

**C-1 Reliquary: armoured personnel carrier.**
- *Silhouette:* a **casket with a steep pitched roof**: the "house" shape (a triangle on a box) that no other unit uses. Wing-mantlets fold down the roof slopes like shingles. Side doors are pointed arches. A small gargoyle head sits on the roof ridge (the gunner, with a short spout).
- *Materials:* iron-banded stone casket walls, a lead roof (dark grey-violet `demon_steel`), gilt ridge studs (Tracery commander).
- *Animation:*
  - 4-frame move on six stone-rimmed wheels (Krybor and Ringfall) or tracks (Ember and later);
  - ridge gun fire;
  - **unload** in 3 frames: the roof wings lift, the arch doors swing open and warm light spills out, then 3–4 Ashlar Guard drop out;
  - hit; 2-frame wreck (the roof caves in).
- *Phone read:* a little house that drives. The roof peak is visible from far away; opened wings mean infantry are coming.

### 4.4 Artillery

**A-1 Carillon: bell-mortar battery.**
- *Silhouette:* a low carriage carrying **three bronze-iron bells mouth-up**, braced in a carved frame. **Open mouths pointing up** are the artillery cue. The bells fire slag: the mouth flashes, and a fat warm shell arcs upward.
- *Materials:* a stone carriage with a gargoyle face at the front, iron bells with gilt rims (Tracery), and a gutter running from a slag hopper at the rear to the bells.
- *Animation:*
  - 4-frame move;
  - **ranging**: the bells tilt one step toward the target;
  - the channel fills;
  - **ripple fire**: three frames, one bell each, each with a stepped warm muzzle bloom and a short soot puff;
  - recoil (the carriage rocks back 1 px);
  - hit; 2-frame wreck (the bells topple).
- *Phone read:* artillery holds back mid-field (z 620–760), so it must read at ×0.6: three warm rings opening upward in sequence. The muzzle bloom is wider than the unit for one frame.

**A-2 Rosegun: rotary rocket artillery (Tier B).**
- *Silhouette:* a **rose window on a turntable**: a large disc of radiating stone tracery, tilted toward the sky, on a squat tracked base. Each tracery petal is a launch cell. The disc is the cue.
- *Animation:* the disc **turns** one petal per frame while moving (4-frame cycle); salvo (petals light in a spiral, then 6 small rockets ripple out); a reload spin.
- *Phone read:* a slowly rotating ring, the only round shape on the field.

### 4.5 Walkers

**W-1 Buttress Strider: bipedal assault walker.**
- *Silhouette:* a heavy hunched torso held up by **two flying-buttress legs**: each leg is an arched stone strut with a pinnacle at the knee. The arches leave a clear **gap of ground under the body**, which is the walker cue shared with the Belfry and the Chapterhouse. A gargoyle head-cockpit sits low at the front, and a spout gun hangs under the chin. Folded wing-mantlets cover the shoulders.
- *Animation:* a 6-frame **stepped stride** (the body lifts 1 px on each push and drops on each plant, with a dust puff at each foot); channel fill; fire; recoil; hit; 3-frame damage (the knee pinnacles snap); a 3-frame collapse (the legs splay, then the torso drops into rubble).
- *Phone read:* a tall shape with light showing between its legs and a rhythmic bob. Nothing tracked bobs like that.

**W-2 Belfry (existing Hollow threat walker).** Keep its rows. Refresh direction:
- a walking **belfry** (a siege tower) on short stone legs, with a missile launch tube in the bell chamber;
- the telegraph (launcher raised, then glow) becomes the bell-chamber channel filling, then the louvres flaring warm.

### 4.6 Support

**S-1 Hodcrawler: field repair.**
- *Silhouette:* a squat crawler with a **crane arm** (a long iron jib ending in a hooked gargoyle hand) carrying a **hod of fresh stone blocks**. The asymmetric arm is the support cue.
- *Animation:* 4-frame crawl with the jib swaying; a 4-frame **mend** (the jib swings over a damaged ally of its own side, sets a block, and the target's cracks glow and close); hit; 2-frame wreck (the jib falls).
- *Phone read:* the only vehicle with a long diagonal arm. Mending shows as a brief warm line of mortar seams on the target.

**S-2 Thurible: smoke screen (Tier B).**
- *Silhouette:* a narrow wheeled cart with a tall iron **gallows-pole** from which a huge **censer** swings on chains. The pendulum is the cue.
- *Animation:* a 4-frame swing cycle while moving; **smoke**: the censer swings wide and lays three stepped dark-violet puffs that drift and fade over about 4 s.
- *Rule:* smoke stays outside the central lane, or, where skirmish units cross the lane, at no more than 30% alpha. It must never hide hostile shots or the ship.

**S-3 Cistern: slag tanker (Tier B).**
- *Silhouette:* a long **round-topped stone tank** with gutters running down its sides into carved spout-mouths.
- *Animation:* glowing slag dribbles from the mouths in a 2-frame loop. When destroyed it makes a larger warm burst (more fire frames) that reads as a valuable kill.

### 4.7 Command

**K-1 Chapterhouse: mobile command walker.**
- *Silhouette:* the **tallest unit on the field**:
  - an **octagonal** stone chamber (a chapter house) on six short buttress legs;
  - a tall **gilt spire** at the centre, with a horned finial and a small rose-window "eye" below it;
  - two tattered membrane banners on poles at the rear corners.

  Pointed, symmetrical and gilt: the command cue.
- *Materials:* the most finished masonry in the Host: smooth ashlar walls, deep tracery windows lit warm from inside, the gilt `demon_gilt` crown, lead roof, iron leg bands.
- *Animation:*
  - a 6-frame slow stride with the legs in pairs;
  - the banners flutter continuously (3 frames, out of step);
  - the rose eye pulses slowly (2 fps, never at telegraph speed);
  - a **command pulse**: the eye flares and a stepped ring spreads over the ground (it marks the moment nearby units speed up, Section 9);
  - hit; 4-frame damage (windows go dark, then the spire cracks);
  - a 5-frame **fall**: the spire topples, the legs fold, and rubble remains with the eye guttering out.
- *Phone read:* even at the horizon its spire is a vertical line with a gilt point. Mid-field it is a lantern-lit tower on legs; near, an octagonal cathedral walking.

---

## 5. Silhouette grammar (the black-fill test)

Every new unit is first drawn as a **solid black fill at its mid-field size (×0.62)** and must name its role with nothing else shown.

| Role | Dominant cue (owned by this role only) | Height : width | Top profile | Motion signature |
| --- | --- | --- | --- | --- |
| Swarm infantry | Many tiny horned bumps in a clump | about 1.2 (each) | Horn pairs | Scurry, scatter |
| Line or heavy infantry | One figure, helmet or launcher | 1.0–1.2 | Helmet with finial / tube | Waddle march |
| Support infantry | Pendulum (bell) on a yoke | about 1.4 | Hood plus yoke | Swing |
| Officer | A vertical pole above the head | about 1.7 | A pointed gilt tip | Pennant flutter |
| Light tank | Long, low, toothed spine | about 0.5 | A saw of hooks | Fast crawl |
| Main battle tank | The longest horizontal barrel | about 0.65 | Horned mantlet | Crawl, recoil |
| Super-heavy | A dark arch at the prow, two storeys | about 0.65 | A small tower | Slow crawl |
| Carrier | A peaked roof (triangle on a box) | about 0.75 | A single ridge peak | Doors and wings open |
| Artillery | Open mouths pointing up | about 0.8 | Cups or rings | Tilt, ripple bloom |
| Rocket artillery | A disc | 1.0 | A circle | Rotation |
| Walker | Ground showing between legs | 1.2–1.3 | Hunched or tower | Stepped bob |
| Repair | A long diagonal arm | about 0.8 | A jib line | Jib sway |
| Smoke | A tall gallows with a hanging weight | about 1.25 | Crossbar | Pendulum |
| Command | The tallest point, symmetrical, with banners | about 0.9 (spire included) | Spire plus banners | Banner flutter, eye pulse |

Rules:
- No two roles may share their dominant cue.
- **Point up = high caste or command. Open up = artillery.** A spire is pointed; a bell is open. Artillery never ends in a point, and command never shows an open mouth upward.
- Walkers keep at least 3 texels of clear ground between their legs in every stride frame.
- The face sits on the **prow corner** so that it reads in the high 3/4 side view: brow, two eye pixels and a maw notch on the front face, and the same features catching the rim light on the side.
- Keep the outer silhouette clean. Inner detail (tracery, mortar lines) uses value steps, never interior outlines that break the shape (the research's pixel-art rule).

## 6. Palette

The Host uses the existing ground family's reserved sets (`art/families/ground-forces.json`) and luminance caps: the `demon_ramp` hull at luma 0.06 / 0.11 / 0.18 / 0.28 / 0.40, rim light ≤ 0.56, hull chroma ≤ 0.36. Brightness rises from 38% at the horizon to full at the fire line, as now.

**Sector stone ramps** are starting points at the demon_ramp lumas (Rec. 709). The pipeline still median-cuts from the sector palette and clamps.

| Sector | Stone | Ramp (dark → light) | Notes |
| --- | --- | --- | --- |
| Krybor | Frost slate | #0C0F17 #171C2A #252E44 #39486A #526798 | Captured human hulls keep patches of their old grey-blue, **defaced** with warm-scratched glyphs. Never cyan stripes |
| Ringfall | Violet salvage-stone | #120E18 #22192C #372948 #563F70 #7B5AA0 | Plates mortared together; rust-warm seams |
| Ember | Basalt | #160E0C #281915 #412923 #664037 #915C4E | Kiln cracks glow faintly even when intact |
| Hollow | Verdigris stone | #0A110D #131F19 #1F3328 #304F3F #45715A | **Keep hue ≤ 155° and chroma low**: it must never approach ally teal #2AA59A or mint #70F5D5 |
| Carrier | Obsidian plum | #160D12 #291820 #432735 #673D52 #945775 | The most gilt; glossy 1-px speculars on obsidian |

**Reserved accents:**
- **`demon_warm`** (#3A0A0C … #FFF0B8; existing): eyes, spout mouths, channels, telegraphs, muzzle blooms, interior window light and damage seams. It is the brightest thing on a Host unit and the only part that blinks.
- **`demon_gilt`** (new; Tracery and Spire rank only): #1B1406 #36280D #644B18 #9A7324, luma up to 0.46. It sits under the rim cap and well under the warm accent, never blinks or animates, and covers at most about 6% of a unit's pixels (Spire) or 2% (Tracery). It sits on crowns, finials, collar rims and bell rims.
- **`demon_steel`** (existing): iron bands, lead roofs, chains, tracks.
- **Membrane** (wing-mantlets, banners): the sector stone ramp shifted 15° warm, steps 1–3 only, so membranes sit darker than the stone as on the flying gargoyles.

**Never on a Host unit:** cyan, teal, mint or grey-blue as a dominant hull tone (those belong to the allies); the four swarm species hues as hull colours; pure white except the 1-px core of a muzzle bloom.

Colour never carries a meaning alone. Rank pairs gilt with height. A telegraph pairs warm light with channel motion and a pose change, plus the existing ground bracket for threat units.

## 7. Damage and defeat

- **Hit flash:** one frame of the ramp stepped toward its light end, with the outline kept, as for the flying gargoyles.
- **Damage molts** (vehicles): the stone cracks with 1-px warm seams, then ornament snaps (hooks, pinnacles, spire tip), then a breach opens on warm interior light.
- **Defeat:** a short warm flash, the shape slumps (the walker's legs splay, the spire topples), then a **rubble heap** with cooling seams. It shares the existing ground effects: the shock ring, ten-frame fireball, debris, scorch and burn loop. The crew never appears hurt; crew figures, when shown, scramble away or crumble into stone.
- **Command fall:** the Chapterhouse spire toppling is the one deliberately "big" death, with 2–3 extra debris chunks and a gilt glint as the finial falls.

## 8. Animation conventions

| State | Frames | Notes |
| --- | --- | --- |
| Move | 4 (walkers 6) | Tracks crawl by link offset; walkers bob 1 px on a stepped cycle; Rubblings and Knell-bearers bob their horns or bell |
| Channel fill (telegraph) | 2–3 | The warm segments light rear to front; on the last frame the eyes flare |
| Fire | 1–3 | The mouth blooms. A ripple (Carillon, Rosegun) is one frame per barrel |
| Recoil | 1 | 1-px rock back, opposite to facing |
| Special | 3–4 | Unload, ring, mend, smoke or command pulse |
| Hit | 1 | Flash |
| Damage | 2–4 | Molts, as in Section 7 |
| Wreck | 2–5 | Defeat sequence |

Timing: hold frames for 0.10–0.14 s for infantry and light vehicles, 0.16–0.20 s for walkers and command (mass). Idle life (eye pulse, banner flutter) runs at 2–3 fps and never at telegraph speed, so idle never looks like attack. With reduced motion, idle loops freeze; channel fills and blooms still show, as a hard cut.

**Facing:** side-on facing right, mirrored for left, as the existing demon units. Mason's marks and lettering-like glyphs must look right mirrored, so they are symmetric.

## 9. How each role reads in play

The skirmish layer adds no threat to the player, so the Host's job is to make the ground war **legible as a war**. A glance down should tell the player who is attacking, who is fighting the convoy, and what is coming next.

- **Horizon (z 1400, ×0.31):** only mass and warm light. Each role has a distinct **light pattern**:
  - infantry: dots;
  - tanks: one forward-facing warm point (the prow eyes);
  - Reliquary: a warm ridge line;
  - Carillon: three upward dots;
  - walkers: a high point with dark under it;
  - Chapterhouse: a vertical line of lit windows and a gilt tip.
- **Mid-field (z 700, ×0.62):** role silhouettes (Section 5). Artillery fights from here.
- **Near (z ≤ 450, ×1.0 and more):** caste ornament, faces, mason's marks and channels.

## 10. Prompt guidance for refinement renders

The pipeline stays as `plan/asset-pipeline.md` describes:
- **silhouettes, launchers and every animation frame are authored on the texel grid**;
- AI keyframes contribute only a −1/0/+1 shading texture on the hull ramp, plus concept reference;
- large-model renders are **refinement and concept sources**, never shipped pixels.

Two kinds of render:

1. **Concept turnarounds** (large model, 1536–2048 px, painterly allowed). These are for review only: they settle proportions, ornament placement and the face before grid authoring. One unit per image, 3/4 high side view facing right, plus an optional top-down inset.
2. **Texture keyframes** (the existing SDXL + pixel-art-xl + LayerDiffuse transparent workflow, 1024² canvas, 3 candidates per seed). The selected one becomes the shading texture.

### Prompt template

```
[STYLE]   pixel art, 16-bit arcade game sprite, crisp square pixels, limited palette, original artwork, centered, isolated, transparent background
[VIEW]    single <vehicle|figure> seen from a high three-quarter side view facing right, top and side visible, night lighting, rim light from upper left
[SUBJECT] <role noun> shaped like <architectural part>, <one gargoyle face detail>, <one membrane detail>, <signature cue>
[MATERIAL] carved <sector stone> with chisel facets, cast iron bands, lead roof plates, chains, <caste ornament>
[LIGHT]   dark low-contrast stone, glowing ember-orange eyes and carved spout mouth, a glowing slag channel along its back
[TONE]    friendly-scary cartoon menace, chunky readable silhouette
```

**Negative (family plus Host):**

```
text, letters, watermark, logo, signature, ui, frame, border, blurry, photo, photorealistic, smooth gradient, multiple views, character sheet, grid, sky, horizon, ground, landscape, scenery, crowd, many objects,
blood, gore, flesh, wounds, skull pile, cross, crucifix, saint, religious icon, halo, scripture, cyan, teal, mint, blue lights, feathers, beak, bird, insect, chitin, tentacles, slime, cute chibi
```

Notes:
- Never name a franchise, studio, artist or film, positive or negative.
- "Insect, chitin, tentacles, slime" are negated so the Host never drifts into the *grown* swarm language.
- "Cyan, teal, blue lights" are negated to protect the allied colour code.
- For infantry use the troops family view: `single full body character, side view facing right`.

### Per-unit subject lines

| Unit | Subject line |
| --- | --- |
| Rubblings | a tiny hunched gargoyle imp made of rough rubble stone, oversized curled ram horns, no helmet, stubby folded bat-wing nubs, holding a stone chisel spear low, glowing ember eyes |
| Knell-bearer | a tall hooded gargoyle bell-ringer, dark cloth hood over stone face, wooden yoke across the shoulders with a heavy iron bell hanging at one end, thin gold rim on the bell, glowing ember eyes, folded bat wings under the hood |
| Prior | a gargoyle officer in a long iron-banded coat, crown of three small gilded stone pinnacles between curled horns, a tall banner pole rising from its back with a tattered bat-wing membrane pennant and a gilded pinnacle tip, holding a staff with a lantern mouth |
| Crocket | a low fast light tank, long flat stone slab hull with a row of curled hooked stone crockets along its spine, snarling gargoyle face on the front corner, short gun barrel ending in a carved mouth, iron tracks |
| Tympanum (refresh) | a heavy battle tank whose sloped front carries a big carved gargoyle face inside a pointed arch panel, horned turret mantlet, one long gun barrel with a glowing gutter channel along its top ending in a fanged mouth, spiked iron tracks |
| Narthex | a huge two storey siege tank, a deep pointed stone archway at the front with a ram shaped gargoyle face inside it, two small horned turrets on the upper deck flanking a short bell tower, double iron tracks |
| Reliquary | an armoured troop carrier shaped like a stone casket with a steep pitched lead roof, bat-wing membranes folded down the roof slopes like shingles, pointed arch side doors, a small gargoyle gunner head on the roof ridge, stone rimmed wheels |
| Carillon | a low artillery carriage carrying three iron bells mouth up in a carved stone frame, gold rims on the bells, gargoyle face on the front of the carriage, a glowing slag gutter from a rear hopper to the bells |
| Rosegun | a squat tracked rocket launcher carrying a large round stone rose window of radiating tracery tilted toward the sky, each petal a launch cell glowing faintly, gargoyle face on the base |
| Buttress Strider | a hunched stone walker carried on two arched flying buttress legs with small pinnacles at the knees, open space under its body, low gargoyle head cockpit with a gun hanging under its chin, folded bat-wing shoulder mantlets |
| Belfry (refresh) | a walking gothic bell tower on short stone legs, louvred bell chamber holding a missile launch tube, horned gargoyle heads at the corners, glowing runes along a slag channel |
| Hodcrawler | a squat crawler with a long iron crane arm ending in a hooked gargoyle hand, carrying a hod of fresh stone blocks, folded wing mantlet, glowing mortar lines |
| Thurible | a narrow wheeled cart with a tall iron gallows pole, a huge iron censer swinging on chains, dark smoke curling from its vents, gargoyle face on the cart |
| Cistern | a long round topped stone tank on wheels with gutters running down its sides into carved gargoyle spout mouths dribbling glowing slag |
| Chapterhouse | a tall octagonal stone chapter house walking on six short buttress legs, a tall gilded spire with a horned finial at its centre, a round rose window eye below the spire glowing ember orange, lit tracery windows, two tattered bat-wing banners at the rear corners, lead roof |

**Sector modifiers** (append one):
- Krybor: `captured human vehicle defaced with carved stone, scratched ember glyphs, frost slate`;
- Ringfall: `salvaged violet hull plates mortared with stone`;
- Ember: `black basalt with faint glowing kiln cracks`;
- Hollow: `dark weathered verdigris stone, cathedral masonry`;
- Carrier: `polished black obsidian, more gilded ornament`.

**Seeds:** Host keyframes use the 76xxxx range: 7601xx infantry, 7602xx tanks, 7603xx carriers, 7604xx artillery, 7605xx walkers, 7606xx support, 7607xx command. Provenance goes in `art/families/ground-host-runs.json`.

### Selecting a keyframe

Pick the candidate whose **shading** best supports the authored silhouette:
- clear stone facets;
- a readable face plane;
- no strong cast shadow.

Never pick for its outline. Reject candidates with crosses, blood-red liquids, cyan lights, insectoid or slimy forms, or text-like marks.

## 11. Review checklist

- [ ] The black-fill test at ×0.62 names every role (Section 5). Do it as a blind sort with the labels hidden.
- [ ] Greyscale contact sheet: hull, ornament and warm accent sit in three distinct value bands.
- [ ] At phone size (360 × 780) over all five sectors, nothing on a Host unit is brighter than the hostile shots, and no hull reads cyan or teal.
- [ ] Allies, swarm and Host can be told apart in a single frame with all three present.
- [ ] Every weapon fires from a mouth, and every telegraph is a channel fill.
- [ ] Gilt never blinks; warm light is the only blinking accent.
- [ ] No blood, crosses, scripture or real-world religious marks; no franchise lookalikes (check every unit against the names in the research originality list).
- [ ] Reduced motion: idle loops freeze, and telegraphs and blooms remain.
- [ ] Mirrored frames: marks and faces still read correctly.

# Demon Attack — visual and musical style guide

## Direction and implemented asset contract

Original pixel artwork honors early-console clarity with animated winged demons, cosmic scenery, and expressive damage states. Ordinary enemies are living creatures: horns, membrane wings, teeth, eyes, and tails. The carrier is a gargoyle warship, a spaceship first: a hard-surface hull with engines, plating, a bridge tower, hangar bays and turrets, wearing gargoyle ornament like a figurehead, and a bigger, darker hull class every run. Preserve hard pixel edges and nearest-neighbor filtering. Keep threats readable against darker scenery; do not bake interface text into images.

### Creature direction: gargoyles, not birds

Every ordinary creature and sentinel is a **demonic gargoyle**: stony, leathery hide; heavy shoulders and a hunched torso; curled or swept horns; a snarling fanged maw; glowing eyes; clawed hands and feet; a barbed tail; and **bat-like membrane wings** stretched between visible finger bones, with scalloped, torn edges. No feathers, beaks, fanned primaries or bird proportions, and no upright "standing, seen from the front, wings wide open" pose. They are cartoonish and friendly-scary, clearly a threat but never gory or truly frightening for a child: damage is cracked stone with glowing fissures and torn membranes, never blood or wounds. Species keep distinct silhouettes and roles: teal a lean imp with big ram horns, violet an armoured brute with massive shoulders and stubby wings, coral a sleek predatory hunter with long horns, jaws and a stinger tail, gold a crowned elder holding orbs. The sentinels are a horned violet warden and a crowned gold colossus. The carrier shares their ornament but not their anatomy: it is an engineered warship whose gargoyle figurehead, bat-wing solar sails, carved spires and buttresses are applied to a hard-surface hull (see [Boss armada](#boss-armada-gargoyle-warships-spaceship-first-gargoyle-second)). Never imitate an existing game's creatures, including the 1982 game this project shares a name with.

## Durable pixel-art and animation rules

These requirements apply to every new combat creature, attack warning and damage effect. The visual reference is the simple, expressive low-resolution silhouettes and stepped poses of 1982-era Demon Attack. All shipping drawings must be original; never copy, trace or extract the original game's sprites or screenshots.

- Author silhouettes on a fixed low-resolution logical pixel grid, with an explicit bounded palette shared with the combat atlas. Enlarge with nearest-neighbor sampling and preserve square pixels. Judge both native logical size and actual phone size.
- Use distinct authored pixel frames for creature wing poses, armor damage, fire, smoke, sparks and destruction. Programmatic generation is welcome when it rasterizes onto that logical grid. Smooth antialiased runtime vector creatures, gradient fire and continuously bent/deformed wings or flames are outside the style.
- A large creature gains scale and a distinct silhouette while retaining the same coarse pixel language. The sentinel has a broad horizontal body and visibly separated wing segments. Its eight-pose bat-wing stroke articulates arm, forearm and finger bones while preserving a broad membrane span. Its slow stepped flap conveys mass: hold each pose noticeably longer than ordinary demons' 0.10–0.14-second wing frames, with a whole flap taking several seconds.
- Telegraph the sentinel's dive with original pixel warning frames on its own eyes or wings. Do not use an arrow. Keep the warning visible against all backgrounds, including with reduced decorative motion.
- Carrier damage uses increasingly numerous/intense pixel-frame smoke, sparks and flames anchored to the damaged hull. Avoid smooth curves, gradient blobs and vector flame tongues. Pixel outlines must remain recognizable during the falling-wreck scene.

Sentinels belong after at least one boss victory in the current campaign. An eligible wave first brings in a small ordinary swarm; the sentinel then descends slowly from offscreen into a position above every ordinary enemy. Hold that high hover with very slow wing poses before the warning and fast heavy dive. The entrance, hover and dive must read as distinct phases even on a narrow phone.

A rare last stand is reserved for a minority of sentinels selected once and reduced to at most 25% health. Give it a subtle but distinct original pixel pose on the creature itself plus a small recognizable preparatory movement throughout a 0.9-second tell; it must differ from the normal dive warning by shape and motion, not only color. Sample the player's position when the tell begins, then rush at 600 arena units/second in Normal (540 Easy, 630 Hard) along a fixed straight path so moving after the tell can dodge. This attack is irreversible: impact or arena exit ends in pixel-frame self-destruction, with no return to formation or player-reward celebration. The sentinel remains shootable during both tell and rush; destruction by player fire keeps its normal rewards. Easy preserves its 10% hostile-rate reduction: a 1-second tell and 540-unit/second rush. Hard’s 5% hostile-rate increase gives an approximately 0.857-second tell. Dedicated raised-wing charge and narrow folded-wing rush frames live in rows 6/7 of the supplemental atlas. Preserve these fairness cues when changing frames, timing or reduced-motion behavior.

The authoritative production atlas layout is [sprite-atlas.md](sprite-atlas.md). Combat creatures are authored on a **64 × 64 logical grid** (raised from 32 × 32 for 16-bit-level detail), stored 1× in `assets/images/combat.png` (2048 × 2560, thirty-two columns) and drawn at the same 40/44-unit size as before, so the footprint and hitboxes are unchanged. The ship and its weapons (`ship-weapons.png`), the sentinels and effects (`sentinel-effects.png`, 128 × 64 logical cells) and the carrier (`boss-carrier.png`, native 368 × 240 per cell) follow the same rules. Do not substitute a differently sized concept sheet into the renderer.

| Combat rows | Content |
| --- | --- |
| 0–35 | Nine rows per species (teal, violet, coral, gold): left / neutral / right flight sets (8-pose flap + 2 glide) for intact, three molts and angry; 60 hit-flash frames; anticipation, weapon fire, eight-frame death and per-damage dive frames; elite armour overlays per direction |
| 36 | Explosions and powered splash |
| 37 | Sparks, impact flash, creature muzzle flash |
| 38 | Pickup badges |
| 39 | Fallback ship and carrier |

The shield, sliding doors and core vulnerability remain tied to simulation state, now drawn with authored door, hatch and wreck frames; the campaign communicates boss damage through shield coverage and pixel hull effects instead of health bars. Creatures have normal, three intermediate damaged and angry appearances; each nonlethal hit updates the lookup.

Combat palette: one bounded palette (`tools/sprite_kit.py`, listed in sprite-atlas.md) shared by every sheet. Gargoyles are a little darker than the round-1 creatures: deeper, more saturated hide ramps (teal #16958A, violet #9070FF, coral #F25A64, gold #C8902A base tones, Rec. 709 luma 0.48–0.58), darker membranes (front luma 0.34–0.38) and a deeper outline #0A0716 for outlines, contours, eye sockets and maws. Body base and light tones stay clearly above the brightest background layer (0.42, the flyover creatures; walls 0.30, landmarks 0.40, ground 0.13), and the highlights are reserved: glowing yellow eyes (#FFD23F with a #FFFBE0 core; red #FF355F when angry or warning), ivory fangs, horns and claws, and thermal weapon mounts and damage fissures. Re-validate readability over all five sector backgrounds at phone size whenever a ramp changes (`test/gargoyle_review_test.dart` renders them). Space uses near-black blue and purple. Friendly shots are cyan/mint/gold; hostile shots use warm red/orange. Shapes and motion reinforce color. Render all new art at native scale before judging enlarged previews. Procedural production sprites and generated illustration/concept assets have distinct roles: AI renders enter the atlases only through the pipeline in [asset-pipeline.md](asset-pipeline.md#sprites), which finishes them onto the grid and palette as shading detail and never replaces authored silhouettes.

## 64-grid detail and animation

The extra resolution goes into motion and readable equipment, capped where it would hurt readability at phone size:

- **3/4 flight, not a frontal pose.** Creatures are rendered by a small 3-D rig (`tools/gargoyle_rig.py`) from a camera tilted 34° above them, the body leaning toward the player with the head forward, legs tucked and tail trailing. Every flight frame exists **banking left, neutral and banking right**: the body turns (yaw ±38°) and leans (roll ±12°), the head leads into the turn, the wings are asymmetric (the inner wing beats shallower and folds more, the outer reaches further) and the tail trails outward. Right banks are real renders, never mirrors, so damage, slanted rank marks, the tail and weapon mounts stay on their anatomical side.
- **Downstroke, upstroke, hover and glide are distinct.** Eight flap poses per 0.5-second stroke: 0–3 the extended wings drive down while the whole body lifts 1–2 px; 4–7 the wrists lead, the wings fold and rise while the body drops. The neutral set is the hover/idle cycle; two glide frames hold the wings spread with the legs trailing. Humerus, forearm and each finger bone articulate separately and the membrane panels are re-rasterised every pose; membrane undersides are darker, so the upstroke reads as the wing turning over. Two-pose toggles and rigid up/down translation are out of style. Sentinels keep eight slow poses held 0.4 s each.
- **Frames follow the creature's actual motion.** The renderer measures each creature's velocity from its successive positions and picks left / neutral / right with hysteresis (enter at 55 units/s, leave below 24, hold ≥ 0.14 s) so it never flickers; climbing strokes faster with a longer downstroke, sinking lingers in the upstroke and fast sinking glides. Dive warning, dive, weapon fire and death still take priority. Every damage molt, the angry state and the hit flash exist for every direction (no overlay compositing). Presentation only: the simulation, its timings and hitboxes are untouched. Details in [sprite-atlas.md](sprite-atlas.md#frame-selection).
- **Armour, weapons, shields and rank are visible.** Every species wears armour (chest plates, pauldrons, crown) and a rank insignia (teal chevron, violet twin bars, coral fang slashes, gold star jewel). Each has a visible weapon mount that animates when it fires: teal throat emitter, violet pauldron barbs, coral tail stinger, gold claw orbs. Elites add a gold double-chevron brow mark, side helm plates, gold crest spikes, a steel gorget and gold-studded pauldrons, authored per direction and shedding one level per hit. Sentinels wear shaped metal armour layers and chest insignia (violet crescent, ruby sunburst) and discharge from the maw. The carrier carries a brood sigil and one rank pip per form.
- **Anticipation before attacks.** Before a dive the creature cocks its wings high, hunches and flares its eyes (four frames); weapon fire plays charge, flash, recoil and settle on the creature while a muzzle flash marks the actual shot spawn.
- **Hits and deaths are authored.** Hit flashes are highlighted frames (ramps stepped toward white, outline kept); molts crack the stone hide with glowing fissures, chip and snap horns and tear the membranes; deaths are an eight-frame species sequence (flash, glowing seams, the stone body breaking into tumbling chunks around a core burst, dust) instead of a generic burst.
- **Readability caps.** Keep a 1 px outline, depth contours between overlapping parts and a top-left key light on every frame; no feature thinner than one logical pixel against the outline; eyes 2 × 2 with a bright core under a dark brow; maws 5–7 px with fangs; insignia at most about 5 × 5 px; detail textures never cover eyes, insignia or plates; the head, horns and wings carry the silhouette. Judge every change on a phone-sized screenshot as well as enlarged.
- **Player cannons.** The nose cannon flashes when no wing module is fitted; a wing module mounts left and right cannons that alternate the primary shot, so only the side that fired recoils (three frames) and flashes (four frames). Modules deploy with a four-frame transition, wear through fresh/worn/critical with a heat overlay, and tumble away spent. The shield is a hex-segmented pixel bubble in healthy, degrading and critical frames, not a vector oval.

## Level and screen art direction

| Level | Visual identity |
| --- | --- |
| KRYBOR | Violet night, rocky horizon, pale rising moon |
| RINGFALL | Teal night, ringed planet and thin cloud bands |
| EMBER MOON | Crimson-violet horizon with contrasting moons |
| THE HOLLOW | Amber eclipse and distant carrier silhouette |
| THE CARRIER | Black-purple occultation; bright shield and core |
| Victory | Warm gold horizon accents and restrained sparks |
| Title / Top 10 | Quiet stars, cyan emblem, gold score accents |

The intended scenery has far stars, slower planet layers, and a closer horizon, with planets and moons rising or setting as the game advances. Background luminance stays below enemy and projectile luminance. Smooth palette and planetary movement between levels is the target; exact layer speeds and transition timing are renderer tuning, not simulation defaults. Reduced-motion support should remove shake and decorative motion without hiding warning cues.

### Backgrounds: oblique flyover with a horizon

Every sector is an endless oblique 3/4 flyover over the planet: a horizon line sits in the upper third (y = 172 of 520), the painted sky with its planets and moons is above it, and below it a receding ground plane streams toward the ship. One camera drives everything below the horizon: a point at forward distance z appears at y = 172 + 348·z0/z with scale z0/z (z0 = 174 ground texels, where one texel is two arena units at the bottom of the screen). Objects therefore emerge small near the horizon and grow and speed up as they approach.

| Layer | Motion | Content | Luminance cap |
| --- | --- | --- | --- |
| Far | ~0.02× (slow sway) | The sector's painted sky (`sector-N.png` rows above its horizon) plus its painted horizon band and sparse stars, baked once per sector into an image | painting under a 44–50% veil |
| Ridges | 0.2× | Ridge silhouettes (the mid strips, rotated) standing on the ground near the horizon, three bands handing over as they approach | 0.13 × 0.55 |
| Ground plane | 1.0× (perspective) | A 2-D seamless ground tile per sector, macro-modulated so it never shows a regular grid, rows compressed toward the horizon and darkened by distance fog | 0.13, chroma ≤ 0.22 |
| Side walls | 1.0× (perspective) | Slim, broken cliff rims hugging both edges, at most ~20% of the width each at the bottom and tapering toward the horizon | 0.30, chroma ≤ 0.28 |
| Landmarks / props | 1.0× (perspective) | Two landmarks per named route beside the walls; small sector props on the open ground | landmarks 0.40, props 0.34 |
| Creatures | 1.0× (perspective) | Two species per sector on the open ground between each wall and the central lane, with a dark outline and a faint upper-left rim light | 0.42, chroma ≤ 0.34 |

- Composable for any session length: seamless tiles (the ground repeats in x and y; walls tile vertically, three variants, never the same twice in a row, mirrored for the right side), plus landmarks, props and creatures placed by seeded, stateless scattering per world segment. The same distance draws the same picture on every device.
- The central lane (x 96–264) stays clear: walls and landmarks hug the edges, creatures are clamped outside it, the ground there is dark, low-contrast texture, and all scenery stays below threat, projectile and core luminance.
- Route identity lives in the landmarks (see the table in [sector-style-guide.md](sector-style-guide.md)); sector identity in the painted sky and horizon, the palette median-cut from it, and each sector's ground and wall materials.
- Creatures: frost hoppers and shell crawlers (Krybor), rock mites and dust grazers (Ringfall), cinder newts and ash borers (Ember), spore crawlers and bone skitters (Hollow), brood larvae and hive ticks (Carrier) — darker and more demonic deeper into the campaign. Discrete frames: four-frame walk/crawl, two duck, two burrow. They dash away from explosions and the falling carrier wreck (sideways inside their band and along the ground), burrowers sink into a mound, and all duck while the ship's shadow passes. Visual only: they read blast, wreck and ship state.
- Travel accelerates flight (up to 10× mid-travel) while the destination world fades in over the current one, so its landmarks appear before arrival. Cinematic blackout and letterbox bars still cover the scenery.
- Reduced motion (`disableAnimations`/`reduceMotion`) freezes flight, sky sway, particle drift and creature walking; scenery and warning cues stay visible.
- Performance: per sector per frame there is one sky image draw, one ground rect with a perspective `ImageShader`, one partial fog gradient (110 px), one ridge `drawAtlas`, one wall `drawVertices` mesh, one landmark/prop `drawAtlas` and one creature `drawAtlas`. Travel crossfades draw the destination with per-draw opacity instead of a full-screen `saveLayer`. Everything samples with `FilterQuality.none` (the sky bake is resampled once at load).

The generator, prompts and seeds are in [asset-pipeline.md](asset-pipeline.md).

Title centers an original horned demon emblem and the Demon Attack wordmark, with Start, Top 10, sound, and short controls guidance. The game HUD displays score, level/cycle, lives, and current power; carrier shield coverage and hull damage communicate boss condition during its encounter. Touch controls occupy a recessed futuristic laptop-style trackpad beneath the arena, with cyan corner lights, pixel circuit traces, and a visible drag indicator. Keep fingers away from combat. This one trackpad layout is used on every device, desktop browsers included; there is no separate desktop mode, and arrow keys or A/D steer alongside it. Real interface text remains legible and accessible; no fake labels baked into generated art.

Top 10 uses aligned rank, three-character initials, and score columns. Initial entry offers three rotating wheels with A–Z and 0–9, clear upper/lower controls, a highlighted middle selection, and Submit. Avoid a freeform text field. Game-over and victory keep a darkened arena behind their overlays. Review phone portrait, narrow desktop, and wide desktop without horizontal overflow.

### Wide-screen backdrops

On landscape windows with at least 48 px beside the 500-px column (never on phone portrait), the margins hold scenery instead of plain ink (`lib/widgets/widescreen_backdrop.dart`; assets and pipeline in [asset-pipeline.md](asset-pipeline.md#wide-screen-backdrops)). The column itself is untouched.

| Screen | Scene | Procedural layers |
| --- | --- | --- |
| Title | **Vista**: violet-navy night, teal nebula over the fleet side, ringed violet planet, an infernal glow on the swarm side, dark mountain horizon | Seen from the flagship bridge: a hull lintel, viewport struts leaning outward, a console bank with blinking mint, gold and steel pixel lights (quiet under the title content), a mint star-map hologram (fleet side) and a salmon threat-map hologram (swarm side); fighters patrolling on the left; the demon swarm wheeling in two-frame wingbeats over the horizon on the right |
| Initials entry / post-run top 10 | **Hall of heroes**: pilasters and alcoves of gold medals with ribbons, an arched starfield window, a reflective floor | Medal glints; the entry overlay fades to 32 % toward the edges so the hall shows |
| Game over | **Defeat**: crimson sky, blood moon, broken black spires, a horde of red-eyed silhouettes | Bridge frame with salmon and alarm-red lights, the swarm on both sides, rising embers, a red veil |
| Boss victory / campaign complete | **Victory**: gold dawn on the horizon, fireworks, formation trails | Bridge frame with gold lights, pixel firework bursts in the outer sky, drifting gold dust |
| Gameplay (and pause) | **Sector N**: the current sector's world extended sideways (from its own painting), dimmed under a 44 % ink veil (62 % while paused) | Starfield; the scenery leans up to 3 logical px against the ship's position; during travel the destination sector crossfades in with the same blend as the flyover; it fades out toward the column so the scene's centred painting has no hard edge |
| Gameplay with side calls | — | **Command-centre wall**: a chamfered bulkhead per side, textured with the wall tile, with each call slot set into a dark recessed bezel, five status lights below each slot and a conduit with a travelling pulse between slots. A backdrop only: the comms panels draw on top and own their own background |

- **Pixels.** Panoramas are 768 × 320 logical pixels drawn at a whole-number nearest-neighbour scale: sector extensions cover the height (`ceil(height / 320)`: 4 at 1080 p, 5 at 1440 p); menu scenes take the largest scale that fits (`floor`: 3 at 1080 p, 4 at 1440 p) so more of the composition shows, and fade into the bridge lintel and console. Procedural layers use a unit of `ceil(height / 160)` pixels or half of it. No smooth vector shapes, no blur.
- **Focus.** Low contrast at the edges: an ink fade over the outer 22 % of the width, darker top and bottom, menu veils of 8–22 %, a 62 % edge shade. Luminance caps in the finish: 0.42 for sectors (the flyover creature cap), 0.5–0.6 for menus, 0.24 for the wall. Lights stay at 62 % alpha or less.
- **Any aspect ratio.** The art is 2.4:1; wider screens (32:9) feather its ends into the starfield. Struts, holograms and fireworks appear only when the margin has room for them.
- **Motion.** Slow sway (±3 logical px over ~2 minutes), twinkle, wingbeats, blinking lights, embers. With reduced motion (`MediaQuery.disableAnimations`) the time input is frozen: everything stays visible and still.
- **Loading.** Images load on first use, only once a wide layout asks for that scene (two sector images during travel, the wall only when side calls show). Total shipped weight: about 575 KB (sectors about 76–102 KB each, menus 17–34 KB, the wall 1 KB); at most two sector images are in memory at once.
- **No text.** Nothing in the art or the overlays spells words; holograms are dots and rings.

### Squad comms video call

A squad video call frames the arena as the shared screen (OpenSpec change `squad-comms`).

- **Layout:**
  - **Wide screens.** When the margins beside the 500-px cabinet are at least 150 px wide, two call tiles stand on each side and never cross the cabinet. The air squad (the Fleet Admiral and pilots) sits on the left. The ground link and the brood intercept sit on the right.
  - **Phones, narrow windows and small landscape.** A compact translucent dock sits at the top of the arena, just below the HUD band, so the score, lives and hearts stay readable. It holds one 36-px strip: a 34-px portrait and the callsign plus up to two lines of subtitle. Spoken lines win the strip, and a grunt takes it only when nobody else talks. A second active line collapses into an 18-px chip (portrait and callsign, or officer and SIGINT gloss); waiting lines show as `+n`. The dock dims to 30 % while the player is being hit, and it moves down under a heart-piece notice.
- **Tile anatomy:** a name, rank and callsign tag; a video area with the pixel portrait at an integer scale, nearest-neighbour; scanlines; LIVE and signal-bar glyphs; a subtitle well. A caller connects and disconnects through blocky signal static. A speaking caller gets a stepped accent glow that pulses with the mouth.
- **Motion:** portraits breathe with a one-logical-pixel bob, blink, and tilt their head now and then. After a line they hold the trigger's mood (smile, worried). A grunting demon officer gets a camera zoom onto the face in whole-pixel steps: the tile grows across its own margin on wide screens and pops inside the strip on phones. The zoom adds a small shake only when motion is allowed. With reduced motion there is no shake, and the static becomes a plain fade.
- **Subtitles:** humans are subtitled with their line. Demon grunts show original bilateral 5 × 7 brood glyphs revealed over the clip, plus a `SIGINT · <intent>` gloss in salmon, so the player reads the enemy's intent without the grunt being words.
- **Celebration:** when the whole allied fleet survives, the left header turns into a gold FLEET INTACT banner and the crew speaks in sequence.
- **Cast and tone:** the cast is original and diverse in age, gender and ethnicity, with no caricature and no stereotyped accents. Several of the senior officers are women, starting with the Fleet Admiral. Allies are never killed: a downed ship or squad is "totalled" and heads back to base.

### App icon

The installed-app and tab icon is a dedicated emblem, never an enemy atlas frame: a horned gargoyle-demon head (violet ramp, bone horns, burning red eyes, fangs) with the fleet starfighter (teal wings, slate hull, cyan canopy) rising at it from below, both wrapped in a stepped cyan glow on midnight #100E2C, inside a gold #EFBD57 rim. The midnight tile and gold rim keep it legible on light and dark tab bars and taskbars. Large sizes rasterise the geometry in `art/icons/icon-spec.json` onto a 64 logical grid (8× at 512, 3× at 192); 16, 32 and 48 px are hand-tuned pixel maps (`art/icons/badge-*.txt`). Maskable and apple-touch versions put the emblem in a gold ring inside the 80% safe circle on a full-bleed field. Regenerate everything with `tools/generate_icons.py`; edit the spec or maps, never the PNGs.

## Current music score and playback

Musical direction: original music only, never imitating an existing song, band, game or soundtrack. Each sector has its own genre and motif, and the campaign gets heavier and more demonic as the swarm closes in: punk, melodic rock, heavy metal, doom, then doom with death-metal colour at the carrier. The fleet's successes are a military march, and the aliens' victory is a cackle followed by a twisted triumphal march. Every cue shares **120 BPM** in 4/4, so all changes land on a bar line. Tension grows through arrangement density (drums, distortion, lead lines, register) across four intensity tiers per level, never through tempo. Everything is fully instrumental. The demonic levels get choir and chant-like pads as texture; the prompt asks for growl texture, but no clear vocals were generated or wanted.

The recorded score is ACE-Step 1.5 re-performing a synthesized guide of each motif (audio-to-audio with the level's genre take as timbre reference). That keeps one motif across a level's cues. Method, commands and checks are in [audio-backend.md](audio-backend.md#recorded-cues-primary). Opus/OGG is the primary format and AAC/M4A the fallback. A level's set loads lazily when the level is cued.

### Motifs

| Level | Genre | Key | Motif (riff · progression · hook) | Drums by tier (1 → 4) |
| --- | --- | --- | --- | --- |
| L1 Krybor | punk rock | E minor | Downstroked E5 eighths with a **G–A push** into every second bar · E E C D E E A–G B · shouted hook **B-B-A-G-E**, answered G-A-B-D-B | straight beat → driving beat → punk "oom-pah" skank (kick every beat, snare every off-beat) → skank + 16th hats |
| L2 Ringfall | melodic rock | D major | Syncopated open-chord pushes on 1, 2&, 3, 4& · **D F♯m G A Bm G Em A** · soaring hook **A–F♯–A, C♯–B**, rising to F♯5 in the second half | half-feel with arpeggiated clean guitar → rock beat → 16th hats → ride and double kicks |
| L3 Ember Moon | heavy metal | E minor | **Gallop** (eighth + two sixteenths) on an E pedal with a Phrygian F · E E C–D E E E F–G A–B · twin-guitar hook **E-F♯-G-B** harmonised in thirds at tier 4 | rock beat → gallop kicks → + off-beat hats → double bass |
| L4 The Hollow | doom metal | C minor | Drop-C crawl **C… E♭ \| G♭-F-C \| E♭-D♭ \| C… B**: the G♭ tritone is the dread · tolling bell/lead motif **C-G-A♭-G, E♭-D-C** | half time (kick 1, snare 3, toms) → half time with organ → full time with choir → 16th double kick with crash/china |
| L5 Carrier | doom-death metal | F minor | **F-G♭-E crawl answered by a low B tritone stab**, D♭-C, a chromatic D♭-D-E♭-E climb, final F-B · tremolo picking from tier 3 · choir, organ and bell | half time → 8th double kick → 16th double kick → blast beat |
| Fleet march | military march | C major | Fanfare **G-G-C-E-G \| C6…**: levelclear plays bars 1–2 and a cadence, victory bars 1–4, the finale all 8 with choir and timpani | bass drum on every beat, snare drags and rolls, crashes. Fleet-intact variants add a brass descant, a trombone counterline and a drum corps (16th snare line, flams, sextuplet flourishes, tenor drums) |
| Alien victory | twisted march | E Phrygian dominant | **E-F-G♯…, B-C-B-G♯**, falling to F: triumph bent out of tune | pounding march with timpani, gated guitars, organ and choir |

### Cues

| Cue | Kind | Source | Beats | Seconds | Loop | Opus | AAC |
| --- | --- | --- | ---: | ---: | --- | ---: | ---: |
| `alienwin` | loop | a2a s44 d0.45 | 32 | 16 | 0–16 s | 171 KB | 257 KB |
| `cackle` | oneshot | synth | 8 | 4 | — | 30 KB | 51 KB |
| `finale` | tail | a2a s42 d0.45 | 36 | 20 | 18–20 s | 212 KB | 322 KB |
| `finale-fleet` | tail | a2a s43 d0.45 | 36 | 20 | 18–20 s | 210 KB | 321 KB |
| `l1-accents` | sprite | synth | — | 7.5 | — | 77 KB | 122 KB |
| `l1-intro` | tail | a2a s43 d0.45 | 16 | 10 | 8–10 s | 101 KB | 163 KB |
| `l1-outro` | loop | a2a s42 d0.45 | 16 | 8 | 0–8 s | 91 KB | 130 KB |
| `l1-t1` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 157 KB | 257 KB |
| `l1-t2` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 169 KB | 257 KB |
| `l1-t3` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 170 KB | 256 KB |
| `l1-t4` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 169 KB | 256 KB |
| `l2-accents` | sprite | synth | — | 7.5 | — | 77 KB | 122 KB |
| `l2-intro` | tail | a2a s42 d0.45 | 16 | 10 | 8–10 s | 104 KB | 163 KB |
| `l2-outro` | loop | a2a s41 d0.45 | 16 | 8 | 0–8 s | 86 KB | 130 KB |
| `l2-t1` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 172 KB | 257 KB |
| `l2-t2` | loop | a2a s42 d0.45 | 32 | 16 | 0–16 s | 164 KB | 257 KB |
| `l2-t3` | loop | a2a s42 d0.45 | 32 | 16 | 0–16 s | 167 KB | 256 KB |
| `l2-t4` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 166 KB | 256 KB |
| `l3-accents` | sprite | synth | — | 7.5 | — | 79 KB | 123 KB |
| `l3-intro` | tail | a2a s42 d0.45 | 16 | 10 | 8–10 s | 105 KB | 162 KB |
| `l3-outro` | loop | a2a s41 d0.45 | 16 | 8 | 0–8 s | 87 KB | 130 KB |
| `l3-t1` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 157 KB | 257 KB |
| `l3-t2` | loop | a2a s45 d0.35 | 32 | 16 | 0–16 s | 159 KB | 257 KB |
| `l3-t3` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 172 KB | 257 KB |
| `l3-t4` | loop | a2a s42 d0.45 | 32 | 16 | 0–16 s | 159 KB | 256 KB |
| `l4-accents` | sprite | synth | — | 7.5 | — | 75 KB | 122 KB |
| `l4-intro` | tail | a2a s43 d0.45 | 16 | 10 | 8–10 s | 103 KB | 162 KB |
| `l4-outro` | loop | a2a s41 d0.45 | 16 | 8 | 0–8 s | 85 KB | 130 KB |
| `l4-t1` | loop | a2a s42 d0.45 | 32 | 16 | 0–16 s | 163 KB | 257 KB |
| `l4-t2` | loop | a2a s42 d0.45 | 32 | 16 | 0–16 s | 166 KB | 257 KB |
| `l4-t3` | loop | a2a s41 d0.45 | 32 | 16 | 0–16 s | 166 KB | 256 KB |
| `l4-t4` | loop | a2a s43 d0.45 | 32 | 16 | 0–16 s | 165 KB | 257 KB |
| `l5-accents` | sprite | synth | — | 7.5 | — | 77 KB | 122 KB |
| `l5-intro` | tail | a2a s42 d0.45 | 16 | 10 | 8–10 s | 112 KB | 162 KB |
| `l5-outro` | loop | a2a s41 d0.45 | 16 | 8 | 0–8 s | 85 KB | 130 KB |
| `l5-t1` | loop | a2a s44 d0.45 | 32 | 16 | 0–16 s | 173 KB | 257 KB |
| `l5-t2` | loop | a2a s44 d0.45 | 32 | 16 | 0–16 s | 170 KB | 256 KB |
| `l5-t3` | loop | a2a s44 d0.45 | 32 | 16 | 0–16 s | 166 KB | 256 KB |
| `l5-t4` | loop | a2a s42 d0.45 | 32 | 16 | 0–16 s | 164 KB | 257 KB |
| `levelclear` | tail | a2a s41 d0.45 | 12 | 8 | 6–8 s | 89 KB | 131 KB |
| `levelclear-fleet` | tail | a2a s41 d0.45 | 12 | 8 | 6–8 s | 85 KB | 130 KB |
| `menu` | loop | text s1101 | 32 | 16 | 0–16 s | 183 KB | 257 KB |
| `victory` | tail | a2a s44 d0.45 | 20 | 12 | 10–12 s | 132 KB | 195 KB |
| **Total** | | | | | | **5.64 MB** | **8.66 MB** |

The intensity tiers of a level are four arrangements of the same 8-bar motif: tier 1 is calm (palm-muted riff, sparse drums), tier 2 driving (full band), tier 3 intense (lead hook, busier drums) and tier 4 peril (double-time or blast, harmonised lead). They share bar 1, so the player switches between them on a bar line without losing the riff's place. The intro states the riff, brings the drums in with a fill and quotes the hook. Then its last bar loops until play begins. The outro is the riff at half energy with the hook in augmentation, for the travel after the level.

### Game events to music

| Game state (read by `MusicDirector`) | Music |
| --- | --- |
| Level arrival (`level`, carrier `boss` event) | `l<n>-intro`, on the next bar |
| Play begins | tier from wave progress: first third → 1, second → 2, last → 3 |
| Elite present / sentinel present | at least tier 2 / tier 3 |
| Reinforcements arrive (`reinforcements` event) | +1 tier for 6 s, and the **reinforce** accent |
| Ground war: `allyUnderAttack`, `groundForceInRange` (shared bridge) | +1 tier for 6 s |
| Ground war: pressure `model.ground.pressure` (0–1) | +1 tier from 0.4, +2 from 0.8 |
| Ground war: `groundBreakthrough` (L3–L4) | **breakthrough** accent |
| A dive tell starts (telegraph) | **dive** accent (at most one per 2 s) |
| Sentinel dive or last stand | tier 4; a new last stand plays the **laststand** accent |
| One life left | +1 tier |
| Carrier form *p* of *n* | tier 4 − (n − 1 − p), so the final form is tier 4; shield down +1 |
| Carrier central hatch opens | **hatch** accent (at most one per 7.5 s) |
| Calmer state | steps down only after 4 s of lower demand; up at once |
| Wave cleared → salvage → `levelclear` | `levelclear` immediately (`levelclear-fleet` after `fleetIntact`) |
| `travel` | the cleared level's `l<n>-outro` |
| Carrier destroyed (`victory`) | `victory`; on the last route the campaign `finale` (`finale-fleet` after `fleetIntact`) |
| `defeat` / `gameover` | `cackle` immediately, then `alienwin` on the bar 8 beats later |

Accents keep one role and shape on every level: dive is the hook's first three notes rising over a root stab and snare; last stand is a tremolo on the tonic rising a semitone with a snare roll and crash; hatch is a low tritone stab with bell, choir and china; reinforcements is a two-chord riff hit with crash; breakthrough is an alarm of the tonic and its flat second, twice, then the hook's first note an octave up over a tom run. Each is played in the level's own pitches and instrumentation, and lands on the next half-beat (dive, reinforce) or beat (last stand, hatch, breakthrough).

### MIDI fallback score

`web/audio/generate-midi.py` writes Standard MIDI Format 0 files for every cue from the same motif events in `tools/music_motifs.py`: riff, bass, lead, kick and snare. When every recorded format of a cue fails, `web/audio/demon-audio.js` plays that cue's MIDI on the same grid, so a fallback tier still plays its level's motif. The MIDI voices use square lead, sawtooth riff and bass, sine pads and triangle percussion.

### Playback rules

A shared audio-clock scheduler runs with lookahead and asynchronous loading, and a request counter rejects stale loads. Cue changes land on the next bar, while tier changes land on the next bar *at the same loop position*: rising tiers cut on the downbeat, falling tiers fade over a beat. The intro hands over to play when its 16-beat opening has played. Clear, victory, the finale and the cackle start immediately with a 90 ms music-only fade. Tail cues hold their last bar, so a long cutscene is never silent, and the alien theme loops until the next cue. Accents never delay the game or replace the music. Effects stay short synth voices with unchanged timing and voice limits (shot 4, hit 4, explosion 5, 14 total). They play at 0.9 against recorded music at 0.7, and the rock and metal levels are mastered 1 dB below the marches so the effects stay audible.

Visiting the page stays silent until a user gesture unlocks browser audio. Muting ramps the master gain, and pause suspends the audio context. Resume keeps the bar grid's phase, skipping only whole beats that fell behind. The bridge also pauses on visibility changes.

Future refinements: true stems (the tiers are full mixes crossfaded on bars, not separately mixable layers), music/effects balance controls, and sound preference persistence.

## Review gates

At native scale every demon species, angry state, player, and pickup must be recognizable, with no screenshot or original-game sprite reused. Inspect extracted alpha edges and atlas frames; generated concept sheets require review before becoming production assets. Review the sentinel and carrier fire together with ordinary demons: all must share hard pixel edges, bounded palettes and discrete frames. Inspect a full sentinel entrance/hover/warning/dive sequence and reject immediate dives, fast flapping, bird silhouettes (feathers, beaks, frontal wide-open wings) and arrow warnings. Enemy bullets must remain visible on every background. Musical loops should have no silent boundary, old voices should release cleanly, state changes must not restore stale cues, and first visit must stay silent until interaction. Browser checks should cover music through a complete boss transformation, victory, next cycle, pause, resume, and muted play.

## Multiwave and cinematic presentation

LV1–2 have three waves; LV3–4 have four. Intermediate-wave banners retain the sector's musical identity. The finite campaign's text-bearing cinematic phases add approximately one third of a second to their previous reading interval; ordinary level-clear and travel scenes therefore target 4.33 s each instead of 4 s. Increase story text visibly beyond the initial campaign captions and use more arena space, while keeping full messages readable without clipping on narrow phones and landscape. Show travel with the same cosmic palette and the next destination's recognizable scenery. Carrier defeat presents a falling wreck, fleet recognition, medal and +1UP before departure; the fifth victory ends the campaign. Keep score and lives legible, freeze power timers, suppress damage and auto-fire, and retain exact visual progress while paused. Use the model's normalized transitionProgress to drive these scenes so animation and phase timing agree.

Heart pieces must read as four complementary quarters of one familiar heart, with an outline showing missing pieces. Keep bottom-left, bottom-right, top-left and top-right visually distinct, with all four required for completion. Completed hearts trigger a visible full-heart and +1UP cue that persists briefly after the inventory slot resets. Collection frequency should make this an occasional recognizable reward, including in dense later-route waves.

## Combined power glyphs

Power status uses transparent pixel-grid layers: Spread cyan #70F5D5 side cannons or Large amber #FFAD53 side shells; Rapid gold #F4CA79 central lightning or Powerful coral #FF786C heavy central cannon; independent Shield violet #A888FF outer enclosure. Legal combinations retain every layer. Display each active name, countdown and timer bar beside the mark inside the controller panel, leaving the arena unobstructed. Losing or replacing one modifier removes only its visual layer and row.

## Extended combat and power presentation

Every sentinel arrives with its own fresh largest reinforcement escort flock and show real shield and armor layers from first sight, separately from hull damage. Evasion uses a short readable lateral movement; their faster bullets need a distinct pixel shape/color so players can recognize the greater threat. Ordinary waves add multiple finite casualty-triggered flocks at their parent wave’s capped strength during combat; show their entrances clearly without disguising them as a new checkpoint or a new wave. Incoming squadrons sweep along curved trajectories (side arcs, top loops, figure-8 descents, and split pincers) and hand off into active formation via a quintic smootherstep (`6t^5 - 15t^4 + 10t^3`) envelope with zero visual snap, pitching slightly into their flight curve during entry and dive maneuvers.

To give the defender, demon swarms, and brood carrier convincing **2.5D arcade depth without smooth GLSL normal-map blur**, apply stepped pixel-grid directional hemisphere and rim lighting (`FilterQuality.none`):
- **Player ship banking, fake-3D shading & sling shots**: When `shipBank` tilts the ship (`±0.14 rad`), elevate the leading wingtip, shade the trailing wing underside, shift the canopy specular pixel toward the top-left zenith key light, and render twin thruster plumes with ground-plane illumination and asymmetric thrust length. Sling-shot projectiles fired at high lateral speed (`|vx| > 25`) render an elongated angled plasma streak with a bright leading tip.
- **Atmospheric Re-Entry Plasma Fire vs. Technological Force Shields**: Strict visual and chromatic separation distinguishes aerodynamic re-entry thermal friction from engineered energy barriers:
  - **Atmospheric Re-Entry Plasma Fire (Diving Demon & Sentinel Dive Envelopes)**: Diving creatures plunge through the sector atmosphere wrapped in a chaotic, strictly **thermal blackbody radiation gradient** with zero cool cyan or violet bands. From leading bow-shock stagnation point to trailing wake, the stepped pixel layers progress through: (1) **blinding white stagnation core** (`#FFFDF7` / `#FFF8DC`) at the compressed leading edge, (2) **incandescent solar yellow** (`#FFE042` / `#FFBF1F`), (3) **superheated ablation orange** (`#FF6B1A` / `#E8430C`), and (4) **deep crimson/charcoal smoke trail** (`#9E1B1B` / `#3B171D`) with turbulent frame-stepped pixel jitter and shedding incandescent embers. Small creatures (`diveShieldMax = 1`) form a compact thermal bow-shock crescent; not-so-small creatures (`diveShieldMax = 2..3`) form a wider double-layered ablative envelope; Sentinels (`diveShieldMax = 4 + floor(route/2)`) project a massive V-shaped aerothermal re-entry shockwave cone that sheds burning slag and shatters into a high-contrast thermal white/amber **Plasma Shatter** burst when broken by powered weapons.
  - **Technological Force Shields (Player Shield, Sentinel Hover Shield & Carrier Energy Egg)**: Engineered energy barriers use cool, structured, **geometric cyan/teal/violet (`#39DFCC` / `#70F5D5` / `#A888FF`) hex and segmented pixel barriers**. Their stepped-pixel silhouettes remain symmetrical and crystalline without smoke trails or thermal ember shedding, contrasting immediately against warm hostile shots and orange/yellow re-entry plasma fire.

### Boss armada: gargoyle warships (spaceship first, gargoyle second)

User feedback on the gargoyle war-ark: "far more gargoyle like, but now it doesn't look like a spaceship. The old ship looked fantastic but it was plain and flat; the new one is rich and full of texture, but doesn't look like a spaceship." The boss is therefore **unmistakably a spaceship first** and a demonic gargoyle warship second, keeping the clean graphic readability of the original flat carrier (strong outline, flat plate tones, lit window rows, clear functional openings) together with the gargoyle round's rich texture (AI-detailed plating, carved stone, leather sails). The contract is [sprite-atlas.md](sprite-atlas.md#boss-armada-atlases-boss-classpng).

- **Hull logic (spaceship):** seen in a 35° 3/4 view with the **bow toward the player** and the stern up the screen. An armoured hammerhead ram-bow (dark vertical skirt, mid-tone sloped glacis, lit chamfered deck with armour plates, a ridged keel roof and gun rails), a narrower waist, and a broad **engine block** at the stern carrying the main engines, with **outboard engine pods** on pylons for the bigger classes. Every engine has a banded nacelle or housing and a flared nozzle with a hot rim; **plumes rise from the nozzles** (front, rear and propulsion read at a glance). A gothic **bridge tower** stands on the waist (stacked tiers with lit amber and teal windows, a glass bridge band, a sensor mast). **Hangar bays** with hazard sills and lit headers flank the maw; **gun turrets** sit under the chin; point-defence turrets dot the engine block; portholes run along skirt, waist and block; **running lights** blink (port red, starboard green, white strobes, amber bow markers).
- **Ornament (gargoyle):** applied like a warship's figurehead. A horned **gargoyle figurehead** on the prow whose mouth is the core maw (fanged blast jaws), with glowing eyes, brows, jowls, swept horns and breathing ear-fins; **bat-wing solar sails** on finger bones with horn spines along the arm; gargoyle-head intakes on the pods; **carved stone spires and flying buttresses** on the tower; stern horns; ember **fissures** spreading over the plating. Turrets wear horned face plates.
- **Hull classes escalate per run:** run 1 Gargoyle Frigate (2 main engines, one sail pair, a small three-tier tower), run 2 Brood Cruiser (+2 pods, ram spikes, three spires, deck turrets), run 3 Siege Battlecruiser (3 main + 4 pods, five spires, bow spurs and tusks, the wreck breaks in two), run 4 Cathedral Battleship (4 main + 4 pods, two sail pairs, seven spires), run 5 Abyssal Dreadnought (5 main + 6 pods, nine spires, a second horn crown, its stern beyond the top of the screen). Each class is darker and more corrupted (ramps eased toward the night, more fissures); the four **forms still escalate within one fight** (violet-grey gunmetal with amber eyes and a chevron, bruised plum with magenta fissures and twin bars, ember-cracked crimson with lava fissures and fang slashes, obsidian with a gold crown and star), each with one rank pip on the sigil.
- **Visual-only scaling:** hitboxes, shield geometry, the maw, bays and turret pivots, HP, damage, fire patterns, scoring and timings are unchanged. The bright bow has the same footprint in every class and holds every functional part; the extra size is a **darker, lower-contrast superstructure** drawn before the creatures, partly behind the shield arc and beyond the screen edges, so shots passing beside the solid body fly over background hull. Functional parts stay the brightest and most saturated. The hull never reaches the player's or the creatures' band and stays inside the full shield egg below its waist.
- **Idle life and response:** eyes pulse and flare, ear-fins breathe, spines flex and fissures flicker (2 fps); engine plumes flicker and lengthen with thrust, vectoring harder on the side away from the motion; lateral bow thrusters puff as it slides; on arrival the bow retro-thrusters brake the descent.
- **Damage and destruction:** cracked plating, then torn plates over the glowing interior, then gaping breaches on the bow, with pixel smoke, sparks and flames; burning breaches open on the superstructure. No gore. The petrified, charred wreck rolls as it falls; bigger classes fall harder: more chain explosions racing along the engines and tower, more tumbling debris, and from the battlecruiser up the keel snaps and the two halves drift apart.
- **Arrival ("Coming-In") Choreography:** the warship descends from orbital shadow on its bow retro-thrusters with gravitational dust ripples and shockwave rings across the sector sky, cycling jaws and bays, before its force shield locks online at cruise altitude (`y = 205`).

### Stylized Starfighter Cockpit Control Panel, Steering Yoke, Interim Gun Angles & Device Tilt

The bottom controller region is styled as an interactive **Starfighter Cockpit Control Panel** that unifies tactile flight control with real-time weapon and shield diagnostics while keeping the player's fingers completely below the combat arena:
- **Coupled Ship Steering & Turret Gun Vectoring (`±6°, ±12°, ±18°, ±24°`)**:
  - Steering the ship or rotating the cockpit yoke couples horizontal ship thrust with **stepped interim turret gun vectoring angles (`±6°, ±12°, ±18°, ±24°`)**. As the pilot banks or angles the yoke, the starfighter's nose cannons and cockpit gimbal indicator step cleanly through discrete pixel-art firing vectors, allowing angled volleys to rake across demon formations and thread open carrier hatches without requiring full-speed lateral sprinting alone.
- **Interactive Cockpit Dashboard & Telemetry Schematic**:
  - The left/flanking instrumentation houses the **Starfighter Weapon/Shield Telemetry Schematic**—a crisp pixel wireframe of the defender displaying layered active weapon modules (`SPREAD` cyan wing cannons, `LARGE` amber ordnance pods, `RAPID` gold capacitor core, `POWERFUL` coral heavy barrel, and `SHIELD` violet hex envelope) alongside 9-second countdown bars and the 4-quarter heart-container diagnostic.
  - The central/right control bay houses the **Rotating Steering Yoke & Gun Angle Gimbal**, showing a tactile pixel flight yoke that rotates smoothly with touch drag or device tilt, highlighted angle ticks at `0°, ±6°, ±12°, ±18°, ±24°`, and an active tilt/touch status indicator.
- **Multi-Touch Drag & Calibrated 3D Device Tilt**:
  - Supports seamless handoff between direct touch dragging on the yoke/trackpad and **calibrated 3D device tilt (`screenRoll`)**, using circular-mean neutral posture calibration and jump-free touch-release rebasing so holding or releasing the panel never snaps the ship or gun angle.

### Last-Life-Lost Defeat Celebration & Skyward Camera Pan to High Scores

Losing the final life replaces an abrupt modal screen cut with a staged arcade defeat sequence:
- **Player Ship Destruction & Enemy Victory Formation**: The defender detonates in a multi-stage pixel-frame hull breakup and expanding shock ring. Rather than freezing or vanishing, surviving ordinary demons, Sentinels, or the Brood Dreadnought transition into a **post-mortem enemy victory celebration**—flocks loop into triumphant synchronized figure-8 / chevron victory parades with rapid wing-flaps and celebratory flashes, Sentinels flare their wings in a dominant hover salute, and the Carrier flexes its talons and chimney fire in an uncontested orbital patrol.
- **Skyward Camera Pan to High Scores**: After the defeat beat registers, the viewport executes a smooth **skyward camera pan** upward past the victorious demon swarm into the upper starfield canopy, where the **High Scores (Top 10) & 3-Wheel Initials Entry** console settles into view without a harsh black-screen cut.

### 3-Beat Opening Cockpit Panel Zoom-Out & Pictorial Storyboard Transitions

Starting a new game or transitioning between campaign milestones uses continuous motivated camera motion and pictorial storytelling:
- **3-Beat Opening Cockpit Panel Zoom-Out**:
  1. **Beat 1 — Tight Cockpit Ignition**: Camera begins framed tightly on the **Starfighter Cockpit Control Panel** as telemetry schematics boot up, the weapon/shield diagnostic illuminates, and the steering yoke calibrates to center (`0°`).
  2. **Beat 2 — Continuous Camera Pullback & Thruster Launch**: The camera zooms out continuously from the cockpit dashboard into the live `360 × 520` arena viewport (with zero fade-to-black cut) as the starfighter's twin thrusters ignite and push the ship onto its combat rail (`y = 477`).
  3. **Beat 3 — Horizon Reveal & Squadron Entry**: The planetary horizon settles into parallax motion, the 4.5-second illustrated arrival card clears, and the opening demon squadron sweeps in along its quintic smootherstep trajectory.
- **Pictorial Storyboard Interludes**: Sector victories, carrier discoveries, and route transitions pair concise narrative captions with framed **pictorial pixel-art storyboard panels** (fleet launch bays, orbital blockade maps, foundry trenches, and carrier wreck salvage) so campaign progression reads visually at a glance on both narrow phones and wide desktops. The ship in every cutscene and storyboard panel, including the route-chart marker, is the real layered ship with the pilot's current modules and shield, never a bare hull.

Carrier eyes gain a pixel rage expression as damage builds, and damaged movement becomes faster; each encounter can start in a different direction and motion phase. Keep smoke detailed with stepped transparent/dithered edges. Explosions use reduced opacity so shots and silhouettes remain visible through bursts; retain crisp pixels rather than blur or glow.

Powers occupy two offensive groups plus an independent shield: RAPID or POWERFUL, and SPREAD or LARGE. Collecting one member replaces only its alternative. POWERFUL uses a red chunky central cannon/double-shell glyph and distinctive double-damage shot at normal cadence. LARGE uses amber broad explosive shell/barrel heads at the sides and a small readable pixel blast on impact. SPREAD retains cyan twin side cannons, RAPID a gold central bolt, and SHIELD the violet outer enclosure. Every legal three-layer combination must keep all colors and silhouettes visible, with separate nine-second countdowns and uninterrupted touch piloting. Powerful + Large + Shield is valid; Rapid + Powerful and Spread + Large are not. Large splash never bypasses an active carrier shield or a closed door.

## Ground war presentation

Ground units, allies, wrecks and tracers stand on the flyover ground with its own camera (texel scale × 1.25), depth-sorted and drawn nearest-neighbour from `ground-forces.png` (contract: `lib/game/ground_atlas.dart`; pipeline: asset-pipeline.md, "Ground forces"). Brightness rises from 38% at the horizon to full at the fire line, so units are subdued far away and threatening up close. Demon units have mid-value dark hulls with saturated warm lights, eyes and launcher glow. Allies (v3) are a convoy seen from behind and above in the near band: rovers, APCs, half-tracks, tanks, howitzers, walkers and infantry squads, two variants per sector, with grey-blue hulls, sector camouflage (snow, patch plates, teal bands), cyan/teal stripes, lamps and an IFF chevron; turrets traverse toward their foe, kick back on each shot with a cyan muzzle flash, and tracks throw dust toward the camera. A blinking cyan distress cross shows while under attack. Ground effects are multi-frame and scaled by depth: a destroyed unit throws a perspective shock ring, a ten-frame fireball and ballistic debris, leaves a scorch decal on the ground and burns (flame-tongue loop, rising smoke column) for a few seconds; tracers have a muzzle flash at the shooter and impact sparks at the target (cyan friendly, warm demon). Flames and flashes fog only half as much as hulls. Decorative creatures stay small, muted and unlit, with no launcher. Allies never show death imagery: a totalled ally sparks, smokes and limps off, or its crew ejects in a pod. Telegraphs combine authored frames (launcher raised, then glow) with a warm stepped bracket on the ground that blinks faster near launch. The ground missile is one high-detail nose-on cell scaled nearest-neighbour from 8 to 36 units, with an analytic smoke trail along its fixed path and a blinking warm marker at the ship plane. Homing missiles (ship-weapons row 7) carry a cyan exhaust trail; a mint reticle locks on the current target; loaded missiles hang on the wing pylons, and so also appear in the transition loadout glyph.

## Illustrated arrival guidance

Before each sector's first wave, replace repeated arrival-story prose with one contextual five-to-nine-word action sentence and a matching original pixel illustration. Travel and rewards retain the destination narrative. Detailed original pixel paintings can illustrate these tactics separately from low-resolution combat sprites; preserve hard edges and reuse exact heart-quarter and weapon glyphs. Keep destination identification concise, words as real UI text, and an equivalent semantic description for meaningful visual information.

The user's chosen presentation is automatic loading/arrival-only hints: keep the complete card visible for 4.5 seconds and then continue into play, with no dedicated hint hold/advance buttons, Field Guide, hint menu or advance preference. No typewriter text or delayed image reveal consumes reading time. Contextual shuffled selection avoids repetitive or irrelevant advice (including the `sling_shot` hint illustrating banked diagonal shots curving into an open carrier hatch). [hint-usability.md](hint-usability.md) and [research-source-ledger.md](research-source-ledger.md) record the primary-source research and distinguish its timing-control recommendations from this explicit product choice. Shield illustrations show hit → grace → fresh pickup; timer expiry alone never grants protection.

Carrier force fields retain their full span outside the hull at every energy level. Use a symmetric stepped-pixel lower egg, contracting its depth toward the ship as depleted rather than narrowing its width. Projectile hit flashes must follow the same model surface. The carrier-field hint teaches removing this protection before attacking the exposed hatch.

Reinforcements and sentinel escorts reuse the parent wave’s species and health profile. Do not visually upgrade every arriving creature into an elite: the entire wave shares a small elite birth budget. Sub-wave size may increase by one body, while evolution changes only through the bounded campaign curve documented in difficulty-calibration.md.

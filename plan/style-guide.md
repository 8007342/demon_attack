# Demon Attack — visual and musical style guide

## Direction and implemented asset contract

Original pixel artwork honors early-console clarity with animated winged demons, cosmic scenery, and expressive damage states. Ordinary enemies are living creatures: horns, membrane wings, teeth, eyes, and tails. The carrier alone combines a broad flying hull with demonic features and a mechanical sliding hatch. Preserve hard pixel edges and nearest-neighbor filtering. Keep threats readable against darker scenery; do not bake interface text into images.

## Durable pixel-art and animation rules

These requirements apply to every new combat creature, attack warning and damage effect. The visual reference is the simple, expressive low-resolution silhouettes and stepped poses of 1982-era Demon Attack. All shipping drawings must be original; never copy, trace or extract the original game's sprites or screenshots.

- Author silhouettes on a fixed low-resolution logical pixel grid, with an explicit bounded palette shared with the combat atlas. Enlarge with nearest-neighbor sampling and preserve square pixels. Judge both native logical size and actual phone size.
- Use distinct authored pixel frames for creature wing poses, armor damage, fire, smoke, sparks and destruction. Programmatic generation is welcome when it rasterizes onto that logical grid. Smooth antialiased runtime vector creatures, gradient fire and continuously bent/deformed wings or flames are outside the style.
- A large creature gains scale and a distinct silhouette while retaining the same coarse pixel language. The sentinel has a broad horizontal body and visibly separated wing segments. Its eight-pose wing stroke articulates roots, outer segments and tips while preserving a broad span. Its slow stepped flap conveys mass: hold each pose noticeably longer than ordinary demons' 0.10–0.14-second wing frames, with a whole flap taking several seconds.
- Telegraph the sentinel's dive with original pixel warning frames on its own eyes or wings. Do not use an arrow. Keep the warning visible against all backgrounds, including with reduced decorative motion.
- Carrier damage uses increasingly numerous/intense pixel-frame smoke, sparks and flames anchored to the damaged hull. Avoid smooth curves, gradient blobs and vector flame tongues. Pixel outlines must remain recognizable during the falling-wreck scene.

Sentinels belong after at least one boss victory in the current campaign. An eligible wave first brings in a small ordinary swarm; the sentinel then descends slowly from offscreen into a position above every ordinary enemy. Hold that high hover with very slow wing poses before the warning and fast heavy dive. The entrance, hover and dive must read as distinct phases even on a narrow phone.

A rare last stand is reserved for a minority of sentinels selected once and reduced to at most 25% health. Give it a subtle but distinct original pixel pose on the creature itself plus a small recognizable preparatory movement throughout a 0.9-second tell; it must differ from the normal dive warning by shape and motion, not only color. Sample the player's position when the tell begins, then rush at 600 arena units/second in Normal (540 Easy, 630 Hard) along a fixed straight path so moving after the tell can dodge. This attack is irreversible: impact or arena exit ends in pixel-frame self-destruction, with no return to formation or player-reward celebration. The sentinel remains shootable during both tell and rush; destruction by player fire keeps its normal rewards. Easy preserves its 10% hostile-rate reduction: a 1-second tell and 540-unit/second rush. Hard’s 5% hostile-rate increase gives an approximately 0.857-second tell. Dedicated raised-wing charge and narrow folded-wing rush frames live in rows 6/7 of the supplemental atlas. Preserve these fairness cues when changing frames, timing or reduced-motion behavior.

The authoritative production atlas layout is [sprite-atlas.md](sprite-atlas.md). Combat creatures are authored on a **64 × 64 logical grid** (raised from 32 × 32 for 16-bit-level detail), stored 1× in `assets/images/combat.png` (1024 × 2048, sixteen columns) and drawn at the same 40/44-unit size as before, so the footprint and hitboxes are unchanged. The ship and its weapons (`ship-weapons.png`), the sentinels and effects (`sentinel-effects.png`, 128 × 64 logical cells) and the carrier (`boss-carrier.png`, native 368 × 240 per cell) follow the same rules. Do not substitute a differently sized concept sheet into the renderer.

| Combat rows | Content |
| --- | --- |
| 0–27 | Seven rows per species (teal, violet, coral, gold): eight-pose wing stroke + angry stroke; three molts each with hit-flash strokes; anticipation, dive and weapon-fire poses; hit flash + eight-frame death; elite plates and armour overlays |
| 28 | Explosions and powered splash |
| 29 | Sparks, impact flash, creature muzzle flash |
| 30 | Pickup badges |
| 31 | Fallback ship and carrier |

The shield, sliding doors and core vulnerability remain tied to simulation state, now drawn with authored door, hatch and wreck frames; the campaign communicates boss damage through shield coverage and pixel hull effects instead of health bars. Creatures have normal, three intermediate damaged and angry appearances; each nonlethal hit updates the lookup.

Combat palette: one bounded palette (`tools/sprite_kit.py`, listed in sprite-atlas.md) shared by every sheet. Midnight outline #100E2C; teal #39DFCC; violet #A888FF; coral #FF786C; gold #EFBD57; ivory highlights and red angry eyes, each species with a four-step ramp. Space uses near-black blue and purple. Friendly shots are cyan/mint/gold; hostile shots use warm red/orange. Shapes and motion reinforce color. Render all new art at native scale before judging enlarged previews. Procedural production sprites and generated illustration/concept assets have distinct roles: AI renders enter the atlases only through the pipeline in [asset-pipeline.md](asset-pipeline.md#sprites), which finishes them onto the grid and palette as shading detail and never replaces authored silhouettes.

## 64-grid detail and animation

The extra resolution goes into motion and readable equipment, capped where it would hurt readability at phone size:

- **Wings flap through a full articulated stroke.** Ordinary demons have eight distinct poses per 0.5-second stroke (raised, early down, level, driving, bottom, folded recovery, rising with trailing fingers, unfolding), and sentinels eight slow poses held 0.4 s each. Humerus, forearm and each finger or feather articulate separately; recovery visibly folds the span. Two-pose toggles and rigid up/down translation are out of style.
- **Armour, weapons, shields and rank are visible.** Every species wears armour (chest plates, pauldrons, crown) and a rank insignia (teal chevron, violet twin bars, coral fang slashes, gold star jewel). Each has a visible weapon mount that animates when it fires: teal throat emitter, violet pauldron barbs, coral tail stinger, gold claw orbs. Elites add gold-trimmed wing-root plates that move with the stroke, a gold double-chevron brow mark, helm, crest and gorget plates that shed one level per hit. Sentinels wear shaped metal armour layers and chest insignia (violet crescent, gold sunburst) and discharge from the beak. The carrier carries a brood sigil and one rank pip per form.
- **Anticipation before attacks.** Before a dive the creature cocks its wings high, hunches and flares its eyes (four frames); weapon fire plays charge, flash, recoil and settle on the creature while a muzzle flash marks the actual shot spawn.
- **Hits and deaths are authored.** Hit flashes are highlighted frames (ramps stepped toward white, outline kept); deaths are an eight-frame species sequence (flash, glowing seams, wings shearing off, core burst, shreds and smoke) instead of a generic burst.
- **Readability caps.** Keep a 1 px ink outline and top-left rim light on every frame; no feature thinner than one logical pixel against the outline; insignia at most about 7 × 6 px; detail textures never cover eyes, insignia or plates; membranes and wings stay the dominant silhouette. Judge every change on a phone-sized screenshot as well as enlarged.
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

### Backgrounds: oblique flyover parallax

Every sector is an endless oblique 3/4 flyover down a canyon: the ship flies forward and the ground streams toward the player. Layers, back to front, with speeds relative to the ground:

| Layer | Speed | Content | Luminance cap |
| --- | --- | --- | --- |
| Far | ~0.02× (slow eased sway) | The sector's painted sky (`sector-N.png`): planets, moons, nebulae; sparse stars; its painted horizon is veiled | painting under a 54% veil |
| Mid | 0.2× | Ridge/mountain banks along both edges | 0.13 (chroma ≤ 0.22) |
| Near | 0.6× | Terrain banks plus route landmarks | 0.18, chroma ≤ 0.25 (landmarks 0.40) |
| Ground | 1.0× | Closest banks, small props, creatures, the ship's shadow | 0.23, chroma ≤ 0.27 (props 0.34, creatures 0.36, chroma ≤ 0.28, dark outline) |

- Layers are composable for any session length: seamless vertically tiling strips (three variants per layer per sector, never the same variant twice in a row, mirrored for the right bank) and a library of landmark/prop sprites placed by seeded, stateless scattering per fixed segment. The same distance draws the same picture on every device.
- The central lane stays dark and clear: banks occupy the outer edges, a horizontal lane veil darkens the middle, and background luminance stays below threats, projectiles and cores.
- Route identity lives in the near-layer landmarks (two per named route, see the table in [sector-style-guide.md](sector-style-guide.md)); sector identity in the painted sky, the palette median-cut from it and each sector's materials.
- Creatures: two original pixel species per sector, darker and more demonic deeper into the campaign (frost hoppers and shell crawlers on Krybor; rock mites and dust grazers in Ringfall; cinder newts and ash borers on Ember; spore crawlers and bone skitters in the Hollow; brood larvae and hive ticks on the Carrier). They walk or crawl with discrete four-frame gaits on the ground banks, scatter from explosions and the falling carrier wreck, burrow (burrowing species) and duck as the ship's shadow passes. Reactions are visual only and read explosion, wreck and ship state.
- Travel accelerates the flight (up to 10× at mid-travel) while the destination world crossfades in, so its landmarks show before arrival. Cinematic blackout and letterbox bars still cover the scenery.
- Reduced motion (`disableAnimations`/`reduceMotion`) freezes flight, star and particle drift and creature walking; scenery and warning cues stay visible.
- All layers draw with `FilterQuality.none` at 2 arena units per logical pixel, batched with `Canvas.drawAtlas` (about six calls per sector).

The generator, prompts and seeds are in [asset-pipeline.md](asset-pipeline.md).

Title centers an original horned demon emblem and the Demon Attack wordmark, with Start, Top 10, sound, and short controls guidance. The game HUD displays score, level/cycle, lives, and current power; carrier shield coverage and hull damage communicate boss condition during its encounter. Touch controls occupy a recessed futuristic laptop-style trackpad beneath the arena, with cyan corner lights, pixel circuit traces, and a visible drag indicator. Keep fingers away from combat. Real interface text remains legible and accessible; no fake labels baked into generated art.

Top 10 uses aligned rank, three-character initials, and score columns. Initial entry offers three rotating wheels with A–Z and 0–9, clear upper/lower controls, a highlighted middle selection, and Submit. Avoid a freeform text field. Game-over and victory keep a darkened arena behind their overlays. Review phone portrait, narrow desktop, and wide desktop without horizontal overflow.

## Current music score and playback

Musical direction: original music only, never imitating an existing game's soundtrack. Retro sci-fi arcade (analog bass, square leads, drum machines) fused with dark synth and orchestral tension. The campaign darkens sector by sector as the demonic swarm consumes the human frontier, and the carrier's four forms escalate. Every cue shares **120 BPM** and a four-beat bar, so transitions land on the next bar line. Tension grows through density, timbre and register, never tempo.

The shipping score is recorded: one ACE-Step 1.5 loop per cue in `web/audio/music/`, made and selected by `tools/music_pipeline.py` from `art/workflows/music/cues.json`. The pipeline and its checks are described in [audio-backend.md](audio-backend.md#recorded-cues-primary). Opus/OGG is the primary format, with AAC/M4A as the fallback. Files load lazily per cue.

| Cue | Sector / role | Direction (prompt essence) | Key | Kind | Length | Seed | Opus | AAC |
| --- | --- | --- | --- | --- | --- | ---: | ---: | ---: |
| `menu` | Title | dark ambient sci-fi pads, distant glassy arpeggio, sub pulse; calm, mysterious | E minor | loop | 32 beats / 16 s | 1101 | 183 KB | 257 KB |
| `level-1` | Krybor frontier | synthwave: pulsing analog bass, bright square lead, 80s drum machine; heroic but tense | A minor | loop | 32 / 16 s | 1201 | 173 KB | 265 KB |
| `level-2` | Ringfall | cold FM bells, fast sequenced arpeggios, tight drums, low strings; orbital pursuit | D minor | loop | 32 / 16 s | 1302 | 185 KB | 257 KB |
| `level-3` | Ember Moon | dark industrial: distorted bass, anvil percussion, low brass stabs; furnace heat | C minor | loop | 32 / 16 s | 1402 | 168 KB | 258 KB |
| `level-4` | The Hollow | dark synth horror: choir pads, gothic organ, war drums, dissonant strings; demonic dread | F minor | loop | 32 / 16 s | 1502 | 171 KB | 257 KB |
| `boss-1-0` / `-1` | Carrier form 1 | dark orchestral synth battle: low brass, taiko, synth bass (later cycle: + string ostinato, rapid hats) | D minor | loop | 32 / 16 s | 2102 / 2113 | 167 / 170 KB | 259 / 259 KB |
| `boss-2-0` / `-1` | Carrier form 2 | staccato string ostinato, aggressive bass, snare rolls, brass hits (+ double-time drums, arpeggio layer) | E♭ minor | loop | 32 / 16 s | 2202 / 2212 | 162 / 154 KB | 258 / 258 KB |
| `boss-3-0` / `-1` | Carrier form 3 | demonic industrial orchestra: distorted bass, dark choir, chromatic brass (+ double kick, screaming lead) | E minor | loop | 32 / 16 s | 2303 / 2311 | 161 / 167 KB | 257 / 260 KB |
| `boss-4-0` / `-1` | Carrier form 4 | frantic final battle: massive choir, blast beats, string tremolo, organ (+ chromatic synth arpeggios) | F minor | loop | 32 / 16 s | 2405 / 2413 | 154 / 168 KB | 257 / 263 KB |
| `travel` | Between sectors | floating arpeggio, warm pads, soft pulse; hopeful, suspended | D major | loop | 16 / 8 s | 3101 | 90 KB | 130 KB |
| `levelclear` | Sector cleared | bright arcade success jingle | G major | tail | 8 beats, then last bar loops (4–6 s) | 3303 | 73 KB | 100 KB |
| `victory` | Carrier defeated | heroic synth + brass fanfare, timpani | C major | tail | 8 beats, then last bar loops (4–6 s) | 3201 | 66 KB | 99 KB |
| `gameover` | Defeat | somber descending synth, decaying pads, distant bell | E minor | oneshot | 8 beats + 0.6 s fade (4.6 s) | 3403 | 56 KB | 76 KB |
| **Total** | | | | | | | **2.41 MB** | **3.68 MB** |

Each loop is exactly 768 000 samples at 48 kHz (16 s; travel 8 s) and starts on a detected downbeat. Its seam is the original continuous waveform, and both codecs are primed with that context and trimmed by the container, so decoded files are sample-exact. `boss-4-0` is pinned (`"pick": 2405`) to the densest even candidate, because the automatic rank favoured a sparser one. Loudness is −18 LUFS integrated with peaks ≤ −1 dBFS. Only one cue is fetched at a time: about 170 KB for a sector.

### MIDI fallback score

`web/audio/generate-midi.py` composes original Standard MIDI Format 0 files in `web/audio/midi/`. When every recorded format of a cue fails to load or decode, `web/audio/demon-audio.js` plays that cue's MIDI note events through its local Web Audio synthesizer on the same grid.

| Cue | MIDI fallback |
| --- | --- |
| Menu | Sparse sine-pad motif; 32 beats |
| Levels 1–4 | Distinct 32-beat scores with increasing melodic subdivisions; percussion from LV2 |
| Boss phases 1–4 | Four increasingly dense 32-beat scores; each has a denser later-cycle version |
| Victory | Eight-beat major fanfare; final cadence continues until travel |
| Level clear | Immediate eight-beat major flourish with a 90 ms music fade |
| Travel | Sixteen-beat suspended arpeggio bridge on the common musical grid |
| Game over | Eight-beat descending cue and dark chord, non-looping |

The carrier has up to four visual forms, each with its own increasing intensity in both scores. The MIDI voices use square lead, sawtooth bass, sine pad, and triangle percussion.

### Playback rules

A shared audio-clock scheduler runs with lookahead and asynchronous cue loading, and a request counter rejects stale loads. Track changes queue to the next bar. The outgoing recorded cue releases over 120 ms across the bar line while the new one starts sample-exactly on it. Level-clear rewards respond immediately, with a 90 ms music-only crossfade. Tail cues hold their final bar until the next cue, so a long cutscene is never silent. Game over ends cleanly. Firing, hits, explosions, power collection, life loss and the wave/extra-life stingers stay short synth effects with unchanged trigger timing. Voice limiting steals the oldest voice per effect (shot 4, hit 4, explosion 5) and caps the total at 14. Explosions and life loss add a short filtered noise layer.

Visiting the page remains silent until a user gesture unlocks browser audio. Start and sound controls should support that gesture deliberately. Muting ramps the master gain. Pause suspends the audio context. Resume keeps the bar grid's phase, skipping only whole beats that fell behind, so it stays locked to the playing loop. The bridge also pauses on visibility changes. Confirm that this stays aligned with the application's deliberate pause/resume controls.

Future refinements: stem crossfades, per-mode tempo ramps, music/effects balance controls, and sound preference persistence. These are intended improvements, not claims about the current player.

## Review gates

At native scale every demon species, angry state, player, and pickup must be recognizable, with no screenshot or original-game sprite reused. Inspect extracted alpha edges and atlas frames; generated concept sheets require review before becoming production assets. Review the sentinel and carrier fire together with ordinary demons: all must share hard pixel edges, bounded palettes and discrete frames. Inspect a full sentinel entrance/hover/warning/dive sequence and reject immediate dives, fast flapping, smooth bird silhouettes and arrow warnings. Enemy bullets must remain visible on every background. Musical loops should have no silent boundary, old voices should release cleanly, state changes must not restore stale cues, and first visit must stay silent until interaction. Browser checks should cover music through a complete boss transformation, victory, next cycle, pause, resume, and muted play.

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

### Brood Dreadnought Carrier Boss Specification & Style Guide

The Brood Dreadnought replaces flat, oversized single-cell boss scaling with a dedicated **high-resolution multi-part sprite hierarchy (`184 × 120` arena units, rasterised at its native `368 × 240` per cell)** rendered with crisp nearest-neighbor fidelity (`FilterQuality.none`):
- **4 Evolution Carapace Forms**:
  1. **Carrier (Route 0)**: Heavy biomechanical armored saucer-hull with ribbed chitin plates, twin dorsal stabilizers, and recessed amber belly conduits.
  2. **Brood Ark (Route 1)**: Swept forward prow horns, reinforced dorsal spine ridges, and wider brood-incubation blisters pulsing along the flanks.
  3. **Siege Carrier (Route 2)**: Broadened heavy siege shoulders, armored mandible-locks, and glowing foundry vents along the hull seams.
  4. **Brood Flagship / Citadel (Routes 3–4)**: Crowned sovereign dreadnought silhouette with multi-tiered dorsal cathedral crests, sovereign gold/crimson trim, and exposed high-energy plasma conduits.
- **Articulated Sub-Components & Overlays**:
  - **Articulated Siege Mandibles**: Fore-mounted biomechanical pincers that flex outward during minion launches and clench inward when firing downward projectile fans.
  - **Dorsal Retro-Thrusters**: Four stepped-pixel upper exhaust nozzles that flare bright gold/white during orbital braking and lateral direction reversals.
  - **Tracking Ventral Dual-Turrets**: Pair of under-slung pixel gun blisters flanking the central bay that visually pivot toward the player's horizontal lane before volley release.
  - **3 Mechanical Launch Bay Shutters**: Stepped sliding blast doors covering the **center core aperture** (`|dx| < 24`) and the **Left and Right auxiliary side hatches** (`dx ≈ ±52`, width `±18`). During non-final forms (`phase < formCount - 1`), all three shutters articulate with amber/coral inner core glow; on the final form (`phase == formCount - 1`), heavy dark armored plates bolt the side shutters shut so the player's eye locks onto the central core aperture.
  - **Progressive Fracture Overlays**: As core HP drops across phases, stepped pixel armor cracks, glowing magma fissures, electrical arcs, and anchored multi-frame smoke/spark plumes overlay the damaged hull quarters without obscuring incoming projectiles.
- **Arrival ("Coming-In") Choreography**:
  - The dreadnought descends from high orbital shadow under a roaring **orbital retro-burn deceleration** with full dorsal thruster flare, casting **gravitational dust ripples** and shockwave rings across the sector sky, followed by mechanical **mandible deployment**, launch-shutter cycling, and pulsing red/amber **klaxon telemetry** before its force shield locks online at cruise altitude (`y = 205`).
- **Destruction ("Going-Down") Choreography**:
  - Defeating the core triggers a **sequential multi-part chain-reaction meltdown**: explosions detonate first across the outer **wing pylons**, propagate inward to rupture the **auxiliary side bays**, and culminate in a catastrophic **central brood core** breach. The crippled hull rolls into a **listing hull descent** (`±0.18 rad` roll tilt), shedding pixel hull plates, burning slag, and dense stepped smoke columns as it falls toward the planetary horizon.

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
- **Player Ship Destruction & Enemy Victory Formation**: The defender detonates in a multi-stage pixel-frame hull breakup and expanding shock ring. Rather than freezing or vanishing, surviving ordinary demons, Sentinels, or the Brood Dreadnought transition into a **post-mortem enemy victory celebration**—flocks loop into triumphant synchronized figure-8 / chevron victory parades with rapid wing-flaps and celebratory flashes, Sentinels flare their wings in a dominant hover salute, and the Carrier cycles its mandibles and thrusters in an uncontested orbital patrol.
- **Skyward Camera Pan to High Scores**: After the defeat beat registers, the viewport executes a smooth **skyward camera pan** upward past the victorious demon swarm into the upper starfield canopy, where the **High Scores (Top 10) & 3-Wheel Initials Entry** console settles into view without a harsh black-screen cut.

### 3-Beat Opening Cockpit Panel Zoom-Out & Pictorial Storyboard Transitions

Starting a new game or transitioning between campaign milestones uses continuous motivated camera motion and pictorial storytelling:
- **3-Beat Opening Cockpit Panel Zoom-Out**:
  1. **Beat 1 — Tight Cockpit Ignition**: Camera begins framed tightly on the **Starfighter Cockpit Control Panel** as telemetry schematics boot up, the weapon/shield diagnostic illuminates, and the steering yoke calibrates to center (`0°`).
  2. **Beat 2 — Continuous Camera Pullback & Thruster Launch**: The camera zooms out continuously from the cockpit dashboard into the live `360 × 520` arena viewport (with zero fade-to-black cut) as the starfighter's twin thrusters ignite and push the ship onto its combat rail (`y = 477`).
  3. **Beat 3 — Horizon Reveal & Squadron Entry**: The planetary horizon settles into parallax motion, the 4.5-second illustrated arrival card clears, and the opening demon squadron sweeps in along its quintic smootherstep trajectory.
- **Pictorial Storyboard Interludes**: Sector victories, carrier discoveries, and route transitions pair concise narrative captions with framed **pictorial pixel-art storyboard panels** (fleet launch bays, orbital blockade maps, foundry trenches, and carrier wreck salvage) so campaign progression reads visually at a glance on both narrow phones and wide desktops.

Carrier eyes gain a pixel rage expression as damage builds, and damaged movement becomes faster; each encounter can start in a different direction and motion phase. Keep smoke detailed with stepped transparent/dithered edges. Explosions use reduced opacity so shots and silhouettes remain visible through bursts; retain crisp pixels rather than blur or glow.

Powers occupy two offensive groups plus an independent shield: RAPID or POWERFUL, and SPREAD or LARGE. Collecting one member replaces only its alternative. POWERFUL uses a red chunky central cannon/double-shell glyph and distinctive double-damage shot at normal cadence. LARGE uses amber broad explosive shell/barrel heads at the sides and a small readable pixel blast on impact. SPREAD retains cyan twin side cannons, RAPID a gold central bolt, and SHIELD the violet outer enclosure. Every legal three-layer combination must keep all colors and silhouettes visible, with separate nine-second countdowns and uninterrupted touch piloting. Powerful + Large + Shield is valid; Rapid + Powerful and Spread + Large are not. Large splash never bypasses an active carrier shield or a closed door.

## Illustrated arrival guidance

Before each sector's first wave, replace repeated arrival-story prose with one contextual five-to-nine-word action sentence and a matching original pixel illustration. Travel and rewards retain the destination narrative. Detailed original pixel paintings can illustrate these tactics separately from low-resolution combat sprites; preserve hard edges and reuse exact heart-quarter and weapon glyphs. Keep destination identification concise, words as real UI text, and an equivalent semantic description for meaningful visual information.

The user's chosen presentation is automatic loading/arrival-only hints: keep the complete card visible for 4.5 seconds and then continue into play, with no dedicated hint hold/advance buttons, Field Guide, hint menu or advance preference. No typewriter text or delayed image reveal consumes reading time. Contextual shuffled selection avoids repetitive or irrelevant advice (including the `sling_shot` hint illustrating banked diagonal shots curving into an open carrier hatch). [hint-usability.md](hint-usability.md) and [research-source-ledger.md](research-source-ledger.md) record the primary-source research and distinguish its timing-control recommendations from this explicit product choice. Shield illustrations show hit → grace → fresh pickup; timer expiry alone never grants protection.

Carrier force fields retain their full span outside the hull at every energy level. Use a symmetric stepped-pixel lower egg, contracting its depth toward the ship as depleted rather than narrowing its width. Projectile hit flashes must follow the same model surface. The carrier-field hint teaches removing this protection before attacking the exposed hatch.

Reinforcements and sentinel escorts reuse the parent wave’s species and health profile. Do not visually upgrade every arriving creature into an elite: the entire wave shares a small elite birth budget. Sub-wave size may increase by one body, while evolution changes only through the bounded campaign curve documented in difficulty-calibration.md.

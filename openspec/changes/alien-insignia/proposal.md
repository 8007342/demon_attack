# Proposal: alien rank insignia and shield readouts (R6)

## Why
From the operator's second playtest on 2026-11-15 (`plan/operator-feedback-2026-11-15b.md` R6): "Fliers currently show
only dots or spikes for status and grade; the original low-res sprites had better indicators." The operator asked
for:
- a styleguide for alien troops;
- shields that read as shields;
- rank insignia, the alien equivalent of chevrons and stars, so higher ranks read at a glance;
- hero art to match.

**Archaeology** (`plan/round2-research.md` §3, `docs/styleguide/alien-troops.md` §1).

The original 32-grid fliers (8cf79246) signalled with the whole body:
- a flat species hue;
- a body hue shift per molt;
- an all-gold angry form;
- code-drawn pips and elite plates.

Today's 64-grid gargoyles are drawn at the same 40 units, so each art pixel is half as large on screen:
- the species rank marks are 3–4 CSS px blobs in textured hide;
- the elite overlay adds a few gold pixels (the "spikes");
- health pips were removed by ux-declutter;
- the only readable signal left is the elite's dotted ring (the "dots").

## What Changes
- **The styleguide** `docs/styleguide/alien-troops.md`: principles, palette, the rank ladder, shield and status
  language, phone-scale acceptance rules, hero-art guidance, and do and don't.
- **Rank insignia as coarse-pixel overlays** (one glyph pixel = 2 art px, ink-outlined, bone on ink), drawn above the
  head at a per-cell head anchor, after the camera, at a fixed CSS size:

  | Rank | Who | Mark |
  |---|---|---|
  | R0 Drone | small creatures | none |
  | R1 Skirmisher | not-so-small creatures | one **talon** |
  | R2 Veteran | route-hardened skirmishers | two talons |
  | R3 Hunter | elites | **ocellus** (rayed eye, ember core) |
  | R4 Sentinel | sentinels | **crown** of tines over an ocellus |
  | Carrier forms | boss forms | the same ladder on the brood sigil |

  The ocellus replaces the elite's dotted ring.
- **Force shields read as shields:**
  - one cyan hex cell per point on an arc in front of the body;
  - spent cells stay as dark sockets;
  - a cyan silhouette rim while any cell is lit;
  - a hit breaks a cell into shards.

  This covers sentinel shields, the rush shield and the boss shield (shared with `boss-grandeur`). Thermal dive
  shields stay thermal but split into one bow segment per point.
- **Health and state:**
  - a whole-hide warm-up per molt (12 / 24 / 36 % toward ember), which restores the old whole-body read;
  - angry adds an ember rim and an angry-gold glyph;
  - a dive tell flashes the glyph and the rim white.
- **Mockups** (no GPU), committed in this change: `art/contact/alien-insignia-{ranks,shields,phone,glyphs}.png`. They
  are made by the new `tools/alien_insignia` (Go, standard library) on the real `combat.png` cells.
- **Hero art to match:**
  - `tools/generate_sprites.py` emits head anchors;
  - future renders keep a crest zone;
  - elite plates are re-drawn at coarse-pixel scale.

## Capabilities
### New Capabilities
(none)

### Modified Capabilities
- `arcade-presentation`: ADDED requirements for rank insignia, force-shield readouts, health and state readouts, and
  their phone-scale legibility.

## Impact
- **New:**
  - `docs/styleguide/alien-troops.md`;
  - `tools/alien_insignia/` (mockup sheets; later an `atlas` verb for the runtime glyph sheet);
  - `assets/images/insignia.png` (a tiny glyph atlas, < 4 KB);
  - `lib/game/insignia_painter.dart`.
- **Changed:**
  - `lib/game/scene.dart`: the dotted ring is removed and the overlay pass added after the camera transform;
  - `lib/game/sprite_atlas.dart`: `headAnchor`, `rankOf(Demon)`;
  - `tools/generate_sprites.py` and `plan/sprite-atlas.md`: head anchors;
  - the sentinel shield draw (cells and rim, replacing the wear frames as the readout);
  - the dive-shield arc (segments);
  - `plan/style-guide.md`: a pointer to the new guide.
- **Tests:**
  - `test/insignia_test.dart`: rank mapping from game data, glyph luma contrast ≥ 0.35 against each species hide, no
    overlap in a dense formation, fixed CSS size under zoom;
  - the existing scene and performance tests;
  - review strips `art/contact/alien-insignia-ingame-*.png`.
- **Gameplay:** unchanged. HP, shields, tiers and budgets are untouched.

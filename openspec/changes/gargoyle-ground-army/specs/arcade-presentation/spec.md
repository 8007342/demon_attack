# Undercroft Host presentation

## ADDED Requirements

### Requirement: One gargoyle ground army
Demon ground units SHALL share one design language, the Undercroft Host: carved stone bodies on cast-iron frames, each with at least one gargoyle face and one membrane element (a folded wing-mantlet, sail or banner).

#### Scenario: Three factions in one frame
- **WHEN** a phone-size frame shows the convoy, the flying swarm and Host units together
- **THEN** a reviewer can tell all three apart, and every Host unit shows a face and a membrane element at near range

### Requirement: Original, friendly-scary Host
Host units SHALL NOT copy or closely imitate any franchise's units, names or art. Generation prompts SHALL NOT name a franchise, studio or artist. Damage SHALL be cracked stone with glowing seams, and defeat a rubble heap. Blood, flesh, wounds and real-world religious symbols SHALL NOT appear.

#### Scenario: Prompt and frame audit
- **WHEN** the Host family JSON and contact sheet are reviewed
- **THEN** no prompt names a franchise, studio or artist, and no frame shows blood, a cross or scripture

### Requirement: Spout-rule weapons and telegraphs
Every Host weapon SHALL fire from a carved mouth fed by a visible channel. Before each shot the channel SHALL fill rear to front in stepped warm segments, the eyes SHALL flare, and the mouth SHALL bloom on the shot. Threat units SHALL keep their existing ground bracket telegraph as well.

#### Scenario: Carillon salvo
- **WHEN** a Carillon fires at its ally
- **THEN** its tilt and channel-fill frames play for about 0.6 s, and each bell blooms in turn as its shell leaves

### Requirement: Role silhouettes
Each Host role SHALL own one dominant silhouette cue that no other role uses, as listed in the style guide's silhouette grammar. Artillery SHALL end in open upward mouths and command in the tallest gilded point.

#### Scenario: Black-fill sort
- **WHEN** reviewers sort solid black fills of the Tier A units at mid-field scale (×0.62) with the labels hidden
- **THEN** every unit is sorted into its role

### Requirement: Walker leg gap
Walkers SHALL keep at least 3 texels of clear ground between their legs in every stride frame.

#### Scenario: Stride frames
- **WHEN** every move frame of the Buttress Strider and Chapterhouse rows is scanned
- **THEN** each has a transparent gap at least 3 texels wide between the legs above the ground row

### Requirement: Rank by height and gilt
Host castes (Rubble, Ashlar, Tracery, Spire) SHALL be shown by the height of the vertical ornament together with the `demon_gilt` ramp, never by colour alone. Gilt SHALL stay at luma 0.46 or below, SHALL NOT animate or blink, and SHALL cover at most 6% of a Spire unit's pixels and 2% of a Tracery unit's. `demon_warm` SHALL remain the only blinking accent on Host units.

#### Scenario: Gilt stillness
- **WHEN** the move frames of a Host row are compared
- **THEN** gilt pixels never change colour between frames, and no gilt pixel exceeds luma 0.46

### Requirement: Host palette
Host hulls SHALL use the sector stone ramps at the `demon_ramp` lumas (0.06–0.40), with chroma ≤ 0.36 and rim ≤ 0.56. Ally cyan, teal, mint and grey-blue SHALL NOT be a dominant Host hull tone. The Hollow stone SHALL keep its hue at 155° or below.

#### Scenario: No ally colours on Host rows
- **WHEN** the Host atlas rows are scanned
- **THEN** no pixel matches the `ally_cyan` reserved set, and Host pixels in the teal hue band stay at chroma ≤ 0.20

### Requirement: Corruption gradient
Host units SHALL look more cathedral-like and more demonic deeper into the campaign:

| Sector | Look |
| --- | --- |
| Krybor | Captured and defaced human hulls |
| Ringfall | Salvage mortared with stone |
| Ember | Kiln-forged basalt |
| Hollow | Full cathedral masonry |
| Carrier | Obsidian with the most gilt |

#### Scenario: Same unit, two sectors
- **WHEN** a Crocket in Krybor is compared with one in Ember
- **THEN** the Krybor one shows a captured hull with stone ornament, and the Ember one is all basalt stone

### Requirement: Host animation states
Host units SHALL have authored grid frames for move, telegraph, fire, hit, damage and wreck. Their special actions SHALL also have authored frames: the Reliquary unloads, the Knell-bearers ring, the Hodcrawler mends, and the Chapterhouse pulses and falls. Idle loops SHALL run at 2–3 fps, never at telegraph speed. With reduced motion, idle loops SHALL freeze while telegraphs, blooms and ripples still show.

#### Scenario: Reduced motion
- **WHEN** reduced motion is on and a Chapterhouse is on the ground
- **THEN** its banners and eye pulse hold still, and a Carillon's channel fill and bloom still appear as hard cuts

### Requirement: Undercroft Host radio events
The model SHALL queue `reliquaryUnloading`, `artilleryRanging`, `walkerSighted`, `hostCommandSighted` and `hostCommandFallen`. Each SHALL carry `sector`, `x` and `y`. The minimum gaps are 8, 10 and 12 s for the first three, and once per visit for the command events. These events SHALL NOT raise music tiers.

#### Scenario: Events in the Hollow
- **WHEN** sector 4 on route 1 is flown for 100 s
- **THEN** `walkerSighted` and `hostCommandSighted` fire, `walkerSighted` at most once per 12 s, and the music tier is unchanged by them

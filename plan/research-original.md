# Original Demon Attack research

Researched 2026-10-20. The remake combines the Atari 2600 game's demon waves with the expanded boss structure familiar from Intellivision and some computer conversions. Demon Attack was an **Imagic** release for Atari hardware, rather than an Atari-published game.

## Original behavior and platform differences

- The [original Imagic Atari 2600 instructions, archived by AtariAge](https://static.atariage.com/manual_html_page.php?SoftwareLabelID=133) place the player on Krybor. The cannon moves horizontally and has unlimited ammunition. Later waves introduce splitting and diving demons; the scoring table values these more highly. The manual describes three reserve bunkers, opportunities to gain more, and optional aggressive difficulty and guided tracer shots. These original reserve rules should not override the requested remake's explicit three lives and one-hit deaths.
- The Atari 2600 instructions describe wave survival rather than a mothership encounter. The [platform screenshot collection](https://www.mobygames.com/game/9448/demon-attack/screenshots/) helps separate that version from the expanded conversions.
- A contemporary [Radio-Electronics June 1983 review, printed page 75 / PDF page 25](https://www.ataricompendium.com/archives/magazines/radio-electronics/radio-electronics_jun83.pdf) documents **Intellivision** play on a cratered Moon with Earth visible behind it. Demons arrive singly, in pairs, then larger groups. A separate space encounter pits the player against a flagship, bird-like suicide defenders, and a revolving vulnerability opening. Victory returns the player to more intense Moon waves. This review also confirms an automatic firing option.
- The [Tandy Color Computer manual, introduction and Playing the Game](https://colorcomputerarchive.com/repo/Documents/Manuals/Games/Demon%20Attack%20(Tandy).pdf) describes swarming creatures, splitting enemies, optional disappearing phantom demons, and a one-eyed leader. Demons must be destroyed and its shield penetrated before attacking the eye. This is another historical basis for a shield-plus-core boss, but its specific rules should not be conflated with the Intellivision encounter.
- The [Intellivision manual image archive](https://www.pixelatedarcade.com/games/demon-attack/documents/images/instruction-manual/51/) provides primary visual reference pages. Its linked PDF could not be retrieved during this research, so precise boss timing is not inferred from it.

## Screenshot references

| Reference | What to study |
| --- | --- |
| [AtariAge Atari 2600 gameplay gallery](https://atariage.com/screenshot_page.php?SoftwareLabelID=135) | Sparse black field, saturated demons, small cannon, thin blue ground, score above and reserves below. |
| [AtariAge gameplay image](https://atariage.com/2600/screenshots/s_DemonAttack_2.png) | Broad flapping creature silhouettes and generous empty space around threats. |
| [MobyGames platform galleries](https://www.mobygames.com/game/9448/demon-attack/screenshots/) | Compare 2600 demons with Intellivision lunar scenes and computer mothership encounters. |
| [PixelatedArcade screenshots by platform](https://www.pixelatedarcade.com/games/demon-attack/screenshots) | Compare Earth/moon backdrops, boss designs, and different sprite interpretations. |
| [Contemporary Intellivision review and screenshot](https://www.ataricompendium.com/archives/magazines/radio-electronics/radio-electronics_jun83.pdf#page=25) | Period presentation of the expanded edition; same page explicitly describes the flagship opening. |

Use these as visual and behavioral research. Produce new artwork and music for the remake; archived images are reference material, not the shipping asset set.

## Requested remake decisions, distinct from historical claims

The user's specification controls these additions: coordinated organic swarm motion with individual predatory dives; multi-hit weakening and angry final forms; a low-flying carrier releasing flocks; a depleted force field followed by a sliding-door core shot; temporary power-ups; permanent auto-fire; touch trackpad controls; keyboard arrows; three total lives; Top 10 Cloudflare Durable Object storage with exactly three A–Z/0–9 characters; layered celestial scenery; and original adaptive synthesized music.

The historical flagship's revolving window supports the timing challenge concept, while the remake's **sliding door** is the chosen modern interpretation. Likewise, later loops exposing additional transformation stages are a new progression design, not a claim about the 2600 original.

## Design implications

1. Preserve high contrast and readable wingbeats: enemies should read as living demons at thumbnail size.
2. Give swarms separation and directional variation. Telegraph individual dives before committing them toward the player's last position.
3. Use distinct shield damage, door movement, and core-hit feedback so a player understands why shots succeed or fail.
4. Make each loop evolve silhouette, attacks, and musical layers as well as speed. Cap speed growth so survival remains dependent on readable decisions.
5. Keep planets, rings, and moons in low-contrast rear layers; enemy bullets and vulnerable cores need the brightest values.

# Operator playtest 2026-11-15 (second round, after PR #2 merged to main at 91d64fa5)

Verified on mobile. The operator's verdicts:
- "It's gorgeous."
- "The ground animations are fantastic."
- "The cinematic transitions using the fog are such a magnificent improvement!!"
- The approaching sentinel is "so ominous and impressive".
- The final rush was "so scary and exciting".

Workstreams for the next round. Each gets its own OpenSpec change; agents implement on `work/*` branches.

## R1. No stragglers at level end (bug, first)
At the end of every level, no incoming demon may be visible in the fog. Some levels still showed stragglers, including
after a boss fight. playtest-fixes covered the sector's final wave. This round covers every level end, including boss
and carrier ends, sentinel silhouettes and divers, across all routes.

## R2. Sentinel lurking shadow + terrain-conforming shadows (change `terrain-shadows`)
The big sentinel shows a slow lurking shadow on the ground as it approaches the front lines. This lifts all shadow
projection, for the sentinel, creatures, ship and boss: shadows follow the terrain relief and deformation instead of a
flat plane.

## R3. Sweeter fog transition (change `transition-ascent`)
- During Pursuit the ship accelerates.
- The background tilts as it slides down, so the ship appears to fly up.
- The transition radio speaks a front-line call that justifies going back and forth between the same set of levels:
  "Ground support needed in <sector>!" or "We're getting overwhelmed here!"

## R4. Boss level as an event (change `boss-grandeur`)
- **Before the boss:**
  - The boss level opens with one or two ordinary waves while the boss looms in.
  - The boss ship flies in from behind and emerges slowly from under the fog.
- **At the front:**
  - When the boss reaches the front, the fight changes dynamically and flies higher.
  - The ground falls farther away: smaller, slower parallax.
  - The camera zooms the whole play area out a little, dynamically (and back in), to convey speed, range of motion and
    the ship's size.
- **Following the boss:**
  - The boss swerves slowly as it changes direction and is seen at slightly different angles (e.g. 38°, 45°, 52°) as it
    glides up and down.
  - The camera follows it up, down and sideways, shifting the perspective of the ground far below.
- **Damage:** shields and armour decay visibly; the ship falls apart in stages until it collapses.
- **Composable:** later runs get larger, scarier, more complex ships.

## R5. Boss hero assets (Blender + ComfyUI)
- Hero art for the enemy boss ship, with several angles rendered so it can swerve and pitch.
- Learn from 8007342/macron.dev, where agents used the forge to render an animation of Tlatoāni and Mācron learning to
  animate and write.
- "Learn how to properly Blender+ComfyUI ourselves a properly scary boss ship."
- Blender is not installed in the forge; the pipeline and tool access are part of the design.

## R6. Alien rank and shield indicators (change `alien-insignia`)
Fliers currently show only dots or spikes for status and grade; the original low-res sprites had better indicators.
Needed:
- a styleguide for alien troops;
- shields that read as shields;
- rank insignia, the alien equivalent of chevrons and stars, so higher ranks read at a glance;
- hero art to match.

## Order
R1 first (bug). In parallel: the R5 research spike (macron.dev, a Blender route) and the R6 styleguide. Then R2, R3,
and R4, with R4 consuming R5.

# Round 2, addendum (same day, after the frigate B2 sheets)

## R7. One-click PWA install toast (change `pwa-install`)
A dismissable, non-intrusive toast on the landing page with a single button that installs the game as a PWA on mobile
and desktop. Ship it ONLY where it is truly one click and prompts the browser's own approval directly
(`beforeinstallprompt`). No links to instructions. Where one click is impossible (e.g. iOS Safari), show nothing.

## R8. Boss art redirection (supersedes the frigate face direction)
The frigate B2 hero (a gargoyle FACE with riveted metal plates) is rejected as a direction. The new direction:
1. **Alien:** organic or exotic alien materials, gargoyle/alien features but no face, not riveted metal. References for
   scale and detail language only: high-res alien/capital ships from StarCraft (Protoss/Zerg carriers), Star Wars and
   Star Trek. Inspiration only; never copy designs.
2. **A ship, GIANORMOUS:** an extremely large carrier. We zoom out to fit it and it often spills off-screen by design.
   The boss fight runs on different camera and background rules: much higher altitude and speed, clouds and fog in
   play, shadows thrown on the intermediate fog layers.
3. **Scary:** intimidating in size, complexity, detail, armour, spikes and other forms of danger; awe-inspiring.
4. **Extendable:** later runs show more cannons, guns, spikes and barriers (visual only), and the boss looks and feels
   far scarier each run.
5. **Decaying:** shields deplete, then armour falls off. Every such event goes into the game event queue for the
   future dynamic music engine.
6. **Composable sets:** module asset sets differ per run (visual only), as groundwork for run customisation.
Use Blender for a complex ship and long-running ComfyUI GPU jobs; "the boss fight is worth it".

## R9. Bonus levels (change `bonus-levels`)
Random "bonus levels" replace a regular level about once per run. Each has special radio comms and may have special
powerups, or a run modifier such as "no powerup X", "only powerup Y", or a chance of something happening. Two Fable
agents design a couple of them and incorporate them "blindly", as a test of the Tillandsias framework and of this
project's design and guidelines completeness. Each agent notes what would need to change significantly where it hit a
blocker.

## R10. Organic growth
Design pre-emptively so that asset complexity (art, music, radio) can grow organically. Asset pipelines, their
reusability and the shared libraries are now critical.

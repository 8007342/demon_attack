# Operator decisions 2026-11-17 (after the carrier-hatches merge)

- **Licences:** "I think our credits section covers the license issues doesn't it? I approve." The operator accepts
  Fish S2-Pro (a free hobby game counts as Non-Commercial Purpose) and the Higgs v2 credit as the credits page shows
  it. Formal signing still goes through `/accept-licence` when the coordinator's proof-of-gate lands
  (`plan/licences-to-sign.md`).
- **End-game cinematic:** the recommendations are approved as written (`openspec/changes/endgame-cinematic/design.md`
  §12). CP0 passes.
- **Release:** "Merge to main and push to remote". `game` goes to `main` through a pull request (branch discipline
  level 1).
- **Next:** ask the coordinator whether licences can be accepted through pull requests, to unblock the missing model
  downloads.

# Round 4 (2026-11-17, phone playtest of the live release on an iPhone, and the soundtrack pilot)

## Music: the problem is combining, not generating
"Each one of the little segments is 'fine' … it's combining them dynamically that has been the problem from day 1.
All the models create 'good enough' random independent assets, the difficult part we're trying to figure out is how
to combine them dynamically beautifully at runtime." This confirms MIDI-first (`adaptive-soundtrack` design §11): one
score and one band, so sections share key, tempo, instruments and mix by construction. Build the runtime section-graph
player driven by the game's events into the live game. The operator verifies by ear once it's live.

## P1. Performance on phones (change `phone-performance`)
- The live release dropped frames a few times on an iPhone during heavy action and bullet fights, and the phone warms
  up quickly. "Are we aiming for 60fps?"
- **Stroboscopic bullets:** heavy bullet action has "weird harmonics with framerate" and looks choppier than it is.
  Tune bullet speed and fire frequency against the frame rate.
- Research Flutter web profiling, asset compression and code minimisation, plus a performance cleanup. The app has
  grown organically.
- Tone down the background eye candy (ground effects, terrain, ambient animation, "the amount of random crap being
  animated on the screen at all times") where the visual cost is negligible or minimal. Add limits so older devices
  don't stutter.

## G2. Player fire rate down (change `fire-rate-tune`)
"It's a bit hard to see everything going on in the screen, we might need to decrease our ships firerate overall, keep
the demons fire rate intact, just decrease ours." Re-adjust the difficulty to match, as usual.
- Change: `openspec/changes/fire-rate-tune` (with P1's stroboscopic bullets on the model side); calibration in
  `plan/calibration-current.md`, "Fire-rate tune".

# Round 5 (2026-11-17, a playthrough of several levels in the preview)

The operator's verdicts:
- On the soundtrack: "the transitions and continuity of the soundtrack are amazing :D !!"
- "This music score is pretty great".
- "The game plays great :D !!"

## M1. Music too loud against the radio (change `mix-balance`)
"The current soundtrack is way too loud, I had to use half music volume to be able to hear the radio chatter at full
volume, and it was still a little louder." Set the default mix so the radio sits clearly above the music at the
default levels, and duck the music under radio lines.

## S1. Dive shields: one continuous shield that thins (change `dive-shield-thinning`)
- The shields are still segmented. The parts zoom in and out independently instead of moving as one continuous asset.
- The shields still wear from the sides to the middle. Instead, the shield should be thick and always wide enough to
  cover the whole demon: a wide arc whose THICKNESS wears down while its angular width stays the same. "Say, a whole
  70 degrees arc of 10 pixels width, then still 70 degrees arc but 9 pixels width, then 8, etc, don't use these
  numbers, but I want you to use this kind of thinning shield, instead of a narrowing one."
- Use the same principle as the carrier's thick force field that thins out.

## I1. Rank insignia that read as gargoyle, not hearts (change `gargoyle-insignia`)
"The Chevrons for the aliens look a little bit too much like hearts." Design tiny rank iconography inspired by fangs
and wings, through the asset pipeline.

## C6. Carrier hatches as the centrepiece (change `hatch-emergence`)
- Keep the large boss ship asset. Redesign the launch hatches so they are central and draw attention, since players
  look at them while shooting them, and give them "nice candy".
- Demons get a few extra sprites that play only once as they come out of a hatch: peeking from the side, holding the
  hatch, jumping off, then a short glide from the top hatches into fighting distance.
- Follow the cinematic guidelines and use the Blender pipeline. "These are tiny assets so these extra sprites
  shouldn't be too bad."

## V2. Flat radio lines
"There are still a few flat emotion radio chatter." Covered by `voice-direction`; this waits for the voice models.

# Round 6 (2026-11-17, after PR #8 merged and a phone playtest)

The operator merged PR #8 (main `58a1140f`; Cloudflare shows `demon-attack` redeployed 16:27 UTC) and played on a
phone: "that midi music has a nice and smooth progression".

## D1. Dev pages overhaul (change `dev-pages-overhaul`)
"The /console, /studio, and /gallery could use some overhauling ;) some of them like the boss fight scene still shows
assets from several versions of the game ago." Audit every scene on the three pages against the shipped atlases and
painters; draw from the live code, never from frozen copies.

## B2. Build version (change `build-version`)
"Please file a spec to have a "vYY.MM.DD.<daily-build-number>", today would be v56.11.17.1, that way I could tell
when the newer versions are live." The major is 56 on 2026-11-17 (the operator's numbering, same as the Tillandsias
lane `56.11.x`), not the calendar's 26.

## T1. Portrait radio: two independent toast lanes (change `portrait-comms-lanes`)
- Today: one queue showing the last two messages; a toast slides left when the left one closes. Wrong.
- Wanted: TWO independent queues, humans on one side and demons on the other, each with its own timeout and
  persistence. A toast stays on its side until it expires.
- Fixed size in portrait: a short line must not collapse to its text height, and must not grow when the other side
  shows a taller one.
- A comeback (human→demon or demon→human) shows in portrait as one combined toast across both lanes; the queues
  support it.

## T2. Radio during level transitions (same change, `portrait-comms-lanes`)
During a level transition, show one or two radio lines at landscape size, centred over the flowing clouds: one longer
line, or two short ones, or one line with its comeback. Follow the cinematic-flow advisories
(`openspec/changes/cinematic-flow`, `openspec/specs/arcade-presentation`) so it stays non-invasive and keeps the game
flowing.

## B3. Bonus level instructions (change `bonus-briefing-clarity`)
"The instructions for the Bonus Levels are still unclear, and the overlapping of the radio chatter closed the box
before I was able to read it." Clear instructions; radio must not close or cover them. Each bonus level gets one radio
line, a single sentence of instruction (it need not match the text), to keep the game flowing.

## A1. Music: what "higher res" means now
The MIDI score is the first layer, as decided. The next step is the CC0 sample bank (`adaptive-soundtrack` §8.5–8.13):
real drum, bass, guitar, organ and brass samples replace the synth voices note for note, so the score keeps its
seamless combining. Samples wait for the register to admit the pins in `plan/sample-bank-pins.md`; the bank builder,
the sampler runtime and the score checks are built now.

# Round 7 (2026-11-17, evening)

- **Licences:** the operator merged PRs #9–#11 (Open RAIL++-M for SDXL and SDXL-Lightning, Open RAIL-M for Pixel Art XL
  and LayerDiffuse). Merging is the acceptance. The inventory is in `plan/licences-round-2.md`. The coordinator cleared
  the CC0 sample bank (196 pins) for a forge fetch at pinned commits.
- **Credits page (change `credits-page`):** "remove the autoscroll, but make it have a nice soundtrack, and display all
  of these licenses and models, and the pile of projects on which we build upon. Please include Tillandsias, Fedora, and
  Podman, prominently near the top, with icons and links to their websites. A self link to the github repo".
- **High-res score:** "I would rather preview the music score replacement with the high res assets until complete".
  The bank ships off by default (`?bank=1` / console toggle) until the operator approves it from a listening page.
- **Sentinel shadow (change `sentinel-shadow-align`):** the looming sentinel's shadow doesn't follow its silhouette
  behind the clouds. "Don't use my percentages lol just make it smaller at a distance, and track the centinel as it
  approaches. Once its shadow maps correctly it should behave correctly for size and perspective as well."
- **Bonus 1UP challenges (change `bonus-challenges`):** "add a condition, and display it with iconography, like "catch
  all the cargo for 1UP", or "dodge all lightning for 1UP", let's use radio comms and in-game idioms".
- **Wind and a wind bonus level (change `crosswind`):** "significant wind effects, enough to deviate bullets, ours and
  enemies, with swinging directions, sometimes even speeding up bullets a tiny little bit, we'll use clouds as effect
  ... one bonus level that uses this wind gimmick for its goal, like no multifire". With pretty assets, radio chatter
  and new musical accents (`bonus-music`), and "figure out how flexible and extensible our pipelines are early on"
  (crosswind design §Pipelines).

# Round 8 (2026-11-17, late)

- **Sampled score (`bank-fidelity`):** "the new high res assets combine themselves smoothly, and respond nicely to game
  events ... However it's the assets themselves, some of them still sound low res, and some even sound worse than the
  MIDI ... please audit the sound pipeline, since our final sound assets will only be as good as the lowest resolution
  step in the pipeline ... a bit of distortion there for the bass ... we better justify that extra weight with properly
  enjoyable high res audio". The bank stays off by default until it beats the synth.
- **1UP stinger:** "I like the A 1up audio." Variant A ships (already the default).
- **Weather everywhere (`weather-everywhere`):** "Lightning and wind are regular weather effects that happen sometimes
  normaly throughout the game, they're just rarer than regular rain. Radio chatter shall notice them. ... no need to
  rebalance. Just make sure that the demons fighting the wind use strategically their sprites flapping their wings
  sideways. The smarter enemies shall also use the wind to dive."
- **Insignia (`insignia-ranks`):** "Currently there are A LOT of fangs on top of the demons, they're not meant to mark
  everything, just higher ranks ... Make simpler versions of those [winged/crown elite marks] for the regular grunts,
  to mark that they're elite grunts, but not elite as the centinels".
- **Lore and war cries (`fang-and-wings-comms`):** "the Fang and Wings shall be their self appointed battle cry: "Fang
  And Wings!" ... a more prevalent topic in the demons radio chatter ... Some dive attacks shall have their war cry".
- **Spear-bearers (`spear-bearers`):** "a little shield and spear for the armored ones later, wielding the spear as they
  dive, and throwing it mid dive ;) New enemy sprites".
- **Demon choir (`demon-choir`):** "find a music model agents that could consider those grunts and war cryes as part
  of the music ... our Epic/Doom metal had some wordless chorus, how about some wordless demon grunts".

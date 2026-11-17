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

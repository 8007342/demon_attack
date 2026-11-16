# Proposal

## Why

The user loves the radio. Their feedback after the first two rounds:
- many voices sound emotionless;
- the mouths glitch while talking;
- the phone toast is too small for the faces;
- call-ins cut each other off, and the fleet cut off the demons, so the brood was rarely heard;
- shield and loot chatter dominates;
- the radio's break-in and break-out noise is harsh.

They also asked for more of several things: more demon radio (including lower-ranked units and dive orders), much more varied ground and terrain chatter, a demon celebration and fleet chatter around a lost life, occasional full-size transmissions on phones, per-character backdrops in the call frames, and immersive in-world spatial language with no screen or device words.

## What Changes

- **Expressive voices.** Each human keeps a consistent voice: a reference clip rendered with Kokoro is cloned by Chatterbox (Resemble AI, MIT) on CPU, with an emotion per line (excited, urgent, panicked, triumphant, teasing, warm, exhausted, calm, stern). Kokoro remains the per-line fallback. The break-in and break-out are softer: a low-passed noise puff, a gentle click and a short soft tone.
- **One channel.**
  - Lines queue and play in sequence with a 0.35 s gap. Nothing is cut, except by the three truly gameplay-critical warnings (`urgent`: sentinel dive, shield expiring, ground breakthrough).
  - Two-party exchanges reserve the channel for both turns: we win and the boss growls back; the brood taunts and we retort; an ally pleads and the brood gloats.
  - The brood gets fair airtime: a 30 % share target that boosts its queue rank, and a starvation timer that raises brood chatter after 20 s of combat.
  - The regroup celebration may overlap for about a second.
- **More radio.** The bank grows to 67 triggers and 478 clips (346 spoken lines, 132 grunts):
  - three minion voices and portraits (a scout imp, a trooper brute, a gunner);
  - dive orders, rallies, panic on a rout, and broodChatter;
  - ground advances, armor sightings, missile launches, kills, pleas, retreats, thanks, and the line easing;
  - terrain chatter (ridge, valley, canyon, forest, crystal field, ruins, climbing, clearing, stuck);
  - a respawn chorus;
  - mission and junior-pilot transmissions.
- **Rebalancing.** Loot and shield triggers are rarer and share a `loot` group gap. The ground narration shares a 6 s `ground` gap.
- **Losing a life.** The game_events vocabulary gains `playerDestroyed`, `regroupStart` and `playerRespawn`. If the model doesn't emit the last two, the comms layer synthesises them from the lost ship.
- **Lip-sync.** `CommsMouth` builds viseme-like openness from the clip envelope with attack and release smoothing, hysteresis and a 2-frame minimum hold. The portrait pipeline composites the mouth frames inside one fixed face box.
- **Phone.**
  - The toast portrait grows to 48 px, and it still never touches the HUD.
  - During a transition, a full-size transmission replaces the transition art: a big portrait with smoothed lip-sync, the caller's backdrop and the subtitle.
- **Backdrops.** Per-character rooms (fleet bridge or cockpit, ground command tent or tank, infernal war-room) sit behind each portrait with a slow parallax and a dark veil.
- **Language.** No screen, phone, display, UI or input words appear in any line; a test guards this.

## Capabilities

### Modified Capabilities
- `squad-comms`: one sequenced channel, exchanges, demon airtime, expressive voices, lip-sync smoothing, transmissions, backdrops, life-loss and terrain chatter.

## Impact

`main.dart` gains a sectioned transmission overlay and passes `combat` to the comms tick. `demon-audio.js` is unchanged. `comms-audio.js` now caps at 3 voices and never steals except for urgent lines.

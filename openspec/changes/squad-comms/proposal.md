# Proposal

## Why

The mission has no voice. The user wants in-mission radio interventions, inspired by real-time-strategy and on-rails space-shooter radio chatter but with original characters, art and lines: a squad video call. On wide screens the call uses the empty margins beside the centered arena, with two call tiles on each side and the game as the shared screen. On phones a compact call stack sits inside the HUD band. The Fleet Admiral, a per-run lineup of pilots and ground troopers, and anthropomorphized gargoyle demon officers comment on what happens. Officers grunt orders in an unintelligible creature voice while their portrait zooms in.

## What Changes

- **Shared event vocabulary** (`lib/game/game_events.dart`): a typed `GameEvent` stream that is read-only over the simulation. Raw model events pass through by name, so the coming ground-force and homing events plug in without edits. Derived events are added on top: sector start, sentinel arrival and dive, attack runs, elites, shield spotted, collected, expiring and broken, weapon pickups by power, lives, carrier arrival and phases, and fleet-intact celebrations (`flawlessSector`, `flawlessVictory`, `flawlessRun`). The music bridge can listen to the same stream.
- **Comms director** (`lib/comms/comms_director.dart`): priority, per-trigger cooldowns, a time-to-live queue, at most two messages at once (one human voice and one demon voice), and a quiet gap between chatter lines. Gameplay-critical warnings (priority 8 and up) interrupt lower lines. The director also assigns slots (air squad on the left; ground link and brood intercept on the right; idle tiles are replaced quietest-first), rations signature lines, chains celebration lines and holds a mood face after each line.
- **Per-run lineup** (`lib/comms/comms_lineup.dart`): the Admiral anchors every run. A seeded pick of 5 of 9 fleet officers and 2 of 4 ground troopers avoids the previous run's lineup, is stored in local storage and is kept when a run is resumed. The pilots on the call rotate per sector.
- **Line bank and cast** (`art/comms/lines.json`, `cast.json`): 39 triggers, with 188 spoken lines and 53 grunts. The cast is 14 humans who are diverse in age, gender and ethnicity and portrayed respectfully, plus 5 demon officers. Allies never die: a downed ship or squad is "totalled" and goes back to base. `tools/comms_pipeline.py dart` generates `lib/comms/comms_bank.dart`.
- **Voices**: local Kokoro-82M TTS, a distinct voice per human, and a radio chain (band-pass, saturation, squelch clicks, noise tail). Demon grunts are synthesized from granulated, pitch- and formant-shifted gibberish with growl layers. Clips are encoded to Opus and AAC under `web/audio/comms/`. `web/audio/comms-audio.js` plays them through demon-audio's context and master, so they follow its mute and pause. It ducks the music while anyone speaks and caps playback at two voices.
- **Portraits**: original pixel portraits from the studio pipeline (SDXL with the pixel-art LoRA, Qwen-Image-Edit expressions, matting), 12 frames per character (idle, blink, four talk frames, shout, grunt or alarm, happy, worried, two head tilts), in `assets/images/comms-portraits.png` with a half-size atlas for phones.
- **Call UI** (`lib/comms/comms_view.dart`): name and rank tags, signal-static connect and disconnect transitions, a speaking glow, scanlines, a stepped breathing bob, blinks and tilts, a demon zoom-in with a shake (no shake with reduced motion), brood glyph subtitles with a SIGINT gloss, and a fleet-intact banner.
- **Settings**: a voice on/off button next to the sound button; subtitles stay on.

## Capabilities

### New Capabilities
- `squad-comms`: the event vocabulary, the director's pacing and casting, the call layouts, voices and portraits.

## Impact

- No gameplay change. `main.dart` gains small sectioned hooks (`// --- squad comms`). The only edit to `demon-audio.js` is a read-only `graph` getter. `scene.dart` and `model.dart` are untouched.
- On wide screens the side labels yield to the call.
- Asset budget: see `plan/audio-backend.md` (clip sizes) and `plan/asset-pipeline.md` (atlas sizes).

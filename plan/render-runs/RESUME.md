# RESUME: start here after a forge relaunch

Written 2026-11-14 (late) by the session that ran the music batch, the notes/studio routes, and the
battle-flow backlog. The operator is asleep; the host session (macuahuitl-fedora) relaunches the forge onto
the new audio studio. Read this file, then `plan/render-runs/rerender-all.md` on `work/music-batch` (its
"Session handoff" section and log), then act.

## 0. First checks (2 minutes)

1. `git fetch --all` in `/home/forge/src/demon_attack`. Integration branch: `game`. Never push `main`
   (level-1 discipline: main advances only by pull request).
2. Disk: `/home/forge/src` is a 2.5 GB RAM tmpfs. Put every worktree and build output under
   `/home/forge/.cache/tillandsias-project/worktrees/`. Agent `isolation: "worktree"` puts worktrees in the
   repo on tmpfs and filled it once: create worktrees on ~/.cache yourself and point agents at them.
3. `mcp__host-browser__tillandsias_lane_version` must say `current`.
4. `mcp__host-browser__studio_models` (and `studio_status`): confirm the batch-1 audio additions are listed
   (FluidSynth/SFZ renderer, NAM, Pedalboard/LSP, Matchering, R128 analysis, Audiobox, HTDemucs (restricted,
   internal only), ACE-Step 1.5 XL-SFT + 4B LM, VoxCPM2) and the audio node pack (the "ComfyUI for music"
   studio). Ask macuahuitl-fedora (ListAgents → SendMessage) for the PR and exact node class names.
5. `/home/forge/.cache/demon-attack` must be a symlink to `/home/forge/.cache/tillandsias-project/demon-attack`;
   if missing, `lua tools/production/bootstrap_radio.lua` from a checkout (it restores it).

## 1. Music: next steps (the main job once the studio is loaded)

Spec: `plan/audio-studio/music-requirements.md` (on `game`). The operator rejected ALL current music. Do not
promote anything from `work/music-batch`.

1. **Pilot L3 Ember Moon** (180 BPM, 64000 samples/bar, E minor, 96 bars in six sections; motif and
   progression in `art/music/campaign.json` and `web/audio/music/manifest.json` `motifs.3`):
   a. Write the full 96-bar multitrack MIDI arrangement (drums, bass, two rhythm guitars, lead, choir/organ
      layers), committed under `art/music/scores/` (new), generated from `tools/music_motifs.py` motifs.
   b. Build a studio workflow: MIDI → SFZ drums/bass, clean DI guitars → NAM amp + cab IR, orchestra/choir
      (VCSL) → bus FX → master (R128 target −18 to −19 LUFS) → full mix + stems through the master bus.
   c. Screen it (loudness, true peak, clicks via audio.detect_glitches, bandwidth > 16 kHz, aesthetics).
   d. Give the operator an A/B in `/studio` (music tab) against the current in-game L3 score. Only after
      approval: the adaptive cut (tiers, layers, power, accents) per spec section 4.
2. Voices: once VoxCPM2 is in, a 5-clip pilot of the worst offenders (the five Kokoro clips:
   `bossArrival.h2`, `groundMissileLaunch.h5`, `sentinelDive.h3`, `shieldSpotted.h0`, `weaponPickup.h0`) at
   48 kHz for the operator, before re-rendering the 574-clip bank.

## 2. Game backlog status (operator, 2026-11-14)

On `game` now:
- `d6c1f868` **wave pressure + distance fog** (OpenSpec `wave-pressure`): the next wave approaches out of the
  fog at Easy 2 / Normal 3 / Hard 4 remaining, joins after 10/8/6 s if the player lingers. Procedural mist and
  horizon smoke are placeholders for the atmosphere atlas. Needs the operator's playtest (task 2.1).
- `40ff5983` **fluid transitions** (OpenSpec `fluid-transitions`): one message at a time, a slim progress
  strip, alternating silent-tip / radio interlude cards on level transitions, wave changes strip-only. Needs a
  browser playtest to tune fade length and reading speed (task 4.3).
- `1aaf284f` **comms middle ground** (OpenSpec `comms-middle-ground`): see section 3.
- `0af66a20` transitions use the comms `hush`/`offer` hooks (silent tips hush the director; the radio card's
  pick is offered through pacing, never over the squad).

All of the above: `flutter analyze` clean, 425 tests passing (1 pre-existing skip). Nobody has played or
listened to any of it in a browser yet; that is the operator's first look.

On branches, awaiting the operator:
- `work/ground-forces-design` (`f7a7b1d0`): OpenSpec `ground-forces-rework` plus
  `plan/human-ground-forces-style-guide.md`, `plan/ground-unit-animation.md`, `plan/ground-atmosphere.md`,
  `plan/ground-easter-eggs.md`, `plan/render-runs/ground-forces-rework.md`. GPU estimate about 13 h (lean
  6.5 h). **Operator questions** before any render:
  1. Five headings per faction, or four (about 20% less art)?
  2. Pilot human and demon sides together, or demons first?
  3. Full pipeline (about 13 h) or lean (about 6.5 h)?
  4. Do the 4 existing threat vehicles also get headings (gameplay contract, behind a flag)?
  5. A Carrier-sector human slot (Skiff), or keep reusing the Hollow units?
  6. Easter-egg rarities (1/3 dances, 1/8 turret-pop jackpots, 2/5 tree flocks)?
  7. Do allied squads dance on `allySaved`?
  8. Half-resolution far atlas if phone memory is tight?

Not started: easter eggs in code (they need the ground art first, see `plan/ground-easter-eggs.md`).

## 3. Comms (middle ground), on `game`

Seeded sim (`test/comms_pacing_sim.dart`, busy sector 3, 600 s, seeds 4/11/23): paced airtime 17–20 % →
38–39 % busy (24–25 % calm), 0 overlaps, 0 cut lines (was 7–12). Ground warnings are never dropped; 1–2 of
51–60 end late (they wait for the line on air plus a 0.4 s grace gap; a fire forecast avoids most conflicts).
Dive calls: 31–40 of 41–42 end within ±0.3 s; the misses are sentinel calls that waited for a line.
Cards stay up max(clip end + hold, 0.9 s + 0.055 s/char), capped 7 s; taunt pairs stay up together.
Air-cover/ground lines are gated on the real ground picture (`groundPicture`, `allyUnderAttack` within 10 s,
engaged units, flank/arm data). Reinforcements, escorts, carrier phases, wave starts, salvage and the new
wave-pressure `incoming` event reuse existing clips.
Pending (no audio yet): `art/comms/pending-lines-2026-11-14.json` (carrier hatch, last stand, incoming, escort,
air cover gained/lost, transitions) plus six interlude lines the transitions author suggested (in the
fluid-transitions OpenSpec report). Record them with the coming 48 kHz voice model (VoxCPM2).
Still silent: `lastStandTell` (needs a recorded line).

## 4. Preview

`npm run build` in a checkout, then `mcp__host-browser__preview_publish {category: WEB}` (reload after
`wrangler.jsonc` edits). Routes: `/` game, `/console`, `/studio` (asset review + notes), `/gallery/`.
Notes from all three pages share one browser store; "Copy for an agent" gives a markdown worklist.

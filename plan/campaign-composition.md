# Campaign composition and large render map

Source: art/music/campaign.json; original level riffs/hooks: tools/music_motifs.py.

The shared four-note theme has a dotted-quarter, eighth, quarter, quarter rhythm
(1.5/.5/1/1 beats). Its minor-key degrees are tonic, minor third, fifth, fourth;
Ringfall opens the third into major. Each level develops it alongside its own
established hook. No external melody or performance is sampled.

| Level | Character | Key / BPM | Full form |
|---|---|---|---|
| Krybor | Rebellious galloping metal; quiet clean arrival | E minor / 170 | 96 bars, ~135.5 s |
| Ringfall | Heroic power metal; twin leads and brighter harmony | D major / 160 | 96 bars, 144 s |
| Ember Moon | Fiery galloping metal and war drums | E minor / 180 | 96 bars, 128 s |
| The Hollow | Crushing doom/battle metal; tolling bells | C minor / 150 | 96 bars, 153.6 s |
| Carrier | Blackened power metal, organ, strongest climax | F minor / 190 | 96 bars, ~121.3 s |

Form: 8-bar opening, 24-bar A, 16-bar answer B, 16-bar reduced contrast C,
24-bar developed/harmonized recap, 8-bar outgoing passage. The guide renders
12 independently arranged blocks; it never extends a shipped eight-bar loop
by copying its audio. Intro/exit leave room for radio and the bridge pivot.
The same motif and level harmonic roots recur, while instrumentation, register,
answer placement, rhythmic density and harmony develop. Intensity is arrangement,
not louder mastering. Exact grids use the existing integer samples-per-bar.

Bridge sketches pair the outgoing and incoming harmony: E pedal to G/A7/D;
B pedal to C/B7/Em; G pedal to G/G7/Cm; C pedal to Db/C7/Fm. A sparse sustained
pivot leaves the source percussion before the incoming tempo arrives. Rendered
bridges must be aligned and auditioned against both adjoining sections; a key
label or prompt alone does not prove the transition works.

Initial large music batch: three audio-to-audio re-performances of each complete
guide at denoise .45/.60/.75, two candidates per bridge, two warm final reprises,
and two menu candidates: 27 long-form candidates, roughly 40 minutes total.
Workflow/model admission remains with the host studio tools. Preserve full
outputs; do not pass them through the old eight-bar build stage. The batch is
for selection and revision, not automatic artistic acceptance or deployment.

Adaptive production must next create phase-compatible section/layer variants,
quantized event accents, and phrase metadata. The final warm F-major resolution
reprises the shared theme at 96 BPM for the beach ending/credits. The PWA will
load compressed phrases/sections with bounded decoded memory; full lossless
masters are checkpointed remotely and excluded from runtime assets.

Radio batch: all 385 human lines and 189 original demon performances, covering
25 synthetic character identities. Demon translations are now playful voiced
sentences rather than one-word grunt labels. Their clean performances are
retained before per-character reversal/down-pitch. More expressive delivery,
light wider-band radio, transformed-voice mouth timing and 48 kb/s Opus are
measured per clip. Candidate fallbacks remain explicit and require review.
One resident model process is guarded; Lua handles scheduling and remote
checkpoints. Audio quality and full dialogue/mouth review remain acceptance work.

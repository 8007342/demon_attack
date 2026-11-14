# Scores

Full multitrack arrangements, one folder per piece, generated from committed
Python sources. These are the source of truth the real-instrument studio
renders (plan/audio-studio/music-requirements.md, UC1 and section 7).

## l3-ember-moon (pilot)

`python3 -I tools/score_l3.py` writes:

- `full.mid`: SMF type 1, PPQ 480, 180 BPM, 4/4, E minor. Track 0 is the
  conductor (tempo, time and key signatures, section markers, rehearsal-mark
  texts). Then one track per part. 96 bars (128.000 s, 96 × 64000 samples at
  48 kHz), plus one bar of ring-out for the final tails.
- `parts/<part>.mid`: the conductor plus one part, so each part can go
  through its own SFZ render (one stem per part, same grid).
- `score.json`: sections, rehearsal marks, the chord of every bar, parts
  (channel, GM program, role, render hint, note counts, ranges) and the
  sha256 of every file.

The output is deterministic: humanisation uses a fixed per-part seed, and
downbeats are not humanised, so bars slice cleanly.

### Form

| Bars | Section | What happens |
|---|---|---|
| 1-8 | opening | organ, strings, choir; the campaign theme on clean guitar; war drums from bar 5; snare and timpani roll into bar 9 |
| 9-16 | theme A1 | gallop riff (both rhythm guitars, bass, gallop kicks); campaign theme on lead, rising |
| 17-24 | theme A2 | the level hook |
| 25-32 | theme A3 | the hook in twin diatonic thirds; choir and organ; double kick at the turnaround |
| 33-40 | answer B1 | new progression C D Em Em Am C B B; 3-3-2 push; lead calls with the theme, brass answers; harmonic-minor run into B2 |
| 41-48 | answer B2 | C D Em G Am F B B; double kick; twin leads develop the call; strings, brass stabs |
| 49-56 | contrast C1 | half-time dark reduction (Em F Em F Am C B B); choir sings the theme augmented (B over F as the dread); crushing held chords from bar 53 |
| 57-64 | contrast C2 | gallop returns under a written guitar solo |
| 65-72 | recap R1 | hook in thirds over choir and organ |
| 73-80 | recap R2 | the anthem: brass and choir sing the augmented theme; the lead answers with the rising A1 line |
| 81-88 | recap R3 | climax: hook in thirds, brass theme, choir, strings, double kick |
| 89-96 | outgoing | thins out; final Em hit on bar 95; bar 96 holds G on top for the L3→L4 bridge (Em → G → G7 → Cm) |

### Parts

drums (GM map, channel 10), bass, gtrL / gtrL-pm and gtrR / gtrR-pm (rhythm
guitars: open power chords and palm mutes on separate channels, written as real
notes: root, fifth, octave; mutes root and fifth), lead, lead2 (harmony),
lead-clean, clean (arpeggios), choir, organ, brass, strings, timpani.

### Render chain (planned, audio studio batch 1, tillandsias#1103)

Each `parts/<part>.mid` → `TillandsiasLoadMIDI` → `TillandsiasSFZRender`
(Karoryfer drums and basses, black-and-green or shiny guitars, VCSL for the
orchestra) → guitars through `TillandsiasAudioSaturate` + `TillandsiasAudioEQ`
until NAM amp/cab models arrive in batch 2 → `TillandsiasAudioPan` →
`TillandsiasAudioMixBus` (bus compression) → `TillandsiasAudioLimiter` →
`TillandsiasAudioNormalizeLoudness` (−18 to −19 LUFS) → full mix plus each
stem through the master bus, checked against `TillandsiasBarGrid`
(64000 samples per bar).

### Composition sketch

`tools/score_sketch.py` plays the score through the old guide synth, rendered
to `~/.cache/demon-attack/scores/` and never committed. It is only for judging
the arrangement (form, parts, density, dynamic arc), not the sound.
Measured on the sketch (integrated LUFS per section): opening −17.7,
A −11.0, B −10.7, C1 −17.6, C2 −10.5, recap −9.6, outgoing −14.0.

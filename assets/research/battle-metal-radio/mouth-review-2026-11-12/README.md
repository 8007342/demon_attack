# Candidate mouth review

These are retained research previews, not shipped replacement banks or a
full-cast acceptance. `reinforcements.h0` (Admiral Hale) and
`reinforcements.d0` (Gorrak) use their newly rendered, encoded radio voices.
The 30 Hz frames come from the game's actual `CommsTilePainter` and
`CommsMouth`, at 128 px and 48 px, with a half-second resting tail.
The WebM files mux that exact frame sequence with each candidate's Opus audio.

The contact sheets were visually inspected: both portraits retain face/body
alignment, pass through several openings, and return to a closed/resting mouth.
The phone previews retain visible mouth movement. This supports keeping these
two source portraits for contextual review rather than regenerating identities.
It does not establish perceived audiovisual synchrony or voice quality: listening
and more characters/emotions remain pending. No frame repairs were made here.

Reproduce from the repository root, with an existing real review font:

```sh
flutter test test/comms_candidate_review_test.dart \
  --dart-define=COMMS_CANDIDATE_REVIEW=/home/forge/src/demon_attack/.cache/candidate-mouth-review \
  --dart-define=COMMS_REVIEW_FONT=/home/forge/src/demon_attack/.cache/review-fonts/Roboto-Regular.ttf
lua tools/production/mux_mouth_review.lua .cache/candidate-mouth-review \
  reinforcements.h0 reinforcements.d0
```

`COMMS_CANDIDATES` accepts a comma-separated set of retained clip IDs.
Each provenance Lua file hashes its metadata, radio audio, atlases, runtime
painter/timing code and review tools. The previews display readable meaning for
review; this is not the runtime subtitle layout or its alien-script reveal.

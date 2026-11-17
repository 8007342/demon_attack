## 1. Mix balance

- [x] 1.1 Offline meter (`tools/mix_meter/`): render the shipped players, BS.1770 integrated loudness, checked against ffmpeg `ebur128`
- [x] 1.2 Measure before: every sector at tiers 1–4, the carrier cores, menu, defeat, the radio bank sample, and Low music
- [x] 1.3 Music level table: Full -20 dB, Low -30 dB; speech, master and effects unchanged; stored choices honoured
- [x] 1.4 Speech duck on the music chain's own stage: 4 dB per line, 2 dB for a growl or a clip under 1 s; 30 ms attack, 250 ms hold, 150 ms release
- [x] 1.5 Measure after (design §1) and log the unsourced targets in `plan/provenance-audit.md`
- [x] 1.6 Tests: `test-worker/mix-balance.test.mjs` (relative levels end to end, duck depth and ramps, early cut, score moves unchanged), `audio-levels`, `comms-audio`; `test/music_constant_test.dart` becomes `test/music_mix_test.dart` (speech reaches the music only through the duck)
- [x] 1.7 Listen in the browser at Full/Full (operator, 2026-11-17): too quiet; superseded by group 2

## 2. Retune (operator follow-up: -20 dB was too low)

- [x] 2.1 Section trims: `tools/mix_meter/trim.mjs` meters all 217 section/tier cases untrimmed and writes `web/audio/score/mix-trim.json` (spread narrowed to 2 LU, order kept, the loudest at 0 dB, at most +8 dB); `--check` reproduces it byte for byte
- [x] 2.2 `demon-score.js` applies the trim on its output gain at each move and tier change (50 ms glide on the line); a missing file or key is 0 dB
- [x] 2.3 Music Full -14 dB (Low -24 dB): the loudest gameplay 2.5 LU under the radio, calm sections 4.5 LU under
- [x] 2.4 Duck 3 dB per squad line, 1.5 dB for a growl or a clip under 1 s (timing unchanged)
- [x] 2.5 Tests: levels 2-4 LU, the trim table's coverage and spread, a rendered calm-vs-loud spread, moves unchanged by trims; design §5
- [ ] 2.6 Listen in the browser at Full/Full (operator)

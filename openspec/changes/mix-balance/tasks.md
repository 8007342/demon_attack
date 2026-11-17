## 1. Mix balance

- [x] 1.1 Offline meter (`tools/mix_meter/`): render the shipped players, BS.1770 integrated loudness, checked against ffmpeg `ebur128`
- [x] 1.2 Measure before: every sector at tiers 1–4, the carrier cores, menu, defeat, the radio bank sample, and Low music
- [x] 1.3 Music level table: Full -20 dB, Low -30 dB; speech, master and effects unchanged; stored choices honoured
- [x] 1.4 Speech duck on the music chain's own stage: 4 dB per line, 2 dB for a growl or a clip under 1 s; 30 ms attack, 250 ms hold, 150 ms release
- [x] 1.5 Measure after (design §1) and log the unsourced targets in `plan/provenance-audit.md`
- [x] 1.6 Tests: `test-worker/mix-balance.test.mjs` (relative levels end to end, duck depth and ramps, early cut, score moves unchanged), `audio-levels`, `comms-audio`; `test/music_constant_test.dart` becomes `test/music_mix_test.dart` (speech reaches the music only through the duck)
- [ ] 1.7 Listen in the browser at Full/Full: the radio is clearly above the score and the duck is not audible as pumping (operator)

# Bass tone research: a metal chain for the sampled DI bass (`adaptive-soundtrack` design §12.12)

Operator, round 8, after the fidelity A/B: the clean sampled bass "sounded like the metallic heavy strings of the bass
without any electronic distortion at all ... the old midi synth is the fully postprocessed bass play with some
distortion ... Our audio pipeline is missing the right amount of distortion for the bass to make it sound like a
metal soundtrack". Then: "even the old bank was really good, it was just missing the postprocessing".

This doc covers how metal and doom productions process a DI bass, how to build that chain cheaply in Web Audio, and
what we measured. The candidates, the pick and the per-stage numbers are in `plan/render-runs/sample-bank.md` §9.

**Provenance.** Researched on 2026-11-18. The forge proxy reset every audio-production site tried: soundonsound.com,
nailthemix.com, urm.academy, darkglass.com, tech21nyc.com, wikipedia.org, rane.com, talkbass.com, gearspace.com,
coda-effects.com and the manual hosts. Only w3.org, webaudio.github.io, developer.mozilla.org, github.com and
raw.githubusercontent.com answered. Nothing was routed around the proxy. So every mixing-practice claim in §2 is
sourced from a search snippet only. Each is marked `UNSOURCED`, with its row in `plan/provenance-audit.md` Part BT,
and the snippet is cited as unread. The Web Audio facts in §3 come from pages that were fetched and read. The numbers in
§1, §4 and §5 are our own measurements, and each names the tool that produced it.

## 1. What is wrong with the clean DI (measured)

`node tools/mix_meter/bass_tone.mjs stages --tone synth,clean --cases k:B@3,c1:core@4` measures the bass alone through
the shipped players. Octave-band energy is in dB relative to the stage total; the crest is peak over RMS.

| | 31.5 Hz | 63 | 125 | 250 | 500 | 1 k | 2 k | 4 k | 8 k | crest |
|---|---|---|---|---|---|---|---|---|---|---|
| synth bass (`k:B@3`) | −4.5 | −2.6 | −13.4 | −16.1 | −18.4 | −23.6 | −33.5 | −53.3 | −89 | 8.1 dB |
| sampled DI, clean bus | −27.5 | −17.8 | −7.9 | −5.7 | −9.3 | −8.2 | −7.3 | −10.3 | −25.9 | 21.2 dB |

The bank plays the bass at C#1 to F#1 (35-46 Hz). The DI's fundamental octave sits 20-25 dB below its 250 Hz-4 kHz
content, and its string zing reaches 8 kHz. Its peaks are 13 dB sharper than the synth's at the same loudness. That
matches what the operator heard: the bare strings, bright and spiky, with no weight. The synth bass is a filtered
oscillator through a mild tanh drive (THD+N −22.6 dB, design §12.11), so it is nearly all fundamental. A metal bass
needs both: weight below about 200 Hz, and a driven, cabinet-filtered midrange ("grind") in place of the raw zing.

## 2. How metal and doom productions process a DI bass (snippet-only sources)

- **A split chain.** The DI is duplicated into a clean low path and a distorted mid and high path, and the
  distorted copy is high-passed near the clean path's cutoff. Most rock and metal producers keep the low end clean
  and distort only the mids and highs. Some, such as Buster Odeholm, distort the lows as well.
  `[UNSOURCED: plan/provenance-audit.md#bt-split-chain]`
  [source: Mike Senior/Sound On Sound, "Mixing Bass", https://www.soundonsound.com/techniques/mixing-bass, unread: snippet only]
  [source: Sound On Sound, "Mixing DI Bass Guitar", https://www.soundonsound.com/techniques/mixing-di-bass-guitar, unread: snippet only]
  [source: Nail The Mix, "Handling Different Types of Bass in Your Metal Mix", https://www.nailthemix.com/different-types-of-bass, unread: snippet only]
  [source: Nail The Mix, "Buster Odeholm bass amp trick", https://www.nailthemix.com/oceano-buster-odeholm-bass-amp-trick, unread: snippet only]
- **The crossover.**
  - Reported points: below 100 Hz up to 200-300 Hz for the clean path.
  - Forum reports run from 80 Hz to 250 Hz: lower for fingerstyle, higher for pick.
  - The distorted copy is high-passed around 200 Hz "or it will be very flabby".
  - URM's advice is to set it by the part being played.

  `[UNSOURCED: plan/provenance-audit.md#bt-crossover]`
  [source: TalkBass, "Parallel Processing for Metal 'Clanky' Tones", https://www.talkbass.com/threads/parallel-processing-for-metal-clanky-tones.1650650/page-3, unread: snippet only]
  [source: Gearspace, "How to get cool distorted bass sound", https://gearspace.com/threads/how-to-get-cool-distorted-bass-sound.839499/, unread: snippet only]
  [source: URM Academy, "Mixing Secrets Vol 2: Bass", https://urm.academy/mixing-secrets-volume-bass/, unread: snippet only]
- **The blend.** Distortion can run as a send and be blended in at a low level. A Darkglass-style pedal blends the clean
  signal with its distorted one. `[UNSOURCED: plan/provenance-audit.md#bt-blend]`
  [source: Sound On Sound, "Better Bass", https://www.soundonsound.com/techniques/better-bass, unread: snippet only]
  [source: Tech 21, SansAmp Bass Driver DI manual (Level, Blend, Treble, Bass, Drive, Presence), https://manualmachine.com/tech21/sansampbassdriverdi/19066333-owners-manual, unread: snippet only]
- **The drive pedal's EQ.** The Darkglass B7K's bands are Low at 100 Hz, Low-Mids at 1 kHz, Hi-Mids at 3 kHz and Treble at 5 kHz,
  so the growl is voiced around 1 kHz. `[UNSOURCED: plan/provenance-audit.md#bt-b7k-bands]`
  [source: Darkglass, "Microtubes B7K Ultra v2 user manual", https://www.fullcompass.com/common/files/34647-DarkglassMicrotubesB7KUltrav2UserManual.pdf, unread: snippet only]
- **Doom fuzz.**
  - A Big Muff's tone stack is a passive high-pass mixed with a low-pass. With the tone control centred it scoops
    the mids around 1 kHz.
  - On bass that scoop makes the instrument "disappear in a busy band mix". The bass versions add a dry blend that
    keeps the lows, and doom players run the tone dark.

  `[UNSOURCED: plan/provenance-audit.md#bt-muff-scoop]`
  [source: Coda Effects, "Big Muff tonestack: dealing with mids", https://www.coda-effects.com/p/big-muff-tonestack-dealing-with-mids.html, unread: snippet only]
  [source: guitar.com, "EHX Bass Big Muff Pi 2 review", https://guitar.com/reviews/effects-pedal/hands-on-electro-harmonix-bass-big-muff-pi-2-review/, unread: snippet only]
- **Compression.** About 4:1 is a starting ratio, and 6-8:1 is used for aggressive control. Metal bass compression
  uses an attack slow enough to keep the pick click and a fast-to-medium release of 100-300 ms; attacks under 5 ms
  can pump. `[UNSOURCED: plan/provenance-audit.md#bt-comp]`
  [source: Nail The Mix, "How to Use Compression on Bass Guitar", https://www.nailthemix.com/how-to-use-compression-on-bass-guitar, unread: snippet only]
  [source: iZotope, "Bass compression", https://www.izotope.com/en/learn/bass-compression, unread: snippet only]
- **Room against distorted guitars.**
  - Guitars are high-passed at 80-100 Hz (higher for drop tunings), and the bass carries everything below about 100 Hz.
  - The bass's grit at 700 Hz-2 kHz backs up the guitars, so it should not be scooped there.
  - Guitar definition sits around 1.5-2.5 kHz.
  - A distorted bass is low-passed at 5-8 kHz to stay out of the cymbals.

  `[UNSOURCED: plan/provenance-audit.md#bt-guitar-slot]`
  [source: Nail The Mix, "High Pass Filter", https://www.nailthemix.com/high-pass-filter, unread: snippet only]
  [source: Nail The Mix, "EQ frequency chart", https://www.nailthemix.com/eq-frequency-chart, unread: snippet only]
  [source: Violet Recording, "How to Mix Metal Guitars", https://violetrecording.com/how-to-mix-metal-guitars/, unread: snippet only]

What we take from §2, as our judgement until a source is read:

- a clean, compressed low band below a 120-250 Hz split;
- a driven band above it, voiced at about 1 kHz before the drive;
- a cabinet low-pass well under the guitars' 5.5 kHz;
- a dip in the guitars' 2.4-2.9 kHz presence (our guitar chain, `web/audio/demon-score.js`);
- the bass body left at 400 Hz, where our guitar cabinet notches;
- a compressor before the split, at about 4:1.

## 3. Web Audio: building it cheaply (read sources)

- **A low- or high-pass Q is in dB.** In the spec's coefficient formulas, `lowpass` and `highpass` take
  α = sin ω0 / (2·10^(Q/20)), while peaking, notch, band-pass and all-pass take a linear Q. A Butterworth section, linear
  Q 0.7071, is therefore `Q = -3.0103`. If you write `0.707`, you get a linear Q of about 1.085, which peaks about
  1.7 dB. A Linkwitz-Riley 4th-order crossover is two such sections per side.
  [source: W3C Audio WG, "Web Audio API" (editor's draft), https://webaudio.github.io/web-audio-api/, read 2026-11-18]
  The flat all-pass sum of LR4 is a textbook property. Its page (Wikipedia, "Linkwitz–Riley filter") reset, so it is
  marked `[UNSOURCED: plan/provenance-audit.md#bt-lr4-sum]`. The offline renderer reads Q the same way
  (`tools/mix_meter/offline-audio.mjs`), and the chain's sums were measured there (§4).
  The synth's existing bus filters write 0.7 and 0.8 for their low- and high-passes. That is a small resonance on the
  synth sound we keep, and changing it would change the synth, so it stays.
- **WaveShaperNode.** The curve is read by linear interpolation over [−1, 1]. An input beyond ±1 takes the curve's end
  value, which is a hard clip. A curve that isn't zero at zero makes DC. `2x` and `4x` up-sample, shape and
  down-sample; the filters and the latency they add are implementation-defined.
  [source: W3C Audio WG, "Web Audio API index.bs", https://raw.githubusercontent.com/WebAudio/web-audio-api/main/index.bs, read 2026-11-18]
  [source: MDN, "WaveShaperNode: oversample property", https://developer.mozilla.org/en-US/docs/Web/API/WaveShaperNode/oversample, read 2026-11-18]
  Chromium's up-sampler is a 128-tap windowed sinc and its down-sampler a 256-tap half-band filter.
  [source: Chromium, "up_sampler.cc", https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/audio/up_sampler.cc, read 2026-11-18]
  [source: Chromium, "down_sampler.cc", https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/platform/audio/down_sampler.cc, read 2026-11-18]
  Measured in Chrome 156 by rendering an impulse in an OfflineAudioContext (host browser, 2026-11-18): **128 frames
  of latency at 2x and 192 at 4x**, and none at `none`. In a parallel chain only the driven band carries that delay, so
  the two bands would comb near the split. The chain measures the latency of the engine it runs on and delays the
  clean band by that much (§4).
- **DynamicsCompressorNode.**
  - Its attack and release are times per 10 dB of gain change, and knee 0 is a hard knee.
  - It applies an automatic make-up gain of (1 / curve(1.0))^0.6.
  - Its model graph has a 6 ms look-ahead delay, and Chromium's is `kPreDelay = 0.006`.
  - It has at most two channels (`clamped-max`).

  [source: W3C Audio WG, "Web Audio API", https://www.w3.org/TR/webaudio/, read 2026-11-18]
  [source: Chromium, "dynamics_compressor.cc", https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/audio/dynamics_compressor.cc, read 2026-11-18]
  [source: MDN, "DynamicsCompressorNode", https://developer.mozilla.org/en-US/docs/Web/API/DynamicsCompressorNode, read 2026-11-18]
  So the compressor sits before the split, where its 6 ms delays both bands alike, and the bass as a whole plays 6 ms
  late (about 2 m of air). Knee 0 is used because the offline renderer models the hard knee only, so the browser and
  the meter agree.
- **Convolver against biquads for the cabinet.** Spotify's Web Audio benchmark rates the compressor, the wave shaper
  and the FFT-based nodes as the most expensive.
  [source: Spotify, "web-audio-bench", https://github.com/spotify/web-audio-bench, read 2026-11-18]
  The cabinet is therefore two Butterworth low-passes and a peaking dip, not an impulse response.

## 4. What was measured here

- **CPU** (Chrome 156, an OfflineAudioContext rendering 20 s of a 41 Hz sawtooth through each chain; median of 5;
  net of a bare render; percent of one desktop core in real time):

  | Chain | CPU |
  |---|---|
  | the synth bass bus (4x shaper + low-pass) | 0.25 % |
  | one guitar bus (two 4x shapers + cabinet) | 0.50 % |
  | bass tone, desktop (compressor, LR4, 4x, 12 biquads), stereo after the compressor | 1.05 % |
  | bass tone, phone (LR2, 2x), stereo after the compressor | 0.84 % |
  | bass tone, phone, folded to mono after the compressor (as built) | 0.59 % |
  | bass tone, phone, no compressor | 0.44 % |
  | the compressor alone | 0.13 % |

  The compressor always outputs two channels, so the chain folds back to mono after it, which halves the downstream
  work. The desktop chain as built is about 0.8 %. The phone tier's variant (LR2 split, 2x oversampling) costs about
  as much as one guitar bus. On a phone core, which may be 3-5× slower, it is a few percent of one core.
  `lib/game/perf/frame_budget.dart` budgets the painters only, and the audio graph runs on the audio thread. The
  game's audio tier is `phoneClass()` in `demon-score.js` (2 GB or less of device memory, or a coarse pointer).
- **The chain's own sum** (`test-worker/bass-tone.test.mjs`): with `grind` 1 and the drive at its smallest, a
  small sine passes LR4, and LR2 with its low band inverted, within 0.01 dB from 50 Hz to 800 Hz. With drive, the
  tanh compresses the driven band, which is the point.
- **The DI's levels at the chain's input** (the sampled bass bus, role level 7.35, bus 0.8): the median 50 ms note
  peak is 1.92, the p95 is 4.43 and the peak is 4.91. The chain's input gain of 0.18 brings the peak to 0.88. The
  shaper then sees at most 0.76 on the music and 0.18 on the sine test's peak level, so it never clips at the curve's
  end. Before bank-fidelity, by contrast, the shared bass shaper took 2.47.

## 5. Drums (checked, unchanged)

The operator hears the sampled drums as fine clean. Metal drum production usually compresses the kit and shapes its
transients. That is our judgement from the same snippet-only sources, and no read source backs it, so it is not
claimed. Measured with `node tools/mix_meter/bank_fidelity.mjs render --solo drums` (figures in
`plan/render-runs/sample-bank.md` §9): the sampled kit's crest is close to the synth kit's. In the full mix, the master
limiter never reduces gain with the bass chain in either bank. A drum compressor would cost about as much as the bass
chain's compressor and would flatten the dynamics the operator likes. **No drum processing is added.** If a later round
asks for punchier drums, a parallel bus compressor on the drums bus is the next step.

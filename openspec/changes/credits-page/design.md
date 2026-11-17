# Design: credits page

## 1. The page
`EndingPage` keeps the beach reveal and its header (DEMON / ATTACK, SKIP REVEAL, CLOSE or CONTINUE). The credits body
moves to `lib/ending/credits_view.dart` (`CreditsView`), shared by the title's CREDITS and the ending.

- **Still.** No ticker, no auto-scroll, no PAUSE/RESUME button. A `SingleChildScrollView` (`credits-scroll`) with a
  `Scrollbar` (always shown at ≥ 600 px wide). Keys: arrows ±48 px, Page Up/Down and Space ±85 % of the viewport,
  Home/End; reduced motion jumps instead of animating. The view takes focus once its data loads; Escape bubbles to
  the page and closes.
- **Layout.** One column, at most 720 px wide, centred. Side padding 16 px on phones, 32 px from 600 px up. The
  built-on cards stack on phones (icon left, text right) and sit three in a row from 600 px up (icon above).
- **Order.** CREDITS → "By Tlatoāni, with love" and "Made alongside Claude by Anthropic" → BUILT ON cards → source
  button → trademark note → the sections of §4-§6 → the source licence line → "Thanks for keeping the sky
  interesting." → PACKAGE LICENSES (Flutter's licence registry).
- **Rows.** Each entry is its name (a link when it has a `url`, opened in a new tab) over a quieter line joining
  `version`, `license` and `source`. Every row has the key `credits-row-<section>-<entry>` so the tests can find
  each one.
- **Phone fit.** At 360 × 780 the three cards end inside the first screen and the source button follows at the top
  of the first scroll (the test allows 1.25 screens); at 1280 × 800 both are in the first screen.

## 2. Built-on cards and their icons
`built_on` in `assets/credits.json`: name, url, one-line blurb, and either `icon` (an asset) or `glyph` (a neutral
Material icon). The rule for each: use the project's own logo only where its published rules allow a "built with"
credit in a free, open-source game; otherwise a neutral glyph that does not imitate the mark.

| Project | Shown | Why |
|---|---|---|
| Tillandsias (https://tillandsias.org/) | its own icon, `assets/images/credits/tillandsias.webp` (96 px, lossless, 1 332 B) | The icon is the site's favicon, an inline SVG air plant (five strokes, `#5fd6a4`). Tillandsias is the same owner's project (github.com/8007342/tillandsias) and is GPL-3.0, as this game is. No trademark policy is published. [source: Tillandsias, "Tillandsias — an ephemeral cloud region, folded through your hypervisor" (home page, favicon `<link rel="icon">`), https://tillandsias.org/, read 2026-11-17]; [source: 8007342, "tillandsias LICENSE" (GNU GPL v3), https://raw.githubusercontent.com/8007342/tillandsias/main/LICENSE, read 2026-11-17] |
| Fedora (https://fedoraproject.org/) | neutral glyph (`Icons.desktop_windows_outlined`) | Fedora's trademark guidelines allow logo use without permission "only in connection with promoting the Fedora Project or Fedora code…", with trademark symbols, the attribution statement and the brand standards; anything implying affiliation needs the Council's permission. A game's "built with" card is not clearly inside that, so no Fedora logo. The brand page also says not to adjust or make variants of the logo, so the glyph is a generic computer, not a stylised "f". [source: Fedora Project / Red Hat, "Fedora trademark guidelines", https://docs.fedoraproject.org/en-US/legal/trademarks/, read 2026-11-17]; [source: Fedora Project, "Fedora Brand" (logo dos and don'ts), https://docs.fedoraproject.org/en-US/project/brand/, read 2026-11-17] |
| Podman (https://podman.io/) | neutral glyph (`Icons.inventory_2_outlined`) | The logo in `containers/podman/logo/` has no licence file of its own; the repository's Apache-2.0 licence (§6) grants no trademark rights. The CNCF artwork repo carries the Podman Container Tools logos "under the Linux Foundation trademark usage guidelines", but that policy page did not load through the forge proxy (podman.io did not either), so its terms are unread and the rule is unclear: no Podman logo. [source: containers/podman, "logo/" directory listing (podman-logo-source.svg, podman-logo.png), https://api.github.com/repos/containers/podman/contents/logo, read 2026-11-17]; [source: containers/podman, "LICENSE" (Apache License 2.0), https://raw.githubusercontent.com/containers/podman/main/LICENSE, read 2026-11-17]; [source: CNCF, "artwork LICENSE.md", https://raw.githubusercontent.com/cncf/artwork/main/LICENSE.md, read 2026-11-17]; [source: The Linux Foundation, "Trademark Usage", https://www.linuxfoundation.org/trademark-usage, unread: blocked by the forge proxy] |

The names themselves appear as plain text, which the trademark rules do not restrict, with the note "Fedora and
Podman are named here only to credit the software this game is built with. This game is not affiliated with or
endorsed by the Fedora Project, Red Hat or the Podman project." Fedora is in the cards because the forge runs on it
(`uname -r` in the forge: `7.3.3-300.fc45`); Podman because every forge, toolchain and studio is a Podman container.

**Recipe for the Tillandsias icon** (the WebP is the only committed format, §5 of CLAUDE.md): save the favicon's SVG
from the home page's `<link rel="icon">` data URL, then
`magick -background none -density 1200 tillandsias-icon.svg -resize 96x96 -define webp:lossless=true assets/images/credits/tillandsias.webp`.
The SVG, for the record:
`<svg viewBox="0 0 16 16" fill="none" stroke="#5fd6a4" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round"><path d="M8 15 Q8 9 8 2.6"/><path d="M8 15 Q6.1 9.4 4.6 4.9"/><path d="M8 15 Q9.9 9.4 11.4 4.9"/><path d="M8 15 Q4.4 11 2.4 7.6"/><path d="M8 15 Q11.6 11 13.6 7.6"/></svg>`

## 3. The credits song
`credits` in `art/music/soundtrack/song-map.json`, composed by `tools/score/songs/credits.lua` (form `credits`).

- **Key and tempo.** G major, the relative major of the overture's E minor, so the move from the title music changes
  colour without a clash; 72 BPM, bar 160 000 samples (3.333 s), the slowest grid in the score.
- **dawn** (tail, 4 bars, next `drift`): clean arpeggios with strings, organ and choir pads on G C Em D, the theme's
  first notes on bells, the bass from bar 3. It ends on D and opens into the loop.
- **drift** (loop, 16 bars): slow clean-guitar arpeggios throughout; bars 1-8 the campaign theme (`art/music/campaign.json`,
  the line the coda sings) on bells over strings, bars 9-16 the theme an octave lower on strings with a held choir,
  bells on each chord's third, and brushed time (a soft kick, a rim, pedal hats). Ends on D so the loop turns back
  to G. No ukulele (the beach's voice), no power chords, no crash.
- **Gates.** `lua tools/score/score_gen.lua --check` passes; dawn 77 notes, peak 16 voices; drift 327 notes, peak 14
  voices; 0 % out of key. `midi_stats.lua check` (the score-sampler gate) passes on the whole score.
- **Level.** The mix keeps every section within 2 LU after its trim (`tools/mix_meter/trim.mjs`, at most +8 dB;
  `test-worker/mix-balance.test.mjs`). A first draft written pianissimo measured -18.6 LUFS (dawn) and -16.7 (drift)
  and failed that test (5.7 LU spread), so the parts are written mezzo-forte (velocities 52-100): dawn -14.1, drift
  -12.9 LUFS before trims. The calm comes from the texture (no power chords, no crash, brushed time only in the
  second half) and the slowest grid in the score, not from a lower level. Adding two sections below the old 5th
  percentile moves the trim rule's floor, so every other section's trim shifts by at most a few tenths of a dB.
- **Moves.** `SongDirector.cue('credits')` → `_scene('credits')` → `credits:dawn` on the playing song's next bar line;
  a repeated cue moves nothing. Closing the title's credits cues `menu` (already in `main.dart`), so the overture
  comes back on the credits' next bar line. Held notes release over 30 ms at each move (demon-score.js), so neither
  move clicks. The music level setting scales the score's bus as for every song.
- **Loading.** `demon-score.js` loads the credits song right after the overture, so a quick click on CREDITS finds
  it ready.
- **The ending keeps the coda.** The in-game ending still cues `ending` (the coda's ukulele, then its warm reprise);
  only the title's CREDITS play `credits`.

## 4. Models and licences
`tools/generate_credits.lua` keeps every earlier model row (the "Built with Meta Llama 3 · …" line and the Higgs and
Fish credit lines verbatim) and adds a `url` to each. Changes, each from the model's Hugging Face card (`license`
field) read through the Hugging Face API on 2026-11-17:

- **ACE-Step 1.5 XL: MIT** (was Apache-2.0). [source: ACE-Step, "acestep-v15-xl-turbo" model card, https://huggingface.co/api/models/ACE-Step/acestep-v15-xl-turbo, read 2026-11-17]. Marked as the soundtrack pilot: the shipped score is MIDI written by `tools/score`.
- **Demucs, Alexandre Défossez** (new), marked analysis and reference only, as `openspec/specs/third-party-licence-demucs-weights-unstated` requires.
- **whisper.cpp models** (new, MIT), the voice stack's recogniser (`plan/model-pins-voice.md`).
- **LayerDiffuse** (CreativeML OpenRAIL-M), **IP-Adapter Plus SDXL** (Apache-2.0), **ControlNet Union SDXL ProMax** (Apache-2.0), **Wan 2.2 VACE Fun** (Apache-2.0): weights named in the committed workflows under `art/workflows/` (`layer_xl_transparent_conv`, `ip-adapter-plus_sdxl_vit-h`, `diffusion_pytorch_model_promax`, `wan2.2_fun_vace_*`). [source: LayerDiffusion, "layerdiffusion-v1", https://huggingface.co/api/models/LayerDiffusion/layerdiffusion-v1, read 2026-11-17]; [source: h94, "IP-Adapter", https://huggingface.co/api/models/h94/IP-Adapter, read 2026-11-17]; [source: xinsir, "controlnet-union-sdxl-1.0", https://huggingface.co/api/models/xinsir/controlnet-union-sdxl-1.0, read 2026-11-17]; [source: alibaba-pai, "Wan2.2-VACE-Fun-A14B", https://huggingface.co/api/models/alibaba-pai/Wan2.2-VACE-Fun-A14B, read 2026-11-17]
- Unchanged licences, re-checked the same way: Kokoro-82M Apache-2.0, Chatterbox MIT, SDXL Base 1.0 OpenRAIL++, Pixel Art XL CreativeML OpenRAIL-M, Qwen Image Edit 2511 Apache-2.0, its Lightning LoRA Apache-2.0. [source: Hugging Face API model cards hexgrad/Kokoro-82M, ResembleAI/chatterbox, stabilityai/stable-diffusion-xl-base-1.0, nerijs/pixel-art-xl, Qwen/Qwen-Image-Edit-2511, lightx2v/Qwen-Image-Edit-2511-Lightning, https://huggingface.co/api/models/<repo>, read 2026-11-17]

**Third-party licences** come from `licences/acknowledgements/*.yaml` (one row per licence id, "Covers <repos>"),
titled from each licence text's own heading and linked to `licences/texts/<id>.md` on GitHub (Demucs, which has no
text, links to its spec). A new signed record therefore appears in the credits on the next generator run; a licence
id without a title in the generator's table stops it.

## 5. Open-source projects
Three groups, each row linked to the project's home page (or repository). A licence is shown only where it was
confirmed: the GitHub repository API's SPDX id for Flutter, Dart, Flame, Go, SciPy, python-soundfile, whisper.cpp,
libwebp and OpenSpec, and the npm registry for wrangler 4.151.2 (`MIT OR Apache-2.0`). The API answered
`NOASSERTION` or nothing for the others (CPython, Node.js, Blender, ComfyUI, PyTorch, NumPy, Pillow, FFmpeg, Opus,
ImageMagick, Git, Lua) and Rust is dual-licensed while the API lists one, so those rows show no licence; their pages
state their terms. [source: GitHub, "REST API: get a repository" (`license.spdx_id`, `homepage`) for each repo named
here, https://api.github.com/repos/<owner>/<repo>, read 2026-11-17]; [source: npm, "wrangler 4.151.2",
https://registry.npmjs.org/wrangler/4.151.2, read 2026-11-17]

- Engine and languages: Flutter, Dart, Flame, Lua, Go, Rust, Python, Node.js.
- Art, music and voice pipelines: Blender, ComfyUI, PyTorch, NumPy, SciPy, Pillow, python-soundfile, whisper.cpp,
  FFmpeg, Opus, libwebp, ImageMagick.
- Planning, delivery and hosting: OpenSpec, Git, Cloudflare Workers, Wrangler.

Left out: ollama and stable-diffusion.cpp. The repo has no record of either making a shipped asset (ollama appears
only in research notes; `image.generate` is a host tool with no ledger entry here). Add them when a ledger names
them.

## 6. CC0 sample libraries: "coming"
The score's sample bank (`openspec/changes/adaptive-soundtrack` §11, `plan/sample-bank-pins.md`) is pinned but has not
shipped: no sample was downloaded and the score still plays its synth voices. The five libraries (Big Rusty Drums,
Growlybass, Black And Green Guitars, VCSL, VSCO 2 CE; CC0 1.0 each, per the pins file's read licence files) are
listed under "CC0 sample libraries (coming)". When the bank ships, the generator's section title drops "(coming)".

## 7. Tests
- `test/ending_page_test.dart`: the order (creator, cards, source, models, licences, samples, projects, SDKs); the
  three cards with their icons (an `Image` for Tillandsias, an `Icon` for Fedora and Podman), hosts and URLs in the
  first screen at 360 × 780 and 1280 × 800, the source button and note; every `credits.json` row rendered by key and
  name; the Llama line verbatim and the Demucs name; every signed licence listed; the samples marked coming; every
  project linked; no auto-scroll (10 s with and without reduced motion), drag, Page Down and Home scroll; the beach
  path still reaches the credits and closes.
- `test/song_director_test.dart`: `scoreScenes` includes `credits: credits:dawn`; the credits song is 72 BPM
  (160 000-sample bars), dawn a 4-bar tail into a 16-bar loop, whole four-bar phrases; the cue lands on a bar line,
  is idempotent, and `menu` brings the overture back on a bar line.

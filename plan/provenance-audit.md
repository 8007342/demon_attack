# Provenance audit (2026-11-16)

The rule (operator, 2026-11-16; `CLAUDE.md` §8; spec `development-workflow`, "Research provenance"): every research
conclusion in a spec or plan doc keeps its sources beside it (author or organisation, title, URL or citation, date
read). This audit lists every conclusion that lacked one. Each was re-sourced from a page actually opened, or marked
`UNSOURCED`. No citation was taken from memory or from a search snippet.

**Scope.** `plan/*research*.md` (including `plan/round2-research.md` and `plan/research-source-ledger.md`), every
`openspec/changes/*/design.md` (including the 15 archived on 2026-11-16) and `docs/styleguide/*.md`. Only claims
about the outside world count: facts about other games, perception, film and animation, browsers, tools, models,
licences and statistics. The project's own design decisions don't count, and neither do measurements that name the
repo test or tool that produced them.

**Totals.**

| Part | Files | Found | Re-sourced | Still unsourced | Contradicted by the source found |
|---|---|---:|---:|---:|---|
| R: research docs | `plan/*research*.md`, ledger | 19 | 3 | 16 | none |
| C: design docs (unshared) | 28 `design.md` | 12 | 7 | 5 | C-09 (in part) |
| D: style guides and designs under concurrent work | 2 style guides, 7 `design.md` | 23 | 9 | 14 | D-13, D-15 |
| **All** | | **54** | **19** | **35** | 3 |

**Where the marks are.** R and C citations and `[UNSOURCED: plan/provenance-audit.md#ID]` marks are written inline in
the source docs. The D files (`docs/styleguide/*`, and `bonus-levels`, `boss-grandeur`, `boss-hero-assets`,
`terrain-shadows`, `transition-ascent`, `alien-insignia`, `pwa-install` design) belong to workstreams that were open
when this audit ran, so their citations and marks are listed here only. Applying them inline is task 6.2 of
`guidelines-hardening`.

**Why so many are still unsourced.** On 2026-11-16 most hosts reset connections from the forge: Wikipedia, arXiv,
publishers, GDC Vault, Google's developer sites and PubMed. A row's "candidate" names a likely source that was not
opened. A candidate seen only as a search-result snippet is labelled `unread: snippet only`; it is not a read
source and does not count as re-sourced. Check it from another network before you cite it (task 6.3).

**Contradictions to act on.**
- C-09: `battle-metal-radio-rework` design says every current browser plays Opus. MDN's codec guide says Safari plays
  Opus in `<audio>` only inside CAF, so keep the AAC fallback (`plan/audio-backend.md`).
- D-13, D-15: `pwa-install` design. The Web Install origin trial's end and the other engines' positions are out of
  date (WebKit is opposed; Gecko has no signal).


## Part R

Conclusions checked are approximate counts of the outside-world claims reviewed. Project decisions and repo measurements were skipped.

- plan/atmosphere-research.md: about 38 checked, 6 unsourced
- plan/battle-metal-radio-research.md: 3 checked, 1 unsourced
- plan/endless-design-research.md: 4 checked, 0 unsourced
- plan/gargoyle-army-research.md: about 20 checked, 0 unsourced (all table rows carry URLs; the "Principles extracted" are design inferences from those rows)
- plan/research-original.md: 8 checked, 0 unsourced
- plan/research-source-ledger.md: about 24 checked, 8 unsourced
- plan/swarm-research.md: about 34 checked, 3 unsourced
- plan/transition-research.md: 3 checked, 0 unsourced
- plan/round2-research.md: about 9 checked, 1 unsourced

Access note: on 2026-11-16 WebFetch and curl got connection resets from almost every host (Wikipedia, arXiv, Nature, Springer, PNAS, GDC Vault, gamedeveloper.com, MathWorld, Britannica, archive.org). Only github.com, raw.githubusercontent.com, pypi.org, developer.mozilla.org, learn.microsoft.com, docs.flutter.dev and w3.org answered. Search snippets were not accepted as sources. Rows marked "candidate" name a likely source that was **not opened**. Check it before citing it.

| ID | File:line | Conclusion | Status | Source or note |
|---|---|---|---|---|
| <a id="R-01"></a>R-01 | plan/atmosphere-research.md:11-14 | Koschmieder law, visual range `−ln ε/β`, per-channel extinction makes distance blue, sun-aware fog warms | UNSOURCED | The source list has only "Tarel & Hautière (Koschmieder)", with no title or year. Quilez, "Better fog" (unread: snippet only). Candidate: Narasimhan & Nayar IJCV 2002 (already in the list). Not opened. |
| <a id="R-02"></a>R-02 | plan/atmosphere-research.md:26 | Ori blends fog colour and value over depth and uses non-linear depth of field | UNSOURCED | "Ori developer posts (Polycount)" names no author, title or URL. |
| <a id="R-03"></a>R-03 | plan/atmosphere-research.md:54 | Screen scroll and scale both ≈ 1/distance under perspective | UNSOURCED | Microsoft Learn "Projection Transform (Direct3D 9)" was opened, but its text does not state the 1/z relation outright, so it was not used. |
| <a id="R-04"></a>R-04 | plan/atmosphere-research.md:74 | Near-stillness (low parallax) reads as large size and distance | UNSOURCED | Tagged [inference] in the doc. This is the motion-parallax depth cue, but no perception source was reachable. |
| <a id="R-05"></a>R-05 | plan/atmosphere-research.md:107 | Saber's Swarm Engine: group motion when far, per-agent flocking when near | UNSOURCED | "Saber Swarm Engine coverage" is not a citation. |
| <a id="R-06"></a>R-06 | plan/atmosphere-research.md:130-131 | Lemniscate of Bernoulli parametric form | UNSOURCED | Only Gerono has a listed source. Candidate: Wikipedia "Lemniscate of Bernoulli". Not reachable. |
| <a id="R-07"></a>R-07 | plan/battle-metal-radio-research.md:15 | Browser audio can be resumed by a user gesture | RE-SOURCED | Mozilla/MDN, "Autoplay guide for media and Web Audio APIs", https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay. It says Web Audio started outside a user-input handler is subject to autoplay rules, and that user interaction can change the policy. |
| <a id="R-08"></a>R-08 | plan/research-source-ledger.md:13 | Half-Life 2 and Portal teach mechanics in zero-threat rooms before mastery | UNSOURCED | The row's only source is the Portal postmortem. Nothing supports the Half-Life 2 half. The GDC Vault/steamstatic PDF was unreachable. |
| <a id="R-09"></a>R-09 | plan/research-source-ledger.md:19 | Atari Star Wars (1983): flight yoke, wireframe display, first-person vector crosshair | UNSOURCED | Partly supported only. MAMEdev `src/mame/atari/starwars.cpp` (https://github.com/mamedev/mame/blob/master/src/mame/atari/starwars.cpp, opened) shows vector-display hardware and a 2-axis analog stick. It does not name a yoke or a crosshair. |
| <a id="R-10"></a>R-10 | plan/research-source-ledger.md:19 | Ikari Warriors: 12-way rotary aim independent of the 8-way movement stick | RE-SOURCED | MAMEdev, `snk.cpp`, https://github.com/mamedev/mame/blob/master/src/mame/snk/snk.cpp: ikari input ports are 8-way joystick plus `IPT_POSITIONAL PORT_POSITIONS(12)`, and the comment says "The rotary joystick is a mechanical 12-way positional switch". This is emulator source, not a manual. |
| <a id="R-11"></a>R-11 | plan/research-source-ledger.md:20 | Phoenix and Gradius bosses use multi-core/layered shielding | UNSOURCED | No reachable source. |
| <a id="R-12"></a>R-12 | plan/research-source-ledger.md:20 | Ikaruga uses polarity toggling; Radiant Silvergun bosses carry dozens of part-score bonuses | UNSOURCED | Wikipedia was unreachable. The Radiant Silvergun "dozens of limb score bonuses" detail looks shaky and needs a check. |
| <a id="R-13"></a>R-13 | plan/research-source-ledger.md:21 | Galaga boss captures a fighter by tractor beam; rescuing it gives a dual fighter | UNSOURCED | Candidates: Wikipedia "Galaga" and the Namco/Nintendo NES Classic manual PDF (ohp.nintendo.co.jp). Both unreachable. |
| <a id="R-14"></a>R-14 | plan/research-source-ledger.md:29 | Background motion of 2–6 px/s stays below conscious saccadic distraction | UNSOURCED | The only source is the sibling `ranitas` doc. No primary psychophysics source is given for the numbers. |
| <a id="R-15"></a>R-15 | plan/research-source-ledger.md:29 | Perlin quintic fade `6t⁵−15t⁴+10t³` with zero first and second derivatives at the ends | UNSOURCED | The only attribution is via ranitas. Candidate: Perlin, "Improving Noise", SIGGRAPH 2002. Not reachable. (The derivative property holds mathematically.) |
| <a id="R-16"></a>R-16 | plan/swarm-research.md:72 | Phones run a Dart MLP about 3–5× slower than desktop | UNSOURCED | The doc's own estimate, and atrapa notes that phones were not measured. Measure it or cite a benchmark. |
| <a id="R-17"></a>R-17 | plan/swarm-research.md:185 | Later studies dispute how general Lévy-flight foraging is | UNSOURCED | Candidate: Edwards et al., Nature 449 (2007), "Revisiting Lévy flight search patterns…". Not opened. |
| <a id="R-18"></a>R-18 | plan/swarm-research.md:197-198 | Fish-school "fountain effect" (split around the predator, rejoin behind it) | UNSOURCED | Pitcher & Parrish are named with no title. The doc itself says "not checked here". |
| <a id="R-19"></a>R-19 | plan/round2-research.md:25 | bpy 5.3 needs Python 3.13; about a 430 MB download | RE-SOURCED | Blender Foundation via PyPI, "bpy 5.3.0" JSON metadata, https://pypi.org/project/bpy/5.3.0/: `requires_python ==3.13.*`, manylinux x86_64 wheel 427,524,100 bytes. |

Totals: 19 found, 3 re-sourced, 16 still unsourced. No contradictions were confirmed. Possible issue not counted: research-source-ledger.md:18 titles Cianciolo's talk "Seamless Transitions from Cutscenes to Gameplay in Mortal Kombat" (gdcvault 1014652). swarm-research.md:114 cites the same speaker as "The Cinematics of…", GDC Europe 2011, with a slides URL. GDC Vault was unreachable, so neither title could be checked.


## Part C

Scope: 13 archived `openspec/changes/archive/2026-11-16-*/design.md` files (`comms-radio-v3` and `sprite-64-grid-overhaul` have no design.md) plus 15 active change design files. Claims sourced through a referenced plan file that carries the source (for example `plan/swarm-research.md`, `plan/gargoyle-army-research.md`, `plan/atmosphere-research.md`, `plan/transition-research.md`, `plan/hint-usability.md`) are not listed.

- archive/2026-11-16-add-ground-forces-homing/design.md: 0 checked, 0 unsourced
- archive/2026-11-16-add-terrain-relief/design.md: 1 checked, 1 unsourced (C-01, re-sourced)
- archive/2026-11-16-balance-five-tour-campaign/design.md: 2 checked (hint research is in plan/hint-usability.md), 1 unsourced (C-02, re-sourced)
- archive/2026-11-16-build-demon-attack-game/design.md: 1 checked, 1 unsourced (C-03, re-sourced)
- archive/2026-11-16-combine-powerups/design.md: 0 checked, 0 unsourced
- archive/2026-11-16-console-runs-final-ending/design.md: 1 checked, 1 unsourced (C-04)
- archive/2026-11-16-deepen-sector-campaign/design.md: 0 checked, 0 unsourced
- archive/2026-11-16-gameplay-round-3/design.md: 0 checked, 0 unsourced
- archive/2026-11-16-ground-forces-rework/design.md: 3 checked (StarCraft and swarm-faction claim is sourced through the gargoyle-ground-army research), 2 unsourced (C-05 re-sourced, C-06)
- archive/2026-11-16-ground-war-v4/design.md: 0 checked, 0 unsourced
- archive/2026-11-16-local-image-ship-asset-pipeline/design.md: 0 checked, 0 unsourced
- archive/2026-11-16-smooth-level-progression/design.md: 1 checked (plan/transition-research.md), 0 unsourced
- archive/2026-11-16-tune-ground-war-front/design.md: 0 checked, 0 unsourced
- demon-intelligence/design.md: 4 checked (Karamouzas, Zanac ALC and Battle Garegga are sourced in plan/swarm-research.md), 1 unsourced (C-07)
- continuous-swarm/design.md: 7 checked (Lévy, Couzin, Hemelrijk, Procaccini, k = 7 topological, Booth and ALC are all sourced in plan/swarm-research.md), 0 unsourced
- cinematic-flow/design.md: 6 checked (Cianciolo, Swink, Storms, Lendino/NES attract, macron.dev and juice are sourced in plan/swarm-research.md), 0 unsourced
- ground-terrain-interaction/design.md: 0 checked, 0 unsourced
- gargoyle-ground-army/design.md: 2 checked (waterspout and swarm factions are sourced in plan/gargoyle-army-research.md), 0 unsourced
- ground-blocks-runtime/design.md: 0 checked, 0 unsourced
- ground-presentation-tuning/design.md: 0 checked, 0 unsourced
- fog-restoration/design.md: 0 checked, 0 unsourced
- ground-easter-eggs/design.md: 0 checked, 0 unsourced
- atmosphere-and-swarms/design.md: 1 checked (grounded in plan/atmosphere-research.md, which has a Sources section), 0 unsourced
- ux-declutter/design.md: 0 checked, 0 unsourced
- battle-metal-radio-rework/design.md: 4 checked (the kumbia-kombat inspection names a commit), 3 unsourced (C-08; C-09 and C-10 re-sourced)
- comms-middle-ground/design.md: 0 checked, 0 unsourced
- add-asset-review-studio/design.md: 1 checked, 1 unsourced (C-11)
- asset-review-progression/design.md: 1 checked, 1 unsourced (C-12, re-sourced)

| ID | File:line | Conclusion | Status | Source or note |
| --- | --- | --- | --- | --- |
| <a id="C-01"></a>C-01 | openspec/changes/archive/2026-11-16-add-terrain-relief/design.md:6 | Park–Miller hashing kept below 2^53 so the Dart VM and the web (JS doubles) agree | RE-SOURCED | MDN, "Number.MAX_SAFE_INTEGER", https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER, read 2026-11-16 |
| <a id="C-02"></a>C-02 | openspec/changes/archive/2026-11-16-balance-five-tour-campaign/design.md:19 | localStorage holds JSON without sending it with HTTP requests as cookies do | RE-SOURCED | MDN, "Using HTTP cookies" ("Cookies are sent with every request…"; Web Storage recommended), https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Cookies, read 2026-11-16 |
| <a id="C-03"></a>C-03 | openspec/changes/archive/2026-11-16-build-demon-attack-game/design.md:15 (also :21) | Browser autoplay rules need a user action (Start) before Web Audio sounds | RE-SOURCED | MDN, "Autoplay guide for media and Web Audio APIs", https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay, read 2026-11-16 |
| <a id="C-04"></a>C-04 | openspec/changes/archive/2026-11-16-console-runs-final-ending/design.md:28 | kumbia-kombat's /console names every option, labels items and separates review links | UNSOURCED | Sibling repo described by file paths only, with no commit or URL. Not fetched, so the project's identity was not sent to an outside service. Fix: add the commit hash, as battle-metal-radio-rework does |
| <a id="C-05"></a>C-05 | openspec/changes/archive/2026-11-16-ground-forces-rework/design.md:53 | Qwen-Image-Edit-2511 can redraw from several reference images (multi-reference) | RE-SOURCED | Qwen, "Qwen/Qwen-Image-Edit-2511" model card (`"image": [image1, image2]`), https://huggingface.co/Qwen/Qwen-Image-Edit-2511, read 2026-11-16 |
| <a id="C-06"></a>C-06 | openspec/changes/archive/2026-11-16-ground-forces-rework/design.md:53 | Wan2.2 VACE draws in-betweens from a reference image plus a control clip | UNSOURCED | Only Wan-AI's "Wan2.1-VACE-14B" card was verified (reference images, pose/depth conditioning: https://huggingface.co/Wan-AI/Wan2.1-VACE-14B). No Wan2.2 VACE page was opened |
| <a id="C-07"></a>C-07 | openspec/changes/demon-intelligence/design.md:11 | 40 × 18k MACs per frame costs 1–4 ms on a phone | UNSOURCED | plan/swarm-research.md:72 calls it an estimate ("3–5× slower than desktop") with no source or measurement. Fix: measure on the operator's phone or cite a benchmark |
| <a id="C-08"></a>C-08 | openspec/changes/battle-metal-radio-rework/design.md:4 | DragonForce's music is defined by pacing, instrumental virtuosity and long crescendos | UNSOURCED | No source in the repo. Wikipedia and music-press pages reset the connection on every try, so nothing could be verified |
| <a id="C-09"></a>C-09 | openspec/changes/battle-metal-radio-rework/design.md:27 | Current browsers can play Opus, so no AAC fallback is required | RE-SOURCED (contradicts in part) | MDN, "Web audio codec guide", https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Audio_codecs, read 2026-11-16: Safari plays Opus in `<audio>` only in a CAF file. Search results claim Safari 18.4 added Ogg Opus (unread: snippet only); no primary page could be opened. plan/audio-backend.md:11 still ships AAC "for browsers that cannot decode Ogg Opus" |
| <a id="C-10"></a>C-10 | openspec/changes/battle-metal-radio-rework/design.md:29 | Browser-decoded audio is much larger than the Opus files | RE-SOURCED | MDN, "AudioBuffer" (non-interleaved 32-bit float linear PCM), https://developer.mozilla.org/en-US/docs/Web/API/AudioBuffer, read 2026-11-16 |
| <a id="C-11"></a>C-11 | openspec/changes/add-asset-review-studio/design.md:7 | kumbia-kombat's console notes key each note by a stable reference and name the source file | UNSOURCED | Sibling repo with no commit, path or URL. Not fetched, for privacy (see C-04) |
| <a id="C-12"></a>C-12 | openspec/changes/asset-review-progression/design.md:8 | FLUX-schnell runs without CFG and largely ignores negative prompts | RE-SOURCED | Hugging Face, "Flux" (Diffusers docs): schnell "`guidance_scale` needs to be 0"; `negative_prompt` is "ignored if `true_cfg_scale` is not greater than 1", https://huggingface.co/docs/diffusers/main/en/api/pipelines/flux, read 2026-11-16 |

**Totals:** found 12, re-sourced 7, still unsourced 5 (C-04, C-06, C-07, C-08, C-11). One claim contradicted in part: C-09.


## Part D

- docs/styleguide/alien-capital-ships.md: 4 conclusions checked, 4 unsourced
- docs/styleguide/alien-troops.md: 2 conclusions checked, 2 unsourced
- openspec/changes/boss-grandeur/design.md: 0 conclusions needing a source (its research basis is `plan/round2-research.md` §3–4; the rest is the project's own design, geometry, or in-repo measurements that name their tests), 0 unsourced
- openspec/changes/boss-hero-assets/design.md: 3 checked (the macron.dev rules, the "three eyes" fix, bpy 5.3 on Python 3.13), all sourced through `plan/round2-research.md` §1.2 and §2.2 and the in-repo `tools/boss_rig/bpy_smoke.py`, 0 unsourced
- openspec/changes/bonus-levels/design.md: 2 checked, 2 unsourced
- openspec/changes/terrain-shadows/design.md: 0 conclusions needing a source (all own design or measured with named tests), 0 unsourced
- openspec/changes/transition-ascent/design.md: 1 checked, 1 unsourced
- openspec/changes/alien-insignia/design.md: 1 checked, 1 unsourced found (since re-sourced)
- openspec/changes/pwa-install/design.md: 14 checked (13 claims, plus the §1 browser matrix, which is already sourced at :25–26 by MDN BCD and Chrome's "Revisiting Chrome's installability criteria"); 13 unsourced found, 8 of them since re-sourced

Network note: from this forge, Google-hosted pages (developer.chrome.com, web.dev, chromestatus.com, the Chrome docs), PubMed, Crossref, Wikipedia and most publisher sites returned connection resets. groups.google.com, MDN and api.flutter.dev/docs.flutter.dev could be opened. A claim whose only candidate source sat on an unreachable host stays UNSOURCED. Where a search found a likely candidate I could not open, the note names it so it can be checked from another network.

| ID | File:line | Conclusion (short paraphrase, ≤ 20 words) | Status | Source or note |
|---|---|---|---|---|
| <a id="D-01"></a>D-01 | docs/styleguide/alien-capital-ships.md:18–22 | StarCraft, Star Wars and Star Trek capital ships show mass through layered decks, detail dense at the prow, oversized silhouettes | UNSOURCED | No specific ships, images or art books named. Cite the concrete reference images or art books, or present it as the project's own reading |
| <a id="D-02"></a>D-02 | docs/styleguide/alien-capital-ships.md:40–41 | Grown surfaces (scale, sinew, bone, no metal or panel lines) are the fastest read of "alien" at phone size | UNSOURCED | Perception claim with no study or test behind it. Either cite one or reword it as a design choice |
| <a id="D-03"></a>D-03 | docs/styleguide/alien-capital-ships.md:70–71 | Stacked terraces as silhouette edges let the eye read height and distance even in flat light | UNSOURCED | Rests on occlusion as a depth cue. No perception source found that I could open |
| <a id="D-04"></a>D-04 | docs/styleguide/alien-capital-ships.md:74–75 | Swept-back spikes read as danger and speed; spikes aimed at the viewer read as threat | UNSOURCED | Candidate (unread: snippet only; PubMed and MGH hosts reset): Bar & Neta, "Humans prefer curved visual objects", Psychological Science 17(8) 645–648, 2006 (sharp contours convey threat). That paper covers threat only, not "speed" |
| <a id="D-05"></a>D-05 | docs/styleguide/alien-troops.md:46 | At small sizes, status reads by silhouette and colour first, fine detail last | UNSOURCED | Rests on preattentive-feature research. No source found that I could open. The in-repo 40 px downscale check is a measurement, not a source for the general principle |
| <a id="D-06"></a>D-06 | docs/styleguide/alien-troops.md:58 | Human militaries mark rank with chevrons, bars and stars | UNSOURCED | Common knowledge, but the reference page I tried (defense.gov insignia) would not open |
| <a id="D-07"></a>D-07 | openspec/changes/bonus-levels/design.md:48 | Most runs end in the first or second tour | UNSOURCED | A statistic about this game's players with no tool, test or data named. Cite the measurement (calibration or telemetry) or mark it as an assumption |
| <a id="D-08"></a>D-08 | openspec/changes/bonus-levels/design.md:355 | Reading time 0.5 s + 0.27 s per word (≈ 222 wpm) is enough to read a silent card line | UNSOURCED | Candidate (unread: snippet only; every host reset): Brysbaert, "How many words do we read per minute? A review and meta-analysis of reading rate", Journal of Memory and Language 109, 104047, 2019 (≈ 238 wpm silent non-fiction). Verify, then cite |
| <a id="D-09"></a>D-09 | openspec/changes/transition-ascent/design.md:27–28 | Rotating the ground plane about the horizon (near rows faster) reads as the ship climbing, not the picture moving | UNSOURCED | Self-motion from optic flow and motion parallax. No source opened. The doc's own check is the operator's phone playtest (:110) |
| <a id="D-10"></a>D-10 | openspec/changes/alien-insignia/design.md:113 | A colour matrix cannot threshold on luma | RE-SOURCED | [source: Flutter (Google), "ColorFilter.matrix constructor" (dart:ui API docs), https://api.flutter.dev/flutter/dart-ui/ColorFilter/ColorFilter.matrix.html, read 2026-11-16] (one fixed linear transform per pixel, so no conditionals) |
| <a id="D-11"></a>D-11 | openspec/changes/pwa-install/design.md:23 | Android WebView and in-app browser hosts rarely install PWAs | UNSOURCED | "Listed as supported" is covered by BCD (:25). "Hosts rarely install" has no source |
| <a id="D-12"></a>D-12 | openspec/changes/pwa-install/design.md:28–31 | Web Install API: DevTrial from 139, desktop origin trial 143–148, Intent to Ship Sept 2026 for desktop M156, Android later, no WebView | RE-SOURCED | [source: Lia Hiscock (Microsoft) on blink-dev, "Intent to Ship: Web Install API", https://groups.google.com/a/chromium.org/d/msgid/blink-dev/dc40448e-61c3-468f-929c-b17bfa21771fn%40chromium.org, read 2026-11-16] (posted 2026-09-21; LGTM from Rick Byers 2026-09-30) |
| <a id="D-13"></a>D-13 | openspec/changes/pwa-install/design.md:29–30 | Web Install API origin trial "extended through 153" | RE-SOURCED | **Partly contradicted.** The April request asked for 153: [source: Lia Hiscock (Microsoft) on blink-dev, "Intent to Extend Experiment: Web Install API", https://groups.google.com/a/chromium.org/g/blink-dev/c/jsXI0W8R3Dc, read 2026-11-16] (2026-04-03; no approval visible). The later Intent to Ship (D-12) lists both extensions as ending in 150. Reword to "extension to 153 requested; the Intent to Ship lists 150" |
| <a id="D-14"></a>D-14 | openspec/changes/pwa-install/design.md:30 | The `<install>` element has its own origin trial, Chrome 148–153 | RE-SOURCED | [source: Lia Hiscock on blink-dev, "Intent to Ship: HTML install element", https://groups.google.com/a/chromium.org/g/blink-dev/c/nrQTNUDm3QI/m/4OA9Cl2eAgAJ, read 2026-11-16] (desktop origin trial 148–153, ship planned for 156) |
| <a id="D-15"></a>D-15 | openspec/changes/pwa-install/design.md:31–32 | Safari and Firefox have not announced the Web Install API | RE-SOURCED | **Contradicted.** The Intent to Ship (D-12) records WebKit (Safari) as *Opposed* (installation should start in browser UI) and Gecko (Firefox) as *No signal*. Reword to match |
| <a id="D-16"></a>D-16 | openspec/changes/pwa-install/design.md:42–45 | Chromium installability needs HTTPS or localhost, a manifest with name or short_name, 192 and 512 px icons, start_url, display, and prefer_related_applications not true | RE-SOURCED | [source: MDN, "Making PWAs installable", https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable, read 2026-11-16] (MDN does not list the allowed `display` values; Chrome's own criteria page was unreachable) |
| <a id="D-17"></a>D-17 | openspec/changes/pwa-install/design.md:46–47 | Since Chrome 108 (Android) and 112 (desktop) menu install needs no service worker; the prompt still wants a fetch handler | UNSOURCED | Probably from the Chrome article cited at :26, but developer.chrome.com reset every request, so I could not open it. Once verified, repeat that citation here |
| <a id="D-18"></a>D-18 | openspec/changes/pwa-install/design.md:47–49 | Flutter's default `flutter_service_worker.js` is a deprecated cleanup worker that unregisters itself | RE-SOURCED | [source: David Iglesias Teixeira (Flutter team), "Web: Default Service Worker implementation getting removed.", https://groups.google.com/g/flutter-announce/c/0Vv-j_TyrdI, read 2026-11-16] and [source: Flutter, "Web FAQ" (service worker section), https://docs.flutter.dev/platform-integration/web/faq, read 2026-11-16]. The version "3.47" is not confirmed by either source |
| <a id="D-19"></a>D-19 | openspec/changes/pwa-install/design.md:50–51 | Chromium fires `beforeinstallprompt` only after the user has interacted with the page | UNSOURCED | Chrome's engagement-heuristic page was unreachable. MDN does not support the claim: it says the event "usually happens on page load" and names no engagement condition ([source: MDN, "Window: beforeinstallprompt event", https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeinstallprompt_event, read 2026-11-16]) |
| <a id="D-20"></a>D-20 | openspec/changes/pwa-install/design.md:60–61 | Calling `preventDefault()` on the event stops the browser's own install UI (mini-infobar) | RE-SOURCED | [source: MDN, "Window: beforeinstallprompt event", https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeinstallprompt_event, read 2026-11-16] ("prevents the browser displaying its own install UI on some platforms". MDN does not use the word mini-infobar) |
| <a id="D-21"></a>D-21 | openspec/changes/pwa-install/design.md:68 | A cache-first service worker makes deploys stale | UNSOURCED | Service-worker caching behaviour with no source cited. None opened |
| <a id="D-22"></a>D-22 | openspec/changes/pwa-install/design.md:72–73 | Registering Flutter's worker at the same root scope would replace `/sw.js` | RE-SOURCED | [source: MDN, "ServiceWorkerContainer: register() method", https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerContainer/register, read 2026-11-16] (one registration per scope; a second `register()` updates it with the new script URL) |
| <a id="D-23"></a>D-23 | openspec/changes/pwa-install/design.md:105–106 | In an incognito profile Chromium never installs or fires `beforeinstallprompt` | UNSOURCED | CDP's `in-incognito` installability error is an in-repo measurement. "Never fires the event" goes beyond that measurement and has no source |

### Totals
- Conclusions found that need a source: 23
- Re-sourced: 9 (D-10, D-12, D-13, D-14, D-15, D-16, D-18, D-20, D-22; D-13 and D-15 with corrections)
- Still unsourced: 14 (D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-09, D-11, D-17, D-19, D-21, D-23)
- Contradicted by their source: D-15 (WebKit is Opposed, not silent) and D-13 (the Intent to Ship lists the origin-trial extensions ending in 150, not 153)


## Part CRE: the carrier rendering engine (`carrier-render-engine`, 2026-11-16)
Our own engineering choices in `plan/carrier-render-engine-research.md` and
`openspec/changes/carrier-render-engine/design.md`. No source states them; each is checked by a repo test or sheet
where one is named.

| ID | Where | Claim | Status | Check |
|---|---|---|---|---|
| <a id="CRE-1"></a>CRE-1 | research D4; design §2.1 | One indexed mesh over one composite cannot open a seam, because adjacent triangles share vertices; per-layer warps drift because each layer has its own copy of shared edges | UNSOURCED | `test/carrier_render_engine_test.dart` ("one surface", "rigid") |
| <a id="CRE-2"></a>CRE-2 | research D14 | Grid density for the hull (the research guessed 12 × 10 cells; the runtime keeps carrier-v3's 20-unit grid) | UNSOURCED | vertex counts in `test/carrier_bend_test.dart` |
| <a id="CRE-3"></a>CRE-3 | research D18, D20 | Bend amplitude and timing for a rigid read (small, slow, eased, no wobble) | UNSOURCED | the carrier-v3 limits; `art/contact/carrier-render-engine-bend*.{png,gif}` |
| <a id="CRE-4"></a>CRE-4 | research X11; design §3.5 | Off-screen policy: every piece stays bound to its body and is cut from one composite of the whole hull | UNSOURCED | "Off-screen parts" scenario; `art/contact/carrier-render-engine-collapse*.{png,gif}` |
| <a id="CRE-5"></a>CRE-5 | research X12; design §3.1–§3.4 | Collapse tiers and numbers (sections, then chunks; the timeline, kicks, spins, gravity, depth scale) | UNSOURCED | `test/carrier_render_engine_test.dart` (hierarchy, continuity, cohesion) |
| <a id="CRE-6"></a>CRE-6 | research F5; design §4 | Shield wear mapping: fixed footprint, width and alpha by the shield, growing gaps, local crackle | UNSOURCED | `test/carrier_render_engine_test.dart` (wear, dropout, offset); `art/contact/carrier-render-engine-field.png` |
| <a id="CRE-7"></a>CRE-7 | research P3; design §2.2 | Texture memory arithmetic (RGBA8 at 4 bytes per pixel) and the 2 px/unit, ≤ 2,048 px cap | UNSOURCED | `compositeBytes` printed by the review test |

## Part W: dynamic-weather (added 2026-11-16)

| ID | File:line | Conclusion | Status | Source or note |
|---|---|---|---|---|
| <a id="W-01"></a>W-01 | plan/dynamic-weather-research.md, conclusion 3 | Rain drawn under the play (and its dimming) keeps bullets and creatures readable | UNSOURCED | No read source measures rain density against gameplay readability. PC Gamer, 80.lv and Tatarchuk 2006 were unreachable (unread: snippet only). Checked instead on `art/contact/dynamic-weather-tiers.png` |

## Part V: voice-stack (added 2026-11-16)

| ID | File:line | Conclusion | Status | Source or note |
|---|---|---|---|---|
| <a id="V-01"></a>V-01 | plan/voice-stack-research.md §4, finding 2 | Rendering a short non-verbal inside a carrier phrase or a multi-cue reel, then cutting it, avoids Dia's unnatural short clips | UNSOURCED | A working assumption from Dia's own note that clips under about 5 s sound unnatural; to be tested in the voice-stack pilot (task 6.1) |
| <a id="V-02"></a>V-02 | plan/voice-stack-research.md §5; openspec/changes/voice-stack/design.md §5 | Integrated loudness is gated over 400 ms blocks, so a very short stinger has few or no complete blocks | UNSOURCED | ITU-R BS.1770 (itu.int) and EBU Tech 3341 (tech.ebu.ch) reset the connection. The 400 ms momentary meter is sourced from libebur128 |
| <a id="V-03"></a>V-03 | plan/voice-stack-research.md §5 | Game loudness targets of about −18 LUFS / −1 dBTP for mobile and −24 LUFS for console | UNSOURCED | Audiokinetic and GANG IESD pages seen as search snippets only (audiokinetic.com, audiogang.org, aes.org blocked) |

## Part CH: the carrier hatch cascade and component break-up (`carrier-hatches`, 2026-11-16)
Our own engineering choices in `plan/carrier-hatches-research.md` and `openspec/changes/carrier-hatches/design.md`.
No source states them; each is checked by the test or sheet named once the change is implemented.

| ID | Where | Claim | Status | Check |
|---|---|---|---|---|
| <a id="CH-1"></a>CH-1 | design §A2 | Tier counts per tour (2/2/3/3/4 upper, plus the deck and maw tiers), the hatch positions, and their visibility at zoom 0.86 | UNSOURCED | `test/carrier_hatches_test.dart` (counts, visibility); `art/contact/carrier-hatches-cascade.png` |
| <a id="CH-2"></a>CH-2 | design §A3 | Upper tiers drop at shield-cell thresholds (6, 0 / 9, 6, 0 / 9, 6, 3, 0); the deck tier at shield 0, the maw tier at the last form | UNSOURCED | `test/carrier_hatches_test.dart` (thresholds); calibration gates |
| <a id="CH-3"></a>CH-3 | design §A10 | The cascade chase and the ember arming as the telegraph of the next tier; the 1.0 s drop | UNSOURCED | `art/contact/carrier-hatches-cascade.{png,gif}` |
| <a id="CH-4"></a>CH-4 | design §A4–§A6, §A11 | Arrival invariance (the lead `transit − 0.55`), the transit line at y + 40, the deck and maw hold of at most one door period, and the order of the calibration levers | UNSOURCED | arrival-invariance test; `test/boss_endurance_test.dart`, `test/campaign_playtest_test.dart`; `plan/calibration-current.md` |
| <a id="CH-5"></a>CH-5 | design §B3 | Transition composites: the before-texture stays resident for +4–7 MB during a transition; at most 15 composes per fight | UNSOURCED | `compositeBytes` and the `composites` counter in the review test |
| <a id="CH-6"></a>CH-6 | design §B4 | The release schedule: at most a quarter of a transition's components (≥ 2) per 0.25 s, ≥ 1.2 s per transition, outer first, 35 % at the armour shed, shield thresholds for the shed, impact-triggered early releases | UNSOURCED | `test/carrier_breakup_test.dart` (rate rule); `art/contact/carrier-hatches-breakup.{png,gif}` |
| <a id="CH-7"></a>CH-7 | design §B9 | The component-id page and manifest add ≤ 1.5 MB per hull | UNSOURCED | `rigsheet budget` after the component pass |
| <a id="CH-8"></a>CH-8 | design §B5 | Body constants per size class (kick, spin, gravity, life, shrink 0.45, the root tear of 8–20° over 0.15–0.35 s, fragments at 0.25–0.7 s) | UNSOURCED | `test/carrier_breakup_test.dart` (continuity, bounds); the break-up sheet |

## Part E: the end-game cinematic (`endgame-cinematic`, added 2026-11-16)

`plan/endgame-cinematic-research.md` marks these 33 claims `[UNSOURCED: plan/provenance-audit.md#<id>]`. Ids
`endgame-coats` to `endgame-flutterweb` are Part A (craft); the rest are Part B (pipeline). Most hosts that would
source Part A were blocked by the forge proxy on 2026-11-16 (Wikipedia, ted.com, npr.org, pixar.com, khanacademy.org,
the animation trade sites), as were blender.org, gnu.org, webkit.org and copyright.gov for Part B. Nothing was routed
around the proxy. Five Stack Exchange answers were read through the site's public API, not as pages; claims resting
only on them are counted here as unsourced. The rules the change draws from these claims are its own design
decisions and do not depend on the attributions.

| Id | Claim | Why unsourced |
|---|---|---|
| <a id="endgame-coats"></a>endgame-coats | The 22 rules are Emma Coats's personal 2011 tweets, not an official Pixar document | snippets only |
| <a id="endgame-spine"></a>endgame-spine | Kenn Adams created the story spine in 1991 for improv; Pixar adopted it later | snippet only |
| <a id="endgame-stanton"></a>endgame-stanton | Stanton's "2+2": give the audience the parts, not the sum | from memory; snippet did not show it |
| <a id="endgame-illusion"></a>endgame-illusion | The twelve principles originate in Thomas and Johnston, "The Illusion of Life" (1981) | snippet only; definitions themselves are read |
| <a id="endgame-dream"></a>endgame-dream | Why "all a dream" feels cheap, and when it works | api-read and snippet only |
| <a id="endgame-twist"></a>endgame-twist | A twist must improve the story and its truth must be present from the start | api-read only |
| <a id="endgame-plants"></a>endgame-plants | Rewatch bonus; techniques for hiding a plant in plain sight | api-read only |
| <a id="endgame-precedents"></a>endgame-precedents | The LEGO Movie, Toy Story 3 opening, Costume Quest, Stick of Truth as described | memory and snippets |
| <a id="endgame-spoiler"></a>endgame-spoiler | Leavitt and Christenfeld (2011): knowing the ending did not reduce enjoyment | snippet only |
| <a id="endgame-density"></a>endgame-density | Any number for plant density (R-A4.3 is a design choice) | no source found |
| <a id="endgame-asl"></a>endgame-asl | Average shot length figures; the 3.5 s average in R-A5.1 is a design choice | snippet only |
| <a id="endgame-eyetrace"></a>endgame-eyetrace | Murch's rule of six and eye-trace (R-A5.6's one-sixth figure is a design choice) | snippet only |
| <a id="endgame-table"></a>endgame-table | Blocking a table scene with seated children and passing adults (R-A5.4, 5.5, 5.8) | inference, no source |
| <a id="endgame-tiltshift"></a>endgame-tiltshift | Shallow focus front and back reads as miniature | api-read only |
| <a id="endgame-transitions"></a>endgame-transitions | Rack focus, dolly-out and crane-up reveals, whip pan, pull-back-to-reveal gag | no source read |
| <a id="endgame-worldizing"></a>endgame-worldizing | Murch's worldizing; the sound-bridge practice in R-A9.1 to R-A9.3 beyond the J/L definitions | snippet only |
| <a id="endgame-flutterweb"></a>endgame-flutterweb | How Flutter web maps the browser's `prefers-reduced-motion` to `disableAnimations` | not stated on the page read |
| <a id="endgame-quality-judgement"></a>endgame-quality-judgement | No local route reaches feature-film character animation; the list of consistency problems of generated video | our judgement, backed in part by repo evidence cited in place |
| <a id="endgame-mpfb-features"></a>endgame-mpfb-features | MPFB2 offers rigs, face shapes, clothes and child phenotypes | its documentation site is blocked; the README does not list features |
| <a id="endgame-hbm-cc0"></a>endgame-hbm-cc0 | Human Base Meshes is CC0, 49 MB, v1.4.1, with stylised meshes | search snippet only; blender.org blocked |
| <a id="endgame-rigify"></a>endgame-rigify | Rigify is bundled with Blender and generates a control rig from a meta-rig | docs.blender.org blocked |
| <a id="endgame-blender-output"></a>endgame-blender-output | Blender's licence does not cover renders made with it | blender.org blocked |
| <a id="endgame-gpl-output"></a>endgame-gpl-output | A GPL tool's licence (Blender, x264, ffmpeg) does not reach its output | gnu.org blocked |
| <a id="endgame-ai-copyright"></a>endgame-ai-copyright | How far generated images are protected by copyright | copyright.gov blocked; a legal question |
| <a id="endgame-ltx-terms"></a>endgame-ltx-terms | The commercial terms of the LTX-Video and LTX-2 licences | only the cards were read |
| <a id="endgame-svd-terms"></a>endgame-svd-terms | The commercial terms of the Stability community licence | stability.ai not fetched (blocked in `plan/voice-stack-research.md`) |
| <a id="endgame-layered-comfy"></a>endgame-layered-comfy | Qwen-Image-Layered runs with core ComfyUI nodes | inferred from the Comfy-Org repack; docs.comfy.org blocked |
| <a id="endgame-ios-gesture"></a>endgame-ios-gesture | iOS needs `playsinline` and a user gesture for video with sound | webkit.org blocked |
| <a id="endgame-lipsync"></a>endgame-lipsync | Envelope-timed mouth poses are good enough at this shot size | untested |
| <a id="endgame-vace-720"></a>endgame-vace-720 | Time and VRAM of a full-frame 81-frame or 720p Fun VACE clip on the A5000 | never run here |
| <a id="endgame-cycles-cpu"></a>endgame-cycles-cpu | The layout's CPU cost is minutes | extrapolated from one 384² measurement |
| <a id="endgame-webp-size"></a>endgame-webp-size | WebP sizes per plate and the 7 MB total | estimates until the first pack |
| <a id="endgame-video-bitrate"></a>endgame-video-bitrate | 2.5 and 5 Mbit/s as adequate bitrates for 720p and 1080p | assumption |

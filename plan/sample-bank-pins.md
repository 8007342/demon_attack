# CC0 sample-bank pins for the Tillandsias open register (2026-11-17)

These are the source pins the coordinator asked for, so the Tillandsias open register can admit the CC0 sample
libraries that the web sampler bank (`openspec/changes/adaptive-soundtrack/design.md` §11, `plan/midi-first-research.md`
§3.3) is cut from. This file holds **research and pins only**. No sample was downloaded. The only files fetched whole
were licence files, readmes and SFZ maps (each under 100 KB). The machine-readable list of every file is
`plan/sample-bank-pins.manifest.tsv` (184 rows: repo, commit, group, path, bytes, git blob sha1, raw URL).
**Round 2 (2026-11-17):** 12 more rows, from the same three repos at the same commits and under the same CC0 licence
files, fill the score's coverage gaps (trumpet, glockenspiel, upper organ pipes, high guitar). The manifest now has
196 rows; see `plan/licences-round-2.md` §5.
**Brood choir (2026-11-18):** epic-choir (CC BY 4.0) and 272 Merry Orks (CC0) are pinned separately, in
`plan/choir-pins.md` and `plan/choir-pins.manifest.tsv`, because epic-choir is not CC0 and its samples live in a
release zip rather than in git.

**Method.**
- Refs came from `git ls-remote https://github.com/<repo>`. Every tag is lightweight, so the tag's sha is the
  commit.
- File lists came from the GitHub tree API (`/repos/<repo>/git/trees/<commit>?recursive=1`, none truncated) at the
  pinned commit. Release assets came from the releases API (`/repos/<repo>/releases`).
- Licence files, readmes and SFZ maps were fetched raw at the pinned commit
  (`https://raw.githubusercontent.com/<repo>/<commit>/<path>`). `git hash-object` on each fetched file reproduces the
  tree API's blob sha1, and `sha256sum` gave the sha256 listed.
- **No LFS.** No repo routes samples through LFS. The Karoryfer `.gitattributes` holds only `* text=auto`, VCSL's only
  sets text and diff attributes, and VSCO 2 CE has none. HEAD requests on one sample per library return a
  `content-length` equal to the tree size, so these are real blobs and not LFS pointers. **Every sample therefore has
  only a git blob sha1, not a sha256.** The coordinator verifies a sample on the host with `git hash-object <file>`
  against the manifest's `git_blob_sha1`, and may record its own sha256 then.
- **Release assets:** the API's `digest` field is `null` for every Karoryfer release used here, so those digests are
  "not provided". None was downloaded to hash it. The subset is cut from per-file raw URLs at the pinned commit, not
  from the release zips.

## Summary

| Library | Repo | Pin | Licence file at the pin | Status | Subset | Subset bytes |
|---|---|---|---|---|---|---:|
| Big Rusty Drums | `sfzinstruments/karoryfer.big-rusty-drums` | tag `v1.100` = `f07ce00df34a46b6b08375be56fe116cf15782bc` | `LICENSE`: CC0 1.0 legal code | **IN** | 48 samples + LICENSE | 10,920,071 |
| Growlybass | `sfzinstruments/karoryfer.growlybass` | tag `v1.002` = `4f483268fc66b5a6d5781d421c0d11b8d08d3fc6` | `LICENSE`: CC0 1.0 legal code | **IN** | 40 samples + 4 docs/maps | 17,246,911 |
| Black And Green Guitars | `sfzinstruments/karoryfer.black-and-green-guitars` | tag `v1.000` = `f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9` | `LICENSE`: CC0 1.0 legal code | **IN** | 36 samples + 4 docs/maps | 9,884,402 |
| VCSL | `sgossner/VCSL` | `master` = `c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e` (no tag) | `LICENSE`: CC0 1.0 legal code (added in this commit) | **IN at this commit**; OUT at tag `v1.2.2-RC` (no licence file) | 23 samples + 2 docs | 51,603,245 |
| VSCO 2 CE | `sgossner/VSCO-2-CE` | tag `1.1.0` = `28092772094b2d9f1148d84cea97f4545b8c687d` | `LICENSE`: CC0 1.0 Universal | **IN** | 20 samples + 6 docs/maps (6 of the samples optional) | 34,458,262 |
| **All** | | | | | **184 files** | **≈ 124.1 MB raw** |

All three Karoryfer `LICENSE` files and VCSL's are byte-identical, with blob sha1 `0e259d42c996742e9e3cba14c677129b2c1b6311`
and sha256 `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`. That is the "Creative Commons Legal Code / CC0 1.0 Universal" text.
[source: Karoryfer/sfzinstruments, "LICENSE" (big-rusty-drums, growlybass, black-and-green-guitars at the pins above),
https://raw.githubusercontent.com/sfzinstruments/karoryfer.big-rusty-drums/f07ce00df34a46b6b08375be56fe116cf15782bc/LICENSE, read 2026-11-17]

**Out:** no library is OUT. VSCO 2 CE passes the rule "a licence file in the pinned source says CC0 1.0", so no
brass alternative is needed. A fallback is still listed under VSCO 2 CE below.

## 1. Karoryfer Big Rusty Drums (drums)

| Field | Value |
|---|---|
| Canonical source | https://github.com/sfzinstruments/karoryfer.big-rusty-drums |
| Pin | tag `v1.100` → commit `f07ce00df34a46b6b08375be56fe116cf15782bc` (also `main` HEAD on 2026-11-17) |
| Licence file | https://raw.githubusercontent.com/sfzinstruments/karoryfer.big-rusty-drums/f07ce00df34a46b6b08375be56fe116cf15782bc/LICENSE: 7,048 B, CC0 1.0 Universal legal code; blob sha1 `0e259d42c996742e9e3cba14c677129b2c1b6311`, sha256 `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`. The API's licence field also says `CC0-1.0`. |
| Whole library (not needed) | release asset https://github.com/sfzinstruments/karoryfer.big-rusty-drums/releases/download/v1.100/Big_Rusty_Drums_1100.zip, 619,600,370 B, API `digest`: **not provided** |
| Tree at the pin | 4,872 blobs, 730.9 MB. Samples are FLAC under `Samples/<piece>/<articulation>/<mic>/`, named `*_vl<N>_rr<M>.flac` |
| Subset | 48 FLAC, 10,913,023 B (plus `LICENSE`). Shells use close mics (`kick`, snare `top`, toms `cl`); hats and cymbals use the overheads (`oh`) |
| sha256 | not provided by the source (plain git blobs): git blob sha1 per file in the manifest |

[source: sfzinstruments, "karoryfer.big-rusty-drums" git tree API at f07ce00,
https://api.github.com/repos/sfzinstruments/karoryfer.big-rusty-drums/git/trees/f07ce00df34a46b6b08375be56fe116cf15782bc?recursive=1, read 2026-11-17];
[source: sfzinstruments, "karoryfer.big-rusty-drums releases", https://api.github.com/repos/sfzinstruments/karoryfer.big-rusty-drums/releases, read 2026-11-17]

Alternative drum source, if a listening test prefers it: `sfzinstruments/virtuosity_drums` tag `v0.925` =
`9f04cf9a734527edfbb0a4eee1f674e45bbf71bc`, CC0-1.0 per the API's licence field (its licence file was **not** fetched,
so it is not pinned here). Its release asset `Virtuosity_Drums_v0.925.zip` (1,227,151,376 B) is the only asset seen
with an API digest: `sha256:c6c5d0fe11a394e94be3146a950c3377ec102cb57d189d5a23cec26183d1963a`.
[source: sfzinstruments, "virtuosity_drums releases", https://api.github.com/repos/sfzinstruments/virtuosity_drums/releases, read 2026-11-17]

## 2. Karoryfer Growlybass (bass DI)

| Field | Value |
|---|---|
| Canonical source | https://github.com/sfzinstruments/karoryfer.growlybass |
| Pin | tag `v1.002` → commit `4f483268fc66b5a6d5781d421c0d11b8d08d3fc6` (also `master` HEAD) |
| Licence file | https://raw.githubusercontent.com/sfzinstruments/karoryfer.growlybass/4f483268fc66b5a6d5781d421c0d11b8d08d3fc6/LICENSE: 7,048 B, CC0 1.0 legal code, the same blob as above |
| Readme | `readme.txt` (1,095 B, sha1 `631a43ddba4a4bb321067e2d33abdb9e6a4d5575`, sha256 `0a8a0a6bf9b38a65234f17cc3689c24ca9bfc135b719cdbffd786b5e63995bfa`). It describes a Squier Jazz Bass recorded direct with all knobs on 10. Sustains have 4 velocity layers (`pp p f ff`) × 4 round robins and staccatos have 5 round robins. Notes are sampled in minor thirds from `db2` (the low E string tuned down to C#) to `eb5`. It also says "Royalty-free … Copyright 2014 Karoryfer Lecolds"; the CC0 `LICENSE` at the same commit is the licence that governs. |
| Whole library (not needed) | release asset https://github.com/sfzinstruments/karoryfer.growlybass/releases/download/v1.002/Karoryfer.Growlybass.v1.002.zip, 167,454,256 B, API `digest`: **not provided** |
| Tree at the pin | 389 blobs, 190.8 MB: `sustain/` (224 WAV, 170 MB), `staccato/` (70), `release/` (70), `scrape/` (16) |
| Subset | 40 WAV (17.2 MB) plus `LICENSE`, `readme.txt`, `growlybass_dirty.sfz` and `growlybass_vicious.sfz` (the maps: keycenters and velocity ranges) |
| sha256 | not provided (plain git blobs): git blob sha1 in the manifest |

[source: Karoryfer/sfzinstruments, "karoryfer.growlybass" readme.txt and git tree API at 4f48326,
https://raw.githubusercontent.com/sfzinstruments/karoryfer.growlybass/4f483268fc66b5a6d5781d421c0d11b8d08d3fc6/readme.txt, read 2026-11-17]

**Meatbass licence (closes a provenance gap).** `plan/midi-first-research.md` B3 cites a news snippet calling Meatbass
GPL-3 (`[UNSOURCED: plan/provenance-audit.md#midi-meatbass-licence]`). The repo's `LICENSE` at tag `v1.001` =
`ac9e859564bda286ab5ec672d00ff1aa2fef2895` is the same CC0 1.0 legal code (blob `0e259d42…`), and the API's licence
field says `CC0-1.0`. Meatbass is a double bass, though, so this bank still uses Growlybass for the metal bass.
[source: Karoryfer/sfzinstruments, "karoryfer.meatbass LICENSE",
https://raw.githubusercontent.com/sfzinstruments/karoryfer.meatbass/ac9e859564bda286ab5ec672d00ff1aa2fef2895/LICENSE, read 2026-11-17]

## 3. Karoryfer Black And Green Guitars (guitar DI)

| Field | Value |
|---|---|
| Canonical source | https://github.com/sfzinstruments/karoryfer.black-and-green-guitars |
| Pin | tag `v1.000` → commit `f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9`. `main` (`b3b3249d…`) is 4 commits ahead and changes only `readme.txt`, `.gitattributes` and the Sforzando `bank.xml` (compare API), so the samples are the same. |
| Licence file | https://raw.githubusercontent.com/sfzinstruments/karoryfer.black-and-green-guitars/f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9/LICENSE: 7,048 B, CC0 1.0 legal code, the same blob |
| Readme | `readme.txt` (514 B, sha1 `a9baa96eb5464dbe384e34cb241cdb1993717a1f`, sha256 `0c0723b70532c7e54dd6cf740b490b6698b74d9939b82913432e3c1c01323d5b`): a green Gretsch Anniversary and a black Hofner Club, "Royalty-free … Copyright 2022 Karoryfer Lecolds" (the CC0 `LICENSE` governs) |
| Whole library (not needed) | release asset https://github.com/sfzinstruments/karoryfer.black-and-green-guitars/releases/download/v1.000/Karoryfer_Black_And_Green_Guitars_1000.zip, 481,838,512 B, API `digest`: **not provided** |
| Tree at the pin | 1,884 blobs, 581.4 MB. For each guitar: `ord/` (chromatic `twang_<note>_<p|mf|f>_rr1-4`, e3 to d7, 430 files), `stac/` (`staccato_<note>_rr1-4`, 188), `rel/`, `btb/`/`hammer/`, `fb/` |
| Subset | the **black** (Hofner) guitar: 36 WAV (9.77 MB) plus `LICENSE`, `readme.txt`, `Programs/modules/maps_black/ord.sfz` and `stac.sfz`. *Pick reason:* its `ord` takes are shorter (165 MB for 430 files, against 266 MB for the green one), so they trim to 1.5 s with less lost. The green guitar at the same pin is the fallback if the amp bake-off prefers it. |
| sha256 | not provided (plain git blobs): git blob sha1 in the manifest |

[source: Karoryfer/sfzinstruments, "karoryfer.black-and-green-guitars" readme.txt, git tree and compare API,
https://api.github.com/repos/sfzinstruments/karoryfer.black-and-green-guitars/compare/f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9...b3b3249d37dc977a1a297bd2dc053e6d9b6b805c, read 2026-11-17]

## 4. VCSL, Versilian Community Sample Library (organ, timpani, bells, war drum)

| Field | Value |
|---|---|
| Canonical source | https://github.com/sgossner/VCSL |
| Pin | `master` → commit `c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e` (2026-01-14, "Create LICENSE"). **There is no tag at this commit.** |
| Licence file | https://raw.githubusercontent.com/sgossner/VCSL/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e/LICENSE: 7,048 B, CC0 1.0 legal code, the same blob `0e259d42…` as the Karoryfer repos. The API's licence field says `CC0-1.0`. |
| Why not the tag | Tag `v1.2.2-RC` = `b6e6ac82d22248edee98a0bde185eb9ef6d439ad` (2019) has **no licence file**. Only its README claims CC0 ("This collection is under a Creative Commons 0 license"). Under the register's rule that pin is OUT. Its release has **no assets**. |
| Readme at the pin | `README.md` 4,365 B, sha1 `655eaa2be2a415dfa526bf6e7729aa40590ac0e8`, sha256 `6f7214a188f106c917d6503748485413c3e47cf56bce69f82beb9d16aa0894a9` |
| Tree at the pin | 4,282 blobs, 6.16 GB, plain WAV (the SFZ maps ship only in the 2019 release, not in the repo) |
| Subset | 23 WAV (51.6 MB) plus `LICENSE` and `README.md`. Pipe Organ "Loud" (manual 3, open), Timpani 1 hits, Tubular Bells 2, Bass Drum 2 (the "war drum") |
| sha256 | not provided (plain git blobs): git blob sha1 in the manifest |

[source: Versilian Studios/sgossner, "VCSL LICENSE" at c1ea7bc,
https://raw.githubusercontent.com/sgossner/VCSL/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e/LICENSE, read 2026-11-17];
[source: sgossner, "VCSL contents at c1ea7bc" (GitHub contents API), https://api.github.com/repos/sgossner/VCSL/contents/?ref=c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e, read 2026-11-17];
[source: sgossner, "VCSL README.md" at v1.2.2-RC, https://raw.githubusercontent.com/sgossner/VCSL/b6e6ac82d22248edee98a0bde185eb9ef6d439ad/README.md, read 2026-11-17]

## 5. VSCO 2 Community Edition (brass; strings optional)

| Field | Value |
|---|---|
| Canonical source | https://github.com/sgossner/VSCO-2-CE |
| Pin | tag `1.1.0` → commit `28092772094b2d9f1148d84cea97f4545b8c687d` (on the `SFZ` branch line; it carries the samples **and** the `.sfz` maps). `master` (`44030090…`) has diverged: 5 commits ahead and 24 behind (compare API). |
| Licence file | https://raw.githubusercontent.com/sgossner/VSCO-2-CE/28092772094b2d9f1148d84cea97f4545b8c687d/LICENSE: 6,555 B, starts "CC0 1.0 Universal / Statement of Purpose" and ends with the creativecommons.org/publicdomain/zero/1.0 link (GitHub's CC0-1.0 template text); blob sha1 `670154e3538863b2d9891fd5483160fbdfc89164`, sha256 `36ffd9dc085d529a7e60e1276d73ae5a030b020313e6c5408593a6ae2af39673`. The API's licence field says `CC0-1.0`. **The rule is met: IN.** |
| Note on `Readme.txt` | `Readme.txt` (1,883 B, sha1 `b7a1941bcb77561148bd6abea2dfceb6e2edf9c2`, sha256 `e0c398cff9660ccc52588b8e4e1554941709996488805f04298bd6e0a7993fcf`, dated 2016) says: "You are permitted to use these samples for ANY purpose. We **ask** that you do not sell the samples directly … Please provide credit to Versilian Studios/Sam Gossner…". These are requests, not conditions of the CC0 `LICENSE`. Shipping trimmed samples inside a game is not selling them directly, and crediting Versilian Studios in the game's credits costs nothing. Recommend: credit them. |
| Whole library | no release assets (the `1.1.0` release has none) |
| Tree at the pin | 3,273 blobs, 3.24 GB WAV plus `.sfz` maps at the root |
| Subset | brass: F horn sustains (6), tenor trombone sustains (4) and staccatos (4); optional cello-section sustains (6) for the string pad. 20 WAV (34.4 MB) plus `LICENSE`, `Readme.txt` and 4 `.sfz` maps |
| sha256 | not provided (plain git blobs): git blob sha1 in the manifest |

[source: Versilian Studios/sgossner, "VSCO-2-CE LICENSE" at 1.1.0,
https://raw.githubusercontent.com/sgossner/VSCO-2-CE/28092772094b2d9f1148d84cea97f4545b8c687d/LICENSE, read 2026-11-17];
[source: Versilian Studios, "VSCO 2: CE Readme.txt" at 1.1.0,
https://raw.githubusercontent.com/sgossner/VSCO-2-CE/28092772094b2d9f1148d84cea97f4545b8c687d/Readme.txt, read 2026-11-17];
[source: sgossner, "VSCO-2-CE compare 1.1.0...master", https://api.github.com/repos/sgossner/VSCO-2-CE/compare/28092772094b2d9f1148d84cea97f4545b8c687d...440300901dfe9275fd84e0b7763af1f8443ae62e, read 2026-11-17]

**Brass fallback** (only if the register refuses VSCO 2 CE): Karoryfer War Tuba, `sfzinstruments/karoryfer.war-tuba`
tag `v1.002` = `5b62dd6ef6b00281bb734769e44a63f5e013018a`. Its release asset `Karoryfer_War_Tuba_v1002.zip` is
109,135,588 B with API `digest`: not provided. The API's licence field says CC0-1.0, but its `LICENSE` file was
**not fetched**, so it would need the same licence check before it is pinned. It is a tuba only, with no horns or
trombones. [source: sfzinstruments, "karoryfer.war-tuba releases", https://api.github.com/repos/sfzinstruments/karoryfer.war-tuba/releases, read 2026-11-17]

## 6. Subset plan

**Rules for the cutter.**
- Take pitch from the SFZ `pitch_keycenter`, never from the file name. The libraries name octaves differently. VSCO's
  `MOHorn_sus_A#1` is keycenter 46 (`FHornSus.sfz`), and Growlybass `e2` is keycenter 40 (`growlybass_dirty.sfz`).
  For the VCSL timpani, which have no map at the pin, use the VSCO `Timpani.sfz` keycenters for the same file names:
  drums 1–5 = 42, 46, 49, 52, 54. Confirm them with a pitch detector.
- Velocity layers: in VSCO, `v1` is the softest (`hivel=41`) and the highest `vN` is the loudest. In Karoryfer,
  `vl1` is the softest. Growlybass uses `pp p f ff`; the guitars use `p mf f`.
- Trim each note to the seconds below, downmix to mono where the group is mono, and encode Opus at 48 kHz: 64 kbps
  mono (≈ 8 KB/s), 96 kbps stereo (≈ 12 KB/s). These are the same rates as `plan/midi-first-research.md` §3.3. The
  channel count of each source is unknown until the host download.

| Instrument (source) | Notes / pieces | Velocity layers | Round robins | Articulations | Files | Raw bytes | Trim | Seconds | Opus est. |
|---|---|---|---|---|---:|---:|---|---:|---:|
| Kick (BRD `kick_24/kick/kick`) | 1 | `vl8`, `vl14` (of 14) | 3 | hit | 6 | 242,537 | 0.6 s mono | 3.6 | 29 KB |
| Snare (BRD `snare_14/center/top`, `rimshot/top`) | 1 | center `vl6`, `vl10` (of 10); rimshot `vl6` (top of 6) | 3 center, 2 rim | center, rimshot | 8 | 359,028 | 0.6 s mono | 4.8 | 38 KB |
| Toms (BRD `tom_14`, `tom_18`, `tom_22` `center/cl`) | 3 | mid + top (t14 `vl3`/`vl6`, t18 `vl4`/`vl8`, t22 `vl4`/`vl7`) | 2 | center | 12 | 654,093 | 0.6 s mono | 7.2 | 58 KB |
| Hi-hat (BRD `hihat_14/tc/oh`, `open/oh`) | 1 | closed `vl4`/`vl8`; open `vl3`/`vl6` | 2 | tight closed, open | 8 | 2,067,965 | 0.4 s / 1.3 s stereo | 6.8 | 82 KB |
| Crash, china, ride (BRD `crash_17/cr`, `china_18/cn`, `ride_22/rd` `oh`) | 3 | crash/china `vl3`/`vl5`; ride `vl6`/`vl10` | 2 | hit | 12 | 6,757,258 | 1.3 s stereo | 15.6 | 187 KB |
| Ride bell (BRD `ride_22/bl/oh`) | 1 | `vl4` (top) | 2 | bell | 2 | 832,142 | 1.3 s stereo | 2.6 | 31 KB |
| Bass DI (Growlybass `sustain/`, `staccato/`) | 10: db2 e2 gb2 a2 c3 eb3 gb3 a3 c4 eb4 (minor thirds, the drop-C# low string included) | sustain `f`, `ff`; staccato 1 | sustain 1, staccato 2 | sustain, staccato (the palm-mute stand-in) | 40 | 17,197,134 | 1.5 s / 0.4 s mono | 38.0 | 304 KB |
| Guitar DI (B&G black `ord/`, `stac/`) | 12: e3 g3 bb3 db4 e4 g4 bb4 db5 e5 g5 bb5 db6 (minor thirds, 3 octaves) | `f` | sustain 1, staccato 2 | sustain ("twang"), staccato | 36 | 9,766,624 | 1.5 s / 0.4 s mono | 27.6 | 221 KB |
| Pipe organ (VCSL Pipe Organ `Loud`) | 6: C2 F#2 C3 F#3 C4 F#4 (tritones, ±3 semitones of shift) | 1 (organ has none) | 1 | sustain, looped | 6 | 13,022,584 | 2 s mono | 12.0 | 96 KB |
| Timpani (VCSL `Timpani 1/Hit`) | 5 drums (keycenters 42 46 49 52 54) | `v2`, `v4` | 1 | hit | 10 | 13,068,524 | 1.5 s mono | 15.0 | 120 KB |
| Tubular bells (VCSL `Tubular Bells 2`) | 5: C4 E4 G4 C5 E5 | `v4` | 1 | hit | 5 | 21,413,984 | 2 s mono | 10.0 | 80 KB |
| War drum (VCSL `Bass Drum 2`) | 1 | `ff`, `mf1` | 1 | hit | 2 | 4,086,740 | 1.5 s mono | 3.0 | 24 KB |
| F horn (VSCO `Brass/F Horn/sus`) | 6: G1 A#1 D2 F2 A2 C3 (file names; keycenter +12) | `v3` | 1 | sustain, looped | 6 | 9,629,368 | 2 s mono | 12.0 | 96 KB |
| Tenor trombone (VSCO `Brass/Tenor Trombone/sus`, `stac`) | sustain 4: F1 A#1 D2 F2; staccato 4: F1 A#1 F2 A#2 | sustain `v3`; staccato `v4` (both the top layer) | 1 | sustain, staccato (stabs) | 8 | 5,580,476 | 2 s / 0.5 s mono | 10.0 | 80 KB |
| **Core bank** | | | | | **161** | **104.7 MB** | | **143.2 mono + 25.0 stereo** | **≈ 1.45 MB** |
| *Optional:* string pad (VSCO `Strings/Cello Section/susvib`) | 6: C1 G1 D2 A2 E3 B3 | `v3` | 1 | sustain vibrato, looped | 6 | 19,223,844 | 2 s mono | 12.0 | 96 KB |
| **Core + strings** | | | | | **167** | **123.9 MB** | | | **≈ 1.54 MB** |

Raw bytes are the tree sizes summed by group. Seconds, Opus and decoded sizes are our arithmetic at the rates above.
The Ogg container adds roughly 1–3 % (our estimate, unmeasured).

**Against the budget.**
- **Compressed:** about 1.45 MB for the core bank and 1.54 MB with the strings. Adding container overhead gives
  about 1.5–1.6 MB, inside the 1.6–2 MB target (design §5.3: ≤ 2 MB). Headroom of about 0.4 MB remains, for example
  a second guitar velocity layer (`mf`, about 0.15 MB) if the bake-off wants one.
- **Decoded:** at 48 kHz Float32 (192 KB/s mono, 384 KB/s stereo), the core bank is 143.2 s × 192 KB + 25.0 s ×
  384 KB ≈ 37.1 MB, or 39.4 MB with the strings. That is under the 41 MB desktop cap.
- **Phone tier** (top velocity only, `rr1` only, no ride bell): ≈ 98 s mono + 5.6 s stereo ≈ 21 MB. That is **over
  the 16 MB phone cap**. To get under it, the phone tier must also skip the guitar notes above bb4, three of the six
  horn notes, the trombone sustains, the bells and the war drum, which brings it to ≈ 15 MB. Those parts then fall
  back to the oscillator voice on phones. This is our arithmetic, and the probe should confirm it (design §5).

## 7. Gaps

- **No CC0 choir.** Karoryfer's choirs (Hadziha, Torgbe) are commercial, and VCSL and VSCO 2 CE have no choir (B4, B6).
  Choir parts stay a rendered texture bed.
- **No CC0 cabinet impulse response.** None was found (M4). The cabinet ships as code (filters), or as an IR we
  generate ourselves and release CC0.
- **No ukulele** in VCSL, VSCO 2 CE or the Karoryfer lists read (B6). The ending's ukulele stays a rendered texture.
- **No palm mute** in Black And Green Guitars: the articulations are `ord`, `stac`, `rel`, `btb`, `hammer` and `fb`.
  The staccato stands in for palm mute, with an envelope and low-pass in the sampler. Both guitars are hollow-body
  electrics (a Gretsch and a Hofner), not high-gain solid bodies, so the browser amp carries the metal tone. This is
  one more reason for the bake-off (task 8.4).
- **No sha256 for any sample.** The sources are plain git blobs, so the coordinator verifies `git hash-object` against
  the manifest and records sha256 on the host. No Karoryfer release asset has an API digest.
- **VCSL has no tag at the licensed commit.** The pin is a bare commit on `master`. The 2019 RC tag predates the
  `LICENSE` file.
- **Timpani pitches** come from VSCO's map, matched by file name, not from a VCSL map. Confirm them by pitch
  detection when cutting.

## 8. Send to coordinator

```text
SAMPLE-BANK PINS (demon_attack, work/sample-bank-pins, plan/sample-bank-pins.md + .manifest.tsv), 2026-11-17
Register: open (CC0-1.0). Every licence file below was fetched at the pin and checked. No LFS anywhere: samples are
plain git blobs, so per-file hashes are git blob sha1s (verify with `git hash-object`). No sample sha256 is provided.
Raw URL form: https://raw.githubusercontent.com/<repo>/<commit>/<url-encoded path> (the manifest has each one).

IN  sfzinstruments/karoryfer.big-rusty-drums  v1.100 = f07ce00df34a46b6b08375be56fe116cf15782bc
    LICENSE CC0 1.0 (blob 0e259d42c996742e9e3cba14c677129b2c1b6311, sha256 a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499)
    subset 48 FLAC + LICENSE = 10,920,071 B; release zip 619,600,370 B, digest not provided (not needed)
IN  sfzinstruments/karoryfer.growlybass        v1.002 = 4f483268fc66b5a6d5781d421c0d11b8d08d3fc6
    LICENSE CC0 1.0 (same blob/sha256 as above)
    subset 40 WAV + 4 docs/maps = 17,246,911 B; release zip 167,454,256 B, digest not provided (not needed)
IN  sfzinstruments/karoryfer.black-and-green-guitars  v1.000 = f3cf516cbe50b2d6019c7c8fafec4251e2fa29c9
    LICENSE CC0 1.0 (same blob/sha256 as above)
    subset 36 WAV + 4 docs/maps = 9,884,402 B; release zip 481,838,512 B, digest not provided (not needed)
IN  sgossner/VCSL  master = c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e (no tag; "Create LICENSE", 2026-01-14)
    LICENSE CC0 1.0 (same blob/sha256 as above)
    subset 23 WAV + 2 docs = 51,603,245 B
    NOTE: tag v1.2.2-RC (b6e6ac82d22248edee98a0bde185eb9ef6d439ad) has NO licence file (README claim only): OUT at that tag
IN  sgossner/VSCO-2-CE  1.1.0 = 28092772094b2d9f1148d84cea97f4545b8c687d
    LICENSE "CC0 1.0 Universal" (blob 670154e3538863b2d9891fd5483160fbdfc89164, sha256 36ffd9dc085d529a7e60e1276d73ae5a030b020313e6c5408593a6ae2af39673)
    subset 20 WAV (6 optional strings) + 6 docs/maps = 34,458,262 B
    NOTE: Readme.txt *asks* (does not require) no direct resale and credit to Versilian Studios; recommend crediting

TOTAL 184 files, 124,112,891 B raw (core bank 161 samples, 104.7 MB)
Manifest: plan/sample-bank-pins.manifest.tsv, sha256 4ebc667d4d1309c1e3694c24c3fb76e0c1090387dccf468460ef860ceb0b75f4
Bank estimate: ≈ 1.45 MB Opus core, ≈ 1.54 MB with strings; decoded ≈ 37.1 / 39.4 MB (desktop cap 41 MB)
Phone tier needs extra drops to reach ≤ 16 MB decoded (see §6)
OUT: none. A brass fallback (karoryfer.war-tuba v1.002 = 5b62dd6ef6b00281bb734769e44a63f5e013018a) is listed, but its
     LICENSE was not fetched
Side finding: karoryfer.meatbass v1.001 (ac9e859564bda286ab5ec672d00ff1aa2fef2895) LICENSE is CC0 1.0, not GPL-3
     (closes provenance-audit#midi-meatbass-licence once the audit is updated)
Gaps: no CC0 choir, no CC0 cabinet IR, no ukulele, no palm-mute articulation (staccato stands in), no sample sha256
```

## Appendix: every file in the subset

Generated from the GitHub tree API at each pin. `plan/sample-bank-pins.manifest.tsv` holds the same rows plus raw URLs.

#### Files: `sfzinstruments/karoryfer.big-rusty-drums` @ `f07ce00df34a`

| Group | Path | Bytes | git blob sha1 |
|---|---|---:|---|
| doc | `LICENSE` | 7048 | `0e259d42c996742e9e3cba14c677129b2c1b6311` |
| kick | `Samples/kick_24/kick/kick/k_vl8_rr1.flac` | 39220 | `870e0f17b2b1c0104e4629f8ccb801863dc463ee` |
| kick | `Samples/kick_24/kick/kick/k_vl8_rr2.flac` | 39072 | `82c850b1d76c0b38f4e7e92372ca3e685e08c598` |
| kick | `Samples/kick_24/kick/kick/k_vl8_rr3.flac` | 39097 | `046b3ff3086f1276ec742898e72283caee28ccd7` |
| kick | `Samples/kick_24/kick/kick/k_vl14_rr1.flac` | 41674 | `5ef8cda56ed2d798f8a3a5eaa877d27615d5a3c0` |
| kick | `Samples/kick_24/kick/kick/k_vl14_rr2.flac` | 41746 | `e4364262fb7be86e1da24e0ea1d572ac99f3fdf0` |
| kick | `Samples/kick_24/kick/kick/k_vl14_rr3.flac` | 41728 | `5d9315e2ab6a35e76c1f96463c0a143341d6699a` |
| snare | `Samples/snare_14/center/top/sn_center_vl6_rr1.flac` | 45024 | `8be87cc6c6c42800728467215858ff3523e695fc` |
| snare | `Samples/snare_14/center/top/sn_center_vl6_rr2.flac` | 45208 | `bbf43a7d93422b93443cba00da3d72472b3ce358` |
| snare | `Samples/snare_14/center/top/sn_center_vl6_rr3.flac` | 45580 | `828a9c54800e4e938854c02dd149edc7e70c365f` |
| snare | `Samples/snare_14/center/top/sn_center_vl10_rr1.flac` | 46798 | `bbd4532e3fedb746c7c6d4230cb17ec054112a58` |
| snare | `Samples/snare_14/center/top/sn_center_vl10_rr2.flac` | 46940 | `07b91e7fe3d8ec7e963bb0f1822fee8444b11a59` |
| snare | `Samples/snare_14/center/top/sn_center_vl10_rr3.flac` | 46879 | `6c188c5aca6d272e8f3b25115c46e982f9bd2d1d` |
| snare-rim | `Samples/snare_14/rimshot/top/sn_rims_vl6_rr1.flac` | 41601 | `39d4b4e543f3931a3794bf1b66e10358ebf1e6e4` |
| snare-rim | `Samples/snare_14/rimshot/top/sn_rims_vl6_rr2.flac` | 40998 | `79d387636de57e7bd8f13f4fb7a8ef3d843a75c7` |
| tom-hi | `Samples/tom_14/center/cl/t14_vl3_rr1.flac` | 49303 | `5c0fc64ab342ee0afc13e1fdb0c414ccaa4698c9` |
| tom-hi | `Samples/tom_14/center/cl/t14_vl3_rr2.flac` | 49373 | `6596ed35d7609e692ceabbee409e10ba8f12d754` |
| tom-hi | `Samples/tom_14/center/cl/t14_vl6_rr1.flac` | 53850 | `008ba2771f250b7851bcbfc7010813353df1bfcd` |
| tom-hi | `Samples/tom_14/center/cl/t14_vl6_rr2.flac` | 54861 | `c9922fa398020447c5cb6eb8231f76e6565d639c` |
| tom-mid | `Samples/tom_18/center/cl/t18_vl4_rr1.flac` | 48056 | `927fe4636562401816e19018dc92d846bd8891c3` |
| tom-mid | `Samples/tom_18/center/cl/t18_vl4_rr2.flac` | 47968 | `9e02a576584d7782c2afa9ab1931de40f7d6a369` |
| tom-mid | `Samples/tom_18/center/cl/t18_vl8_rr1.flac` | 51674 | `9f94a75a7b9e4e4bfeec49701cdabd41d9c949f6` |
| tom-mid | `Samples/tom_18/center/cl/t18_vl8_rr2.flac` | 51513 | `6dc76c89962bbf3de189fbca9e791664a5aa6a70` |
| tom-floor | `Samples/tom_22/center/cl/t22_vl4_rr1.flac` | 60171 | `4c62b94ee26bce562bda4a3768d562e7662ff8c4` |
| tom-floor | `Samples/tom_22/center/cl/t22_vl4_rr2.flac` | 60014 | `96e4bf59ec329487b03f2915109a854e883a3b19` |
| tom-floor | `Samples/tom_22/center/cl/t22_vl7_rr1.flac` | 63754 | `8e6cc9fdd51af75041cc774b4cd239d6db612fb6` |
| tom-floor | `Samples/tom_22/center/cl/t22_vl7_rr2.flac` | 63556 | `1e84264e7efba881079e6af5a651dbf90ec9bb06` |
| hat-closed | `Samples/hihat_14/tc/oh/ht_tc_vl4_rr1.flac` | 61129 | `bcf1fb7413e8e76232cb7b143665b45396283ce5` |
| hat-closed | `Samples/hihat_14/tc/oh/ht_tc_vl4_rr2.flac` | 60550 | `1a3efe74b8668f7ff533ff228d16a3430925e0eb` |
| hat-closed | `Samples/hihat_14/tc/oh/ht_tc_vl8_rr1.flac` | 71107 | `d1bc328feadadf2dcee238ca460f8fdeb342857c` |
| hat-closed | `Samples/hihat_14/tc/oh/ht_tc_vl8_rr2.flac` | 71839 | `f937e05431160917c92eb2462a89a56b335646a9` |
| hat-open | `Samples/hihat_14/open/oh/ht_open_vl3_rr1.flac` | 428990 | `df687442eace22375cac7be3ddb8bf6c3ba5f6cc` |
| hat-open | `Samples/hihat_14/open/oh/ht_open_vl3_rr2.flac` | 437391 | `13565ab55e9c850df2e5a65d2285c159970f1731` |
| hat-open | `Samples/hihat_14/open/oh/ht_open_vl6_rr1.flac` | 468234 | `09aac894ca1195997ac6074b323a8c09046c8245` |
| hat-open | `Samples/hihat_14/open/oh/ht_open_vl6_rr2.flac` | 468725 | `7712422d57f4c7019d80b7151c4f57b95f336273` |
| crash | `Samples/crash_17/cr/oh/cr_vl3_rr1.flac` | 651467 | `f8736b02a6dd1fbde335cae4b1b4f7fecd128b12` |
| crash | `Samples/crash_17/cr/oh/cr_vl3_rr2.flac` | 611723 | `d4db307fc742265cf0eaafab519091f000e8fb7e` |
| crash | `Samples/crash_17/cr/oh/cr_vl5_rr1.flac` | 707073 | `15ee015dee2622db0594e43bb114fecfcb566701` |
| crash | `Samples/crash_17/cr/oh/cr_vl5_rr2.flac` | 682038 | `88d862ed5e968e225cfc66eace1741a90ade4a65` |
| china | `Samples/china_18/cn/oh/cn_vl3_rr1.flac` | 372825 | `95bdc524ad8449a5ae6a36f26b971a94d527e9b7` |
| china | `Samples/china_18/cn/oh/cn_vl3_rr2.flac` | 375336 | `d9c1908ccaad4bd1a5b7520416dc7d7e79ce9482` |
| china | `Samples/china_18/cn/oh/cn_vl5_rr1.flac` | 396208 | `ad3d21368b7efc377315cd35abb9a3e70fc983f8` |
| china | `Samples/china_18/cn/oh/cn_vl5_rr2.flac` | 388718 | `dcde15582f6e170593bb2392464f1427c4fe6d83` |
| ride | `Samples/ride_22/rd/oh/rd_vl6_rr1.flac` | 629367 | `702cbd44dfb9d6ad5a06b1df1937b88dcee06f3a` |
| ride | `Samples/ride_22/rd/oh/rd_vl6_rr2.flac` | 630753 | `d2e9027d2a16f7bc27b2041c1d7662bd3a1636db` |
| ride | `Samples/ride_22/rd/oh/rd_vl10_rr1.flac` | 656830 | `82835154599c0396b8d8fe4a4b9ea0dbd265f121` |
| ride | `Samples/ride_22/rd/oh/rd_vl10_rr2.flac` | 654920 | `cc71c8a702de988a91f99e29e8644575ecf6f894` |
| ride-bell | `Samples/ride_22/bl/oh/rd_bl_vl4_rr1.flac` | 414020 | `e9be15ea41a3dac98f6e0bab026403460c1bd7ab` |
| ride-bell | `Samples/ride_22/bl/oh/rd_bl_vl4_rr2.flac` | 418122 | `f92e0123c89645cb4c8d8fa7cf57ce30becf076d` |

#### Files: `sfzinstruments/karoryfer.growlybass` @ `4f483268fc66`

| Group | Path | Bytes | git blob sha1 |
|---|---|---:|---|
| doc | `LICENSE` | 7048 | `0e259d42c996742e9e3cba14c677129b2c1b6311` |
| doc | `readme.txt` | 1095 | `631a43ddba4a4bb321067e2d33abdb9e6a4d5575` |
| doc | `growlybass_dirty.sfz` | 33111 | `80d928c7176afbdfa6408ffd630f8771c40094b0` |
| doc | `growlybass_vicious.sfz` | 8523 | `af3166e9085d627eac214f7197ff20f262943c63` |
| bass-sus | `sustain/db2_f_rr1.wav` | 796606 | `6c9ef40f284242defb8d2768fca96aba432e972b` |
| bass-sus | `sustain/db2_ff_rr1.wav` | 796606 | `f5cc3c22d1247292b997e62c66eca16317c96a0c` |
| bass-sus | `sustain/e2_f_rr1.wav` | 796608 | `6ce5f45b31802bedd9f8271dd8b4a6328297677c` |
| bass-sus | `sustain/e2_ff_rr1.wav` | 796608 | `67e57ca739e2bcf72ded99c78d7e5935a8813f71` |
| bass-sus | `sustain/gb2_f_rr1.wav` | 796608 | `9f6dc96d1517897e4a88f5a67d63528763e9d7d4` |
| bass-sus | `sustain/gb2_ff_rr1.wav` | 796606 | `cbea71ed9e601ab2378edccf636575cb5a9dc364` |
| bass-sus | `sustain/a2_f_rr1.wav` | 796606 | `a5e573691aa06ac30c21544374a46037c4ef28a4` |
| bass-sus | `sustain/a2_ff_rr1.wav` | 796606 | `514641ec28b0486352abd6dff69889a7cc29bf12` |
| bass-sus | `sustain/c3_f_rr1.wav` | 796606 | `e377845aa4d29f01e4485f8dc68ee936814d5a78` |
| bass-sus | `sustain/c3_ff_rr1.wav` | 796606 | `eb2af27cade55daae3972ebbb30257aa42c6ab56` |
| bass-sus | `sustain/eb3_f_rr1.wav` | 796608 | `2d79cbaf8ccaab9f09e6bec1e46481ee87037e4a` |
| bass-sus | `sustain/eb3_ff_rr1.wav` | 796608 | `0cfd1265b54e7928e463eb68a4f1275c874d1661` |
| bass-sus | `sustain/gb3_f_rr1.wav` | 796608 | `f36cf7007997c52fb3111670f1c207d29d6a0520` |
| bass-sus | `sustain/gb3_ff_rr1.wav` | 796608 | `cac47287360dbb5a5e013b839b17dfa5f56d18dd` |
| bass-sus | `sustain/a3_f_rr1.wav` | 796608 | `ec0c04ebb6254bfbaf55107da4a986bb3622ae9c` |
| bass-sus | `sustain/a3_ff_rr1.wav` | 796608 | `9dbf24b71c3564c4336ca2182deca9ff794595f7` |
| bass-sus | `sustain/c4_f_rr1.wav` | 796608 | `dce2dee367417812c20f95953533b8a3b162690c` |
| bass-sus | `sustain/c4_ff_rr1.wav` | 796608 | `4af0b39d2a1db7fb6ea5964a1e36c9bfc8352632` |
| bass-sus | `sustain/eb4_f_rr1.wav` | 796606 | `2c967da452613efac70ebfc477490ff9b0cbb08d` |
| bass-sus | `sustain/eb4_ff_rr1.wav` | 796606 | `d170fe26ee5aa42429f02202aea721062ca8cf44` |
| bass-stac | `staccato/db2_staccato_rr1.wav` | 71230 | `33f44df047a191669c8569bab997ea9b128037eb` |
| bass-stac | `staccato/db2_staccato_rr2.wav` | 71230 | `1f57bfdf0ac5460653930ce5925544f7bdf800ad` |
| bass-stac | `staccato/e2_staccato_rr1.wav` | 71232 | `61fd450986dae75feba81890683078059f6b1700` |
| bass-stac | `staccato/e2_staccato_rr2.wav` | 71232 | `28dd2d63539cee3ada7cfd8afe632e677c789426` |
| bass-stac | `staccato/gb2_staccato_rr1.wav` | 71230 | `096a329fc93c85ba7f03e6be9cff4c200f62beb1` |
| bass-stac | `staccato/gb2_staccato_rr2.wav` | 71230 | `de7db3b756939ca1e11b72d7ee821f810ecbbad1` |
| bass-stac | `staccato/a2_staccato_rr1.wav` | 59828 | `f964fb6269d7d74b17a302ab9ad4adc3ddb26b32` |
| bass-stac | `staccato/a2_staccato_rr2.wav` | 59828 | `de8f45cfc28cbccc8b1d429d1ffec000470e2339` |
| bass-stac | `staccato/c3_staccato_rr1.wav` | 59828 | `219a86c660afa3a5e38b2e9b3b9c770853e8a6cd` |
| bass-stac | `staccato/c3_staccato_rr2.wav` | 59828 | `401b70d806d6606f242b631f9a9550572273ba6d` |
| bass-stac | `staccato/eb3_staccato_rr1.wav` | 59830 | `3cfde7689be7f8f7408c3216e87acf2250b897ab` |
| bass-stac | `staccato/eb3_staccato_rr2.wav` | 59830 | `063494b47950dc1cb42584c19100b72c566bc7be` |
| bass-stac | `staccato/gb3_staccato_rr1.wav` | 59830 | `c0d6106cf3455394a03eeab893e98019e43985f2` |
| bass-stac | `staccato/gb3_staccato_rr2.wav` | 59830 | `dcfe6e199c10fdd08df235dda1bd7523bfc79499` |
| bass-stac | `staccato/a3_staccato_rr1.wav` | 59830 | `089cecd80ff3f21730eb51aa2505446c382f8202` |
| bass-stac | `staccato/a3_staccato_rr2.wav` | 59830 | `1cb9bd8facfe8a47a69726cb3a0387e6c411e8cb` |
| bass-stac | `staccato/c4_staccato_rr1.wav` | 59830 | `5c114528753f46c7a832fe3a5a3e30344ff771fd` |
| bass-stac | `staccato/c4_staccato_rr2.wav` | 59830 | `21bff9ad7504be3c3e0716e9a7fd678aeece601c` |
| bass-stac | `staccato/eb4_staccato_rr1.wav` | 59828 | `c89e69433ee50d403f2943cf959f8c6f022f144c` |
| bass-stac | `staccato/eb4_staccato_rr2.wav` | 59828 | `2e624583b355f9601f6154e31263278db22011fd` |

#### Files: `sfzinstruments/karoryfer.black-and-green-guitars` @ `f3cf516cbe50`

| Group | Path | Bytes | git blob sha1 |
|---|---|---:|---|
| doc | `LICENSE` | 7048 | `0e259d42c996742e9e3cba14c677129b2c1b6311` |
| doc | `readme.txt` | 514 | `a9baa96eb5464dbe384e34cb241cdb1993717a1f` |
| doc | `Programs/modules/maps_black/ord.sfz` | 83265 | `f2ddad402ff63d24efb4fd42564c3c75d79647fe` |
| doc | `Programs/modules/maps_black/stac.sfz` | 26951 | `1a91ab5a343e7d614f4931cea57273b6ea492e23` |
| gtr-sus | `Samples/black/ord/twang_e3_f_rr1.wav` | 741936 | `88ba131aa045329eb94729f642ae9cd34d5650e8` |
| gtr-sus | `Samples/black/ord/twang_g3_f_rr1.wav` | 511082 | `c3e5756274cee80b258ffb95ceb131936c0b5722` |
| gtr-sus | `Samples/black/ord/twang_bb3_f_rr1.wav` | 542772 | `0b6f01969ad39abecf8a368ea61737df92d31728` |
| gtr-sus | `Samples/black/ord/twang_db4_f_rr1.wav` | 599864 | `cf7e737974211fcbf5bd71f5a778317413251ee1` |
| gtr-sus | `Samples/black/ord/twang_e4_f_rr1.wav` | 592628 | `bf3c082d0a57c3c61c26746aa7dfc51ff0650a2e` |
| gtr-sus | `Samples/black/ord/twang_g4_f_rr1.wav` | 732048 | `3aa166d18715f6881d14e34cc43efd6d3bd08799` |
| gtr-sus | `Samples/black/ord/twang_bb4_f_rr1.wav` | 588978 | `fa60304fb766da09b9eef9fd2542ef995626938d` |
| gtr-sus | `Samples/black/ord/twang_db5_f_rr1.wav` | 655400 | `c99475bbfc84cd9ff78376d7fe4233f5ded65dcc` |
| gtr-sus | `Samples/black/ord/twang_e5_f_rr1.wav` | 579632 | `7004334fa956b78be9e21cad2902da030bca06d7` |
| gtr-sus | `Samples/black/ord/twang_g5_f_rr1.wav` | 569466 | `5b3163df4200c8a913c32473007b593d7188aa17` |
| gtr-sus | `Samples/black/ord/twang_bb5_f_rr1.wav` | 531564 | `1da02d6c1471b7f234421691ef5b6e81665d6473` |
| gtr-sus | `Samples/black/ord/twang_db6_f_rr1.wav` | 463134 | `3b0f3b828190832274a9536eafdffc862c19a9e2` |
| gtr-stac | `Samples/black/stac/staccato_e3_rr1.wav` | 118100 | `989158b308c6d8af56e0765d9fa6f1a601b35a43` |
| gtr-stac | `Samples/black/stac/staccato_e3_rr2.wav` | 133280 | `5b5fc628b2d60849d95681a29e6a3ad15d9e9902` |
| gtr-stac | `Samples/black/stac/staccato_g3_rr1.wav` | 118904 | `67d045e60cdef486965e1f4e4c9523e5e0a0cf11` |
| gtr-stac | `Samples/black/stac/staccato_g3_rr2.wav` | 124772 | `e8b48e2f45a3ec08270d6ef550107df8e18f7314` |
| gtr-stac | `Samples/black/stac/staccato_bb3_rr1.wav` | 117252 | `ccb9afc44537bbeb36bb7df5df4cf013423597b9` |
| gtr-stac | `Samples/black/stac/staccato_bb3_rr2.wav` | 124802 | `9bee426e6c03e5933c7403fc2a3c7a10e10bc140` |
| gtr-stac | `Samples/black/stac/staccato_db4_rr1.wav` | 101144 | `d5ff2fca92a7607c2c5ec06a38738348a206773f` |
| gtr-stac | `Samples/black/stac/staccato_db4_rr2.wav` | 102438 | `eacc6c1a1fee56301e0ecbcdcad04fb86dbd4cca` |
| gtr-stac | `Samples/black/stac/staccato_e4_rr1.wav` | 100430 | `6a73daacbd981f56e81fe4d58517ab247219b578` |
| gtr-stac | `Samples/black/stac/staccato_e4_rr2.wav` | 88392 | `8e3a2251dc2bb8280669b14df5beb7fba1452a52` |
| gtr-stac | `Samples/black/stac/staccato_g4_rr1.wav` | 125508 | `7777f7fdd7778e53e5a0e24db6815164340a2966` |
| gtr-stac | `Samples/black/stac/staccato_g4_rr2.wav` | 109190 | `da8185eb0c02c20351c82fc2243d33e549c261c8` |
| gtr-stac | `Samples/black/stac/staccato_bb4_rr1.wav` | 113924 | `279928ee46dbaddbba1570327d2ae67d792cc161` |
| gtr-stac | `Samples/black/stac/staccato_bb4_rr2.wav` | 95898 | `1ddbe9ec128867baeacdf54021f7fcc5ff958c46` |
| gtr-stac | `Samples/black/stac/staccato_db5_rr1.wav` | 135936 | `beac1a2aec8c86993cb1dad54354b1539b09bad1` |
| gtr-stac | `Samples/black/stac/staccato_db5_rr2.wav` | 109434 | `28caaef8245028b3044f95cc68cfa9920e8b3c5f` |
| gtr-stac | `Samples/black/stac/staccato_e5_rr1.wav` | 93962 | `5e42449cd9025cdbc11be4ba3bfb0eae7742d23c` |
| gtr-stac | `Samples/black/stac/staccato_e5_rr2.wav` | 106172 | `828e79ee96db8fd23e4269615e2b86b522809b5e` |
| gtr-stac | `Samples/black/stac/staccato_g5_rr1.wav` | 96828 | `3bca61b6697f0634757091fd47b909eecc8e5493` |
| gtr-stac | `Samples/black/stac/staccato_g5_rr2.wav` | 99110 | `930f444501dc9254414614f07d67ef3ee437f44a` |
| gtr-stac | `Samples/black/stac/staccato_bb5_rr1.wav` | 123242 | `60f6ad15da5a1cebead6e9e80ec612e0ecc7d6c4` |
| gtr-stac | `Samples/black/stac/staccato_bb5_rr2.wav` | 110552 | `6e384360dfa92b89eb0915cbde6f388b74597a0c` |
| gtr-stac | `Samples/black/stac/staccato_db6_rr1.wav` | 109398 | `99e298b1ed7ed287e2f4be0feed20d9f0e633ab9` |
| gtr-stac | `Samples/black/stac/staccato_db6_rr2.wav` | 99452 | `fba9dc6799f293ea15fb91d46e2a4245503e785f` |

#### Files: `sgossner/VCSL` @ `c1ea7bcc3c73`

| Group | Path | Bytes | git blob sha1 |
|---|---|---:|---|
| doc | `LICENSE` | 7048 | `0e259d42c996742e9e3cba14c677129b2c1b6311` |
| doc | `README.md` | 4365 | `655eaa2be2a415dfa526bf6e7729aa40590ac0e8` |
| organ | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_C2.wav` | 2169390 | `0d68a094fbfbce26e0334c6286106c7aa3f468b8` |
| organ | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_F#2.wav` | 2197326 | `7f08f09b1afba404569f415040767aea84fe7038` |
| organ | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_C3.wav` | 2180642 | `66755890efd10ee015f7972de4e3cd7c22ee3a69` |
| organ | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_F#3.wav` | 2167714 | `b5573c0e706b03087e7f5d68087f0bbebffe44e2` |
| organ | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_C4.wav` | 2187714 | `e1edb88fdb776827136e0c72cd37c1ea5f931cec` |
| organ | `Aerophones/Edge-blown Aerophones/Pipe Organ/Loud/Rode_Man3Open_F#4.wav` | 2119798 | `1d5ef04f7b98a6d61dd4dc3932e7800b0f7d6aea` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani1_Hit_v2_rr1_Sum.wav` | 1289332 | `933fde51859104606e61849eceb7e5a526083231` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani1_Hit_v4_rr1_Sum.wav` | 2025204 | `77ea696f4cd071877927f9b6e55bd80b794dc29c` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani2_Hit_v2_rr1_Sum.wav` | 1536488 | `ce8d0dcc354a04bacd46453adb9c3eefb4f94052` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani2_Hit_v4_rr1_Sum.wav` | 1638140 | `9ea50b2bf3a7c6d438e939e348a698d93f30f1f3` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani3_Hit_v2_rr1_Sum.wav` | 616268 | `e0e1c3f7b1e70c946b9a7148afb03ccbdd455842` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani3_Hit_v4_rr1_Sum.wav` | 1813928 | `020341b6f206e571211e240e544f2bc314215553` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani4_Hit_v2_rr1_Sum.wav` | 735232 | `0f7552ea4a946f612b4123c16ba8307239ecd08f` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani4_Hit_v4_rr1_Sum.wav` | 1599356 | `e677f48530d9715c1e8ebbd35e1795de9e7ea207` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani5_Hit_v2_rr1_Sum.wav` | 600696 | `2e7dedecee32d6130be9fac12d18660da855734f` |
| timpani | `Membranophones/Struck Membranophones/Timpani 1/Hit/Timpani5_Hit_v4_rr1_Sum.wav` | 1213880 | `5de0226ebb7e3b4a343b23e71517147aa5102f2e` |
| bells | `Idiophones/Struck Idiophones/Tubular Bells 2/TB_hit_C4_v4_1.wav` | 3377124 | `76efa7c6770b43a670a2cdde701ec26486af9c46` |
| bells | `Idiophones/Struck Idiophones/Tubular Bells 2/TB_hit_E4_v4_1.wav` | 4319576 | `5bb77f3e3597dc81235001d63c00ab99f65bd363` |
| bells | `Idiophones/Struck Idiophones/Tubular Bells 2/TB_hit_G4_v4_1.wav` | 2873324 | `5360b27e9e160acea82a4e705381007b0845b06c` |
| bells | `Idiophones/Struck Idiophones/Tubular Bells 2/TB_hit_C5_v4_1.wav` | 7836692 | `0256331a16c9c3a77a584f63d2c2caecffbba60d` |
| bells | `Idiophones/Struck Idiophones/Tubular Bells 2/TB_hit_E5_v4_2.wav` | 3007268 | `bf74da188e2f2676b640445a0f9dcc2aa23a50ed` |
| war-drum | `Membranophones/Struck Membranophones/Bass Drum 2/bassdrum_hit_ff.wav` | 2198042 | `1df2aa8cb2775318920eb35e6dd6b67d096be9da` |
| war-drum | `Membranophones/Struck Membranophones/Bass Drum 2/bassdrum_hit_mf1.wav` | 1888698 | `9a34afe4256e5ef3756bdd90fb2143cfe8621634` |

#### Files: `sgossner/VSCO-2-CE` @ `28092772094b`

| Group | Path | Bytes | git blob sha1 |
|---|---|---:|---|
| doc | `LICENSE` | 6555 | `670154e3538863b2d9891fd5483160fbdfc89164` |
| doc | `Readme.txt` | 1883 | `b7a1941bcb77561148bd6abea2dfceb6e2edf9c2` |
| doc | `FHornSus.sfz` | 3250 | `8bf03e466eab3294d607b9056a229e0c9970a8d5` |
| doc | `TromboneSus.sfz` | 3550 | `b109b4135b0658d8003a986c51f7c5b4d55f786b` |
| doc | `TromboneStac.sfz` | 6403 | `6e60edef55889d4ff78f82971f9d9b81bc40987a` |
| doc | `CelloEnsSusVib.sfz` | 2933 | `9b34afd020314d1bfa01d5578c9b30aae9cdc603` |
| horn-sus | `Brass/F Horn/sus/MOHorn_sus_G1_v3_1.wav` | 941656 | `e824ccfe9f9b0a33e31151cec90e838dc769d949` |
| horn-sus | `Brass/F Horn/sus/MOHorn_sus_A#1_v3_1.wav` | 1829064 | `8fe919bf02a81284083f9a356db56591ffbb5e31` |
| horn-sus | `Brass/F Horn/sus/MOHorn_sus_D2_v3_1.wav` | 1746204 | `aec5cfdb8e2532338f69f6726c77c1d8e5044f0d` |
| horn-sus | `Brass/F Horn/sus/MOHorn_sus_F2_v3_1.wav` | 1692688 | `af9345753c5b31083a3e344dd7bbf6c978de59c3` |
| horn-sus | `Brass/F Horn/sus/MOHorn_sus_A2_v3_1.wav` | 1305440 | `d4088d29905d60944c524d443f66c55035301e47` |
| horn-sus | `Brass/F Horn/sus/MOHorn_sus_C3_v3_1.wav` | 2114316 | `69e3187ccc4d4338931d412a9f50978ca576db5c` |
| tbn-sus | `Brass/Tenor Trombone/sus/tenortbn_sus_F1_v3_1.wav` | 1197948 | `81a07a374fad649fb6d2589cea8756b0af3fc8f2` |
| tbn-sus | `Brass/Tenor Trombone/sus/tenortbn_sus_A#1_v3_1.wav` | 930872 | `52f58161c3944d30fb5598144697650b29224947` |
| tbn-sus | `Brass/Tenor Trombone/sus/tenortbn_sus_D2_v3_1.wav` | 1162132 | `eef36ce79c6497eacde16aca18edbfbd0418e837` |
| tbn-sus | `Brass/Tenor Trombone/sus/tenortbn_sus_F2_v3_1.wav` | 1107668 | `f6c1025383f62db27083c3cb78d5046d748ada4c` |
| tbn-stac | `Brass/Tenor Trombone/stac/tenortbn_stac_F1_v4_rr1.wav` | 323208 | `2a88b80622277b5a4739445a7945cdc7a95123b8` |
| tbn-stac | `Brass/Tenor Trombone/stac/tenortbn_stac_A#1_v4_rr1.wav` | 230512 | `9947fab6818aebb2977c473e964088638b02ff14` |
| tbn-stac | `Brass/Tenor Trombone/stac/tenortbn_stac_F2_v4_rr1.wav` | 270120 | `1ccb564b7564df62ac16af6947e1216489730941` |
| tbn-stac | `Brass/Tenor Trombone/stac/tenortbn_stac_A#2_v4_rr1.wav` | 358016 | `8d68825cf75741d32d75bd182130bb6ebb0bf3e9` |
| strings-opt | `Strings/Cello Section/susvib/susvib_C1_v3_1.wav` | 3335948 | `d3820a6d57daf9a202a000bff0fa082a3f77acf6` |
| strings-opt | `Strings/Cello Section/susvib/susvib_G1_v3_1.wav` | 3370496 | `35971538059e18b8f38cdc556630967777a0a0d5` |
| strings-opt | `Strings/Cello Section/susvib/susvib_D2_v3_1.wav` | 3291368 | `fdb46242bb68876ad275b9b8ed10c4b8508b9292` |
| strings-opt | `Strings/Cello Section/susvib/susvib_A2_v3_1.wav` | 3082676 | `ad696c6ad3cbacb37b6d9cf4f26da4a54521e7ce` |
| strings-opt | `Strings/Cello Section/susvib/susvib_E3_v3_1.wav` | 3278270 | `7711cb67795d692b0d732eb8fd234c41d5980f42` |
| strings-opt | `Strings/Cello Section/susvib/susvib_B3_v3_1.wav` | 2865086 | `3b1685e657db57bd71c979da8c2d9d35d2d0d197` |

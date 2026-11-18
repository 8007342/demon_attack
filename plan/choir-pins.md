# Brood-choir sample pins: epic-choir and 272 Merry Orks (2026-11-18)

The operator approved pinning two more sample libraries for the brood choir (`openspec/changes/demon-choir`,
`plan/demon-choir-research.md` §5a and §6a; operator feedback round 9). This file holds **research and pins only**, in
the method of `plan/sample-bank-pins.md`. **No sample audio was downloaded.** The only files fetched whole were licence
files, readmes, `SOURCE.json` and SFZ maps (each under 100 KB). For epic-choir's release zip, only the zip's central
directory (10,791 B of file names, sizes and CRC32s) and its 22-byte end record were read, by HTTP range; no byte of
any member's data was fetched.

The machine-readable list is **`plan/choir-pins.manifest.tsv`** (30 rows), a separate manifest rather than more rows in
`plan/sample-bank-pins.manifest.tsv`, for two reasons:
- epic-choir is **CC BY 4.0**, not CC0, so it does not belong in the open register's CC0 list that the first
  manifest feeds;
- epic-choir's samples are not git blobs: they exist only inside a release zip. Their rows have no git blob sha1 and
  no per-file raw URL, so the manifest adds four columns after the first manifest's seven: `crc32`, `zip_offset` (the
  member's local-header offset), `zip_csize` (its compressed size) and `container_sha256` (the zip's digest). Rows
  that are plain git blobs put `-` in those four columns, so a reader of the first seven columns still works.

## Method

- Refs from `git ls-remote https://github.com/<repo>`; both tags read through `/git/refs/tags/<tag>` are lightweight
  (`type: commit`), so the tag's sha is the commit.
- File lists from the GitHub tree API at the pinned commit (`/repos/<repo>/git/trees/<commit>?recursive=1`, neither
  truncated); releases from `/repos/<repo>/releases`.
- Licence files, readmes and maps fetched raw at the commit. `git hash-object` on each reproduces the tree API's blob
  sha1 (all 11 matched), and `sha256sum` gave the sha256 below.
- **LFS:** neither repo has a `.gitattributes` in its tree. The one Merry Orks sample probed with `HEAD` returns
  `content-length: 126834`, its tree size (`samples/misc/argh_rr1.wav`), so the samples are real blobs, not LFS
  pointers. epic-choir keeps no samples in git at all (only two demo MP3s, whose `HEAD` length also matches the tree).
- **epic-choir's zip:** `HEAD` on the release URL redirects to `release-assets.githubusercontent.com`, which answers
  `Accept-Ranges: bytes` with `Content-Length: 173859746`, equal to the API size. A suffix range was refused by the
  proxy's cache (`501 Unsupported client range`); an explicit range (`173859724-173859745`) returned the end record
  (156 entries, central directory 10,791 B at offset 173,848,933), and a second range returned exactly that directory,
  which ends where the end record starts. A Lua reader (session scratch, not committed) listed the members.

## Summary

| Library | Repo | Pin | Licence at the pin | Verdict | Reachable | Subset | Subset raw bytes |
|---|---|---|---|---|---|---|---:|
| epic-choir, B part | `thepok/epic-choir` | tag `v1.0` = `38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3` (also `main` HEAD) | `LICENSE`: CC BY 4.0, a derived work of VocalSet | **IN, conditional** on VocalSet's licence being confirmed upstream (§1.3) | repo, raw files, API and release asset: yes. Zenodo (upstream VocalSet): **no**, blocked by the forge proxy | 10 WAV (oh/ah × 5 notes, `f`) inside `epic-choir-v1.0-B.zip`, + 6 docs/maps | 13,414,084 (uncompressed members; 12,462,384 compressed) + 14,165 docs |
| 272 Merry Orks | `sfzinstruments/karoryfer.272-merry-orks` | tag `v1.001` = `a437e2c02014e02710a104a6692193eab8672d0a` (also `master` HEAD) | `LICENSE`: CC0 1.0 legal code, the same blob as the admitted Karoryfer repos | **IN** | yes (GitHub only) | 10 WAV (8 grunts, 2 growled vowels) + 3 docs/maps | 1,565,766 + 59,205 docs |
| **Both** | | | | | | **20 samples + 9 docs** | **14,979,850 samples; 15,053,220 with docs** |

## 1. thepok/epic-choir (CC BY 4.0): the B part's "oh" and "ah"

| Field | Value |
|---|---|
| Canonical source | https://github.com/thepok/epic-choir |
| Pin | tag `v1.0` → commit `38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3` (2026-10-24, "README: one zip per part"); `main` HEAD is the same commit |
| Licence file | `LICENSE`, 499 B, blob sha1 `628ff3e397a72da3607cd9f6af41fafc5f2e5e2e`, sha256 `89d6c6c8e6d919152ca115fce46c180b7e843dd04d0722602e7bd7986dc18ec6`: "Creative Commons Attribution 4.0 International (CC BY 4.0)", linking the legal code, and "The samples, SFZ programs and demos of epic-choir are a derived work of VocalSet (Wilkins, J., Prem Seetharaman, Alison Wahl, & Bryan Pardo. (2018). VocalSet: A Singing Voice Dataset (Version 1.2) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.1442513), licensed under CC BY 4.0, and are released under the same licence by thepok (2026)." The repository API's licence field says `NOASSERTION` (GitHub does not recognise the short text as a template); the file governs. |
| Docs at the pin | `README.md` 2,938 B (sha1 `9b16672aa90f2e5e5726f3ae27a4df12efeb0096`, sha256 `bcb7ad6efaf06d607b5c529fd7804892e4b7ad9857033e2ea0688adf3a1390b2`); `ATTRIBUTION.txt` 1,957 B (sha1 `e4143592a43aaebe04327d1012fff1223e3b4e81`, sha256 `1ef756e087e06c4e648c308f735ff726a13b4c2697bf899819f3c81ddacecd0c`); `SOURCE.json` 2,713 B (sha1 `551492908f901002c5b5b1dc101dc406a2f22d83`, sha256 `7355ea4d91d2c90747dc5b1547438f9862b46e5b7b2b1a0833ec25f9a1b57aea`; `"license": "CC-BY-4.0"`, source `VocalSet11.zip` md5 `0c09396242f946e7111ad7d8fc649b81`, 2,077,243,579 B) |
| Maps at the pin | `B_oh.sfz` 3,029 B (sha1 `0f676fdb69baa6bc4e3dfd4614117503270bf516`, sha256 `3846ea4738163482a5988467fab311c7648675d3622a39a9782ea2ea10edc2d0`); `B_ah.sfz` 3,029 B (sha1 `4e1cd86231ad253687dddf1d3e123d35fa969dc8`, sha256 `ca21700d938981b7b5a18d7adbcd9d6ca00bd2ecc0a14020303734f40c99a3bd`). Each maps 10 notes × `p`/`mf`/`f` (crossfaded on CC1): `As2 C3 D3 E3 Fs3 Gs3 As3 C4 D4 E4`, keycenters 46-64 in whole tones, keys 45-65 (A2-F4), every region `offset=3528` (80 ms at 44.1 kHz) |
| Tree at the pin | 26 blobs, 3,182,078 B: the 20 SFZ programs, the four docs and `demos/hymn.mp3`, `demos/phrases.mp3`. **No samples in git.** |
| Release asset | https://github.com/thepok/epic-choir/releases/download/v1.0/epic-choir-v1.0-B.zip, 173,859,746 B, API digest `sha256:3f78e9b59018dc2ef45bb30d1b57cb68f22768d15e1f1c1a4f93d0b5e4b3002f`. 156 members: 150 WAV (`samples/B/B_<vowel>_<dyn>_<note>.wav`, 5 vowels × 3 dynamics × 10 notes, 193.3 MB uncompressed in all), the 5 `B_*.sfz` and `ATTRIBUTION.txt`. The S, A and T zips (171.7-175.8 MB, each with its own digest) are not needed. |
| Zip copies of the docs | the zip's `B_oh.sfz` and `B_ah.sfz` are 3,070 B and its `ATTRIBUTION.txt` 1,979 B, against 3,029 and 1,957 in git. The git copies have 41 and 22 LF lines, so the differences (41 and 22 B) are consistent with CRLF line endings in the zip. That is our inference; the members were not extracted. The git copies at the pin are the ones pinned. |
| Format | 44.1 kHz 16-bit stereo, per the README ("600 [samples], one per whole tone (repitched by at most 1 semitone), 44.1 kHz 16-bit stereo"). Each subset member is 1.22-1.46 MB uncompressed, so about 7-8 s at 176,400 B/s (our arithmetic). |
| Singers | the B part sums the 10 male VocalSet singers (`m1`-`m8`, `m10`, `m11`: baritones, tenors, basses), 3-10 per sample (`ATTRIBUTION.txt`, `SOURCE.json`) |
| sha256 per sample | not provided; the zip has one API digest, and each member has the zip's CRC32 (manifest) |

[source: thepok, "epic-choir LICENSE, README.md, ATTRIBUTION.txt, SOURCE.json, B_oh.sfz, B_ah.sfz" at 38df98f,
https://raw.githubusercontent.com/thepok/epic-choir/38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3/LICENSE, read 2026-11-18];
[source: GitHub API, "thepok/epic-choir git tree at 38df98f",
https://api.github.com/repos/thepok/epic-choir/git/trees/38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3?recursive=1, read 2026-11-18];
[source: GitHub API, "thepok/epic-choir releases", https://api.github.com/repos/thepok/epic-choir/releases, read 2026-11-18];
[source: thepok, "epic-choir-v1.0-B.zip central directory" (bytes 173848933-173859745 only),
https://github.com/thepok/epic-choir/releases/download/v1.0/epic-choir-v1.0-B.zip, read 2026-11-18]

### 1.1 Licence verdict: IN, conditional

- epic-choir's own `LICENSE` at the pin grants CC BY 4.0. CC BY 4.0 allows commercial use, adaptation and
  redistribution, with attribution, an indication of changes and a link to the licence
  (`https://creativecommons.org/licenses/by/4.0/`, named in the `LICENSE` file; its legal text was not fetched here).
- It is **not CC0**, so it cannot enter the open register's CC0 list. It needs its own admission as a CC BY 4.0 source,
  with the credit line below shipped wherever the choir ships.
- The chain rests on VocalSet being CC BY 4.0 (§1.3), which is still not confirmed from the dataset's own page.
- **Caution, unchanged from the research:** a single-author repository created 2026-10-24 (API `created_at`
  2026-10-24T21:48:36Z, no stars). The README says it was built with AgentSound, the author's own tool.

### 1.2 Credit line (CC BY 4.0 requires it)

The README asks for this, verbatim:

> Choir samples derived from VocalSet (Wilkins, Seetharaman, Wahl, Pardo 2018), CC BY 4.0, https://doi.org/10.5281/zenodo.1442513 — epic-choir by thepok

`ATTRIBUTION.txt` asks for the same line without "— epic-choir by thepok"; the README's longer form covers both.
Because we change the samples (cut, pitch, downmix, resample, encode), CC BY 4.0 also needs the change noted and the
licence linked. **The exact line to ship** (credits page, and `choir.json`'s source `credit`):

> Choir samples derived from VocalSet (Wilkins, Seetharaman, Wahl, Pardo 2018), CC BY 4.0, https://doi.org/10.5281/zenodo.1442513 — epic-choir by thepok. Changed for this game: cut, pitched, downmixed to mono and encoded to Opus. Licence: https://creativecommons.org/licenses/by/4.0/

`tools/generate_credits.lua` carries it as one row: the README line as the name (linked to the repository), `CC BY 4.0`
as the licence, and the change note and licence URL as the source.

### 1.3 Upstream: VocalSet (Wilkins, Seetharaman, Wahl, Pardo, ISMIR 2018)

- **Zenodo is blocked** from the forge: `zenodo.org/records/1442513`, `zenodo.org/api/records/1442513` and
  `doi.org/10.5281/zenodo.1442513` each end in "Connection reset by peer" (checked 2026-11-18). Not routed around.
  [source: Zenodo, "VocalSet: A Singing Voice Dataset", https://zenodo.org/records/1442513, unread: blocked by the forge proxy]
- What was reachable says CC BY 4.0, but only second-hand:
  - the Hugging Face mirror's card (`license: cc-by-4.0`, revision `00fa241c9c941d8f6b1c5e640a1111e0e67a3815`);
    [source: Bill13579, "vocalset-mirror README", https://huggingface.co/datasets/Bill13579/vocalset-mirror, read 2026-11-18]
  - epic-choir's own `LICENSE` and `SOURCE.json` (above).
- The authors' lab pages reachable on GitHub state no licence: `interactiveaudiolab/vocalset_demo` (HEAD
  `aeed66719e5f17ad64d4388ef353b43025894f13`; a 182 B README, a notebook and its HTML) and the lab site's
  `demos/vocalset.html` (at `77870f7179bf5c8476f740a6a9594109fad73636`; only its CSS libraries' licences).
  [source: Interactive Audio Lab, "vocalset_demo README.md", https://github.com/interactiveaudiolab/vocalset_demo/blob/aeed66719e5f17ad64d4388ef353b43025894f13/README.md, read 2026-11-18];
  [source: Interactive Audio Lab, "demos/vocalset.html", https://raw.githubusercontent.com/interactiveaudiolab/interactiveaudiolab.github.io/77870f7179bf5c8476f740a6a9594109fad73636/demos/vocalset.html, read 2026-11-18]
- **Verdict:** VocalSet's licence is CC BY 4.0 per two independent second-hand sources, **unconfirmed at the source**.
  The coordinator (or the operator) should read the Zenodo record from the host, which is outside the forge's proxy
  by design, before epic-choir is admitted.

## 2. Karoryfer 272 Merry Orks (CC0): grunts, shouts and growls

| Field | Value |
|---|---|
| Canonical source | https://github.com/sfzinstruments/karoryfer.272-merry-orks |
| Pin | tag `v1.001` → commit `a437e2c02014e02710a104a6692193eab8672d0a` (2022-11-04, "Create LICENSE"); `master` HEAD is the same commit. Tag `v1.000` = `daa249d94f8bf85a3fbc01967d4d4d1e7244cfe3` predates the `LICENSE` commit, so it is not used (as with VCSL's old tag). |
| Licence file | `LICENSE`, 7,048 B, blob sha1 `0e259d42c996742e9e3cba14c677129b2c1b6311`, sha256 `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`: the CC0 1.0 legal code, byte-identical to the admitted Karoryfer and VCSL licence files. The API's licence field says `CC0-1.0`. |
| Readme | `readme.txt`, 492 B, sha1 `9fa7d2d5047d5d8deeb4634309dfa10eab836aa7`, sha256 `f048c4299a530f3385fbd26610ca18a7b23bbdffa22b1c9631727dead3e04538`: "272 Merry Orks is a sample library of female death metal vocals … one for monster voice sound design … Royalty-free for all commercial and non-commercial use. Copyright 2015 Karoryfer Lecolds." The CC0 `LICENSE` at the same commit governs, as for the other Karoryfer repos. |
| Maps | `ork_vocals.sfz` 51,665 B (sha1 `bc4e8173fb44d865ca1fdbb4267f7bbba5a51e94`, sha256 `68f034d7fa0fb78e6b799674f4e357e7da461991208ede0557514ec6f272a103`): maps every subset file (12 `misc` and 12 `vowels` regions match the subset's names). Also fetched and hashed, not in the subset: `ork_dialogue.sfz` 20,920 B (sha1 `ebec5cef3e3b1243bafb154a51b0b117ab1d0b5d`, sha256 `1ca94a8fea7900cbcd154e2ae831c611961046b476f922778727a4318326abdc`) and `ork_predrops.sfz` 5,426 B (sha1 `dcf4ebf9061d8fcfe144a8e315131696293309fa`, sha256 `be019d71cd9ceb831cb87aca9c24fa8f24bff9fe02786bd3a3c5048d8f5f5ff4`). |
| Tree at the pin | 277 blobs, 45,627,769 B: `samples/consonants` 96, `predrop` 70, `misc` 46, `vowels` 36, `dipthongs` 24 WAV |
| Release assets (not needed) | `v1.001`: `Karoryfer.272_Merry_Orks.v1.001.zip`, 40,439,723 B; `v1.000`: 40,442,101 B; API `digest`: **not provided** for either |
| Format | mono 44.1 kHz 24-bit, read from one WAV header by the earlier research (`plan/demon-choir-research.md` §5a); so 132,300 B/s, and the subset's grunts are 0.72-1.43 s and its growls 1.60-1.74 s long (our arithmetic) |
| sha256 per sample | not provided (plain git blobs): git blob sha1 in the manifest |

**Licence verdict: IN** (CC0 1.0, the same licence file as the admitted Karoryfer libraries).

**Credit line** (CC0 asks none; given as for the other Karoryfer libraries): "272 Merry Orks by Karoryfer Lecolds (CC0 1.0)".

[source: Karoryfer Lecolds/sfzinstruments, "karoryfer.272-merry-orks LICENSE, readme.txt, ork_vocals.sfz, ork_dialogue.sfz, ork_predrops.sfz" at a437e2c,
https://raw.githubusercontent.com/sfzinstruments/karoryfer.272-merry-orks/a437e2c02014e02710a104a6692193eab8672d0a/LICENSE, read 2026-11-18];
[source: GitHub API, "karoryfer.272-merry-orks git tree at a437e2c",
https://api.github.com/repos/sfzinstruments/karoryfer.272-merry-orks/git/trees/a437e2c02014e02710a104a6692193eab8672d0a?recursive=1, read 2026-11-18];
[source: GitHub API, "karoryfer.272-merry-orks releases", https://api.github.com/repos/sfzinstruments/karoryfer.272-merry-orks/releases, read 2026-11-18]

## 3. The subset

What the choir needs (`openspec/changes/demon-choir/design.md` §4): `brood` "oh"/"ah" zones on a velocity axis (oh
1-84, ah 85-127), one dynamic, and `grunt` hits as syllables a-d × 2 round robins.

| Instrument | Source | Files | Notes / pieces | Raw bytes | Trim | Seconds | Opus est. at 128 / 160 kbps mono |
|---|---|---:|---|---:|---|---:|---:|
| `brood` "oh" | epic-choir `samples/B/B_oh_f_*.wav` | 5 | A#2 D3 F#3 A#3 D4 (keycenters 46 50 54 58 62; major thirds, ±2 semitones of shift each, so G#2-E4, 1.67 octaves) | 6,766,200 | 2.6 s, loop as now | 13.0 | 208,000 / 260,000 |
| `brood` "ah" | epic-choir `samples/B/B_ah_f_*.wav` | 5 | the same five | 6,647,884 | 2.6 s | 13.0 | 208,000 / 260,000 |
| `grunt` | Orks `samples/misc/` | 8 | a = `ugh`, b = `oh`, c = `hey`, d = `argh` (softest to fiercest, on the velocity axis as now), `rr1`, `rr2` | 1,123,200 | 0.45 s hit, 0.15 s end fade | 3.6 | — / 72,000 |
| growl (new; `warcry` candidate) | Orks `samples/vowels/a_from_car_rr1`, `o_from_pot_rr1` | 2 | growled "ah" and "oh", unpitched | 442,566 | 1.6 s hit | 3.2 | — / 64,000 |
| **Subset** | | **20** | | **14,979,850** | | **32.8** | **552,000** (brood at 128) / **656,000** (brood at 160) |

Plus the 9 docs and maps (73,370 B). The `f` dynamic is the pick: it carries the most harmonics, which survive
the downmix and pitch shift, and every zone is normalised to −1 dBFS anyway (§12.11). `mf` at the same five notes is
the fallback if a listen prefers the softer colour (about 6.5 MB raw, the same Opus size).

**Rules for the cutter** (on top of `plan/sample-bank-pins.md` §6):
- epic-choir: extract only the 10 members (the manifest's `zip_offset` and `zip_csize` allow range reads of about
  12.5 MB instead of the 174 MB zip) and check each against its `crc32`; or fetch the whole zip and check the API
  sha256. Start each sample at the SFZ `offset=3528`. Pitch from `pitch_keycenter`.
- Resample 44.1 → 48 kHz (bank-fidelity step 2) and downmix the stereo hall takes to mono; check the downmix for
  comb filtering against one channel and keep whichever measures cleaner.
- Merry Orks: the voice is female; pitch it down into the grunt range (nominal C3, D#2-G3) as the ACE-Step grunts are.
  The `pitch_keycenter`s in `ork_vocals.sfz` (85 for `argh_rr1`, …) are key slots, not pitches.

## 4. Against the choir budget (800,000 B Opus, 9,000,000 B decoded, desktop only)

The rates follow §12.11's rule (the lowest rate whose median magnitude SNR reaches 35 dB, at most 160 kbps), measured
when cut. Until then: brood 128 kbps (what the synth brood measured, `demon-choir/design.md` §4.1) with 160 as the worst
case, and the shouts at the 160 cap, like the ACE-Step ones. 128 kbps mono is 16,000 B/s and 160 is 20,000 B/s; the
Ogg container adds 1-3 % (estimate, unmeasured). Decoded is 48 kHz Float32 mono, 192,000 B/s.

| Choir with | Opus | + 2 % Ogg | Decoded | Fits |
|---|---:|---:|---:|---|
| as built now (synth brood, ACE-Step grunts and cries) | 756,366 measured | | 7,677,400 measured | yes |
| epic-choir brood (128) + Orks grunts + growls + ACE-Step war cries (108,000) | 660,000 | ≈ 673,000 | 38.2 s → 7,334,400 | yes, ≈ 127 KB headroom |
| the same, brood at 160 | 764,000 | ≈ 779,000 | 7,334,400 | yes, ≈ 21 KB headroom |
| growls replace the ACE-Step war cries (brood 128) | 552,000 | ≈ 563,000 | 32.8 s → 6,297,600 | yes |
| + keep the synth "oh" at C2 and F2 for the low drones (2 zones, 83,200 at 128) | 743,200 | ≈ 758,000 | 43.4 s → 8,332,800 | yes, tight |
| brood kept **stereo** (160 kbps for both channels) | 764,000 | ≈ 779,000 | 26 s × 384,000 + 12.2 s × 192,000 = 12,326,400 | **no** (decoded over 9 MB): stays mono |

Phones: unchanged, no choir (the first bank's phone tier is full).

## 5. Gaps and open questions

1. **VocalSet's licence is unconfirmed at the source** (§1.3). Zenodo is blocked in the forge; read
   https://zenodo.org/records/1442513 from the host before admitting epic-choir.
2. **epic-choir is CC BY 4.0**, so the register needs a CC BY entry (not the CC0 list), and the credit line in §1.2 must
   ship with the choir. The credits page lists it under "Sample libraries (coming)", which is now the section's
   title; `openspec/changes/credits-page` still says "CC0 sample libraries" in its spec and design §6.
3. **The low drones fall below epic-choir's range.** The B part starts at A#2 (keys from A2). `c1:core` drones from F2
   and `k:B` from E2 (`demon-choir/design.md` §3), 5-6 semitones under the lowest zone. Options: shift A#2 down that far
   (a darker formant; it may suit a demon brood, a listen decides), keep two synth "oh" zones at C2/F2 (fits, table
   above), or raise the drones' floor.
4. **Single-author source.** epic-choir is three weeks old with one author; the pin is a commit and a digest, so
   later changes cannot reach us, but its provenance claims (singers, changes) rest on its own docs.
5. **Merry Orks is a female voice** pitched down for male demons; the ACE-Step grunts stay the fallback if a listen
   prefers them.
6. **No sha256 per sample**: Merry Orks samples have git blob sha1s; epic-choir members have CRC32s inside a zip whose
   sha256 is the API digest. The coordinator may record its own sha256s on the host.

## 6. Send to coordinator

```text
CHOIR PINS (demon_attack, work/choir-pins, plan/choir-pins.md + plan/choir-pins.manifest.tsv), 2026-11-18
No sample audio downloaded. Licence files, readmes, SOURCE.json and SFZ maps fetched at the pins; git hash-object
matches every tree sha1. epic-choir's zip: only its central directory was read (HTTP range).
Manifest columns: the sample-bank manifest's 7, then crc32, zip_offset, zip_csize, container_sha256 ("-" for git blobs).

IN (conditional)  thepok/epic-choir  v1.0 = 38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3   licence CC BY 4.0 (NOT CC0)
    LICENSE blob 628ff3e397a72da3607cd9f6af41fafc5f2e5e2e, sha256 89d6c6c8e6d919152ca115fce46c180b7e843dd04d0722602e7bd7986dc18ec6
    samples only in release asset epic-choir-v1.0-B.zip, 173,859,746 B, sha256 3f78e9b59018dc2ef45bb30d1b57cb68f22768d15e1f1c1a4f93d0b5e4b3002f
    subset 10 WAV members (13,414,084 B uncompressed, 12,462,384 compressed; CRC32 each) + 6 docs/maps (14,165 B)
    CONDITION: VocalSet (zenodo.org/records/1442513) licence = CC BY 4.0, confirmed only second-hand; Zenodo is
               blocked in the forge. Please read it from the host.
    CREDIT (must ship): Choir samples derived from VocalSet (Wilkins, Seetharaman, Wahl, Pardo 2018), CC BY 4.0,
      https://doi.org/10.5281/zenodo.1442513 — epic-choir by thepok. Changed for this game: cut, pitched, downmixed
      to mono and encoded to Opus. Licence: https://creativecommons.org/licenses/by/4.0/
IN  sfzinstruments/karoryfer.272-merry-orks  v1.001 = a437e2c02014e02710a104a6692193eab8672d0a   licence CC0 1.0
    LICENSE blob 0e259d42c996742e9e3cba14c677129b2c1b6311 (same as the admitted Karoryfer repos)
    subset 10 WAV (1,565,766 B) + 3 docs/maps (59,205 B); no LFS; release zip digest not provided (not needed)
TOTAL 29 files, 15,053,220 B raw (20 samples, 14,979,850 B)
Choir estimate: ≈ 673 KB Opus with brood at 128 kbps (≈ 779 KB at 160), 7.33 MB decoded; budget 800 KB / 9 MB, desktop only
```

## Appendix: every file in the subset

`plan/choir-pins.manifest.tsv` holds every row (path, bytes, git blob sha1 or CRC32, URL, zip offsets). The groups:
`doc` (9), `release` (1, the B zip), `brood-oh` (5), `brood-ah` (5), `grunt` (8), `growl` (2).

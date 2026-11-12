# Design

## Approved direction
Treat the entire five-level campaign as one long original song. DragonForce references describe pacing, instrumental virtuosity and long crescendos, not material to reproduce. Wordless choir is permitted; sung lyrics would compete with radio. Do not equate increasingly loud mastering with increasing musical intensity.

## Score architecture
Inventory actual level durations and music state transitions before choosing section lengths. Establish a common thematic and harmonic map, then write extended sections with compatible stems and phrase-boundary alternatives. Compose each outgoing level bridge together with the next arrival. Variable gameplay duration requires non-obvious alternate phrases and evolving arrangements rather than restarting short full-mix loops. Boss progression must reach the campaign's strongest arrangement. Quantize musical accents; never delay gameplay to match music. Weapon/effect integration is optional and requires listening evidence before expanding replacement scope.

## Comms and mobile
Two half-width cards show full subtitles, with portraits at the outer edges. Audio remains paced so overlapping voices do not mask one another; two visible cards need not mean two voices speaking continuously. Explicit reply linkage retains the opener through its comeback and identifies the pair. Preserve HUD/touch clearance at 360px widths and landscape. Alien writing should use a stable original alphabet with progressive reveal and a translation delayed slightly behind it, plus accessible readable meaning. Avoid random changing glyph identities.

Human voices: expressive clean performance, light radio treatment applied after mastering. Demons: original performances with per-character down-pitch and reversal, selected by listening; avoid destructive distortion as a substitute for a convincing performance. Derive mouth timing from the final transformed voice, excluding radio noise. Compare repair cost with regeneration; preserve face alignment and identity across mouth frames.

## Ending
Keep battle language playful. Scatter sparse ambiguous references to turns, supplies, sand or snacks among ordinary battle exchanges without explaining the setting. After all five levels, pull back from apparent battle into a board on a San Diego beach with teenage human and demon friends, then show credits with a warm thematic reprise. Respect reduced motion, skip/replay, saved progression and score submission; inspect existing victory/cycle flow before insertion. Credits must use verified contributors and model/asset attribution, never invented names.

## Rendering and recovery
Inventory available CPU/GPU/NPU, RAM/VRAM, installed models, licences and current jobs first. Serialize GPU workloads where required. Lua owns orchestration; Rust/Go own suitable DSP/throughput work; necessary Python model runtimes remain isolated. Each render ledger records immutable input/config hashes, model/version/licence, seed, job/output locations, checksums, status, failures and review decisions. Resume verifies outputs rather than merely trusting a completed flag. Local caches are ephemeral: push small manifests and work frequently, and establish durable storage for lossless masters before large renders. Preserve shipped assets until reviewed replacements are complete.

## Acceptance
Automated measurements detect clipping, loudness, seams and timing, but do not establish musical quality. Listen to long passages, every level bridge, boss escalation and repeated event accents. Review mobile mouths with final audio in context. Record what was actually auditioned and unresolved issues; never call metrics-only selection an audition.

## Reference availability
The operator made kumbia-kombat public and access now succeeds. Inspected commit a922b434b280bd4db15d9933da23250d9083f4d2: lib/credits/credits_page.dart, credits_data.dart, assets/credits.json and the add-credits-roll design/spec. The roll leads with “Built using / Tillandsias.org”, groups verified dependencies by degree, auto-scrolls with touch hold, close and browser sound recovery, and follows the final campaign end screen. Adopt these principles using our own dependency/provenance records, with a Lua generator and dedicated thematic reprise. Support reduced motion and manual scrolling; do not transplant its stand-in music or its dependency list. Contributor identities and final provenance still require verification against this project.

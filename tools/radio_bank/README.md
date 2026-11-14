# Radio bank assembly and verification

Build with `go build -o <cache>/radio-bank .` in this directory. It uses Go's
standard library and the installed FFmpeg decoder; it never loads a speech model.

From the repository root:

```
<cache>/radio-bank --out <cache>/radio-bank-staging
lua tools/production/stage_radio_bank.lua <cache>/radio-bank-staging <cache>/radio-tree
```

The assembler requires all source lines by default. It checks the exact clip
identity and current input hashes, all three retained master hashes, Opus hash,
decoded sample count (within two 24 kHz samples), finite samples, peak <= 0 dBFS,
BS.1770 loudness within 1.5 LU of the voice target, mouth-track duration,
nonzero openness and absence of single-frame mouth flicker. The Go K-weighting
implementation is checked against the existing scipy reference and gain law.
Codec/corruption tests exercise an actual encoded Opus fixture.

`--allow-partial` is only a development audit. It writes `complete:false` and
lists missing/stale/invalid candidates. The Dart staging exporter rejects it.
A strict incomplete assembly removes an old staging manifest and exits nonzero.
The tool refuses to assemble directly over the runtime bank. No source assets
are promoted or deployed by either command. Final integration can copy only the
complete verified manifest's clip inventory, regenerate Dart data, and remove
legacy AAC files. Listening and synchronized mouth review remain separate from
numeric validation; the manifest records that they are pending.

Every staging directory is owned by the assembler. Use a fresh cache directory,
not a directory containing unrelated user files. Run `go test ./...` for the
filter, timing, stale-input, encoded-audio and corruption checks.

# Guidelines and specs hardening

## Why

Workstream G1 of `plan/operator-feedback-2026-11-16.md`. The two blind bonus-level builds logged 63 blockers
(`plan/bonus-levels-blockers-a.md`, `-b.md`), and most of them came from missing working rules. The repo had no
`CLAUDE.md` or `AGENTS.md`, the OpenSpec context still described the 2025 game, strict validation failed on `game`
(7 of 47 items), 38 changes were unarchived, and research conclusions had lost their sources. The operator made
provenance mandatory. Nothing outside the committed repo survives a forge exit, so the rules have to live in the
repo.

## What changes

- `CLAUDE.md` (authoritative) and `AGENTS.md` (a pointer) at the repo root. They cover the branch flow, the test
  gates, generated files, the asset pipelines, the OpenSpec workflow, the calibration gates, provenance and the forge
  rules. Every command they document was run.
- `openspec/config.yaml` and `openspec/project.md` are refreshed, and `config.yaml` gains `rules:` for spec length,
  MODIFIED blocks and provenance.
- 15 finished changes are archived in chronological order. The strict-validation failures are fixed or recorded
  (see design).
- Durable rules move into the specs: a new `development-workflow` capability, rules that every hazard keeps
  (`arcade-combat`), where powers drop from (`arcade-combat`), and flash safety (`arcade-presentation`).
- Every blind-test blocker that needs only a doc or config change is fixed. The rest become tasks below, each
  with its reason.
- Provenance audit: `plan/provenance-audit.md`, with citations or `UNSOURCED` marks added inline.

## Impact

Docs, OpenSpec files and plan files only. No `lib/` code changes: the `LevelDef` extraction and the other code
blockers are planned as tasks, because four other workstreams are editing `lib/` right now.

# Development workflow

## ADDED Requirements

### Requirement: Branch flow
Work SHALL happen on `work/<id>` branches that merge with `--no-ff` into the integration branch `game`; `main` SHALL move only by pull request, because pushes to `main` deploy production. A branch that has been pushed SHALL NOT be rewritten; it SHALL take later `game` commits by merging `origin/game`.

#### Scenario: Game moved after a push
- **WHEN** `game` gains commits after a work branch was pushed
- **THEN** the branch merges `origin/game` and pushes fast-forward, and is never rebased

### Requirement: Test gates before integration
No push to `game` SHALL happen unless `flutter analyze` reports no issues, `flutter test` prints "All tests passed!", `npm run test:worker` has no failures, `npm run build` succeeds and the branch's own OpenSpec change validates with `--strict`.

#### Scenario: Toolchain flake
- **WHEN** the `flutter test` output lacks the "All tests passed!" line, even with a zero exit status
- **THEN** the push waits until a clean run prints it

### Requirement: Generated files are regenerated, not edited
A file whose header says it is generated SHALL change only by rerunning its generator (listed in `CLAUDE.md` §4). When two branches both changed one, the merge SHALL resolve its inputs and rerun the generator.

#### Scenario: Two branches add radio lines
- **WHEN** two branches each append lines to `art/comms/lines.json`
- **THEN** the merge keeps both blocks and reruns `python3 -I tools/comms_pipeline.py dart` instead of hand-merging `lib/comms/comms_bank.dart`

### Requirement: Research provenance
Every research conclusion in a spec or plan document SHALL keep its source beside it: author or organisation, title, URL or citation, and date read. A conclusion with no source that can be verified online SHALL be marked `UNSOURCED` with a reference into `plan/provenance-audit.md`. Citations SHALL NOT be invented.

#### Scenario: New research
- **WHEN** an agent writes a conclusion drawn from a talk, paper or web page
- **THEN** the line carries `[source: Author/Org, "Title", URL, read YYYY-MM-DD]`

#### Scenario: Source cannot be reached
- **WHEN** the only source for a claim cannot be opened from the forge
- **THEN** the claim is marked `UNSOURCED` and listed in the audit, not cited from memory or a search snippet

### Requirement: Render durability and studio safety
Picked raw renders and their rebuild recipes SHALL be committed, because a host reset wipes everything outside the repository and re-rendering a seed is not byte-identical. Agents SHALL NOT call `studio.restart`, and SHALL NOT start a model download without the operator's consent token.

#### Scenario: A pick is made
- **WHEN** an agent picks a render
- **THEN** the raw, the pick's reason and the recipe are committed and logged in the run ledger and on the contact sheet

#### Scenario: A model is missing
- **WHEN** a tool answers `consent_required`
- **THEN** the agent shows its `ask` sentence to the operator verbatim and retries only with the token they give

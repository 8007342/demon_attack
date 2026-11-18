# Agents

Read [CLAUDE.md](CLAUDE.md): it is the authoritative rule set for every agent in this repository, whatever the tool
(Claude Code, Codex, OpenSpec skills). The short form:

- Work on `work/<id>` in a worktree under `~/.cache/tillandsias-project/worktrees/`, push only that branch; the lead
  squashes it into `game` (one commit per piece of work); `main` moves only by pull request. Never push `main`; never rebase a branch after pushing it (merge `origin/game`).
- Gates before a push: `flutter analyze` clean, `flutter test` prints "All tests passed!", `npm run test:worker`,
  `npm run build`, `openspec validate <change> --strict`.
- Never hand-edit generated files (CLAUDE.md §4); regenerate them.
- Work is an OpenSpec change; plans live in `plan/`; research keeps its sources beside each conclusion.
- Never `studio.restart`, never download a model without the operator's consent token, never commit `.agents/skills/`
  or `.claude/`.
- Stop a process by PID (`pgrep -af <name>`, then `kill <PID>`), never `pkill -f`. Never wait with
  `until ! pgrep -f '<pattern>'`: the loop matches itself and never ends. Take the background job's completion notice,
  or loop on `kill -0 <PID>` under a `timeout` (CLAUDE.md §9).

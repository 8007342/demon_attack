# Agents

Read [CLAUDE.md](CLAUDE.md): it is the authoritative rule set for every agent in this repository, whatever the tool
(Claude Code, Codex, OpenSpec skills). The short form:

- Work on `work/<id>` in a worktree under `~/.cache/tillandsias-project/worktrees/`; merge `--no-ff` into `game`;
  `main` moves only by pull request. Never push `main`; never rebase a branch after pushing it (merge `origin/game`).
- Gates before a push: `flutter analyze` clean, `flutter test` prints "All tests passed!", `npm run test:worker`,
  `npm run build`, `openspec validate <change> --strict`.
- Never hand-edit generated files (CLAUDE.md §4); regenerate them.
- Work is an OpenSpec change; plans live in `plan/`; research keeps its sources beside each conclusion.
- Never `studio.restart`, never download a model without the operator's consent token, never commit `.agents/skills/`
  or `.claude/`.

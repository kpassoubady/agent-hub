# Changelog

All notable changes to this hub are recorded here. Hub follows semver; each agent file also carries its own `version:` in frontmatter for finer-grained tracking.

## [0.2.0] — 2026-06-02

### Added

- **`agent-hub-detect.sh`** — auto-generates `.agenthub-config.yaml` for any project. Detects language, framework, project shape, test framework, suggested source folders, and default test/lint/typecheck commands. Supports `--force`, `--dry-run`, and a positional project-path argument.
- **Project shape model** in `.agenthub-config.yaml`: `full-stack`, `backend-only`, `frontend-only`, `library`. The orchestrator uses this to skip irrelevant builders.
- **Escalating retry context** in the `feature-factory` orchestrator. Attempt 1 gets the full brief; attempt 2 gets a narrow failure-focused prompt; attempt 3 adds root-cause context and prior-attempt summaries.
- **Learning directory pattern** (`<project>/.claude/feature-factory/learning/`) for cross-run memory: `patterns.md` (researcher), `selectors.md` (test-verifier), `failures.md` (validator). Documented in the orchestrator and referenced from `researcher`, `spec-writer`, and `validator`.
- **CHANGELOG.md** (this file).

### Changed

- **`spec-writer.md`** output contract now leads with a one-line `Builders needed:` declaration so the orchestrator knows whether to invoke backend-builder, frontend-builder, both, or neither for the current feature.
- **`feature-factory` SKILL.md** gained a `Step 0 — Read project shape` section and a per-feature override rule: a builder is skipped when its section in the brief is `None`, regardless of project shape.
- **`validator.md`** gained a failure mode for recurring findings: append to `learning/failures.md` and recommend a `CLAUDE.md` or hub-config rule.
- **`researcher.md`** now reads `learning/patterns.md` at start and appends novelties at the end.
- **README** updated with auto-detect instructions, the new schema, and the project-shape table.
- **VERSION** bumped to `0.2.0`.

### Migration from 0.1.x

Existing projects on v0.1 don't have `project.shape` in their config. The orchestrator falls back to `full-stack` and warns once per run. Run `./agent-hub-detect.sh --force` from the hub directory against any project to upgrade its config to v2 schema.

## [0.1.0] — 2026-05-27

### Added

- 7-agent factory chain: `researcher`, `story-writer`, `spec-writer`, `backend-builder`, `frontend-builder`, `test-verifier`, `validator`.
- `feature-factory` orchestrator skill with three human checkpoints (story, brief, PR).
- `install.sh` / `install.ps1` — Claude Code installer (copies modules to `~/.claude/`).
- `sync-windsurf.sh` — Windsurf workspace sync (symlinks by default).
- `hooks/block-secrets.sh` — pre-commit secret blocker.
- `diagrams/` — mermaid diagrams for factory chain, distribution, drift loop.
- Repository structure: `agents/`, `skills/`, `hooks/`, `templates/`, `diagrams/`.
- `LICENSE` (MIT) and `.gitignore`.

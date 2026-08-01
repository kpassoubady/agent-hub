# Changelog

All notable changes to this hub are recorded here. Hub follows semver; each agent file also carries its own `version:` in frontmatter for finer-grained tracking.

## [0.5.0] — 2026-07-31

### Added

- **Generic graph-engine skill** (`skills/graph-engine/SKILL.md`) — a reusable multi-node orchestration protocol for skills that need more than one loop: nodes (agents/tools/checks), edges (sequential, conditional, parallel fan-out, fan-in, loop-back), a shared-state contract (`graph-state.json`), and a "reality anchor" requirement to avoid all-LLM graphs agreeing with themselves. Composes `loop-engine` for per-node retries. Maps directly onto Claude Code's native [dynamic workflows](https://code.claude.com/docs/en/workflows) (`agent()`, `parallel()`, `pipeline()`, `phase()`) when available, with a documented fallback to sequential subagent calls otherwise.
- **Graph guide** (`docs/graph-guide.md`) — when a graph is warranted (the 4-box test), the "sequential because it has to be vs. sequential because I said so" trap (a node whose stated input is another node's live output is not parallelizable without finding the real upstream contract first), and a worked case study using feature-factory's backend/frontend step.
- **Graph-aware skill template** (`templates/graph-template.md`) — skeleton for new skills with more than one node, covering nodes, contract, fan-in gate, reality anchor, optional configurable sequential/parallel modes, and the dynamic-workflow primitive mapping.
- **Graph engine diagram** (`diagrams/05-graph-engine.md`) — the generic fan-out/fan-in/reality-anchor shape, and `feature-factory`'s Step 4 redrawn as an explicit graph with its sequential and parallel paths.
- **Configurable parallel backend/frontend build** in `feature-factory` Step 4. `spec-writer`'s brief now declares `API contract confidence: high | low`; combined with the new `.agenthub-config.yaml` key `build.parallel-builders` (`auto` | `always` | `never`, default `auto`), the orchestrator decides per feature whether backend-builder and frontend-builder build concurrently against the brief's API section (the contract) or sequentially with frontend consuming backend's actual summary. A new fan-in **contract-check** gate (`04b-contract-check.md`) reconciles the brief's promise against both builders' actual output in parallel mode, routing mismatches back through the existing loop-back path (max 3 round trips, unchanged).

### Changed

- **`spec-writer.md`** (1.1.0 → 1.2.0) gained the `API contract confidence` output section and guidance that a wrong `high` call costs a reconciliation round trip — default to `low` when in doubt.
- **`frontend-builder.md`** (1.0.0 → 1.1.0) now supports two contract sources: backend-builder's summary (sequential mode, unchanged) or the brief's API section directly (parallel mode). Reports which source it used so the orchestrator's fan-in gate knows what to diff against.
- **`backend-builder.md`** (1.0.0 → 1.1.0) gained a failure mode for parallel mode: flag brief ambiguity explicitly rather than silently guessing, since there's no live frontend feedback loop to catch it mid-build.
- **`feature-factory` SKILL.md** (1.2.0 → 1.3.0) Step 4 rewritten with the sequential/parallel decision table, a "Graph integration" section referencing `graph-engine`, an updated Loop point 3 covering both the sequential handoff loop and the new parallel contract-check loop, and the state file list updated with `04b-contract-check.md` and `graph-state.json`.
- **README** gained a "Graph framework" section (mirroring the existing "Loop framework" section), `graph-engine` in the project tree, the `build.parallel-builders` config key in the schema example, and a Windsurf compatibility note that parallel fan-out requires Claude Code dynamic workflows and falls back to sequential in Windsurf.
- **`CLAUDE.md`** repository layout and config schema sections updated to include `graph-engine`, `graph-guide.md`, `graph-template.md`, and `build.parallel-builders`.
- **`diagrams/README.md`** updated with `05-graph-engine.md` entry.
- **VERSION** bumped to `0.5.0`.

## [0.4.0] — 2026-06-25

### Added

- **GitHub Copilot workspace sync scripts** (`sync-github-copilot.sh`, `sync-github-copilot.ps1`) — sync agents and skills to GitHub Copilot workspaces under `.github/copilot/`. POSIX shell script for macOS/Linux and PowerShell script for Windows support. Follow the same pattern as `sync-windsurf.sh` (symlink by default, with force and copy options).

### Changed

- **README** updated with GitHub Copilot sync in project tree and usage documentation.
- **VERSION** bumped to `0.4.0`.

## [0.3.0] — 2026-06-21

### Added

- **Generic loop-engine skill** (`skills/loop-engine/SKILL.md`) — a reusable loop protocol that any skill can invoke for iterative work. Handles the 5-phase loop lifecycle (DISCOVER → PLAN → EXECUTE → VERIFY → ITERATE), state persistence via `loop-state.jsonl`, escalating retry context, stop conditions, cost awareness, and three operating modes (`autonomous`, `checkpointed`, `hybrid`).
- **Loop configuration schema** (`templates/loop-config-schema.yaml`) — YAML schema for declaring loop behaviour in any skill's frontmatter: max-iterations, mode, verifier type (command / agent / rubric), escalation strategy, state directory, checkpoint behaviour, learning paths, and optional token budget.
- **Loop-aware skill template** (`templates/loop-template.md`) — skeleton for building new skills that use the loop-engine protocol, complementing the existing `agent-template.md`.
- **Loop framework diagram** (`diagrams/04-loop-framework.md`) — mermaid diagrams showing the generic loop lifecycle, escalating context flow, and how the feature-factory maps its 5 loop points to the engine.
- **Loop guide** (`docs/loop-guide.md`) — practical documentation: when to loop (the 4-box test), how the engine works, building loop-aware skills step by step, extending for specific projects, feature-factory as case study, and cost awareness.

### Changed

- **`feature-factory` SKILL.md** gained a "Loop integration" section referencing the loop-engine protocol for its 5 existing retry loops (story revisions, spec revisions, backend↔frontend handoff, test failures, validator criticals). Additive only — no existing behaviour removed.
- **Factory chain diagram** (`diagrams/01-factory-chain.md`) updated with a cross-reference to the loop framework diagram.
- **README** updated with loop framework section, `loop-engine` in the project tree, and loop framework diagram reference.
- **`diagrams/README.md`** updated with `04-loop-framework.md` entry.
- **VERSION** bumped to `0.3.0`.

## [0.2.0] — 2026-06-02

### Added

- **`agent-hub-detect.sh`** — auto-generates `.agenthub-config.yaml` for any project. Detects language, framework, project shape, test framework, suggested source folders, and default test/lint/typecheck commands. Supports `--force`, `--dry-run`, and a positional project-path argument. Languages supported: Python, Node, Ruby, Go, Rust, Java (Maven + Gradle), and .NET (C# / F#).
- **Project shape model** in `.agenthub-config.yaml`: `full-stack`, `backend-only`, `frontend-only`, `library`. The orchestrator uses this to skip irrelevant builders.
- **Escalating retry context** in the `feature-factory` orchestrator. Attempt 1 gets the full brief; attempt 2 gets a narrow failure-focused prompt; attempt 3 adds root-cause context and prior-attempt summaries.
- **Learning directory pattern** (`<project>/.claude/feature-factory/learning/`) for cross-run memory: `patterns.md` (researcher), `selectors.md` (test-verifier), `failures.md` (validator). Documented in the orchestrator and referenced from `researcher`, `spec-writer`, and `validator`.
- **CHANGELOG.md** (this file).

### Changed

- **`agent-hub-detect.sh`** language-aware folder suggestions:
  - Java projects suggest `src/main/java` (backend) and `src/test/java` (test) instead of generic defaults.
  - Python "script-style" projects (with `.py` files at the root and no package or `src/` directory) suggest `.` (project root) instead of a non-existent `src/`.
  - Java `test-command` and `typecheck-command` detect Gradle vs Maven and use the right tool.
  - .NET projects get `dotnet test`, `dotnet build --no-restore`, `dotnet format --verify-no-changes`.
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

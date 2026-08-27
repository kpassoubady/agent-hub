# Changelog

All notable changes to this hub are recorded here. Hub follows semver; each agent file also carries its own `version:` in frontmatter for finer-grained tracking.

## [0.8.0] — 2026-08-27

Motivated by running `agent-hub-detect.sh` against 10 real POC/MVP repos: several produced a config pointing at folders that don't exist, and none of the sample repos without tests had any path forward other than hand-writing a test setup before `/feature-factory` could gate meaningfully.

### Added

- **`test-bootstrapper` agent + `test-bootstrap` skill.** Installs a minimal, idiomatic test framework (pytest / vitest+Playwright / JUnit / xUnit, chosen by language) for a project that has none, writes one real passing smoke test per side, and updates `.agenthub-config.yaml` to match. Scaffolding only — it does not write feature-specific tests (`test-verifier`'s job) or chase coverage (a coverage-raising agent's job). Requires `backend.folders`/`frontend.folders` to already be confirmed; a human checkpoint gates the framework choice before anything is installed.
- **`feature-factory` (1.4.0 → 1.5.0): Step 0 now rejects placeholder test commands.** A `test.command` (or any `*-command` key) that resolves to `agent-hub-detect.sh`'s own fallback text or an unconfirmed `REPLACE_ME` folder now fails validation the same as a command that doesn't resolve at all, and points the user at `/test-bootstrap`. Previously such a config could pass Step 0 and let the coverage report and validator both report green against a command that runs nothing.

### Fixed — `agent-hub-detect.sh` silently emitted folders that don't exist

- **`first_existing_dir` no longer falls back to a guessed name.** It previously returned its first candidate literally even when none of the candidates existed on disk — e.g. a dotnet project with no `src/` directory (`recipe-sharing-app`'s `RecipeApp.Api`/`.Client`/`.Shared` layout) still got `backend.folders: [src]`, a path that doesn't exist. It now returns empty, and the generated config emits an explicit `REPLACE_ME` placeholder plus a `WARNING` comment naming which sections need manual attention, instead of a folder reference that silently doesn't exist.
- **dotnet multi-project solutions with no top-level `src/` are now detected correctly.** Backend/frontend detection previously only checked for directories literally named `frontend`/`web`/`client`/`static/js`, which never matches per-project naming like `RecipeApp.Client`. `recipe-sharing-app` was misclassified as `backend-only`; it's now correctly `full-stack` with `backend.folders: [RecipeApp.Api]` and `frontend.folders: [RecipeApp.Client]`.
- **Frontend folder candidates gained `static`/`templates`.** Flask/Jinja-style layouts (`trimly`, `movie-watchlist`) previously fell through to a guessed `src/web` that doesn't exist.
- **Node backend/frontend detection still misses flat-root layouts** (e.g. `book-log`'s root-level `app.js`, `quote-of-the-day`'s root-level `server.js`) — these now correctly surface the `REPLACE_ME`/WARNING path instead of emitting a wrong `src/server` guess, but no folder is auto-detected for them yet. Left as a known gap rather than adding another fixed candidate name — see the WARNING block's advice to restructure.
- **A `set -e`/`pipefail` regression introduced while fixing the above** silently aborted the script (no output, exit 1) on projects where a folder guess came back empty. Fixed by ensuring `first_existing_dir` and the new dotnet detection helpers always exit 0 on the "nothing matched" path.

## [0.7.0] — 2026-08-27

Motivated by a retrospective on 21 real chain runs across two projects — see `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md`.

### Changed — Step 0 is now a blocking gate (breaking behaviour change)

- **`feature-factory` (1.3.0 → 1.4.0): Step 0 blocks instead of warning.** Previously a missing `.agenthub-config.yaml` produced a one-time warning and the chain assumed `full-stack`. It now resolves to one of three outcomes:
  - *missing* → run `agent-hub-detect.sh -d`, show the proposed YAML, require **accept / edit / abort**;
  - *invalid* → **stop**, reporting every offending key (folders/files that don't exist, commands that don't resolve, overlapping backend/frontend scopes, unknown `project.shape` or `build.parallel-builders`);
  - *valid* → proceed.
  - A `--no-config` escape hatch remains for genuine one-offs and must be disclosed in the Checkpoint 3 summary.
- **The gate's decisions are now binding.** Step 0 writes `00-config-resolved.md` into the run's state directory holding the validated shape, folder scopes, and command strings. **Every downstream agent reads that file instead of re-deriving from `.agenthub-config.yaml` or `package.json`.** In one observed run, four separate stages re-derived the same test commands because nothing bound the Step 0 result.
- **A skipped builder is no longer spawned.** The orchestrator writes the one-line placeholder itself, naming the rule that caused the skip. Previously a project correctly declaring `shape: backend-only` still had `frontend-builder` spawned on 8 of 18 features, each time consuming a context window to write "N/A — backend-only".
- **`adaptive-engine` (1.0.0 → 1.1.0): added Phase 0**, running the same gate before the planner. A planner working from an assumed shape emits nodes for builders the project may not have, and every node inherits unvalidated commands.
- **`adaptive-engine`: slug derivation is now deterministic** and shared with `feature-factory` (description → lowercase → slugify → truncate 40). Planning must first check for an existing state directory and resume rather than re-plan. One story was previously planned twice, two minutes apart, under two different slugs, producing two mutually incompatible graph schemas — neither matching the feature-factory directory holding the actual work.
- **All 8 agents bumped** (`researcher` 1.2.0, `story-writer` 1.1.0, `spec-writer` 1.3.0, `backend-builder` 1.2.0, `frontend-builder` 1.2.0, `test-verifier` 1.1.0, `validator` 1.2.0, `planner` 1.1.0) — each now prefers `00-config-resolved.md` and falls back to reading the YAML only when invoked standalone outside a chain.

### Added

- **`backend.files` / `frontend.files` (schema v2, optional)** — individual files owned by one side when a folder is genuinely shared with the other. Solves the Next.js App Router case, where `src/app` holds both `api/` route handlers and the `page.tsx`/`layout.tsx` shell: give the subtree to the backend and list the shell files under `frontend.files`, keeping scopes non-overlapping without splitting the framework's tree.
- **`docs/config-gate-guide.md`** — teaching-oriented guide: what the gate is, why it blocks, why it must be binding, the full validation list, the overlap rule and its Next.js wrinkle, and a graded exercise with four seeded defects.

### Fixed

- **`agent-hub-detect.sh` emitted overlapping scopes.** For a Next.js project it produced `backend.folders: [src]` alongside `frontend.folders: [src/components]` — an overlap the new gate correctly rejects, meaning the detector's own output would have failed validation. It now detects nesting, narrows the outer side to real subfolders (`src/app/api`, `src/lib`, `src/utils`), emits Next.js shell files under `frontend.files`, and explains what it narrowed in a `# NOTE:` block. Non-overlapping layouts (e.g. `src/server` + `src/web`) are unaffected.
- **`agent-hub-detect.sh` bash 3.2 compatibility.** The new logic initially used `mapfile`, which does not exist in the bash 3.2 that ships with macOS; replaced with a portable read loop, plus an empty-array guard around `printf`.

## [0.6.0] — 2026-08-01

### Added

- **`install_all.sh` / `install_all.ps1`** — one command to install/sync Agent Hub into Claude Code, Gemini/Antigravity, Devin, and GitHub Copilot at once.
- **`gemini_install.sh` / `gemini_install.ps1`** — install agents, skills, templates, and hooks as a Gemini/Antigravity plugin under `~/.gemini/config/plugins/agent-hub/`, including a `plugin.json` manifest.
- **`claude_install.sh` / `claude_install.ps1`** — convenience wrappers around the existing `install.sh` / `install.ps1` for users familiar with the personal-helper naming.
- **`devin_install.sh` / `devin_install.ps1`** — convenience wrappers around `sync-devin.sh` / `sync-devin.ps1`.
- **`sync-devin.ps1`** — Windows PowerShell workspace sync for Devin.
- **`-Global` support in `sync-github-copilot.ps1`** — sync GitHub Copilot agents and skills to `~/.copilot/` on Windows, matching the `--global` flag in `sync-github-copilot.sh`.

### Changed

- **Windsurf is now Devin.** `sync-windsurf.sh` has been renamed to `sync-devin.sh` and now targets `.devin/workflows/` (the Devin Desktop preferred location). `.windsurf/workflow/` directories still work as a legacy fallback in Devin Desktop and are left untouched.
- **README** updated with the new multi-tool installer list, `install_all` usage, a per-tool installer table, and the renamed Devin sync section.
- **CLAUDE.md** repository layout and installation examples updated to list all new scripts.
- **VERSION** bumped to `0.6.0`.

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
- **README** gained a "Graph framework" section (mirroring the existing "Loop framework" section), `graph-engine` in the project tree, the `build.parallel-builders` config key in the schema example, and a Devin compatibility note that parallel fan-out requires Claude Code dynamic workflows and falls back to sequential in Devin (formerly Windsurf).
- **`CLAUDE.md`** repository layout and config schema sections updated to include `graph-engine`, `graph-guide.md`, `graph-template.md`, and `build.parallel-builders`.
- **`diagrams/README.md`** updated with `05-graph-engine.md` entry.
- **VERSION** bumped to `0.5.0`.

## [0.4.0] — 2026-06-25

### Added

- **GitHub Copilot workspace sync scripts** (`sync-github-copilot.sh`, `sync-github-copilot.ps1`) — sync agents and skills to GitHub Copilot workspaces under `.github/copilot/`. POSIX shell script for macOS/Linux and PowerShell script for Windows support. Follow the same pattern as `sync-devin.sh` (symlink by default, with force and copy options).

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
- `sync-devin.sh` — Devin workspace sync (symlinks by default; formerly Windsurf).
- `hooks/block-secrets.sh` — pre-commit secret blocker.
- `diagrams/` — mermaid diagrams for factory chain, distribution, drift loop.
- Repository structure: `agents/`, `skills/`, `hooks/`, `templates/`, `diagrams/`.
- `LICENSE` (MIT) and `.gitignore`.

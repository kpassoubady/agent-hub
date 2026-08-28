# Changelog

All notable changes to this hub are recorded here. Hub follows semver; each agent file also carries its own `version:` in frontmatter for finer-grained tracking.

## [0.15.0] — 2026-08-27

Implements item 9 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9/§8.4 — the `hub-improve` consumer skill and inbox. This is the last item in that retrospective's tracking checklist; all 11 recommended-sequence items are now shipped. Also resolves both of §10's remaining open questions: `hub-improve` never auto-applies (human approval required per candidate, confirmed against the retrospective's own §10.2 recommendation); `run-feedback` was already mandatory/automatic as of `v0.13.0`, so no change was needed there.

### Added — `hub-improve` skill + `hub-improve-analyzer` agent (item 9, §8.4)

- **New `agents/hub-improve-analyzer.md` (0.1.0).** Reads every entry in `llm-context/feedback/inbox/`, clusters findings by target file and underlying behavior (not filename alone), and **recomputes recurrence itself** by counting distinct source-run filenames — never trusting an inbox entry's own `Recurrence` line, which always reads "1 run" by construction. A cluster becomes a proposal candidate only with ≥2 distinct runs, or exactly 1 run at severity `high` with its evidence independently re-verified this pass (re-running the cited grep/diff, not just repeating the claim). Drafts a literal diff-shaped edit and version bump per candidate, and separately flags a cluster as "recurring but contested" when every occurrence's `Counter-argument` raises the same objection — surfaced to the human rather than silently overridden. Read-only on every hub file; Write is scoped to exactly `llm-context/feedback/hub-improve-report.md`.
- **New `skills/hub-improve/SKILL.md` (0.1.0).** Standalone-invoked only (`/hub-improve`) — unlike `run-feedback`, it is *not* wired into any project's automatic chain, since its value depends on cross-run accumulation in the inbox rather than firing per-run. Presents the analyzer's report one candidate at a time; the human approves, rejects, or defers each individually — no batch approval, matching the retrospective's own root finding that unscrutinized batch approval is how verification theatre slips through (§2, checkpoint 2's 56-minute zero-revision approval of a 465-line brief). Only a human-approved candidate is applied: edits the target file, bumps its version, appends a `CHANGELOG.md` entry citing the motivating inbox entries, and files the contributing inbox files to a new `inbox/applied/`. A rejected candidate's inbox files move to a new `inbox/rejected/` (so a stale single-run finding can't silently re-pair with a future run's entry and look new). A deferred candidate's files stay in `inbox/` untouched. No mode, flag, or override in this skill writes a hub file without that per-candidate human decision.
- **New `llm-context/feedback/inbox/applied/` and `inbox/rejected/`** (both `.gitkeep`-only), completing the inbox lifecycle `run-feedback` (v0.13.0) started.
- **`CLAUDE.md` updated** — added the `run-feedback`/`hub-improve` paragraph that was missing since `run-feedback` shipped in `v0.13.0`, and added both skills to the repository-layout list.
- **Real inbox entry used as the design case**: the 4 findings filed against InvoiceGen's `test-foundation-and-cloudflare-compatibi` run (`v0.13.0`) all sit at "1 run" and would not clear the recurrence gate on their own — exactly the intended behavior, and the reason two of those four (F-001, F-003) carry counter-arguments arguing the real fix is enforcement of an existing rule rather than a new one was used to shape the "recurring but contested" reporting path above.

## [0.14.0] — 2026-08-27

Implements item 11 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9/§5 — narrowing `adaptive-engine` to declared pre/post gates around `feature-factory`'s fixed chain, instead of re-deriving the chain from scratch. The last unchecked item in that retrospective's tracking checklist.

### Changed — `adaptive-engine` no longer re-derives feature-factory's chain (item 11, §5)

- **`agents/planner.md` (1.1.0 → 2.0.0): the planner's job is redefined.** It no longer selects which of feature-factory's 7 agents to run and how to wire them — it treats the entire chain as one opaque node, `feature-factory-chain`, and decides only whether the feature needs extra `pre-gate` nodes (hard preconditions the chain can't see, e.g. a cross-feature dependency) or `post-gate` nodes (independent verification with a different lens than the chain's own `validator`) around it. Explicitly instructed that the correct answer for most features is zero extra gates, in which case it recommends `/feature-factory` directly instead of emitting a graph. New failure mode added: if the planner's output names any of `researcher`/`story-writer`/`spec-writer`/`backend-builder`/`frontend-builder`/`test-verifier`/`validator` as a separate node, it has regressed to re-deriving the chain and must be corrected.
- **`skills/adaptive-engine/SKILL.md` (1.2.0 → 2.0.0): reframed as a thin wrapper, not an alternative pipeline.** Phase 1 now sanity-checks the planner's returned graph and rejects one that re-lists feature-factory's own agents as nodes. Checkpoint 1 stops and hands off to plain `/feature-factory` when the planner declares zero extra gates, rather than executing a one-node graph through Phase 2 for nothing. Phase 2's `feature-factory-chain` node executes by invoking the `feature-factory` skill unmodified — including that skill's own three checkpoints — rather than re-implementing any of its steps. Phase 3 no longer duplicates feature-factory's own Step 7/Checkpoint 3 (which already runs `run-feedback` and summarizes the build); it shows that summary as-is and adds only what the post-gates produced. Removed the stale "only if a validator node ran" conditional on `run-feedback`, since `feature-factory-chain` always contains a `validator` internally now.
- **Deterministic shared state, closing the slug-divergence bug.** `feature-factory-chain` now runs against `<project>/.claude/feature-factory/<feature-slug>/` — the exact same directory and slug rule `feature-factory` uses standalone — rather than a separate nested copy under the adaptive-engine's own state directory. The adaptive-engine's state directory holds only pre-gate/post-gate artifacts and a one-line pointer to that shared directory. This directly closes the real defect the retrospective found: one story was planned twice, two minutes apart, under two different invented slugs, producing mutually incompatible graph schemas that matched neither each other nor the feature-factory directory that actually held the work, leaving an orphan directory that was neither resumable nor collectable under the graph's own resume policy. (The slug-determinism *rule* itself already shipped in an earlier `adaptive-engine` revision; this release is what makes the two skills actually share one directory rather than each deriving the same rule independently and still forking.)
- **`diagrams/06-adaptive-engine.md` and `docs/adaptive-engine-guide.md` rewritten** to match — the diagram now shows a pre-gate → `feature-factory-chain` → post-gate spine instead of a "simple vs. complex" custom-graph branch, and the guide leads with "this is a thin wrapper, use plain feature-factory unless you have genuinely extra structure" instead of "dynamically constructs the optimal execution graph."
- **`README.md` / `CLAUDE.md` updated** — the one-line description of `adaptive-engine` no longer says "dynamic orchestration layer (planner agent → custom graph)"; it says what actually happens now.

This closes the retrospective's tracking checklist — all 11 items in §9's recommended sequence are now shipped except item 9 (`hub-improve` consumer skill), which remains deliberately gated on ≥2-run recurrence evidence.

## [0.13.0] — 2026-08-27

Implements item 8 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9/§8 — the `run-feedback` skill. Explicitly stops short of item 9 (the `hub-improve` inbox consumer), sequenced separately because it needs this item's real output to design against.

### Added — `run-feedback` skill + `run-feedback-analyzer` agent (item 8, §8)

- **New `agents/run-feedback-analyzer.md` (0.1.0).** Read-only on the project except for exactly two files: `<state-dir>/08-feedback.md` and, when the hub is discoverable locally, one entry under `llm-context/feedback/inbox/`. Runs the mechanical check table from §8.2 verbatim — gate enforceability, orphan code, coverage-scope bias, threshold drift, duplication ratio, AC roll-up integrity, state-file honesty, config gating, cost-vs-complexity, retry productivity, landed-vs-claimed — every check a `grep`/count/diff, never a self-assessed quality score. Output is two parts: Part A, a scorecard capped at ~600 words (a net token add to every run, so kept deliberately cheap per §8.5); Part B, zero or more hub-change proposals in the `F-00N` format from §8.3, each with a mandatory `Counter-argument` field arguing against its own proposed change — an entry without one is not written. `Recurrence` always reads "1 run" from this agent; counting recurrence across runs is item 9's job, not this one's.
- **New `skills/run-feedback/SKILL.md` (0.1.0).** Orchestrates the agent: confirms `07-validator.md` (or the graph-engine equivalent) is present before running, shows the caller Part A inline at whichever checkpoint invoked it (never makes the human open a file — the exact failure mode that left `learning/` directories unread across 21 runs), and reports whether an inbox entry was filed or prints the fallback copy command when the hub isn't present locally.
- **New `llm-context/feedback/inbox/` directory** (empty, `.gitkeep` only). This pass builds the producer side only — `run-feedback` writes entries here. The consumer that reads, clusters by recurrence, and edits hub files (§8.4) is item 9, deliberately not built yet.
- **`feature-factory` (1.9.0 → 1.10.0): Step 7 invokes `run-feedback` before Checkpoint 3**, folding Part A into the existing hand-off summary as one more section rather than a fourth checkpoint. The chain never blocks on anything this skill finds — that enforcement already happened in Step 6.
- **`adaptive-engine` (1.1.0 → 1.2.0): Phase 3 invokes `run-feedback` before Checkpoint 2** on the same basis, gated on the graph having actually run a validator node (several checks need its coverage report). Also removed a stale `graph-state.json` reference in this same checkpoint's summary line, left over from item 10 (`v0.12.0`) removing that file as the graph-engine default — noticed while editing the adjacent line; narrowing adaptive-engine further is still item 11, untouched here.
- **Ran once against a real project** (see `llm-context/feedback/` for the resulting `08-feedback.md`/inbox entry, when available) so item 9 can be scoped against actual output rather than the spec alone.

## [0.12.0] — 2026-08-27

Implements items 6, 7, and 10 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9. These three are independent of each other and of items 8/9 (the `run-feedback`/`hub-improve` pair, still pending real output to design against) and item 11 (adaptive-engine-specific).

### Added — production-reachability requirement (item 6, §2.2/§7)

- **`validator` (1.4.0 → 1.5.0): promoted the production-reachability grep from a single checklist bullet to its own mandatory section**, mirroring the existing "Negative-control requirement." For every new exported guard/helper/assertion module either builder added, `grep` for a non-test caller outside `test.folders`; if none exists, file a **Critical** finding naming the module, regardless of the module's own test coverage percentage. Motivated by the retrospective's `assertInventoried`/`withCapability` defect: a test asserted the helper existed, but it was imported by zero production code paths, so a new unprotected route would have failed no test. Coverage measures whether a helper's own lines ran under test, not whether the shipped code path depends on it — the mechanical AC roll-up rule now folds a Critical reachability finding into a criterion's verdict the same way an `UNENFORCED` gate already does.

### Added — researcher peer-dependency verification and environment preflight (item 7, §7)

- **`researcher` (1.3.0 → 1.4.0): verifies any candidate library's peer-dependencies against the project's real manifest before recommending it**, and folds an orchestrator-provided environment-preflight result into a new `environment` Risks category. Motivated by two real defects: a research pass's headline recommendation required a major version of a framework the project's manifest pinned two majors behind, costing three verification rounds to unwind; and Docker Desktop's absence blocked the same acceptance criterion across backend, frontend, and validator rounds because nothing checked for it before research began. Researcher has no Bash access, so it cannot probe tool availability itself — it reports what the orchestrator's preflight found, or notes explicitly that availability wasn't checked.
- **`feature-factory` (1.8.0 → 1.9.0): new Step 0.5 runs the environment preflight** before spawning `researcher` — probing for a container runtime, DB client, or deploy CLI only when the project's stack or the feature description plausibly needs one, not an exhaustive tool inventory. The result is passed to `researcher` as an input, not saved to its own file; a missing tool surfaces as a Risk rather than blocking Step 1.

### Changed — state files (item 10, §4)

- **`loop-engine` (1.0.0 → 1.1.0): `loop-state.jsonl` is now append-only-at-transition.** Each iteration's entry must be written the moment that phase's VERIFY result is known, not batched at the end of the run. Motivated by a real run where six iterations — spec approval, reconciliation, three test-verification rounds, a coverage fix — shared one timestamp, meaning a crash mid-run would have lost the entire retry history the file exists to preserve. A repeated timestamp across consecutive entries is now called out as a defect in the calling skill's integration, not a cosmetic detail.
- **`graph-engine` (1.0.0 → 1.1.0): removed `graph-state.json` as the default.** For the common case (a linear chain with one fan-out/fan-in pair), node status and fan-in results are derived from the calling skill's own numbered artifacts — no separate file. Motivated by two real instances of the file actively lying: one run recorded status for 2 of 7 participating nodes, and another was written once, hours after the fact, under node names from an abandoned plan, contradicting the coverage report on whether migrations had run. A calling skill that genuinely needs cross-node bookkeeping beyond what artifacts capture (many nodes, non-file-derivable status, a multi-source fan-in) may still declare a structured state file, but it must be written append-only-at-transition and its `reality-anchor` field must be a pointer to captured output, never a free-text string.
- **`feature-factory` (1.9.0, same bump as above): updated its own state listing and "State integration" section to match** — no `graph-state.json` entry; `04-backend-summary.md`/`04b-contract-check.md` presence is the node/fan-in status, and `loop-state.jsonl` entries are written per-loop-point as each one resolves, not retroactively at hand-off.

## [0.11.0] — 2026-08-27

Implements item 5 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9 — a complexity tier at Step 0 (§3.1/§3.2). Motivated by two structurally identical bookbuilder features ("add a CSS property driven by a config key") costing 69,459 vs 5,389 chars — a 13× spread — because nothing in the chain routed by complexity; the story-writer's stylistic choice of how many ACs to enumerate set the cost of every downstream stage.

### Added — `trivial`-tier fast path

- **`researcher` (1.2.0 → 1.3.0): new "Suggested complexity tier" output field.** After mapping the feature area, the researcher suggests `trivial` or `standard` with a one-paragraph scope read, gated on evidence it actually found this pass (exactly one relevant file, no tenant/timezone/retry/secrets/migration risk, no implied migration, no new dependency) — not on how short the feature description happens to be. Ties toward `standard` on any uncertainty, since a wrong `standard` costs unnecessary ceremony but a wrong `trivial` skips checkpoints a real feature needed.
- **`feature-factory` (1.7.0 → 1.8.0): new Step 1.5 reads the researcher's tier suggestion and gates it behind one lightweight checkpoint** (accept fast path / escalate to standard) — shown only when the researcher suggests `trivial`; a `standard` suggestion proceeds straight to Step 2 with no extra prompt. Accepting collapses the two pre-build checkpoints (story approval, brief approval) into this one and skips story-writer and spec-writer entirely, since for a single-file, no-data-model, no-new-dependency change there's nothing in a separately-approved story or brief that the researcher's scope read didn't already establish. This does not violate the skill's own "checkpoints are non-negotiable" rule in "What this skill does NOT do" — every run still gets at least one pre-build human gate plus Checkpoint 3 at hand-off; a trivial run consolidates checkpoints, it never zeroes them.
- **Test-verifier's negative-control requirement and validator's mechanical AC roll-up rule run unchanged on a trivial-tier run.** Step 5/6 substitute the feature description + researcher's output for "approved story + approved brief" as the input those agents check against, but the checks themselves — negative controls, `UNENFORCED` gates, `synthetic`/`reused`/`not executed`/`pending` sub-checks forcing `PARTIAL` — are identical to a standard-tier run. The retrospective's item 1–2 fixes (shipped `v0.9.0`) are gates, not ceremony, and the trivial tier only removes ceremony.
- **Escalation path for a wrong trivial call.** If a builder discovers mid-run that the feature needs a migration, touches materially more than the one file the researcher named, or requires a new dependency, it stops and reports the discovery. The orchestrator then generates `story-writer`/`spec-writer` retroactively — from the researcher's output *and* what the builder already learned, not from scratch — and runs Checkpoints 1 and 2 as normal before resuming Step 4. This mirrors the existing escape valve for a wrong `API contract confidence: high` call: a wrong guess costs one extra round trip, not a restart.

## [0.10.0] — 2026-08-27

Implements item 4 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9 — cite-don't-restate plus the `06-coverage.md` / `07-validator.md` merge (§3.2). Motivated by real duplication in the corpus: the same 7 acceptance criteria appeared four times across `02-story.md` → `03-spec.md` §1 → `03-spec.md` §10, the Bluehost prerequisite checklist appeared three times, and `06-coverage.md`/`07-validator.md` verified identical evidence with diverging numbers (three different test totals in one file; `74.6%` vs `75%` branch coverage for the same run).

### Changed — cite acceptance criteria, don't restate them

- **`spec-writer` (1.3.0 → 1.4.0): acceptance criteria are cited by number, never re-quoted.** The brief's "Tests required" section now references `02-story.md:AC<N>` rather than re-expanding the criterion's text, and restating or re-expanding acceptance criteria anywhere in the brief is now an explicit "what it cannot do" violation. `02-story.md` remains the one place criteria are written out in full — a citation can't drift out of sync with it; a fourth copy already did.

### Changed — `06-coverage.md` merged into `07-validator.md` (breaking artifact-layout change)

- **`test-verifier` (1.2.0 → 1.3.0) no longer owns a standalone coverage file.** It still writes test files, runs the suite, and captures negative controls exactly as before, but returns its report (test files added, per-criterion verdicts, gate-enforceability results, test run output) directly to the orchestrator instead of writing `06-coverage.md`.
- **`validator` (1.3.0 → 1.4.0) now embeds that report as a section of its own output.** `07-validator.md` has two sections: "Coverage report" (test-verifier's report, included as-is, with each criterion's verdict re-derived from the evidence text rather than trusting test-verifier's label) and "Findings" (the gap analysis, unchanged). This removes the redundant-verification surface the retrospective flagged — `07-validator.md`'s AC verdicts previously cited `06-coverage.md` as if it were independent evidence, when it was the same evidence read twice.
- **`feature-factory` (1.6.0 → 1.7.0): Step 5/6 updated to match.** Step 5 holds test-verifier's report in context instead of saving it; Step 6 folds it into `07-validator.md` via validator. The state-file listing and resume note no longer mention `06-coverage.md` — a resume landing between Step 5 and 6 re-runs test-verifier and hands the report straight to validator, the same as a fresh pass. Saves roughly the volume `06-coverage.md` used to cost (~10% of total artifact output in the corpus analysed) without losing any check.

## [0.9.0] — 2026-08-27

Implements items 1–2 of the recommended sequence in `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §9 — the two highest-value fixes from a retrospective on 21 real chain runs. Item 3 (enforce Step 0 config gating) was checked against the current chain and confirmed already resolved by the `v0.7.0` blocking gate; no further change was needed there.

### Added — negative-control requirement for every gate

- **`test-verifier` (1.1.0 → 1.2.0): must prove every gate it relies on can fail.** For any CI step, coverage threshold, assertion helper, or guard module cited as evidence for a `PASS`, test-verifier now temporarily violates the invariant, captures the resulting non-zero exit or failing assertion, restores the repo, and reports the captured failure as evidence. A gate that can't be shown to fail is reported `UNENFORCED`, never as satisfied. Motivated by three real defects found in the retrospective: a CI step that `grep`s a directory that doesn't exist (so its `!`-inverted exit passes vacuously forever), a coverage `--include` list built file-by-file that quietly omitted the one untested file, and an assertion helper (`assertInventoried`, `withCapability`) imported by zero production code paths — the test only proved the helper exists, not that anything used it.
- **`validator` (1.2.0 → 1.3.0): checks that a negative control is on record before crediting a gate.** Being read-only, validator can't run the negative control itself — it confirms `06-coverage.md` recorded one for every gate cited as PASS evidence, and files a **Critical** finding when none is on record, regardless of how correct the gate's code looks on read-through. Also now greps every exported guard/helper the builders added for a non-test caller, catching the "enforcement code" that no route or route actually imports.

### Added — mechanical AC roll-up rule

- **`test-verifier` (1.2.0), `validator` (1.3.0), `feature-factory` (1.5.0 → 1.6.0): an acceptance criterion cannot be `PASS` if any of its sub-checks self-report as unreliable.** If a sub-check's evidence is labelled `synthetic`, `reused` (citing a prior run's artifact instead of re-running), `not executed`, or `pending`, or rests on a gate just flagged `UNENFORCED`, the criterion is mechanically downgraded to `PARTIAL` — never `PASS`, no matter how many other sub-checks for that criterion are solid. `validator` re-derives the verdict from the evidence text rather than trusting `06-coverage.md`'s label. `feature-factory` Step 5/6 treat `PARTIAL` like `FAIL` for loop-control purposes and never let it reach Checkpoint 3 looking like a pass. Motivated by Story 1's AC4 (marked `PASS` on self-labelled "synthetic" API evidence), AC5 (cited a validator ADR still reading "pending checkpoint 3"), and AC7 (`PASS` with no owner named and no credential rotated).

### Verified — Step 0 config gating (no change needed)

- **Confirmed the `v0.7.0` blocking gate already covers both `§6` complaints.** A project declaring `shape: backend-only` can no longer have `frontend-builder` spawned per-feature (Step 4's skip rules make "never spawns" literal, and the orchestrator writes the skip placeholder itself instead of spawning the builder to report its own inapplicability). A project with no `.agenthub-config.yaml` at all now hits Outcome A — generate via `agent-hub-detect.sh -d`, show the user the proposed YAML, require explicit accept/edit/abort — rather than silently assuming `full-stack`. Both were real gaps against the `v0.6.0` chain the retrospective analysed; both are resolved as of `v0.7.0`.

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

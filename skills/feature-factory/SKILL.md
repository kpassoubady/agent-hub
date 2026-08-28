---
name: feature-factory
version: 1.10.0
hub-source: agent-hub
description: Orchestrates the 7-agent factory chain to build a feature from idea to validated implementation, with three human checkpoints, a blocking config gate, an environment preflight, mechanical gate/AC enforcement, a trivial-tier fast path for small features, and an automatic mechanical run-feedback scorecard at hand-off.
---

# Feature Factory

Orchestrates the 7-agent factory chain: researcher → story-writer → spec-writer → backend-builder + frontend-builder → test-verifier → validator.

Three human checkpoints — story approval, brief approval, PR review — for `standard`-tier features. A `trivial`-tier feature (see [Step 1.5](#step-15--complexity-tier)) collapses the first two into one lightweight checkpoint and skips story-writer and spec-writer entirely; test-verifier and validator still run unchanged. Everything else runs on its own. The backend/frontend step runs sequentially or in parallel per feature — see [Step 4](#step-4--build) and [graph-engine](../graph-engine/SKILL.md).

## When to use

The user invoked `/feature-factory <feature description>` (or asked to "build feature X with the factory") and wants to build a feature end-to-end through the chain.

**Do not use this skill for:**
- One-line bug fixes (overkill — use direct edits)
- Pure refactors with no user-visible behaviour change
- Exploratory work where the goal isn't yet a concrete feature

## The chain

### Step 0 — Config gate (blocking)

**This is a gate, not a lookup. Nothing downstream runs until it resolves.** The chain does not proceed on assumed defaults — a wrong assumption here is paid for four times over, once by every agent that has to re-derive what the config should have told it.

Read `<project>/.agenthub-config.yaml`. Exactly one of three outcomes:

#### Outcome A — missing

Do **not** assume `full-stack`, and do **not** just tell the user to go make a file. Generate a candidate and ask them to confirm it:

1. Run the hub's detector: `<hub>/agent-hub-detect.sh -d <project>` (dry-run — prints YAML to stdout, writes nothing).
2. Show the user the proposed YAML in full.
3. **🛑 Ask: accept / edit / abort.**
   - *accept* → write it to `<project>/.agenthub-config.yaml`, then continue to validation below.
   - *edit* → take their changes, show the result, ask again.
   - *abort* → stop the chain. Do not fall back to defaults.

If the detector is unavailable (hub path unknown, script missing), hand-write a candidate from what's actually in the repo — read `package.json` / `pyproject.toml` / `go.mod`, list the real folders, quote the real scripts — and still require explicit confirmation. Never invent a command you haven't seen in a manifest.

#### Outcome B — present but invalid

**Fail. Do not proceed.** A config that names things which don't exist is worse than no config, because every downstream agent will trust it and report green against commands that never ran. Validate all of the following and report *every* failure at once, each with the offending key and value:

| Check | Fails when |
|---|---|
| Folders exist | any path in `backend.folders`, `frontend.folders`, or `test.folders` is not a directory |
| Files exist | any path in the optional `backend.files` / `frontend.files` is not a file |
| Commands resolve | any `test-command`, `typecheck-command`, `lint-command`, or `test.command` names a script/binary that doesn't exist (check `package.json` scripts, `pyproject.toml`, or `$PATH`) |
| **Folders don't overlap** | any `backend.folders` entry is inside a `frontend.folders` entry, or vice versa |
| Files respect the other side's folders | a `frontend.files` entry sits inside a `backend.folders` entry, or vice versa |
| Shape is known | `project.shape` is not one of `full-stack` \| `backend-only` \| `frontend-only` \| `library` |
| Shape matches sections | shape is `backend-only`/`library` but `frontend.folders` is populated, or `frontend-only` but `backend.folders` is populated |
| Parallel flag is known | `build.parallel-builders` is set and is not `auto` \| `always` \| `never` |

If `test.command` (or any `*-command` key) resolves to a placeholder rather than a real command — `agent-hub-detect.sh`'s own fallback text (`echo 'no test command configured'`), or a `REPLACE_ME` folder it couldn't confirm — treat that the same as failing the "commands resolve" check: **fail, do not proceed.** Point the user at the `test-bootstrap` skill to install a real framework and smoke test first, then re-run Step 0. A chain that "passes" tests by running `echo` is worse than one that visibly has no tests, because the coverage report and validator will both report green.

The overlap check matters more than it looks. `backend.folders` is a **hard scope restriction** for backend-builder, and the same is true of `frontend.folders` for frontend-builder. If `frontend.folders` contains `src/app` while `backend.folders` contains `src/app/api`, then frontend-builder is authorised to rewrite your API routes. Narrow one side; don't let both claim the same tree.

**When a framework directory genuinely holds both halves** — Next.js App Router being the common case, where `src/app` contains `api/` routes *and* `page.tsx`/`layout.tsx` — don't hand the whole folder to one builder. Give the shared folder's subtree to the backend and list the frontend's individual files under the optional `frontend.files` key (or vice versa):

```yaml
backend:
  folders: [src/app/api, src/lib]
frontend:
  folders: [src/components, public]
  files: [src/app/page.tsx, src/app/layout.tsx, src/app/globals.css]
```

`backend.files` / `frontend.files` are optional and behave as an extension of that side's `folders` for scope purposes.

Offer to re-run detection (`--force`) or let the user fix the file by hand, then re-validate. Nothing proceeds on an invalid config.

#### Outcome C — present and valid

Proceed — and **make the gate binding** (see below).

#### Binding the resolved config

Write the resolved values to `<project>/.claude/feature-factory/<feature-slug>/00-config-resolved.md`:

```markdown
# Resolved config — <feature-slug>
Source: <project>/.agenthub-config.yaml (validated <ISO-8601 timestamp>)
Origin: existing | generated-and-confirmed-this-run

shape: full-stack
builders eligible: backend-builder, frontend-builder
backend.folders: src/app/api, src/lib
frontend.folders: src/components, public
frontend.files: src/app/page.tsx, src/app/layout.tsx
test.command: pnpm test:e2e
backend.test-command: pnpm test
backend.typecheck-command: pnpm exec tsc --noEmit
backend.lint-command: pnpm lint
build.parallel-builders: auto
```

**Every downstream agent reads this file, not the YAML.** That is what makes Step 0 binding rather than advisory. It also means each command string is resolved and validated exactly once instead of being re-derived by the researcher, the spec-writer, and both builders.

This is a real bug the hub has shipped: a project correctly declaring `shape: backend-only` still had frontend-builder spawned on 8 of 18 features, each time to write a one-line "N/A — backend-only" placeholder. Step 0's decision was being recomputed, and ignored, downstream.

#### Shape → chain

| `project.shape` | Chain adjustment |
|---|---|
| `full-stack` | All 7 agents eligible. |
| `backend-only` | frontend-builder **never spawns**. test-verifier exercises API or CLI only. |
| `frontend-only` | backend-builder **never spawns**. The spec must say where the API lives (external service, mock). |
| `library` | Same as `backend-only`. spec-writer treats the package's public surface as the "API". |

"Never spawns" is literal. An ineligible builder is not spawned to report its own inapplicability — the orchestrator writes the placeholder itself (see Step 4).

**Per-feature override.** Even when `project.shape` allows both builders, **skip a builder when the spec-writer's brief has no work for it.** The brief is the per-feature source of truth — a `full-stack` project can still run a 6-agent chain for an API-only feature. The skip rule:

- Backend-builder skipped if the brief's `API changes` and `Data model changes` sections are empty or marked `None`.
- Frontend-builder skipped if the brief's `Frontend changes` section is empty or marked `None`.

#### Escape hatch

`/feature-factory --no-config <description>` runs without a config for a genuine one-off. It assumes `full-stack`, and the Checkpoint 3 summary must state prominently that the run was unconfigured and which commands were guessed. Use it for throwaway experiments, not for real features.

### Step 0.5 — Environment preflight

The orchestrator runs this itself, before spawning `researcher` — `researcher` has no Bash access and cannot probe tool availability. Real defect this closes: Docker Desktop's absence blocked the same acceptance criterion across backend, frontend, *and* validator rounds of one run, discovered only mid-build each time, because nothing checked for it before research began.

Probe for whatever the feature is plausibly going to need, based on `00-config-resolved.md`'s stack and the feature description — not an exhaustive tool inventory:

- A container runtime, if the project's config or manifest references one (`docker --version`, or check the daemon is actually reachable, not just that the CLI exists on `$PATH`)
- A DB client matching the project's declared database, if migrations or seed data are plausible for this feature
- A deploy/preview CLI matching the project's declared platform (e.g. `wrangler`, `vercel`, `flyctl`) if the feature or its acceptance criteria are likely to need a preview/deploy step

Record the result — present/absent, and version if present — as one short block, and pass it as an input to `researcher` alongside the feature description. Do not block Step 1 on a missing tool; the point is to surface it as a Risk early, not to gate research on infrastructure being installed. If something needed turns out missing, `researcher` folds it into Risks (§5, `environment` category) per `agents/researcher.md`'s "Environment preflight" section, and the checkpoint at Step 2 or Step 1.5 is where the user decides whether to install it now or accept the risk and proceed.

### Step 1 — Research
Spawn the `researcher` agent. Inputs: the feature description + project CLAUDE.md + Step 0.5's preflight result.
Save the output to `<project>/.claude/feature-factory/<feature-slug>/01-research.md`.
Do not show the user — the next checkpoint is more useful to review.

Any library the researcher names as a recommendation carries a peer-dependency check against the project's real manifest (see `agents/researcher.md`'s "Peer-dependency verification") — a conflict discovered this early is one research pass; discovered by a builder mid-build, it's the three-round-trip defect this closes.

### Step 1.5 — Complexity tier

The researcher is the first agent with real evidence about scope — it has read the actual files, so this is where the tier gets decided, not as a blind heuristic against the raw feature description before anything was read. Read `01-research.md`'s "Suggested complexity tier" field.

**🛑 CHECKPOINT (trivial fast-path only) — if the researcher suggests `trivial`, show the user its one-paragraph scope read and the file it names. Ask: accept fast path, or escalate to standard?**

- *Escalate*: proceed to Step 2 (Story) as normal — the standard chain, unchanged.
- *Accept*: mark `<feature-slug>` as `tier: trivial` in `00-config-resolved.md` (append, don't overwrite the config gate's own fields) and skip directly to Step 4 (Build). Story-writer and spec-writer do not run.

If the researcher suggests `standard`, skip this checkpoint entirely and proceed straight to Step 2 — a `standard` suggestion needs no separate confirmation, since the full two-checkpoint chain is already the safe default.

**Why one checkpoint, not zero.** This skill's own "What this skill does NOT do" section treats the three checkpoints as non-negotiable. A trivial-tier run does not violate that: it still gates on human approval before any code changes, it just consolidates the two pre-build checkpoints (story approval, brief approval) into one, because for a single-file, no-data-model, no-new-dependency change there is nothing in a separately-approved story or brief that the researcher's scope read didn't already establish. Checkpoint 3 (PR review) is untouched either way.

**What "trivial" skips and what it doesn't.** Story-writer and spec-writer (and their prose) are skipped. Everything downstream of Step 4 — test-verifier's negative-control requirement and mechanical AC roll-up rule, validator's Critical-finding gates, the loop-control limits — runs exactly as it does for a `standard` feature. See "Trivial tier and the build/verify chain" below for how a builder without a brief still gets the inputs those agents expect.

### Step 2 — Story
Spawn the `story-writer` agent. Inputs: feature description + researcher's output.
Save to `02-story.md`.

**🛑 CHECKPOINT 1 — Show the user the user story and acceptance criteria. Ask: approve, request changes, or reject?**

- Rejected: stop. Ask what to do next.
- Request changes: capture the specific feedback, re-spawn story-writer with it, save as a new version, return to checkpoint.
- Approved: add `STATUS: APPROVED` marker to `02-story.md` and proceed.

### Step 3 — Spec
Spawn the `spec-writer` agent. Inputs: approved story + researcher's output + project CLAUDE.md.
Save to `03-spec.md`.

**🛑 CHECKPOINT 2 — Show the user the technical brief. Ask: approve, request changes, or reject?**

This is the most important checkpoint. Watch for and call out:
- "store IDs in memory" or other anti-patterns the researcher flagged
- Missing tenant isolation
- Scope creep beyond the story
- API shapes that won't fit the UI

- Rejected: stop. Ask whether to revise the story (back to Step 2) or abandon.
- Request changes: capture the specific issue, re-spawn spec-writer, save as a new version, return to checkpoint.
- Approved: mark `STATUS: APPROVED` and proceed.

### Trivial tier and the build/verify chain

A trivial-tier run has no `02-story.md` or `03-spec.md` when it reaches Step 4. Everything downstream that normally reads "approved story" or "approved brief" instead reads the researcher's scope read plus the single named file:

- **Step 4 (builder inputs)**: the researcher's output stands in for the brief. Since a trivial feature is single-file with no API/data-model change by definition (or it wouldn't have qualified), there is no contract to hand a second builder — Step 4 runs exactly one builder (whichever side owns the named file), never both.
- **Step 5 (test-verifier)**: give it the original feature description + researcher's output + the builder's summary in place of "approved story + approved brief." It still writes an acceptance test, still maps it to a testable statement of what the feature should do (derived from the feature description, since there's no numbered AC list), and still runs the full negative-control requirement and mechanical AC roll-up rule from `agents/test-verifier.md` — unchanged. A trivial tier is a scope reduction, not a rigor reduction.
- **Step 6 (validator)**: same substitution — feature description + researcher's output stand in for story + brief. All of validator's checks, including the negative-control confirmation and the production-reachability grep, run unchanged.
- **Step 7 (hand-off)**: the Checkpoint 3 summary states plainly that this feature ran the trivial fast path and names the file(s) touched, so the user reviewing the PR knows a story/brief was never produced.

### Escalation — trivial turns out not to be trivial

If backend-builder or frontend-builder discovers mid-run that the feature needs a migration, touches materially more than the one file the researcher named, or requires a new dependency, it must stop and report the discovery rather than proceeding on the wrong tier. The orchestrator then:

1. Marks the state directory `tier: standard (escalated from trivial)` in `00-config-resolved.md`.
2. Spawns `story-writer` and `spec-writer` **retroactively** — inputs are the original feature description, the researcher's output, *and* whatever the builder already learned (the specific files touched, the schema/dependency it discovered it needed). This is generated from what's already been learned, not from scratch: the story-writer and spec-writer prompts include the builder's partial-progress report so the story and brief reflect the real scope on the first draft, instead of re-deriving it as if Step 4 had never run.
3. Runs Checkpoints 1 and 2 as normal on these retroactively-generated documents — the human still approves a real story and a real brief before the chain proceeds, same as any standard-tier run.
4. Resumes at Step 4 with the (now approved) brief. Any work the builder already completed that's still valid is kept; work that contradicts the approved brief is redone.

This is the same escape valve a wrong `API contract confidence: high` call gets in Step 4 — the chain doesn't punish a wrong tier guess, it costs one extra round trip to correct it.

### Step 4 — Build

Apply the skip rules from Step 0 first:

- If `project.shape` is `frontend-only`, skip 4a.
- If `project.shape` is `backend-only` or `library`, skip 4b.
- If the brief's backend sections are empty, skip 4a even when shape allows it.
- If the brief's frontend section is empty, skip 4b even when shape allows it.

If only one of 4a/4b runs, there is nothing to parallelize — run it alone and proceed to Step 5. The choice below only applies when both builders run.

**Decide sequential vs. parallel.** This follows the [graph-engine protocol](../graph-engine/SKILL.md) — see [docs/graph-guide.md](../../docs/graph-guide.md) for the reasoning. Read `build.parallel-builders` from `.agenthub-config.yaml` (`auto` | `always` | `never`; default `auto`) and the brief's `API contract confidence` line:

| `build.parallel-builders` | `API contract confidence` | Mode |
|---|---|---|
| `never` | (any) | Sequential |
| `auto` (default) | `high` | Parallel |
| `auto` (default) | `low` | Sequential |
| `always` | `high` | Parallel |
| `always` | `low` | Parallel, but warn the user that confidence is `low` before proceeding |

#### Sequential mode

Run **backend-builder first**, then frontend-builder.

Why backend first here: without a high-confidence contract, the safest source of truth for the frontend is the backend's *actual* implementation, not a brief that might drift once backend really builds it.

a) Spawn `backend-builder`. Inputs: approved brief + researcher's output + project CLAUDE.md.
   Save its summary to `04-backend-summary.md`.

b) Spawn `frontend-builder`. Inputs: approved brief + researcher's output + backend-builder's summary + project CLAUDE.md.
   Save its summary to `05-frontend-summary.md`.

If frontend-builder surfaces an API mismatch:
- Save its feedback to `05-frontend-feedback.md`
- Loop back to step 4a, passing the feedback to backend-builder
- After backend re-implements, re-run frontend-builder
- Max 3 round trips per feature; if not converged, pause and ask the user

#### Parallel mode

Both builders read the brief's **API changes** section as the contract — neither reads the other's output as input. This is a `parallel-fanout` edge per the graph-engine protocol: spawn both concurrently (as a Claude Code dynamic workflow's `parallel()` call when available, or as two sequential subagent calls with the same contract-only inputs when it isn't).

a) Spawn `backend-builder`. Inputs: approved brief (contract source) + researcher's output + project CLAUDE.md.
   Save its summary to `04-backend-summary.md`.

b) Spawn `frontend-builder`. Inputs: approved brief (contract source, **not** backend-builder's summary) + researcher's output + project CLAUDE.md.
   Save its summary to `05-frontend-summary.md`.

**Fan-in — contract-check gate**, once both finish: diff three things — what the brief's API section promised, what `04-backend-summary.md` actually shipped, and what `05-frontend-summary.md` assumed. Save the result to `04b-contract-check.md`.

- **Match**: proceed to Step 5.
- **Mismatch**: loop back to whichever builder drifted from the brief (usually backend, since frontend built to the brief verbatim by construction). Re-run the contract-check after the fix.
- Max 3 round trips per feature; if not converged, pause and ask the user — the brief's API section is likely the actual problem, not either builder's implementation. This is the same reality-anchor principle graph-engine requires: the contract-check compares against the brief's literal text, not one builder's opinion of the other's code.

When a builder is skipped, **the orchestrator writes the placeholder itself — it does not spawn the builder to write it.** Spawning an agent to report that it has nothing to do costs a full context window and returns no information the orchestrator didn't already have from `00-config-resolved.md` and the brief.

The placeholder is one line naming the rule that caused the skip, so downstream agents see an explicit absence rather than a missing file:

- `04-backend-summary.md`: *"SKIPPED — project.shape is frontend-only (00-config-resolved.md)"*
- `05-frontend-summary.md`: *"SKIPPED — brief marks Frontend changes: None (03-spec.md)"*

### Step 5 — Verify
Spawn `test-verifier`. Inputs: approved story + approved brief + both builder summaries.
Its report (test files added, per-criterion coverage verdicts, gate-enforceability results, test run output) is **not** saved to its own file — hold it in context and hand it to `validator` in Step 6, which folds it into `07-validator.md`. There is no `06-coverage.md`; see `agents/test-verifier.md`'s "Output contract" and `agents/validator.md`'s "Coverage report" for why the merge happened.

Every gate `test-verifier` relies on for a `PASS` (CI step, coverage threshold, assertion/guard helper) must carry a captured negative-control result per `agents/test-verifier.md`'s "Negative-control requirement." A gate with no negative control on record is `UNENFORCED`, not evidence — the orchestrator does not accept a `PASS` that rests on one (see the mechanical roll-up rule below).

For each criterion result:
- `PASS`: continue
- `PARTIAL`: treat like `FAIL` for loop-control purposes — the specific sub-check named in the rationale needs a real fix (a synthetic/reused/not-executed check made real, or an `UNENFORCED` gate proven to fail), not a re-run that just relabels the same evidence.
- `FAIL`: identify whether the failing behaviour is backend or frontend. Loop back to the appropriate builder with the specific failing criterion. Re-run test-verifier after the fix.
- `UNCOVERED`: flag for the validator to decide severity.

Max 3 fix attempts per failing or PARTIAL criterion. If still not PASS, pause and ask the user (likely the brief is wrong).

#### Mechanical AC roll-up rule

`PASS` on an acceptance criterion is a claim that every sub-check behind it actually ran and actually enforces something — this is checked mechanically, not by vibes. **If any sub-check's evidence is self-labelled `synthetic`, `reused`, `not executed`, or `pending`, or cites a gate reported `UNENFORCED`, the criterion is `PARTIAL`, never `PASS`** — regardless of how many other sub-checks for that criterion are solid, and regardless of what label test-verifier's report or `07-validator.md` originally attached to it. The orchestrator does not pass a `PARTIAL` criterion through to Checkpoint 3 as if it were a `PASS`; it stays visible as open work until fixed or the user explicitly accepts it as a known gap.

### Step 6 — Validate
Spawn `validator`. Inputs: story + brief + both builder summaries + test-verifier's coverage report from Step 5.
Save to `07-validator.md` — this is now the single file holding both the coverage report and the gap analysis (see `agents/validator.md`'s "Output contract").

`validator` re-derives each criterion's verdict from the evidence text rather than trusting test-verifier's label (see `agents/validator.md`'s "Mechanical AC roll-up rule") and files a Critical finding for any gate cited as evidence with no negative control on record. Treat those Critical findings the same as any other:

Handle findings:
- **Critical**: loop back to the appropriate builder. Re-run validator after the fix. Repeat until no Critical findings remain.
- **Important**: present to user. Ask: fix now (loop) or accept (continue)?
- **Minor**: report only. User reviews at the final checkpoint.

### Step 7 — Hand off

Before presenting Checkpoint 3, invoke the [run-feedback skill](../run-feedback/SKILL.md) against this feature's state directory. It writes `08-feedback.md` (mechanical checks only — gate enforceability, orphan code, duplication ratio, state-file honesty, and the rest of its check table) and, when the hub is present locally, files any hub-actionable finding to its feedback inbox. Fold its ~600-word Part A scorecard into the Checkpoint 3 summary below as one more section — do not present it as a separate checkpoint, and do not let the chain block on anything it finds (that's `validator`'s job, already done in Step 6).

**🛑 CHECKPOINT 3 — Summarize for the user:**
- What was built (one paragraph)
- Files changed (count + folder breakdown)
- Tests added (count + acceptance criteria covered)
- Validator findings still open (with the user's accept/defer choices)
- Run-feedback's scorecard (Part A of `08-feedback.md`), plus a note naming how many Part B hub-change proposals exist and whether they were filed to the hub's inbox
- The local branch name and a suggested PR title

The chain stops here. The hub never opens PRs on its own — the human reviews the diff and runs `gh pr create` (or equivalent).

## Loop control

Hard limits to prevent thrashing:

| Step | Max iterations | Action when exceeded |
|---|---|---|
| Config gate (Step 0) | 3 | Stop. Do not run the chain unconfigured — ask the user to fix `.agenthub-config.yaml` by hand |
| Trivial-tier escalation (Step 1.5) | 1 per feature | An escalated feature does not re-attempt trivial — it runs the standard chain from that point on, no exceptions |
| Story checkpoint | 3 | Ask if the feature is well-defined enough to proceed |
| Spec checkpoint | 3 | Ask if the story needs to be revised |
| Backend ↔ frontend handoff (sequential mode) | 3 | Pause; the brief's API design is likely wrong |
| Backend/frontend contract-check (parallel mode) | 3 | Pause; the brief's API section is likely imprecise despite being marked `high` confidence |
| Test failures per criterion | 3 | Pause; the brief or the criterion is likely wrong |
| Validator critical findings | 3 | Pause; something fundamental is off |

When a limit hits, do not push past it. Stop and surface the question to the user.

## Retry strategy — escalating context

A retry that gets the same context as attempt 1 will produce the same mistake. Vary what the retrying agent sees so each attempt has a fresh angle:

| Attempt | Context provided to the retrying agent |
|---|---|
| 1 (initial) | Approved brief + researcher's findings + project CLAUDE.md (the full kit) |
| 2 (first retry) | The specific failure (criterion number or validator finding) + the files the agent changed in attempt 1 + a one-paragraph summary of attempt 1. **Not** the full brief — narrow the focus. |
| 3 (second retry) | Attempt-2 context + full failure traces + a one-paragraph summary of "what attempts 1 and 2 tried and why each failed." Root-cause mode. |
| 4+ | Stop. Pause and ask the user — the problem is upstream (story or brief), not in the implementation. |

This applies to all retry loops: backend-builder retries (test failures, validator findings), frontend-builder retries (same), and the backend↔frontend handoff or contract-check (whichever mode Step 4 ran in).

## Loop integration

The feature-factory follows the generic [loop-engine protocol](../loop-engine/SKILL.md) at 5 points. Each maps to the loop engine's 5-phase cycle (DISCOVER → PLAN → EXECUTE → VERIFY → ITERATE) with explicit configuration.

### Loop point 0 — Trivial-tier accept/escalate checkpoint (Step 1.5)

**Loop: invoke loop-engine protocol.** Only runs when the researcher suggests `trivial`; a `standard` suggestion skips straight to Loop point 1.

- Goal: User accepts the trivial fast path, or explicitly escalates to the standard chain
- Success criteria:
  1. The researcher's scope read and named file were shown to the user
  2. User explicitly chose accept or escalate
- Verifier: human approval
- Max iterations: 1 (this is a binary choice, not a revision cycle — there is nothing to iterate on)
- Mode: `checkpointed`
- On CONVERGED (accept): mark `tier: trivial` in `00-config-resolved.md`, skip to Step 4
- On CONVERGED (escalate): proceed to Step 2 as a standard-tier run
- On PAUSED_FOR_HUMAN: present the scope read and ask: accept fast path, or escalate to standard?

### Loop point 1 — Story checkpoint revisions (Step 2)

**Loop: invoke loop-engine protocol.**

- Goal: User approves the user story and acceptance criteria
- Success criteria:
  1. Story covers the feature description completely
  2. Acceptance criteria are numbered and verifiable
  3. User explicitly approves
- Verifier: human approval
- Max iterations: 3
- Mode: `checkpointed`
- On CONVERGED: add `STATUS: APPROVED` to `02-story.md`, proceed to Step 3
- On STOPPED_AT_LIMIT: ask if the feature is well-defined enough to proceed
- On PAUSED_FOR_HUMAN: present the story and ask: approve, request changes, or reject

### Loop point 2 — Spec checkpoint revisions (Step 3)

**Loop: invoke loop-engine protocol.**

- Goal: User approves the technical brief
- Success criteria:
  1. Brief covers data model, API changes, frontend changes, and file-level plan
  2. No anti-patterns flagged by the researcher
  3. No scope creep beyond the story
  4. User explicitly approves
- Verifier: human approval
- Max iterations: 3
- Mode: `checkpointed`
- On CONVERGED: mark `STATUS: APPROVED`, proceed to Step 4
- On STOPPED_AT_LIMIT: ask if the story needs to be revised (back to Loop point 1)
- On PAUSED_FOR_HUMAN: present the brief with callouts for contract mistakes

### Loop point 3 — Backend ↔ frontend reconciliation (Step 4)

This is a `loop-back` edge inside the Step 4 graph node (see "Graph integration" below); which trigger fires depends on which mode Step 4 ran in.

**Sequential mode — loop: invoke loop-engine protocol.**

- Goal: Frontend-builder accepts the API contract from backend-builder
- Success criteria:
  1. Frontend-builder does not report an API mismatch
  2. Both builder summaries are complete
- Verifier: frontend-builder's feedback (agent verifier)
- Max iterations: 3
- Mode: `hybrid`
- On CONVERGED: proceed to Step 5
- On STOPPED_AT_LIMIT: pause — the brief's API design is likely wrong
- On PAUSED_FOR_HUMAN: present the mismatch and ask whether to fix the brief or adjust the API

**Parallel mode — loop: invoke loop-engine protocol.**

- Goal: Backend's actual API and frontend's assumed API both match the brief's API section
- Success criteria:
  1. Contract-check (`04b-contract-check.md`) reports no mismatch between brief, backend summary, and frontend summary
  2. Both builder summaries are complete
- Verifier: contract-check gate — a command/agent diff against the brief's literal API section (a reality anchor, not one builder's opinion of the other's code)
- Max iterations: 3
- Mode: `hybrid`
- On CONVERGED: proceed to Step 5
- On STOPPED_AT_LIMIT: pause — the brief's API section is likely imprecise despite being marked `high` confidence; consider re-running Step 4 in sequential mode for this feature
- On PAUSED_FOR_HUMAN: present the mismatch (brief vs. backend vs. frontend) and ask whether to fix the brief or one of the builders

### Loop point 4 — Test failure → builder fix (Step 5)

**Loop: invoke loop-engine protocol.**

- Goal: Failing or PARTIAL acceptance criterion reports a genuine `PASS`
- Success criteria:
  1. The specific criterion reports `PASS` on re-run, with no sub-check evidence labelled `synthetic`/`reused`/`not executed`/`pending` and no `UNENFORCED` gate behind it (mechanical AC roll-up rule)
  2. No regressions in previously passing criteria
- Verifier: test-verifier re-run (command verifier via `test.command`)
- Max iterations: 3 per failing or PARTIAL criterion
- Mode: `autonomous`
- On CONVERGED: continue to next failing criterion or proceed to Step 6
- On STOPPED_AT_LIMIT: pause — the brief or the criterion is likely wrong
- On PAUSED_FOR_HUMAN: present the criterion, all 3 attempts, and ask whether the brief needs revision

### Loop point 5 — Validator critical → builder fix (Step 6)

**Loop: invoke loop-engine protocol.**

- Goal: No Critical findings remain in the validator report
- Success criteria:
  1. Validator re-run reports zero Critical findings
  2. No new Critical findings introduced by the fix
- Verifier: validator re-run (agent verifier)
- Max iterations: 3
- Mode: `autonomous`
- On CONVERGED: proceed to Step 7 (hand off)
- On STOPPED_AT_LIMIT: pause — something fundamental is off
- On PAUSED_FOR_HUMAN: present all Critical findings and ask what to do

### State integration

Each loop point writes its iteration log to `loop-state.jsonl` within the feature's state directory (`<project>/.claude/feature-factory/<feature-slug>/`). This sits alongside the existing numbered output files (`01-research.md`, `02-story.md`, etc.) and enables resume on session interruption — **but only if each entry is written the moment that iteration's VERIFY result is known, not batched at the end of the run.** A real run's `loop-state.jsonl` had six iterations (spec approval, reconciliation, three test-verification rounds, a coverage fix) sharing one timestamp; a crash during that run would have left the retry history unrecoverable, defeating the reason the file exists. Per loop-engine's "State tracking" section (`skills/loop-engine/SKILL.md`), the orchestrator appends the entry for a loop point as soon as that point's iteration converges, fails, or pauses — before moving on to the next step — never after Step 7's hand-off as a retroactive summary.

The escalating context strategy from the "Retry strategy" section above maps directly to the loop engine's standard escalation: attempt 1 full context, attempt 2 narrow, attempt 3 root-cause, attempt 4+ stop.

See the [loop framework diagram](../../diagrams/04-loop-framework.md) for a visual overview and the [loop guide](../../docs/loop-guide.md) for the full protocol reference.

## Graph integration

Step 4 (backend-builder + frontend-builder) follows the generic [graph-engine protocol](../graph-engine/SKILL.md): a `parallel-fanout` edge from the approved brief's API section (the contract) to both builders, gated by a fan-in contract-check, with the mode chosen per-feature by `build.parallel-builders` + the brief's `API contract confidence`. Every other step in the chain remains a plain sequential edge — the graph structure only branches at this one point.

| Graph concept | Feature-factory Step 4 |
|---|---|
| Contract | The approved brief's API changes section |
| Parallel nodes | `backend-builder`, `frontend-builder` |
| Fan-in gate | Contract-check (`04b-contract-check.md`) — command/agent diff, not an LLM opinion |
| Loop-back | Back to whichever builder drifted, via loop-engine, max 3 round trips |
| Reality anchor | The brief's literal text (fixed at Checkpoint 2, not re-interpreted by either builder) |

See the [graph engine diagram](../../diagrams/05-graph-engine.md) for the visual and [docs/graph-guide.md](../../docs/graph-guide.md) for when parallelizing a pair of nodes is safe versus when it's a race condition in disguise.

## Learning directory (optional, project-local)

If `<project>/.claude/feature-factory/learning/` exists, the chain reads/writes three files:

| File | Owner | Use |
|---|---|---|
| `patterns.md` | researcher | Cached patterns from past runs — researcher reads at start, appends novelties |
| `selectors.md` | test-verifier | CSS/XPath/API paths reused across features |
| `failures.md` | validator | Recurring findings — spec-writer reads to avoid re-proposing patterns that previously failed |

The learning directory is per-project, not per-feature, and survives across chain runs. Whether to commit it (team benefit) or gitignore it (personal preference) is the project's call.

## State

All intermediate outputs persist under `<project>/.claude/feature-factory/<feature-slug>/`:

```
00-config-resolved.md   (Step 0 gate output — the binding config for every later agent; carries `tier: trivial|standard` after Step 1.5)
01-research.md          (includes the Suggested complexity tier field read at Step 1.5)
02-story.md          (with STATUS: APPROVED once approved — absent for a trivial-tier run unless it later escalates)
03-spec.md           (with STATUS: APPROVED once approved; includes API contract confidence — absent for a trivial-tier run unless it later escalates)
04-backend-summary.md
04b-contract-check.md   (only in parallel mode)
05-frontend-summary.md
05-frontend-feedback.md  (only in sequential mode, if there was a mismatch)
07-validator.md       (test-verifier's coverage report + validator's findings — no separate 06-coverage.md; see Step 5/6)
08-feedback.md        (run-feedback's mechanical scorecard + hub change proposals — see Step 7)
```

There is no `graph-state.json`. Step 4's node status and fan-in result live in this same listing — `04-backend-summary.md` present means backend-builder finished, `04b-contract-check.md` present (and its verdict) is the fan-in result — per graph-engine's "State tracking" section (`skills/graph-engine/SKILL.md`), which dropped the separate state file after it was found recording 2 of 7 nodes in one real run and, in another, contradicting the coverage report it was supposed to summarize. `loop-state.jsonl` (below) still carries the iteration-level retry detail for whichever loop point is currently retrying.

This lets the chain resume cleanly if the session is interrupted. On resume: read the highest-numbered file present, identify the next step, continue from there. Because Step 5's report is no longer its own file, a resume landing between Step 5 and Step 6 has no `06-coverage.md` to pick up — re-run test-verifier and hand its report straight into validator, same as a fresh Step 5 → 6 pass. For a trivial-tier run, the absence of `02-story.md`/`03-spec.md` is expected, not a sign of interruption — check `00-config-resolved.md`'s `tier` field before assuming the chain crashed between Step 1 and Step 2.

`<feature-slug>` is the feature description lowercased, slugified, truncated to 40 chars (e.g., `invoice-reminders-for-overdue-invoices`).

## What this skill does NOT do

- Open a PR (the human handles checkpoint 3 hand-off)
- Modify CLAUDE.md (that's the drift loop, run separately after merge)
- Skip checkpoints, even if the user says "just do it" — every run gets at least one pre-build human gate (the trivial fast path's single accept/escalate checkpoint, or story + brief approval for everything else) plus Checkpoint 3 at hand-off. A trivial-tier run consolidates checkpoints, it never zeroes them.
- Add agents to the chain at runtime (the chain is fixed; new agents go through hub planning)
- Run in fully autonomous mode without checkpoints — that's a different skill, not this one
- Proceed past Step 0 on an assumed or invalid config (use `--no-config` if you genuinely mean to)
- Spawn a builder that Step 0 or the brief already ruled out, just to have it report "N/A"
- Weaken test-verifier's negative-control requirement or validator's mechanical AC roll-up rule for a trivial-tier run — those gates cost the same regardless of tier

## Drift signals to record

Every run, note for the hub's drift loop:
- Any time a builder reported a "CLAUDE.md rules that would have helped" entry
- Any time the user rejected story or spec for the same reason twice
- Any time the validator caught a class of issue that wasn't in its default checks
- Any time Step 4 ran in parallel mode and the contract-check found a mismatch — signals `spec-writer` is over-confident marking `API contract confidence: high`
- Any time a trivial-tier run escalated mid-build — signals `researcher` is over-confident marking `Suggested complexity tier: trivial`; recurring escalations on the same kind of feature are a reason to tighten the tier heuristic in `agents/researcher.md`

These feed into hub agent updates. Surface them in the checkpoint 3 summary so the user can decide whether to update the hub now or batch later.

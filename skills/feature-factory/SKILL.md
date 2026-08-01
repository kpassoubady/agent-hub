---
name: feature-factory
version: 1.3.0
hub-source: agent-hub
description: Orchestrates the 7-agent factory chain to build a feature from idea to validated implementation, with three human checkpoints.
---

# Feature Factory

Orchestrates the 7-agent factory chain: researcher → story-writer → spec-writer → backend-builder + frontend-builder → test-verifier → validator.

Three human checkpoints — story approval, brief approval, PR review. Everything else runs on its own. The backend/frontend step runs sequentially or in parallel per feature — see [Step 4](#step-4--build) and [graph-engine](../graph-engine/SKILL.md).

## When to use

The user invoked `/feature-factory <feature description>` (or asked to "build feature X with the factory") and wants to build a feature end-to-end through the chain.

**Do not use this skill for:**
- One-line bug fixes (overkill — use direct edits)
- Pure refactors with no user-visible behaviour change
- Exploratory work where the goal isn't yet a concrete feature

## The chain

### Step 0 — Read project shape

Before starting, read `<project>/.agenthub-config.yaml` and extract `project.shape`. This decides which agents in the chain actually run.

| `project.shape` | Chain adjustment |
|---|---|
| `full-stack` | Run all 7 agents (default). |
| `backend-only` | Skip frontend-builder. test-verifier exercises API or CLI only. |
| `frontend-only` | Skip backend-builder. The spec must say where the API lives (external service, mock). |
| `library` | Same as `backend-only`: skip frontend-builder. spec-writer treats the package's public surface as the "API". |

If `.agenthub-config.yaml` is missing or `project.shape` is unset, assume `full-stack` and warn the user once at the start: *"No project.shape in .agenthub-config.yaml — assuming full-stack. Run `./agent-hub-detect.sh --force` in the hub directory to refresh."*

**Per-feature override.** Even when `project.shape` allows both builders, **skip a builder when the spec-writer's brief has no work for it.** The brief is the per-feature source of truth — a `full-stack` project can still run a 6-agent chain for an API-only feature. The skip rule:

- Backend-builder skipped if the brief's `API changes` and `Data model changes` sections are empty or marked `None`.
- Frontend-builder skipped if the brief's `Frontend changes` section is empty or marked `None`.

### Step 1 — Research
Spawn the `researcher` agent. Inputs: the feature description + project CLAUDE.md.
Save the output to `<project>/.claude/feature-factory/<feature-slug>/01-research.md`.
Do not show the user — the next checkpoint is more useful to review.

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

When a builder is skipped, write a one-line placeholder to its summary file (e.g., `04-backend-summary.md`: *"SKIPPED — project.shape is frontend-only"*) so downstream agents have a clear, explicit absence rather than a missing file.

### Step 5 — Verify
Spawn `test-verifier`. Inputs: approved story + approved brief + both builder summaries.
Save coverage report to `06-coverage.md`.

For each criterion result:
- `PASS`: continue
- `FAIL`: identify whether the failing behaviour is backend or frontend. Loop back to the appropriate builder with the specific failing criterion. Re-run test-verifier after the fix.
- `UNCOVERED`: flag for the validator to decide severity.

Max 3 fix attempts per failing criterion. If still failing, pause and ask the user (likely the brief is wrong).

### Step 6 — Validate
Spawn `validator`. Inputs: story + brief + both builder summaries + coverage report.
Save to `07-validator.md`.

Handle findings:
- **Critical**: loop back to the appropriate builder. Re-run validator after the fix. Repeat until no Critical findings remain.
- **Important**: present to user. Ask: fix now (loop) or accept (continue)?
- **Minor**: report only. User reviews at the final checkpoint.

### Step 7 — Hand off

**🛑 CHECKPOINT 3 — Summarize for the user:**
- What was built (one paragraph)
- Files changed (count + folder breakdown)
- Tests added (count + acceptance criteria covered)
- Validator findings still open (with the user's accept/defer choices)
- The local branch name and a suggested PR title

The chain stops here. The hub never opens PRs on its own — the human reviews the diff and runs `gh pr create` (or equivalent).

## Loop control

Hard limits to prevent thrashing:

| Step | Max iterations | Action when exceeded |
|---|---|---|
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

- Goal: Failing acceptance criterion passes
- Success criteria:
  1. The specific criterion reports `PASS` on re-run
  2. No regressions in previously passing criteria
- Verifier: test-verifier re-run (command verifier via `test.command`)
- Max iterations: 3 per failing criterion
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

Each loop point writes its iteration log to `loop-state.jsonl` within the feature's state directory (`<project>/.claude/feature-factory/<feature-slug>/`). This sits alongside the existing numbered output files (`01-research.md`, `02-story.md`, etc.) and enables resume on session interruption.

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
01-research.md
02-story.md          (with STATUS: APPROVED once approved)
03-spec.md           (with STATUS: APPROVED once approved; includes API contract confidence)
04-backend-summary.md
04b-contract-check.md   (only in parallel mode)
05-frontend-summary.md
05-frontend-feedback.md  (only in sequential mode, if there was a mismatch)
06-coverage.md
07-validator.md
graph-state.json      (Step 4 node status + fan-in result — managed by graph-engine)
```

This lets the chain resume cleanly if the session is interrupted. On resume: read the highest-numbered file present, identify the next step, continue from there.

`<feature-slug>` is the feature description lowercased, slugified, truncated to 40 chars (e.g., `invoice-reminders-for-overdue-invoices`).

## What this skill does NOT do

- Open a PR (the human handles checkpoint 3 hand-off)
- Modify CLAUDE.md (that's the drift loop, run separately after merge)
- Skip checkpoints, even if the user says "just do it" — the three checkpoints are non-negotiable
- Add agents to the chain at runtime (the chain is fixed; new agents go through hub planning)
- Run in fully autonomous mode without checkpoints — that's a different skill, not this one

## Drift signals to record

Every run, note for the hub's drift loop:
- Any time a builder reported a "CLAUDE.md rules that would have helped" entry
- Any time the user rejected story or spec for the same reason twice
- Any time the validator caught a class of issue that wasn't in its default checks
- Any time Step 4 ran in parallel mode and the contract-check found a mismatch — signals `spec-writer` is over-confident marking `API contract confidence: high`

These feed into hub agent updates. Surface them in the checkpoint 3 summary so the user can decide whether to update the hub now or batch later.

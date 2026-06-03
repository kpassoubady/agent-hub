---
name: feature-factory
version: 1.1.0
hub-source: agent-hub
description: Orchestrates the 7-agent factory chain to build a feature from idea to validated implementation, with three human checkpoints.
---

# Feature Factory

Orchestrates the 7-agent factory chain: researcher → story-writer → spec-writer → backend-builder + frontend-builder → test-verifier → validator.

Three human checkpoints — story approval, brief approval, PR review. Everything else runs on its own.

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

Run **backend-builder first**, sequentially with frontend-builder (not in parallel).

Why backend first: the frontend reads the API contract from the backend's summary. If the API doesn't fit the UI, frontend-builder surfaces it as feedback and we loop back to backend-builder — not patch it client-side.

a) Spawn `backend-builder`. Inputs: approved brief + researcher's output + project CLAUDE.md.
   Save its summary to `04-backend-summary.md`.

b) Spawn `frontend-builder`. Inputs: approved brief + researcher's output + backend-builder's summary (if 4a ran) + project CLAUDE.md.
   Save its summary to `05-frontend-summary.md`.

If frontend-builder surfaces an API mismatch:
- Save its feedback to `05-frontend-feedback.md`
- Loop back to step 4a, passing the feedback to backend-builder
- After backend re-implements, re-run frontend-builder
- Max 3 round trips per feature; if not converged, pause and ask the user

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
| Backend ↔ frontend handoff | 3 | Pause; the brief's API design is likely wrong |
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

This applies to all retry loops: backend-builder retries (test failures, validator findings), frontend-builder retries (same), and the backend↔frontend handoff (API-mismatch loop).

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
03-spec.md           (with STATUS: APPROVED once approved)
04-backend-summary.md
05-frontend-summary.md
05-frontend-feedback.md  (only if there was a mismatch)
06-coverage.md
07-validator.md
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

These feed into hub agent updates. Surface them in the checkpoint 3 summary so the user can decide whether to update the hub now or batch later.

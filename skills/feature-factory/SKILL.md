---
name: feature-factory
version: 1.0.0
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

Run **backend-builder first**, sequentially with frontend-builder (not in parallel).

Why backend first: the frontend reads the API contract from the backend's summary. If the API doesn't fit the UI, frontend-builder surfaces it as feedback and we loop back to backend-builder — not patch it client-side.

a) Spawn `backend-builder`. Inputs: approved brief + researcher's output + project CLAUDE.md.
   Save its summary to `04-backend-summary.md`.

b) Spawn `frontend-builder`. Inputs: approved brief + researcher's output + backend-builder's summary + project CLAUDE.md.
   Save its summary to `05-frontend-summary.md`.

If frontend-builder surfaces an API mismatch:
- Save its feedback to `05-frontend-feedback.md`
- Loop back to step 4a, passing the feedback to backend-builder
- After backend re-implements, re-run frontend-builder
- Max 3 round trips per feature; if not converged, pause and ask the user

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

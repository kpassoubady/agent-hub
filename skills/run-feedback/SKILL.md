---
name: run-feedback
version: 0.1.0
hub-source: agent-hub
description: Runs mechanical checks against a just-completed feature-factory or adaptive-engine run and emits a scorecard plus hub change proposals, filed to the hub's feedback inbox when it's present locally.
---

# Run Feedback

Runs the `run-feedback-analyzer` agent against a chain run's own state directory, computing mechanical facts — never a self-assessed quality score — about verification theatre, duplication, state-file honesty, and cost-vs-complexity. Closes the gap the retrospective found: `learning/` directories were documented since `v0.2.0` and never once populated across 21 real runs, because capture depended on a human noticing a surprise. This skill captures automatically, at the point the human is already looking.

## When to use

- **Automatic** — feature-factory's Checkpoint 3 (Step 7) and adaptive-engine's Checkpoint 2 (Phase 3) both invoke this skill before presenting their hand-off summary. See "Trigger integration" below.
- **Standalone** — `/run-feedback <state-dir>` against any completed or in-progress run's state directory, for a retroactive check or a run that predates this skill.

**Do not use this skill for:**
- Grading a run's code quality, architecture, or design choices — that's `code-reviewer` / `validator`'s job, and this skill's whole design rests on never producing that kind of output (see "Mechanical only" below)
- Applying any proposed hub change — this skill only writes findings; consuming them and editing hub agent/skill files is `hub-improve`'s job (not yet built — see the hub's own todo tracking)
- A run still missing `07-validator.md` — several checks need the validator's coverage report; run this after Step 6/the graph's validator node, not before

## Mechanical only

Every check `run-feedback-analyzer` runs reduces to a `grep`, a count, or a diff — never a judgment call, never the agent scoring its own chain's "quality." This is deliberate: the loop-engine's own verifier principle ("the agent that did the work is too generous grading its own output") applies one level up here too. The skill reports numbers; the human reads them and decides what, if anything, is worth escalating to a hub change. If a check can't be reduced to a command whose output is the answer, it does not belong in this skill — see `agents/run-feedback-analyzer.md`'s check table for the full list (gate enforceability, orphan code, coverage-scope bias, threshold drift, duplication ratio, AC roll-up integrity, state-file honesty, config gating, cost-vs-complexity, retry productivity, landed-vs-claimed).

## Step 1 — Locate the run

Given a state directory (passed directly, or the calling skill's own `<project>/.claude/feature-factory/<feature-slug>/` / `<project>/.claude/adaptive-engine/<feature-slug>/`), confirm at minimum `07-validator.md` (or the graph-engine equivalent — whichever node ran the validator) is present. If it isn't, tell the caller which artifact is missing and stop rather than running a partial analysis silently.

## Step 2 — Run the analyzer

Spawn `run-feedback-analyzer`. Inputs: the state directory, the source requirements doc if `01-research.md`/`02-story.md` names one, `git diff`/`git log` scoped to files the run's builder summaries claim to have touched, and the hub's own agent/skill files (for citing versions in any Part B finding).

## Step 3 — Report

The agent writes `<state-dir>/08-feedback.md`. Show the caller **Part A only** — the ~600-word scorecard — inline, at whichever checkpoint invoked this skill. Do not make the human open a file to see it; that is exactly how the `learning/` directories went unread for 21 runs.

If Part B has any entries, say how many and name their `Target` files, but do not inline the full entries — those are for the inbox, not the checkpoint. Tell the caller whether an inbox entry was written (and its path), or show the fallback copy command if the hub wasn't discoverable locally (see `agents/run-feedback-analyzer.md`'s Output contract).

## Trigger integration

This skill is invoked automatically from two points, both **before** their checkpoint's summary is shown:

- `feature-factory` Step 7, immediately before Checkpoint 3's hand-off summary (see `skills/feature-factory/SKILL.md`).
- `adaptive-engine` Phase 3, immediately before Checkpoint 2's final review (see `skills/adaptive-engine/SKILL.md`).

Both callers fold Part A into their existing checkpoint summary rather than presenting it as a separate wall of text — the scorecard is one more section of the hand-off, not a fourth checkpoint.

## What this skill does NOT do

- Gate the chain on its own findings — Part A and B are informational; the chain does not pause or fail because this skill ran, even if it finds a Critical-shaped issue (that issue was `validator`'s job to catch and block on already)
- Consume more than the ~600-word Part A cap per run — this is a net token add to every run, so it stays cheap; see `agents/run-feedback-analyzer.md`'s "What it cannot do"
- Build or maintain the hub-side inbox consumer — writing to `llm-context/feedback/inbox/` is this skill's job; reading it, clustering by recurrence, and editing hub files is a separate skill, not yet built
- Skip a trivial-tier feature-factory run — a trivial run still produced code and still ran test-verifier/validator, so the same mechanical checks apply; only the artifacts this skill reads differ (feature description + researcher output stand in for story + brief, same as everywhere else in a trivial run)
- Run against a state directory with no validator output yet — see Step 1

## State

Writes exactly:

```
<state-dir>/08-feedback.md                                              (Part A + Part B)
<hub-root>/llm-context/feedback/inbox/<project>-<feature-slug>-<date>.md   (Part B only, when the hub is discoverable locally)
```

No other file is created, edited, or deleted.

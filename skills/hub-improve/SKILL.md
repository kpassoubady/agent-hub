---
name: hub-improve
version: 0.1.0
hub-source: agent-hub
description: Consumes the feedback inbox, clusters findings by recurrence, and — only after explicit human approval per candidate — applies the resulting hub-file edit, version bump, and CHANGELOG entry.
---

# Hub Improve

Closes the loop `run-feedback` opens. `run-feedback` writes single-run findings to `llm-context/feedback/inbox/`; this skill reads across all of them, drafts a change only for what recurs, and never writes to a hub file without a human saying yes to that specific change.

## When to use

- **Standalone**, invoked deliberately by the hub maintainer: `/hub-improve`. This is not wired into any project's automatic run — it operates on the hub's own inbox, across however many project runs have accumulated since it was last invoked.
- Run it periodically (weekly, or whenever the maintainer notices the inbox has a few new entries) rather than after every single run — recurrence needs more than one run to exist, so running it after each `run-feedback` invocation is wasted work.

**Do not use this skill for:**
- Producing findings — that's `run-feedback`'s job. This skill only consumes what's already in the inbox.
- Auto-applying anything. There is no mode of this skill, interactive or otherwise, that writes a hub file without a human approving that exact change first. If you are looking for unattended hub maintenance, this skill is not it — by design (see §10.2 of `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md`).

## Step 1 — Run the analyzer

Spawn `hub-improve-analyzer`. It reads every file in `llm-context/feedback/inbox/`, clusters by target file and underlying behavior, recomputes recurrence itself (never trusting an entry's own "1 run" line), and writes `llm-context/feedback/hub-improve-report.md`.

If the inbox is empty or the report shows zero candidates, say so and stop — do not manufacture a checkpoint over nothing.

## Step 2 — Human checkpoint: approve, reject, or defer, one candidate at a time

Show the report's **Candidates** section. For each one, in order:

1. Show its cluster (which runs, which files), the recurrence count, the draft diff, and whether it's flagged contested.
2. Ask the human: **apply**, **reject**, or **defer** (leave in the inbox, unfiled, for a future pass — useful when a candidate is real but the maintainer wants to see a third occurrence first).
3. Do not batch this into one yes/no for the whole report — a human approving candidate 1 has said nothing about candidate 2, and the retrospective's own root finding was that *plausible* approval-without-scrutiny is exactly how verification theatre slips through.

Also show the **Rejected** section from the report as information only (the analyzer already rejected these; no action needed) unless the human asks to override one — overriding a rejection requires the same evidence re-verification the analyzer would have done, so re-run it before treating an analyzer-rejected candidate as approved.

## Step 3 — Apply approved candidates only

For each candidate the human approved in Step 2:

1. Edit the target file with the approved draft diff (adjust only if the human requested a change to the wording during Step 2 — never apply the unmodified draft after the human asked for edits).
2. Bump that file's `version:` frontmatter per the candidate's proposed bump.
3. Append a `CHANGELOG.md` entry citing which inbox entries (by filename and `F-00N` id) motivated the change, following the existing changelog's per-release format.
4. Move every inbox file that contributed an entry to this candidate into `llm-context/feedback/inbox/applied/` (create the directory if absent).

For each candidate the human rejected: move its contributing inbox files into `llm-context/feedback/inbox/rejected/` (create if absent) — this prevents the same single-run finding from silently re-surfacing as "new" in a future pass once a second run's entry might otherwise pair with it.

For each candidate the human deferred: leave its inbox files in place, untouched, so a future run's entry can still join the same cluster.

## Step 4 — Report

State plainly what was applied (files, version bumps), what was rejected (and moved to `rejected/`), and what was deferred (and stays in `inbox/`). If nothing was approved this pass, say that — a report with zero applications is a legitimate, expected outcome when the recurrence gate is doing its job.

## What this skill does NOT do

- Apply any change without a per-candidate human decision in Step 2 — there is no flag, mode, or override that skips this
- Treat a single inbox entry as sufficient evidence on its own, regardless of severity — `hub-improve-analyzer`'s only exception (severity `high` + independently re-verified evidence) still requires the analyzer to re-run the check this pass, not just repeat the entry's own claim
- Run automatically as part of any project's `feature-factory`/`adaptive-engine` chain — unlike `run-feedback`, this skill is hub-maintainer-invoked only, since its whole purpose is accumulating cross-run signal before acting
- Delete an inbox entry outright — rejected and applied entries are moved, never deleted, so the hub's own history of what was proposed and why remains inspectable

## State

Writes, only after Step 1/Step 3 as described above:

```
llm-context/feedback/hub-improve-report.md        (overwritten each run — Step 1)
<target agent/skill file>                          (only for a human-approved candidate — Step 3)
CHANGELOG.md                                        (appended, only for a human-approved candidate — Step 3)
llm-context/feedback/inbox/applied/<file>.md        (moved from inbox/ — Step 3)
llm-context/feedback/inbox/rejected/<file>.md       (moved from inbox/ — Step 3)
```

No file is written, moved, or deleted outside of an explicit human decision in Step 2.

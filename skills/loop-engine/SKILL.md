---
name: loop-engine
version: 1.0.0
hub-source: agent-hub
description: >
  Generic loop engine that any skill can invoke for iterative work.
  Handles the 5-phase loop protocol (DISCOVER → PLAN → EXECUTE → VERIFY → ITERATE),
  state persistence, escalating retry context, stop conditions, and cost awareness.
---

# Loop Engine

A reusable loop protocol that turns a one-shot agent action into a goal-directed iteration cycle. Any skill that needs retry logic, verification gates, or iterative improvement calls this engine instead of re-implementing loop control from scratch.

## When to use

A loop is worth invoking only when **all four** of these are true:

1. The task repeats or retries — not a one-shot action
2. Something can automatically reject bad output (a test, a check, a rubric)
3. The agent can do the work end-to-end without handing half back to the user
4. "Done" is objective, not a judgment call

If any box is unchecked, keep it as a single-pass agent call.

**Do not use this skill for:**
- One-shot prompts that need no verification
- Tasks where quality is purely subjective (no gate possible)
- Work that requires human judgment on every iteration (use direct checkpoints instead)

## The five phases

Every loop iteration runs these five phases in order:

### Phase 1 — DISCOVER

Read the goal, prior state, and any learning from past runs.

- Read the **goal description** and **success criteria** from the calling skill
- Read **loop state** from `loop-state.jsonl` if resuming a prior run
- Read the **learning directory** if it exists (patterns, failures from past runs)
- Identify: is this iteration 1 (fresh start) or iteration N (resuming)?

### Phase 2 — PLAN

Decide the single next action to take.

- If iteration 1: use the full context (goal + all inputs from the calling skill)
- If iteration N: use the escalating context strategy (see below)
- State the plan as a single, specific next step — not a list of everything remaining
- The calling skill's agent does the planning; the loop engine enforces the structure

### Phase 3 — EXECUTE

Do the work.

- The calling skill's agent performs the planned action
- The loop engine does not do the work itself — it delegates to the agent the calling skill specifies
- All changes are recorded in the state log

### Phase 4 — VERIFY

Check the result against the success criteria. This is the gate.

The verifier type is declared in the calling skill's loop config:

| Verifier type | How it works |
|---|---|
| `command` | Run a shell command (test suite, linter, type checker). Exit 0 = pass. |
| `agent` | Spawn a read-only agent that scores the result against criteria. |
| `rubric` | Score each criterion 1–10. All criteria must be 8+ to pass. |

The verifier must be **separate from the executor**. The agent that did the work is too generous grading its own output. Use a different agent, a hard test, or a measurable condition.

Results:
- **PASS** — all criteria met → proceed to Phase 5 with `CONVERGED`
- **FAIL** — specific criteria failed → proceed to Phase 5 with failure details
- **PARTIAL** — some criteria met, some failed → proceed to Phase 5 with partial results

### Phase 5 — ITERATE

Decide what happens next.

```
if PASS:
    → CONVERGED. Stop. Report success.

if iteration >= max-iterations:
    → STOPPED_AT_LIMIT. Stop. Report what's done and what's not.

if mode is "checkpointed":
    → PAUSED_FOR_HUMAN. Stop. Present results and ask.

if mode is "hybrid" and FAIL:
    → PAUSED_FOR_HUMAN. Stop. Present failure and ask.

else:
    → ITERATING. Feed failure details back into Phase 2.
      Use escalating context for the next attempt.
```

## Operating modes

The calling skill declares one of three modes:

| Mode | Behaviour |
|---|---|
| `autonomous` | Runs to completion or limit. No human pauses between iterations. Use for fully automated loops with hard gates (test suites, linters). |
| `checkpointed` | Pauses after every iteration for human review. Use for high-stakes work where every change needs approval. |
| `hybrid` | Runs autonomously on success; pauses on failure or limit. Use for most real-world loops — let it fly when things work, stop when they don't. |

Default: `hybrid`.

## Escalating context

A retry that gets the same context as attempt 1 will produce the same mistake. Each attempt gets a progressively narrower, deeper view:

| Attempt | Context provided to the retrying agent |
|---|---|
| 1 (initial) | Full context from the calling skill — goal, inputs, all supporting material |
| 2 (first retry) | The specific failure + files changed in attempt 1 + one-paragraph summary of what attempt 1 tried. **Not** the full context — narrow the focus. |
| 3 (second retry) | Attempt-2 context + full failure traces + a root-cause summary of what both prior attempts tried and why each failed. |
| 4+ | Stop. The problem is upstream — surface it to the human or the calling skill. |

This pattern applies universally. The calling skill can override it by setting `escalation: custom` in its loop config and defining its own context strategy.

## State tracking

Every iteration is logged as one JSON line in `loop-state.jsonl`, persisted in the calling skill's state directory:

```jsonl
{"iteration":1,"phase":"VERIFY","result":"FAIL","criteria_met":["C1","C3"],"criteria_failed":["C2"],"summary":"Attempt 1: implemented auth middleware but missed tenant isolation check on the /invoices endpoint.","timestamp":"2025-06-21T19:30:00Z"}
{"iteration":2,"phase":"VERIFY","result":"FAIL","criteria_met":["C1","C2","C3"],"criteria_failed":["C4"],"summary":"Attempt 2: fixed tenant isolation. New failure: missing rate limit on bulk export.","timestamp":"2025-06-21T19:35:00Z"}
{"iteration":3,"phase":"VERIFY","result":"PASS","criteria_met":["C1","C2","C3","C4"],"criteria_failed":[],"summary":"Attempt 3: added rate limiter. All criteria pass.","timestamp":"2025-06-21T19:40:00Z"}
```

This lets:
- The loop **resume** if the session is interrupted (read the last entry, continue from there)
- The loop **learn** from prior attempts (each iteration sees what failed before)
- The calling skill **report** iteration history at its checkpoint

## Stop conditions

Every loop has exactly two ways to stop:

1. **Success** — the verifier gate passes all criteria
2. **Hard limit** — `max-iterations` reached

A loop with no exit runs until it succeeds, breaks, or drains your budget. The engine enforces both stops; the calling skill cannot override the hard limit.

When a hard limit is reached:
- Log the final state
- Report what's done and what's still failing
- If mode is `autonomous`: return `STOPPED_AT_LIMIT` to the calling skill
- If mode is `hybrid` or `checkpointed`: pause for human decision

## Cost awareness

Loops compound cost. Every iteration re-reads context, and the context grows each pass.

The engine tracks:
- **Iteration count** — how many times around the loop
- **Context growth** — whether each iteration's input is larger than the last
- **Progress rate** — are new criteria being met, or is the loop spinning?

Warning signals (surfaced in the state log):
- 3 iterations with no new criteria met → warn: "Loop is not making progress"
- Context growing by >50% per iteration → warn: "Context is compounding — consider narrowing scope"

The calling skill can optionally set `token-budget` as advisory guidance. The engine cannot enforce a hard token cap (it runs as agent instructions, not runtime code), but it logs the warning so the agent and user are aware.

## Learning directory integration

If the calling skill defines `learning.read-from` and `learning.write-to` paths:

- **On DISCOVER**: read cached patterns, selectors, and past failures
- **On CONVERGED or STOPPED_AT_LIMIT**: append new patterns or failures discovered during this run

This is the fast, project-local feedback path. Hub-level improvements go through the [drift loop](../diagrams/03-drift-loop.md).

## Inputs

The calling skill provides:

| Input | Required | Description |
|---|---|---|
| `goal` | Yes | What the loop is trying to achieve |
| `success-criteria` | Yes | Numbered list of criteria the verifier checks |
| `verifier` | Yes | How to check: `command`, `agent`, or `rubric` |
| `max-iterations` | Yes | Hard stop (recommended: 3 for most loops) |
| `mode` | No | `autonomous`, `checkpointed`, or `hybrid` (default: `hybrid`) |
| `state-dir` | Yes | Where to persist `loop-state.jsonl` |
| `escalation` | No | `standard` or `custom` (default: `standard`) |
| `token-budget` | No | Advisory token limit for the full loop run |
| `learning.read-from` | No | Path to learning directory to read |
| `learning.write-to` | No | Path to learning directory to write |

## Output contract

The loop engine returns one of three results:

### CONVERGED

All success criteria met. Includes:
- Total iterations taken
- Per-criterion status (all PASS)
- Summary of what changed across all iterations
- Duration (first iteration timestamp to last)

### STOPPED_AT_LIMIT

Max iterations reached without full success. Includes:
- Criteria that passed
- Criteria that still fail (with the last failure detail)
- Summary of all attempts and what each tried
- Recommendation: is the problem upstream (goal/criteria wrong) or downstream (implementation)?

### PAUSED_FOR_HUMAN

The loop hit a checkpoint that requires human input. Includes:
- Current iteration number
- What just happened (last phase completed)
- What the loop would do next if allowed to continue
- The specific question for the human

## What this skill does NOT do

- Execute work itself — it delegates to the calling skill's agents
- Override the calling skill's checkpoints — if the calling skill has non-negotiable human gates, those are in addition to the loop engine's mode
- Run as background code — it's agent instructions, not a daemon
- Guarantee convergence — some problems genuinely can't be solved by iteration; that's what the hard limit is for
- Skip the verifier — no verification, no loop; it's just an agent agreeing with itself

## Integration pattern

A calling skill invokes the loop engine by following this protocol in its own SKILL.md:

```markdown
### Step N — [step name]

**Loop: invoke loop-engine protocol.**

- Goal: [what this step achieves]
- Success criteria:
  1. [criterion 1]
  2. [criterion 2]
- Verifier: [command | agent | rubric] — [details]
- Max iterations: [N]
- Mode: [autonomous | checkpointed | hybrid]
- On CONVERGED: proceed to Step N+1
- On STOPPED_AT_LIMIT: [what to do — pause, escalate, skip]
- On PAUSED_FOR_HUMAN: [what to present to the user]
```

See [feature-factory](../feature-factory/SKILL.md) for a working example with 5 loop integration points.

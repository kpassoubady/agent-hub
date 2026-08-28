# Loop Guide

A practical guide to building and extending loops in the agent hub. Start here if you want to understand when loops help, how the loop engine works, and how to build your own loop-aware skill.

## What is a loop?

A prompt gives you one answer and waits. A loop runs the full cycle on its own:

```
DISCOVER → PLAN → EXECUTE → VERIFY → ITERATE
```

You define a goal, success criteria, and a hard limit. The AI iterates until the criteria are met or the limit is reached.

The difference from a single prompt: **a loop has a gate**. Something objectively checks the result on every pass. Without a gate, you have an agent agreeing with itself on repeat.

## Do you even need one?

A loop is worth building only when **all four** of these are true:

| # | Test | Why it matters |
|---|---|---|
| 1 | The task repeats — at least within a single run | Otherwise a one-shot is cheaper |
| 2 | Something can automatically reject bad output | Tests, linters, type checks, hard rules |
| 3 | The agent can do the work end-to-end | If it hands half back to you, it's not a loop |
| 4 | "Done" is objective, not a judgment call | If quality is taste, a human still wins |

Miss one box: keep it as a single-pass agent call. Loops are powerful, but they compound cost.

## The loop engine

The hub provides a generic [loop-engine skill](../skills/loop-engine/SKILL.md) that any other skill can invoke. It handles:

- **State tracking**: every iteration is logged to `loop-state.jsonl` **the moment that iteration's VERIFY result is known** — append-only-at-transition, not batched at the end of the run. A real run once had six iterations sharing one timestamp because the file was written retroactively; a crash mid-run would have lost the entire retry history the file exists to preserve. A repeated timestamp across consecutive entries is a defect in the calling skill's integration, not a cosmetic detail.
- **Escalating context**: each retry gets a progressively narrower, deeper view so the same mistake is not repeated
- **Stop conditions**: success gate passes, or max iterations reached — a loop with no exit runs until it drains your budget
- **Cost awareness**: warns when the loop is spinning (no progress) or compounding (context growing faster than it's solving)
- **Three operating modes**: autonomous (no pauses), checkpointed (pause every iteration), hybrid (pause on failure)

### The five phases

Every iteration runs in this order:

```
1. DISCOVER — read the goal, prior state, learning from past runs
2. PLAN     — decide the single next action
3. EXECUTE  — do the work (delegated to the calling skill's agent)
4. VERIFY   — check against success criteria (the gate)
5. ITERATE  — decide: done, retry with escalation, or stop at limit
```

### Three results

| Result | Meaning |
|---|---|
| `CONVERGED` | All success criteria met. The loop is done. |
| `STOPPED_AT_LIMIT` | Max iterations reached. Some criteria still failing. |
| `PAUSED_FOR_HUMAN` | The loop needs human input before continuing. |

## Building a loop-aware skill

### Step 1 — Get one manual run reliable first

Before adding a loop, make sure the underlying agent can do the work in a single pass. If it can't succeed once, iteration won't save it.

### Step 2 — Define clear success criteria

Every criterion must be **objectively verifiable**. "Code is clean" is not a criterion. "All tests pass, lint has zero warnings, type checker reports zero errors" is.

### Step 3 — Choose a verifier

| Verifier type | When to use | Example |
|---|---|---|
| `command` | The criterion has a hard test | `npm test`, `npx tsc --noEmit`, `npm run lint` |
| `agent` | The criterion needs code analysis but no judgment | validator agent checking for scope drift |
| `rubric` | The criterion is qualitative but scorable | "Score readability 1–10; must be 8+" |

**The verifier must be separate from the executor.** The agent that did the work is too generous grading its own output.

### Step 4 — Use the template

Start from [templates/loop-template.md](../templates/loop-template.md). Fill in:

1. **Frontmatter**: name, description, and the `loop:` config block
2. **Goal**: what the loop achieves
3. **Success criteria**: numbered, verifiable
4. **Steps**: each step that needs iteration references the loop-engine protocol
5. **Loop control**: max iterations per step, and what happens at each limit
6. **State**: where intermediate outputs persist

### Step 5 — Declare the loop in each step

At each step that needs iteration, add the loop-engine invocation block:

```markdown
**Loop: invoke loop-engine protocol.**

- Goal: [specific to this step]
- Success criteria:
  1. [criterion 1]
  2. [criterion 2]
- Verifier: command — `npm test`
- Max iterations: 3
- Mode: hybrid
- On CONVERGED: proceed to next step
- On STOPPED_AT_LIMIT: pause and ask the user
- On PAUSED_FOR_HUMAN: present failure details
```

### Step 6 — Add a learning directory (optional)

If the skill runs repeatedly against the same project, a learning directory prevents repeat mistakes:

```yaml
learning:
  read-from: "{project}/.claude/{skill-name}/learning/"
  write-to: "{project}/.claude/{skill-name}/learning/"
```

Agents read cached patterns at the start and write new findings at the end. The learning directory is per-project, not per-run.

## Extending for a specific project

The loop engine and its configuration are **generic by design**. To adapt for a specific project:

### Override the verifier

In `.agenthub-config.yaml`, set project-specific test commands:

```yaml
backend:
  test-command: "pytest tests/ -v"
  lint-command: "ruff check src/"
test:
  command: "npx playwright test"
```

The loop engine's `command` verifier reads these.

### Add project-specific success criteria

The calling skill defines criteria, not the loop engine. For a specific project, fork the skill template and add project-relevant criteria:

```markdown
- Success criteria:
  1. All tests pass (`pytest tests/ -v`)
  2. Ruff reports zero errors
  3. MyPy type-checks cleanly
  4. Coverage does not drop below 80%
```

### Customize escalation

Set `escalation: custom` in the loop config and define your own context strategy in the skill's steps. The standard escalation (full → narrow → root-cause → stop) works for most cases.

### Set a mode per step

Different steps in the same skill can use different modes:

- Research loops: `autonomous` (let it iterate on its own)
- Build loops with test gates: `hybrid` (fly when tests pass, stop on failure)
- User-facing deliverables: `checkpointed` (every iteration needs approval)

## Examples: feature-factory loops

The [feature-factory](../skills/feature-factory/SKILL.md) has 5 loop integration points. Here's how each maps to the loop engine:

### 1. Story checkpoint revisions

```
Goal:      User approves the story
Verifier:  Human approval (mode: checkpointed)
Max:       3 iterations
On limit:  "Is the feature well-defined enough to proceed?"
```

### 2. Spec checkpoint revisions

```
Goal:      User approves the technical brief
Verifier:  Human approval (mode: checkpointed)
Max:       3 iterations
On limit:  "Does the story need to be revised?"
```

### 3. Backend ↔ frontend handoff

```
Goal:      Frontend-builder accepts the API contract
Verifier:  Frontend-builder's feedback (mode: hybrid)
Max:       3 round trips
On limit:  "The brief's API design is likely wrong"
```

### 4. Test failure → builder fix

```
Goal:      Failing acceptance criterion passes
Verifier:  Test-verifier re-run (mode: autonomous)
Max:       3 fix attempts per criterion
On limit:  "The brief or the criterion is likely wrong"
```

### 5. Validator critical → builder fix

```
Goal:      No Critical findings remain
Verifier:  Validator re-run (mode: autonomous)
Max:       3 fix attempts
On limit:  "Something fundamental is off"
```

## Cost awareness

Loops compound cost. Every iteration re-reads context, and context grows each pass.

### The metric that matters

**Cost per accepted change.** Not tokens spent, not loops run. If the loop gives you 10 results and you toss 6, you are doing the review work it was meant to save.

### The "Ralph Wiggum loop"

The agent decides it's done too early, exits on a half-finished job, and the loop keeps running and billing while producing nothing. Without a hard gate that can fail the work, loops don't crash — they bill you in silence.

Prevention: always have a verifier. Always have a hard limit.

### The compounding trap

A loop that runs 10 times doesn't cost 10 prompts. It costs 10 prompts that each keep getting bigger. The maker-and-checker pattern that lifts quality doubles the bill.

Prevention: the loop engine warns when context growth outpaces progress.

## The order that works

If you're building a new loop from scratch:

1. **Get ONE manual run reliable first.** Prove the agent can do the work once.
2. **Turn that into a skill.** Save the instructions so the loop reads them by name.
3. **Wrap the skill in a loop.** Add the gate and stop condition.
4. **THEN put it on a schedule** (if applicable).

Skipping ahead — scheduling something you haven't made reliable by hand — is exactly how loops run all night for nothing.

---
name: <skill-name>
version: 0.1.0
hub-source: agent-hub
description: <one-sentence description of what the skill does>
loop:
  max-iterations: <N>
  mode: <autonomous | checkpointed | hybrid>
  verifier:
    type: <command | agent | rubric>
    command: "<shell command>"        # if type: command
    # agent: "<agent-name>"          # if type: agent
    # rubric:                        # if type: rubric
    #   - "<criterion 1>"
    #   - "<criterion 2>"
  escalation: standard
  state-dir: "{project}/.claude/<skill-name>/{run-id}/"
---

# <Skill Name>

<One paragraph: what this skill does and why it needs iteration.>

## When to use

<When should someone invoke this skill? What's the trigger?>

**Do not use this skill for:**
- <Anti-use-case 1>
- <Anti-use-case 2>

## Goal

<What is the loop trying to achieve? Be specific — this is the target the verifier checks against.>

## Success criteria

The loop converges when **all** of these are true:

1. <Criterion 1 — must be objectively verifiable>
2. <Criterion 2>
3. <Criterion 3>

## Agents used

| Agent | Role in the loop | Phase |
|---|---|---|
| <agent-name> | <what it does> | EXECUTE |
| <verifier-agent> | <what it checks> | VERIFY |

## The loop

### Step 1 — <step name>

<What happens in this step.>

**Loop: invoke loop-engine protocol.**

- Goal: <what this step achieves>
- Success criteria:
  1. <criterion 1>
  2. <criterion 2>
- Verifier: <command | agent | rubric> — <details>
- Max iterations: <N>
- Mode: <autonomous | checkpointed | hybrid>
- On CONVERGED: proceed to Step 2
- On STOPPED_AT_LIMIT: <what to do — pause, escalate, skip>
- On PAUSED_FOR_HUMAN: <what to present to the user>

### Step 2 — <step name>

<Repeat the pattern for each step that needs iteration.>

## Loop control

Hard limits to prevent thrashing:

| Step | Max iterations | Action when exceeded |
|---|---|---|
| <step 1> | <N> | <what happens> |
| <step 2> | <N> | <what happens> |

When a limit hits, do not push past it. Stop and surface the question to the user.

## State

All intermediate outputs persist under `<state-dir>`:

```
loop-state.jsonl         (iteration log — managed by loop-engine)
<step-1-output>.md
<step-2-output>.md
```

This lets the loop resume cleanly if the session is interrupted. On resume: read `loop-state.jsonl`, identify the last completed phase, continue from there.

## Learning directory (optional)

If `<project>/.claude/<skill-name>/learning/` exists:

| File | Owner | Use |
|---|---|---|
| `patterns.md` | <agent> | <what it caches> |
| `failures.md` | <agent> | <what it records> |

## What this skill does NOT do

- <Hard constraint 1>
- <Hard constraint 2>
- Skip the verifier — no verification, no loop

## Failure modes

- **<Failure 1>.** <What happens.>
- **<Failure 2>.** <What happens.>

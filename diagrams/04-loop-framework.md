# The Loop Framework

The generic loop lifecycle that powers iterative work across the hub. Any skill that needs retry logic, verification gates, or goal-directed iteration follows this protocol.

> **v0.3.0** — introduced as a first-class building block alongside the factory chain and drift loop.

```mermaid
flowchart TD
    Goal["Goal + Success Criteria\n(from calling skill)"]
    Goal --> D["Phase 1 — DISCOVER\nread goal · prior state · learning"]

    D --> P["Phase 2 — PLAN\ndecide single next action"]
    P --> E["Phase 3 — EXECUTE\nagent performs the work"]
    E --> V{"Phase 4 — VERIFY\ngate: test · agent · rubric"}

    V ==>|"PASS\n(all criteria met)"| Conv["CONVERGED\nstop · report success"]
    V -->|"FAIL\n(criteria failed)"| Decide{"Phase 5 — ITERATE\ncheck mode + limits"}

    Decide -->|"mode: autonomous\nunder limit"| Esc["Escalate context\n(narrow → deeper)"]
    Decide -->|"mode: hybrid\nfailure"| Pause1["PAUSED_FOR_HUMAN\npresent failure · ask"]
    Decide -->|"mode: checkpointed"| Pause2["PAUSED_FOR_HUMAN\npresent result · ask"]
    Decide -->|"at max-iterations"| Limit["STOPPED_AT_LIMIT\nreport · recommend"]

    Esc --> P
    Pause1 -.->|"user: continue"| Esc
    Pause1 -.->|"user: stop"| Limit
    Pause2 -.->|"user: continue"| P
    Pause2 -.->|"user: stop"| Limit

    State[("loop-state.jsonl\niteration log")] -.-> D
    E -.-> State
    V -.-> State

    Learn[("learning/\npatterns · failures")] -.-> D
    Conv -.-> Learn
    Limit -.-> Learn

    style Goal fill:#f5f5f5,stroke:#666,color:#000
    style D fill:#e1f5ff,stroke:#0366d6,color:#000
    style P fill:#e1f5ff,stroke:#0366d6,color:#000
    style E fill:#e1f5ff,stroke:#0366d6,color:#000
    style V fill:#fff3cd,stroke:#d4a017,color:#000
    style Decide fill:#fff3cd,stroke:#d4a017,color:#000
    style Conv fill:#d4edda,stroke:#28a745,color:#000
    style Limit fill:#f8d7da,stroke:#dc3545,color:#000
    style Pause1 fill:#fff3cd,stroke:#d4a017,color:#000
    style Pause2 fill:#fff3cd,stroke:#d4a017,color:#000
    style Esc fill:#e1f5ff,stroke:#0366d6,color:#000
    style State fill:#f0e6ff,stroke:#7c3aed,color:#000
    style Learn fill:#f0e6ff,stroke:#7c3aed,color:#000
```

## The five phases

| Phase | What happens | Who does it |
|---|---|---|
| **DISCOVER** | Read the goal, prior state, and learning directory | Loop engine |
| **PLAN** | Decide the single next action | Calling skill's agent |
| **EXECUTE** | Perform the work | Calling skill's agent |
| **VERIFY** | Check against success criteria (the gate) | Verifier (test / agent / rubric) |
| **ITERATE** | Decide: done, retry with escalation, or stop at limit | Loop engine |

## Three operating modes

| Mode | When it pauses | Best for |
|---|---|---|
| `autonomous` | Only at limit | Fully automated loops with hard gates (test suites, linters) |
| `checkpointed` | Every iteration | High-stakes work where every change needs human approval |
| `hybrid` (default) | On failure or limit | Most real-world loops — fly when things work, stop when they don't |

## Escalating context

Each retry gets a progressively narrower, deeper view so the same mistake is not repeated:

```mermaid
flowchart LR
    A1["Attempt 1\nfull context"]
    A2["Attempt 2\nnarrow: failure + changes + summary"]
    A3["Attempt 3\ndeep: prior context + traces + root cause"]
    A4["Attempt 4+\nSTOP — problem is upstream"]

    A1 -->|FAIL| A2
    A2 -->|FAIL| A3
    A3 -->|FAIL| A4

    style A1 fill:#e1f5ff,stroke:#0366d6,color:#000
    style A2 fill:#fff3cd,stroke:#d4a017,color:#000
    style A3 fill:#f8d7da,stroke:#dc3545,color:#000
    style A4 fill:#f5f5f5,stroke:#999,color:#000
```

## State persistence

Every iteration is logged as one JSON line in `loop-state.jsonl`:

```jsonl
{"iteration":1,"result":"FAIL","criteria_met":["C1"],"criteria_failed":["C2","C3"],"summary":"..."}
{"iteration":2,"result":"FAIL","criteria_met":["C1","C2"],"criteria_failed":["C3"],"summary":"..."}
{"iteration":3,"result":"PASS","criteria_met":["C1","C2","C3"],"criteria_failed":[],"summary":"..."}
```

This enables **resume** (pick up after interruption), **learning** (each iteration sees what failed before), and **reporting** (calling skill shows iteration history at its checkpoint).

## Cost awareness

Loops compound cost. The engine warns when:
- 3+ iterations with no new criteria met (spinning)
- Context growing >50% per iteration (compounding)

The key metric: **cost per accepted change**, not tokens spent or loops run.

## How the feature-factory uses this

The [feature-factory](../skills/feature-factory/SKILL.md) invokes the loop-engine protocol at 5 points:

| Loop point | Verifier | Max | Mode |
|---|---|---|---|
| Story checkpoint revisions | Human approval | 3 | checkpointed |
| Spec checkpoint revisions | Human approval | 3 | checkpointed |
| Backend ↔ frontend handoff | Frontend-builder feedback | 3 | hybrid |
| Test failure → builder fix | Test-verifier re-run | 3 | autonomous |
| Validator critical → builder fix | Validator re-run | 3 | autonomous |

See [01-factory-chain.md](01-factory-chain.md) for the full chain diagram with loop-back arrows.

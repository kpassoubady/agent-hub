# Run Feedback

Mechanical, never self-graded: a completed run's own artifacts feed a fixed check table, which fans into a per-run scorecard shown inline at the checkpoint, and zero or more hub-change proposals filed to an inbox nobody has to remember to open.

> **v0.13.0** — introduced alongside the `run-feedback` skill and `run-feedback-analyzer` agent (item 8 of the run retrospective's recommended sequence). Explicitly stops at the producer side — `hub-improve`, the inbox consumer, is not built yet and is drawn below as a distinct, dashed shape so it is never mistaken for shipped behaviour.

## Flow

```mermaid
flowchart TD
    T1["feature-factory Step 7\n(before Checkpoint 3)"]
    T2["adaptive-engine Phase 3\n(before Checkpoint 2,\nonly if a validator node ran)"]
    T3["standalone\n/run-feedback &lt;state-dir&gt;"]

    T1 --> Artifacts
    T2 --> Artifacts
    T3 --> Artifacts

    Artifacts["Run's own artifacts\n07-validator.md · loop-state.jsonl\nbuilder summaries · git diff/log"]
    Artifacts --> Checks["run-feedback-analyzer\nmechanical checks only\n(grep / count / diff — never a score)"]

    Checks --> PartA["Part A — scorecard\n~600-word cap\none row per check"]
    Checks --> PartB["Part B — hub change proposals\nF-00N, each with a\nmandatory Counter-argument"]

    PartA ==>|"shown inline"| Checkpoint["Checkpoint 3 / Checkpoint 2\nhand-off summary"]

    PartB --> HubLocal{"Hub root\ndiscoverable locally?"}
    HubLocal -->|yes| Inbox[("llm-context/feedback/inbox/\n&lt;project&gt;-&lt;slug&gt;-&lt;date&gt;.md")]
    HubLocal -->|no| CopyCmd["Print fallback:\nfile path + copy command"]

    Inbox -.->|"not yet built"| HubImprove["hub-improve\ncluster by target file,\ngate on ≥2-run recurrence"]
    HubImprove -.->|"not yet built"| HubFiles[("agents/*.md · skills/*/SKILL.md\nhuman-approved edits only")]

    style T1 fill:#e1f5ff,stroke:#0366d6,color:#000
    style T2 fill:#e1f5ff,stroke:#0366d6,color:#000
    style T3 fill:#e1f5ff,stroke:#0366d6,color:#000
    style Artifacts fill:#f5f5f5,stroke:#666,color:#000
    style Checks fill:#d4edda,stroke:#28a745,color:#000
    style PartA fill:#d4edda,stroke:#28a745,color:#000
    style PartB fill:#d4edda,stroke:#28a745,color:#000
    style Checkpoint fill:#fff3cd,stroke:#d4a017,color:#000
    style HubLocal fill:#fff3cd,stroke:#d4a017,color:#000
    style Inbox fill:#f0e6ff,stroke:#7c3aed,color:#000
    style CopyCmd fill:#f5f5f5,stroke:#666,color:#000
    style HubImprove fill:#eeeeee,stroke:#999,color:#666,stroke-dasharray: 5 5
    style HubFiles fill:#eeeeee,stroke:#999,color:#666,stroke-dasharray: 5 5
```

Grey, dashed nodes (`hub-improve`, the human-approved hub-file edit) are **not yet built**. Nothing today reads the inbox or auto-edits an `agents/*.md` or `skills/*/SKILL.md` file — a human reads Part A at the checkpoint and Part B's entries in the inbox, and a human decides what happens next.

## Why mechanical only

Every box under "mechanical checks" reduces to a `grep`, a count, or a diff — never a self-assessed quality score. This is the same rule `loop-engine` enforces for its own verifiers (the agent that did the work is too generous grading its own output), applied one layer up: `run-feedback` never lets the chain's own agents vouch for each other's work through a new file. See [docs/run-feedback-guide.md](../docs/run-feedback-guide.md) for the full check table and the reasoning.

## Two triggers, one skip condition

| Trigger | Gate |
|---|---|
| `feature-factory` Step 7 | Always runs, immediately before Checkpoint 3 |
| `adaptive-engine` Phase 3 | Runs only if the graph included a validator node — several checks read `07-validator.md`'s coverage report and have nothing to check without one |
| Standalone `/run-feedback <state-dir>` | Requires `07-validator.md` (or the graph-engine equivalent) already present |

## See also

- [docs/run-feedback-guide.md](../docs/run-feedback-guide.md) — full guide: the problem it solves, the check table explained, the output contract, and the "where this is headed" arc
- [agents/run-feedback-analyzer.md](../agents/run-feedback-analyzer.md) — the agent
- [skills/run-feedback/SKILL.md](../skills/run-feedback/SKILL.md) — the orchestrating skill
- [01-factory-chain.md](01-factory-chain.md) — Step 7's hand-off, where this folds in for `feature-factory`

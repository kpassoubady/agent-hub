# Adaptive Engine Architecture

```mermaid
flowchart TD
    Start([User Request: /adaptive-engine]) --> Planner(Planner Agent)

    subgraph "Phase 1: Planning (extra gates only)"
        Planner -->|Reads| ClaudeMD(CLAUDE.md)
        Planner -->|Analyzes| Gates{Extra structure needed?}
        Gates -->|None| Recommend[Recommend plain /feature-factory]
        Gates -->|Pre/post gates| GraphA["graph.json: pre-gate(s) + feature-factory-chain + post-gate(s)"]

        GraphA --> PlanApproval{Checkpoint 1: Plan Approval}
    end

    Recommend --> End2([Stop — hand off to /feature-factory])
    PlanApproval -->|Approved| Phase2
    PlanApproval -->|Rejected/Feedback| Planner

    subgraph "Phase 2: Execution via Graph Engine"
        Phase2(Graph Engine reads graph.json) --> PreGate[Pre-gate node(s)<br/>must pass first]
        PreGate --> Chain["feature-factory-chain<br/>(single opaque node —<br/>runs feature-factory unmodified,<br/>own checkpoints included)"]
        Chain --> PostGate[Post-gate node(s)]
    end

    PostGate --> HandOff{Checkpoint 2: Hand-off}
    HandOff --> End([Ready for PR])

    style Start fill:#234,stroke:#333,stroke-width:2px,color:#fff
    style End fill:#234,stroke:#333,stroke-width:2px,color:#fff
    style End2 fill:#234,stroke:#333,stroke-width:2px,color:#fff
    style PlanApproval fill:#d42,stroke:#333,stroke-width:2px,color:#fff
    style HandOff fill:#d42,stroke:#333,stroke-width:2px,color:#fff
    style Chain fill:#264,stroke:#333,stroke-width:2px,color:#fff
```

`feature-factory-chain` is never expanded into its own 7 agents in this graph — it is one node that delegates to the `feature-factory` skill wholesale, including that skill's own three checkpoints. Only the extra pre-gate and post-gate nodes are genuinely new structure. The common case is zero extra gates, ending at "Recommend plain /feature-factory" before Phase 2 ever runs.

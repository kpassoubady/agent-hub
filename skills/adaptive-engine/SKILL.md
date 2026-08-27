---
name: adaptive-engine
version: 1.1.0
hub-source: agent-hub
description: Dynamically generates and executes a custom workflow graph for a feature request using a planner agent.
---

# Adaptive Engine

The Adaptive Engine acts as a dynamic orchestration layer. Instead of running every feature through a fixed pipeline (like `feature-factory`), it uses a `planner` agent to analyze the request and generate a custom execution graph (`graph.json`). It then delegates the execution to the `graph-engine`.

## When to use

Invoke `/adaptive-engine <feature description>` when you want the system to intelligently decide which agents to run.
- For a simple UI typo, it might only run `frontend-builder`.
- For a complex multi-service integration, it might spawn multiple researchers and builders.
- For architectural changes, it guarantees human checkpoints at critical junctions.

**Do not use this skill for:**
- Workflows that strictly require the 7-agent pipeline (use `feature-factory` directly).
- If downstream tooling explicitly expects hardcoded `feature-factory` outputs (e.g., `07-validator.md` gating).

## Phases

### Phase 0: Config gate (blocking)

Run [feature-factory's Step 0 config gate](../feature-factory/SKILL.md#step-0--config-gate-blocking) **before spawning the planner**, and write `00-config-resolved.md` into this skill's state directory.

Same three outcomes: missing → generate a candidate with `agent-hub-detect.sh -d`, show it, require accept/edit/abort; invalid → fail with every offending key; valid → bind it. The planner reads `00-config-resolved.md`, never the raw YAML.

The planner cannot make a sound graph without this. A graph built on an assumed `full-stack` shape plans builders the project may not have, and every node it emits inherits the wrong test commands.

### Phase 1: Planning (The Planner Agent)
Spawn the `planner` agent.
- **Inputs:** The user's feature description + project `CLAUDE.md`.
- **Output:** A `graph.json` defining the execution nodes, edges, parallel branches, and reality anchors, plus a short markdown explanation of the plan (`00-plan-summary.md`).

**🛑 CHECKPOINT 1: Plan Approval**
Show the user the generated `00-plan-summary.md` and the `graph.json` structure.
Ask: approve, request changes, or reject?
- Rejected: Stop. Ask what to do next.
- Request changes: Pass feedback back to the `planner` to regenerate the graph.
- Approved: Add `STATUS: APPROVED` to the plan and proceed to Phase 2.

### Phase 2: Execution (Graph Engine)
Pass the approved `graph.json` to the `graph-engine` protocol.
The `graph-engine` handles all execution, concurrent fan-outs, and fan-in reconciliations according to the dynamically generated configuration.

### Phase 3: Hand-off
**🛑 CHECKPOINT 2: Final Review**
Once the graph execution concludes (as indicated by the terminal node in `graph.json`), summarize the results for the user:
- The graph execution state (`graph-state.json` status).
- Files changed and tests run.
- Validator findings (if the graph included a validator node).

The human handles the PR creation.

## Graph Constraints

The `planner` is strictly instructed to ensure:
- **Reality Anchors:** Every generated graph must contain at least one reality anchor (e.g., `test-verifier`).
- **Safety Checkpoints:** Any graph involving significant architectural or cross-component changes must insert a human approval node (e.g., a `spec-writer` brief checkpoint) before building begins.

## State

All intermediate outputs persist under `<project>/.claude/adaptive-engine/<feature-slug>/`:

```
00-config-resolved.md  (Phase 0 gate output — binding config)
00-plan-summary.md
graph.json
graph-state.json (managed by graph-engine)
[dynamically generated node outputs]
```

### Slug derivation must be deterministic

`<feature-slug>` uses **the same rule as feature-factory**: the feature description lowercased, slugified, truncated to 40 chars. Nothing else.

Do not invent a prettier or shorter slug, and do not prefix it (`story-2-…`). Before planning, check whether `<project>/.claude/adaptive-engine/<feature-slug>/` or `<project>/.claude/feature-factory/<feature-slug>/` already exists; if so, resume it rather than planning a second time.

This is a real failure the hub has shipped: one story was planned twice, two minutes apart, under two different slugs, producing two mutually incompatible graph schemas — and neither matched the feature-factory directory that actually held the work, forcing a hardcoded cross-directory pointer. The orphan directory had no state file, so under the graph's own resume policy it was neither resumable nor collectable.

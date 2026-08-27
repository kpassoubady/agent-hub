# Adaptive Engine Guide

The **Adaptive Engine** (`skills/adaptive-engine/SKILL.md`) is a dynamic orchestration skill designed as a flexible alternative to the fixed 7-agent pipeline used by `feature-factory`.

Instead of running every feature through a rigid sequence of agents, the Adaptive Engine uses a **Planner Agent** to analyze the request and dynamically construct the optimal execution graph on the fly. 

## Visual Overview

See the full diagram: [Adaptive Engine Architecture](../diagrams/06-adaptive-engine.md)

## Why use the Adaptive Engine?

1. **Efficiency for Small Changes:** Not every feature needs a `story-writer` and extensive research. For a simple UI text change, the planner can generate a graph that only invokes `frontend-builder` and `test-verifier`.
2. **Safety for Large Changes:** For significant architectural work, the planner will enforce a `spec-writer` checkpoint to ensure the human reviews the technical brief before any code is written.
3. **Dynamic Parallelization:** The planner can orchestrate complex swarms, spawning multiple builders depending on the scope of the project.

## How it works

The engine operates in three distinct phases:

### Phase 1: Planning
The user triggers the process with `/adaptive-engine <feature description>`. The `planner` agent is spawned. It reads the project's `CLAUDE.md` and the feature description, then emits a `graph.json` defining the execution nodes (agents) and edges (how they connect).

Crucially, this phase ends with **Checkpoint 1**. The user is shown the proposed plan (`00-plan-summary.md`) and must approve it before execution begins. If the planner has missed a step or over-complicated a simple task, the user can request changes here.

### Phase 2: Execution
Once approved, the `graph.json` is handed off to the standard [graph-engine](./graph-guide.md). The graph engine manages parallel fan-outs, sequential dependencies, and fan-in reconciliations just as it does in `feature-factory`, but across the dynamically defined topology.

Every generated graph must include at least one **reality anchor** (e.g., the `test-verifier` agent) to ensure LLM assumptions are tested against real-world execution.

### Phase 3: Hand-off
Once the execution graph terminates, the user is presented with **Checkpoint 2**. The engine summarizes the modified files, test results, and any open validator findings, handing off the code for the human to create a Pull Request.

## Integration with existing tools
The Adaptive Engine is designed to sit alongside `feature-factory` rather than overwrite it. Existing tools and scripts (such as `bookbuilder`'s `/ship-feature`) that expect the strict output constraints of `feature-factory` (e.g., `07-validator.md`) can continue using the fixed factory, while newer or ad-hoc workflows can utilize the Adaptive Engine for speed and flexibility.

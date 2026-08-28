# Adaptive Engine Guide

The **Adaptive Engine** (`skills/adaptive-engine/SKILL.md`) is a thin wrapper around `feature-factory`'s fixed 7-agent pipeline, not an alternative to it. It exists for the rare feature that needs genuinely extra structure the fixed chain has no slot for — a precondition gate before building starts, or an independent verification pass after the chain's own hand-off.

Earlier versions of this skill had the `planner` agent re-derive the whole 7-agent pipeline into a custom graph. In practice this produced an 18-node graph where 14 nodes just re-encoded steps `feature-factory` already runs — at the cost of a full planning pass and a checkpoint — while the genuinely new nodes never executed. See `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §5 for the retrospective that motivated the redesign.

## Visual Overview

See the full diagram: [Adaptive Engine Architecture](../diagrams/06-adaptive-engine.md)

## Why use the Adaptive Engine?

Only when the feature has structure `feature-factory` alone cannot express:

1. **A hard precondition.** Building cannot start until something external is true — another story's migration has landed, a service exposes an endpoint. Declared as a `pre-gate` node.
2. **An independent post-build check.** A second, differently-lensed verification after the chain's own `validator` has already run — e.g. a cold security re-read. Declared as a `post-gate` node.
3. **Genuinely independent parallel subsystems** that need to reconcile before a shared build step. Rare — feature-factory's own Step 4 fan-out already covers the common backend/frontend case.

**If none of these apply, use `/feature-factory` directly.** The planner is expected to say so in most cases — treat "recommend plain feature-factory, zero extra gates" as the normal, correct outcome, not a degenerate one.

## How it works

### Phase 0: Config gate
Same blocking config gate as `feature-factory`'s Step 0, run once and shared.

### Phase 1: Planning
The user triggers the process with `/adaptive-engine <feature description>`. The `planner` agent is spawned. It does **not** re-derive feature-factory's internal steps — it treats the entire chain as one opaque node, `feature-factory-chain`, and only decides whether to add pre-gate or post-gate nodes around it.

Checkpoint 1 shows the user `00-plan-summary.md` and the (small) `graph.json`. If the planner proposes zero extra gates, the orchestrator stops here and hands off to plain `/feature-factory` rather than running a one-node graph through Phase 2 for nothing.

### Phase 2: Execution
The approved `graph.json` is handed to the [graph-engine](./graph-guide.md). Pre-gates run and must pass before `feature-factory-chain` starts; `feature-factory-chain` executes by invoking the `feature-factory` skill unmodified (its own three checkpoints run exactly as documented); post-gates run afterward, reading that run's artifacts.

`feature-factory-chain` is itself a valid reality anchor — it contains `test-verifier` and `validator` internally — so the outer graph does not need a separate one unless a post-gate adds a stronger check.

### Phase 3: Hand-off
Checkpoint 2 shows `feature-factory-chain`'s own Checkpoint 3 summary as-is (not restated) plus each post-gate's result. The human handles PR creation, same as `feature-factory` alone.

## Shared state, not a second copy

`feature-factory-chain` runs against `<project>/.claude/feature-factory/<feature-slug>/` — the exact same slug-derivation rule feature-factory itself uses. The adaptive-engine's own state directory holds only the pre-gate/post-gate artifacts and a one-line pointer to that shared directory. This closes a real bug: an earlier run was planned twice under two different invented slugs, producing incompatible graph schemas that matched neither each other nor the feature-factory directory holding the actual work.

## Integration with existing tools

Tools that expect `feature-factory`'s strict output shape (e.g. `07-validator.md`) keep working unchanged — `feature-factory-chain` produces exactly that shape, in exactly that location, whether it was invoked directly or wrapped by the adaptive engine.

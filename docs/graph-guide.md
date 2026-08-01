# Graph Guide

A practical guide to when and how to structure a skill as a graph instead of a straight chain of loops. Start here if a skill you're building has more than one node, or if you're deciding whether `feature-factory`'s backend/frontend step should run in parallel for a given feature.

## What is a graph, and why now?

A loop is one agent iterating on itself: DISCOVER → PLAN → EXECUTE → VERIFY → ITERATE, over and over, until a gate passes. `feature-factory` already chains several of these loops together in sequence, with a few loop-back edges (test failures, validator findings, the backend↔frontend mismatch feedback path).

That chain is already a graph — it just wasn't written as one. Formalizing it matters once you want to:

- Run two independent nodes **concurrently** instead of one-after-the-other
- Route to a different next node based on a **runtime condition**, not a fixed sequence
- **Reconcile** multiple nodes' outputs before the chain continues, instead of trusting the first one that finishes

This isn't a new architecture for the hub — it's naming and formalizing the structure `feature-factory` already has, and giving new skills a reusable way to declare the same thing instead of writing bespoke fan-out prose each time. See [skills/graph-engine/SKILL.md](../skills/graph-engine/SKILL.md) for the full protocol.

## Do you even need one?

| # | Test | Why it matters |
|---|---|---|
| 1 | Two or more nodes can run without waiting on each other's actual output | Otherwise there's nothing to parallelize |
| 2 | The next node depends on a runtime condition | Otherwise a fixed sequence is simpler |
| 3 | Multiple nodes' outputs must converge before continuing | Otherwise there's no fan-in to design |
| 4 | A branch's failure should be isolated, not restart the whole chain | Otherwise a single loop-back edge is enough |

Miss all four: keep it a straight sequential chain of loops, like `feature-factory` already is for most of its steps.

## The trap: "sequential because I said so" vs. "sequential because it has to be"

The most common mistake when reaching for a graph is parallelizing a pair of nodes where the second one's documented input is literally "the first one's output":

> `frontend-builder`'s stated input used to be "Backend-builder's summary (the API contract)" — it reads the backend's summary **first** and consumes the API **as built**.

Running that "in parallel" doesn't create concurrency — it creates a frontend agent building against nothing, followed by rework once backend actually finishes. That's not a graph optimization, it's a race condition.

**The fix is not to force the parallelism — it's to find the real contract underneath.** In this case, the contract was already there: `spec-writer`'s brief has an "API changes" section that its own output contract describes as *"the contract the frontend-builder will consume verbatim."* The brief — not backend's implementation — is the thing both builders can build against independently. See [Contract-first parallelization](../skills/graph-engine/SKILL.md#contract-first-parallelization) for the general pattern, and the section below for how `feature-factory` applies it.

If you can't find an upstream contract precise enough for both sides to build against independently, don't force it — leave the edge sequential. A vague contract plus parallel execution produces divergent work and a reconciliation loop that costs more than it saved.

## Case study: feature-factory's backend/frontend step

`feature-factory` makes this configurable rather than always-parallel or always-sequential, because the deciding factor — how precise the brief's API section is — varies per feature, not per project.

| Mode | When | How it runs |
|---|---|---|
| **Sequential** (default fallback) | `spec-writer` marks the brief's API contract confidence `low`, or `.agenthub-config.yaml` sets `build.parallel-builders: never` | backend-builder runs first; frontend-builder reads backend's actual summary as the contract (today's behaviour, unchanged) |
| **Parallel** | `spec-writer` marks confidence `high` and `build.parallel-builders` is `auto` (default) or `always` | backend-builder and frontend-builder both start from the brief's "API changes" section as the contract; a fan-in **contract-check** gate compares what the brief promised, what backend actually shipped, and what frontend assumed, once both finish |

The fan-in gate is a reality anchor, not another LLM's opinion: it diffs backend's actual returned shapes (from its summary) against frontend's assumed shapes (from its summary) against the brief's promised shapes. Any mismatch routes back through the existing backend↔frontend loop-back edge (max 3 round trips, unchanged from before).

This means parallelizing is a bet on brief quality, made explicitly by the agent that wrote the brief (`spec-writer`), not a blanket architectural change. See [skills/feature-factory/SKILL.md](../skills/feature-factory/SKILL.md) Step 4 for the full logic.

## Building a graph-aware skill

### Step 1 — List the nodes and their real dependencies

For each node, write down what it actually reads as input — not what step number it happens to follow. If node B's input is "node A's live output," that's a sequential edge. If node B's input is an upstream artifact both A and B could read at the same time, that's a candidate for a fan-out.

### Step 2 — Find or create the shared contract

A parallel fan-out only works if there's a fixed, precise artifact upstream of both nodes. If it doesn't exist yet, that's a sign the graph isn't ready — go make the upstream node produce that contract explicitly (as `feature-factory` did by holding `spec-writer`'s brief to being "the contract, consumed verbatim").

### Step 3 — Design the fan-in gate

Decide, concretely:
- What does each parallel node's output need to be checked against? (the contract, each other's output, or both)
- Is the check a command (diff, schema validator), an agent (structured comparison), or a rubric?
- Where does a mismatch route? (almost always: loop-back to the node that drifted, using `loop-engine`'s escalating retry context)

### Step 4 — Add at least one reality anchor

Somewhere in the graph — ideally at the fan-in gate or the terminal edge — have a check that isn't just one LLM agreeing with another LLM's read of the same contract. A real test run, a real type-check, a human checkpoint.

### Step 5 — Declare it with graph-engine

Use [skills/graph-engine/SKILL.md](../skills/graph-engine/SKILL.md)'s inputs (`nodes`, `edges`, `contract`, `fan-in-gate`, `reality-anchor`, `state-dir`) instead of writing new fan-out prose from scratch.

### Step 6 — Prefer native dynamic workflows when available

If running in Claude Code with dynamic workflows enabled, a real fan-out node should be expressed as a `parallel()` call in a dynamic-workflow script rather than simulated by a single agent working through both nodes "in spirit." See the [graph-engine skill](../skills/graph-engine/SKILL.md#relationship-to-claude-code-dynamic-workflows) for the primitive mapping. Fall back to sequential subagent calls where dynamic workflows aren't available — the graph's structure (contract, fan-in, reality anchor) doesn't change, only how concurrency is executed.

## What graph-engine does NOT fix

Adding nodes and edges does not create independent judgment on its own. Twenty agents reading the same flawed contract and checking each other against it will agree with each other at scale, incorrectly. If every check in a fan-in is an LLM comparing another LLM's work to a contract only LLMs authored, the graph looks well-governed and is still wrong. Keep at least one non-LLM check in every graph that matters.

## See also

- [skills/graph-engine/SKILL.md](../skills/graph-engine/SKILL.md) — the protocol
- [skills/loop-engine/SKILL.md](../skills/loop-engine/SKILL.md) — what each node uses internally for retries
- [docs/loop-guide.md](loop-guide.md) — the loop equivalent of this guide
- [diagrams/05-graph-engine.md](../diagrams/05-graph-engine.md) — the fan-out/fan-in diagram, and feature-factory redrawn as an explicit graph
- [templates/graph-template.md](../templates/graph-template.md) — starting point for a new graph-aware skill

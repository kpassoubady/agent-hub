---
name: graph-engine
version: 1.0.0
hub-source: agent-hub
description: >
  Generic graph orchestration protocol for skills that need more than one loop.
  Formalizes nodes (agents/tools/checks), edges (sequential, conditional,
  parallel fan-out/fan-in, loop-back), and a shared-state contract. Delegates
  each node's retry behaviour to the loop-engine, and maps directly onto
  Claude Code's native dynamic-workflow primitives when available.
---

# Graph Engine

A loop is one node with an edge back to itself. A graph is what you need the moment a skill has more than one node — parallel work, conditional routing, or several agents whose outputs must reconcile before the chain continues. This skill formalizes that structure so orchestrating skills (like `feature-factory`) don't hand-write bespoke fan-out/fan-in logic in prose.

## When to use

A graph is worth declaring only when **any** of these is true:

1. Two or more nodes can run **concurrently** because they don't depend on each other's output
2. A node's next step depends on a **condition** evaluated at runtime (not a fixed sequence)
3. Multiple nodes' outputs must **converge** into one shared state before the chain proceeds (fan-in)
4. A failure in one branch should be **isolated** — retried or rolled back — without restarting the whole chain

If none of these apply, a single loop or a straight sequential chain is simpler and cheaper. **Do not reach for a graph to make a linear, single-dependency chain look more sophisticated.**

**Do not use this skill for:**
- A single agent doing one task (no loop needed, just call the agent)
- A single retry cycle with one verifier (use `loop-engine` directly)
- Purely sequential steps where step N always needs step N-1's actual output (there's nothing to parallelize — see "Contract-first parallelization" below for the one case that looks sequential but isn't)

## Core concepts

| Concept | What it is | Example |
|---|---|---|
| **Node** | One unit of work: an agent, a deterministic tool/script, or a gate/check | `backend-builder`, `npm test`, a human checkpoint |
| **Edge** | The routing between nodes | sequential, conditional (`if X then Y else Z`), parallel fan-out, fan-in, loop-back |
| **Shared state** | The data that crosses edges — not a transcript, a structured record | `graph-state.json` (see below) |
| **Reality anchor** | A node whose output does not come from another agent — a real test run, a real command, real human judgment | test-verifier's actual test run, a human checkpoint |

A single agent looping on itself is the smallest possible graph (one node, one self-edge — that's exactly what `loop-engine` formalizes). Graph-engine is what you reach for when you need more than one node.

## Edge types

| Edge type | Behaviour |
|---|---|
| `sequential` | Node B starts only after node A finishes and reads A's output |
| `conditional` | Router evaluates a condition against shared state and picks the next node |
| `parallel-fanout` | Two or more nodes start from the same shared-state snapshot, independently, at the same time |
| `fan-in` | A gate that waits for all nodes in a fan-out to finish, then reconciles their outputs before continuing |
| `loop-back` | A node's failure routes back to an earlier node with escalated context (delegates to `loop-engine`) |

## Contract-first parallelization

The most common reason a "sequential" pair of nodes is actually parallelizable: node B doesn't need node A's *implementation*, it needs the *contract* node A is building against — and that contract already exists upstream (written by a prior node, approved by a human, or otherwise fixed before either A or B starts).

Rule: **a fan-out is only safe when every parallel node consumes the same upstream contract, not each other's in-progress output.** If node B's inputs say "reads node A's summary," that is a sequential edge — parallelizing it means B builds against nothing.

To convert a sequential pair into a real parallel fan-out:

1. Identify the contract both nodes need (an API shape, a schema, an interface — something a human or upstream agent already approved).
2. Confirm the contract is precise enough to build against independently — if it's vague, parallelizing produces divergent guesses, not saved time.
3. Point both nodes at the **contract**, not at each other's output.
4. Add a **fan-in reconciliation gate** after both finish: diff what was promised (the contract) against what each node actually produced. Route any mismatch through a `loop-back` edge to the node that drifted.

This is not free — it trades a guaranteed-consistent sequential build for a faster, occasionally-reconciling parallel build. Use it when the contract's owner has high confidence in its precision (see `feature-factory`'s `build.parallel-builders` config for a concrete example), and fall back to sequential when it doesn't.

## Reality anchors — avoiding organized nonsense

A graph with more nodes is not automatically more correct. N agents reading the same flawed contract and checking each other's work against that same contract will agree with each other at scale — and be wrong together. This is the graph-engineering failure mode: it looks well-governed because there are reviewers everywhere, and it's still wrong.

Every graph must have at least one **reality anchor** somewhere on its fan-in or terminal edges — a node whose pass/fail does not come from another LLM agreeing with a prior LLM:

- An actual test suite run (exit code, not a model's opinion of the code)
- An actual type-checker or linter
- A human checkpoint
- A measurement from outside the agent system (a real API response, a real file diff)

If every node in a fan-in is itself an LLM judging another LLM's output against a contract only LLMs wrote, add a hard check before trusting convergence.

## Relationship to loop-engine

Graph-engine does not replace `loop-engine` — it composes it. Any single node that needs retry logic (a builder fixing a failing test, a checkpoint needing re-approval) invokes the [loop-engine protocol](../loop-engine/SKILL.md) internally. Graph-engine is responsible for:

- Which nodes can start concurrently (fan-out)
- What each node reads as its input contract
- How fan-in reconciles multiple nodes' outputs
- Which edge to take next when a condition is met

Loop-engine is responsible for what happens *inside* a node when its own verifier fails.

## Relationship to Claude Code dynamic workflows

Where available, prefer running a fan-out as a native [Claude Code dynamic workflow](https://code.claude.com/docs/en/workflows) rather than hand-simulating concurrency by writing prose instructions for a single agent to "pretend" to run two things at once:

| Graph-engine concept | Dynamic-workflow primitive |
|---|---|
| Node (agent) | `agent(prompt, opts)` |
| Parallel fan-out + fan-in barrier | `parallel(thunks)` |
| Same transform across many items | `pipeline(items, fn)` |
| Progress grouping | `phase(title)` |

If dynamic workflows aren't available (older Claude Code version, or another host like Windsurf), fall back to running fan-out nodes as sequential subagent calls with an explicit note that true concurrency isn't available in this environment — the graph structure (contract-first inputs, fan-in reconciliation, reality anchors) stays identical either way. Orchestration logic itself costs no model tokens under dynamic workflows; hand-simulated fan-out does not have that property, so treat it as a portability fallback, not the default.

## State tracking

Graph runs persist to `graph-state.json` (not a flat log like `loop-state.jsonl`, because a graph's state is a structured record of node outputs, not a linear iteration history):

```json
{
  "run-id": "feature-slug-2026-07-31",
  "nodes": {
    "spec-writer": { "status": "done", "output": "03-spec.md" },
    "backend-builder": { "status": "done", "output": "04-backend-summary.md", "started-with": "contract:03-spec.md#api-changes" },
    "frontend-builder": { "status": "done", "output": "05-frontend-summary.md", "started-with": "contract:03-spec.md#api-changes" }
  },
  "fan-in": {
    "gate": "backend-frontend-contract-check",
    "result": "MISMATCH",
    "detail": "frontend assumed `error.code`, backend returned `error.type`",
    "routed-to": "backend-builder"
  }
}
```

Each node that runs a loop internally still writes its own `loop-state.jsonl` under its step's state directory — graph-state.json records node-level status and fan-in results, not iteration-level detail.

## Inputs

The calling skill provides:

| Input | Required | Description |
|---|---|---|
| `nodes` | Yes | List of nodes (agent name, tool, or check) participating in this graph |
| `edges` | Yes | For each node, its incoming edge type and source(s) |
| `contract` | Required for any `parallel-fanout` edge | What upstream artifact the parallel nodes read instead of each other |
| `fan-in-gate` | Required for any `parallel-fanout` edge | How reconciliation is checked (command, agent diff, or rubric) and where mismatches route |
| `reality-anchor` | Recommended | At least one node in the graph whose result doesn't come from another LLM's judgment |
| `state-dir` | Yes | Where to persist `graph-state.json` |

## Failure modes

- **A "parallel" fan-out node actually needs another node's live output.** Not parallelizable — that's a sequential edge. Don't force it; downgrade to sequential.
- **Fan-in gate finds a mismatch beyond the loop-back limit.** Stop. Surface it — the contract itself is probably wrong, not either node's implementation (same escalation principle as `loop-engine`: after repeated failures, the problem is upstream).
- **No reality anchor in the graph.** Warn the calling skill before running — an all-LLM graph checking itself is a known failure mode, not a hypothetical one.
- **Dynamic workflows unavailable.** Fall back to sequential subagent calls; note in the run's state that true concurrency was not used.

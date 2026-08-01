---
name: <skill-name>
version: 0.1.0
hub-source: agent-hub
description: <one-sentence description of what the skill does>
graph:
  nodes:
    - <node-1-name>
    - <node-2a-name>
    - <node-2b-name>
    - <node-3-name>
  edges:
    - from: <node-1-name>
      to: [<node-2a-name>, <node-2b-name>]
      type: parallel-fanout
      contract: "<the upstream artifact both nodes read — not each other's output>"
    - from: [<node-2a-name>, <node-2b-name>]
      to: <node-3-name>
      type: fan-in
      gate: <command | agent | rubric>
  reality-anchor: <node-name — must not be an LLM judging another LLM's output>
  state-dir: "{project}/.claude/<skill-name>/{run-id}/"
---

# <Skill Name>

<One paragraph: what this skill does, and why it needs more than one node — what would break if it were a straight sequential chain of loops instead?>

## When to use

<When should someone invoke this skill? What's the trigger?>

**Do not use this skill for:**
- <Anti-use-case 1 — usually: "when the nodes have a real sequential dependency, use a plain chain instead">
- <Anti-use-case 2>

## Nodes

| Node | Role | Reads | Writes |
|---|---|---|---|
| <node-1-name> | <what it does> | <inputs> | <output artifact — this becomes the contract for any downstream fan-out> |
| <node-2a-name> | <what it does> | <the contract, NOT node-2b's output> | <output artifact> |
| <node-2b-name> | <what it does> | <the contract, NOT node-2a's output> | <output artifact> |
| <node-3-name> | <fan-in / reconciliation> | <both node-2a and node-2b outputs + the contract> | <reconciliation result> |

## The contract

<Name the exact upstream artifact the parallel nodes both read. State why it's precise enough to build against independently — if you can't answer this, the fan-out isn't ready; keep the edge sequential instead.>

## Fan-in gate

<How reconciliation works after both parallel nodes finish:>

- Verifier: <command | agent | rubric> — <details>
- Compares: <what promised> vs <what each node actually produced>
- On match: proceed to <next node>
- On mismatch: loop back to <the node that drifted>, via [loop-engine protocol](../skills/loop-engine/SKILL.md), escalating context
- Max round trips: <N> — if not converged, pause and ask the user (the contract is likely wrong, not either node's implementation)

## Reality anchor

<Which node in this graph produces a result that is NOT another LLM's judgment of a prior LLM's output? A real test run, a real command, a human checkpoint. Every graph needs at least one.>

## Configurable parallel/sequential (optional)

<If this graph's fan-out is a bet on upstream quality (like feature-factory's backend/frontend step), describe the fallback:>

| Mode | When | How it runs |
|---|---|---|
| Sequential (fallback) | <condition, e.g. low confidence in the contract> | <node-2a then node-2b, node-2b reads node-2a's actual output> |
| Parallel | <condition, e.g. high confidence, config allows it> | <both nodes read the contract concurrently, fan-in gate reconciles> |

## Dynamic workflow mapping (if running in Claude Code)

| Graph node/edge | Dynamic-workflow primitive |
|---|---|
| <node-2a-name> + <node-2b-name> fan-out | `parallel([...])` |
| <node-1-name> | `agent(prompt, opts)` |

Fall back to sequential subagent calls where dynamic workflows aren't available.

## State

All intermediate outputs persist under `<state-dir>`:

```
graph-state.json         (node status + fan-in result — managed by graph-engine)
<node-1-output>.md
<node-2a-output>.md
<node-2b-output>.md
```

Each node that runs its own retry loop internally also writes `loop-state.jsonl` under its own step directory.

## Failure modes

- **<Node> actually needs another node's live output, not the contract.** Not parallelizable — downgrade this edge to sequential.
- **Fan-in gate finds a mismatch beyond the round-trip limit.** Stop. The contract is probably wrong upstream — pause and ask.
- **No reality anchor identified.** Add one before running this graph for real — an all-LLM fan-in is a known failure mode.

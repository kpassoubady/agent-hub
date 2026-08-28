---
name: adaptive-engine
version: 2.0.0
hub-source: agent-hub
description: Thin wrapper around feature-factory's fixed chain — a planner agent declares only the extra pre/post gates a feature genuinely needs (dependency checks, independent validators), never re-derives the chain itself. Automatic mechanical run-feedback scorecard at hand-off.
---

# Adaptive Engine

`feature-factory`'s 7-agent chain is mature and already handles the standard build-a-feature shape. The Adaptive Engine is **not** a replacement for it and does not re-plan it from scratch. It is a thin wrapper: a `planner` agent looks at the feature description and decides whether anything *extra* is needed **around** the fixed chain — a precondition gate before building starts, or an independent verification pass after the chain's own Checkpoint 3. The fixed chain itself always runs as a single opaque node, `feature-factory-chain`.

This design exists because an earlier version of the planner re-derived the whole 7-agent pipeline as an 18-node graph, at the cost of a full planning pass and a checkpoint, and 14 of those nodes just re-encoded steps `feature-factory` already runs unchanged (their node prompts literally said "run feature-factory's step for this"). The 3 genuinely new nodes in that graph (a dependency gate, an independent security validator, a fan-in step) never even executed. See `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §5 for the full analysis.

## When to use

Invoke `/adaptive-engine <feature description>` only when you have genuinely non-linear structure the fixed chain has no slot for:
- A hard precondition that must hold before building starts (e.g., "this story cannot begin until another story's migration has landed").
- An independent post-build verification pass with a different lens than the chain's own `validator` (e.g., a cold security re-read of the diff).
- Multiple independent subsystems that build in parallel and need to reconcile before the chain's own build step — a rarer case; most parallel-build needs are already handled by feature-factory's own Step 4 fan-out.

**In the common case — no genuinely extra structure — the planner will say so and recommend `/feature-factory` directly.** Expect that outcome most of the time; don't be surprised if the planner declares zero extra gates.

**Do not use this skill for:**
- Any feature that fits the standard build-a-feature shape (research → story → spec → build → test → validate). Use `/feature-factory` directly — it is cheaper and more mature.
- Workflows that strictly require the 7-agent pipeline with no extra gates (use `feature-factory` directly).
- If downstream tooling explicitly expects hardcoded `feature-factory` outputs (e.g., `07-validator.md` gating).

## Phases

### Phase 0: Config gate (blocking)

Run [feature-factory's Step 0 config gate](../feature-factory/SKILL.md#step-0--config-gate-blocking) **before spawning the planner**, and write `00-config-resolved.md` into this skill's state directory.

Same three outcomes: missing → generate a candidate with `agent-hub-detect.sh -d`, show it, require accept/edit/abort; invalid → fail with every offending key; valid → bind it. The planner reads `00-config-resolved.md`, never the raw YAML.

The planner cannot make a sound graph without this. A graph built on an assumed `full-stack` shape plans builders the project may not have, and every node it emits inherits the wrong test commands.

### Phase 1: Planning (The Planner Agent)
Spawn the `planner` agent.
- **Inputs:** The user's feature description + project `CLAUDE.md`.
- **Output:** A `graph.json` whose nodes are drawn from exactly three kinds — `pre-gate` nodes, the single `feature-factory-chain` node, and `post-gate` nodes — plus a short markdown explanation of the plan (`00-plan-summary.md`). See `agents/planner.md`.

**Sanity-check the returned graph before showing it to the user.** If any node name matches one of feature-factory's own 7 agents (`researcher`, `story-writer`, `spec-writer`, `backend-builder`, `frontend-builder`, `test-verifier`, `validator`), the planner has re-derived the chain instead of wrapping it — reject the output and re-spawn the planner with that specific correction, rather than passing a bloated graph to Checkpoint 1.

**🛑 CHECKPOINT 1: Plan Approval**
Show the user the generated `00-plan-summary.md` and the `graph.json` structure — this should be small: the extra gates plus one node for the whole fixed chain.
Ask: approve, request changes, or reject?
- Rejected: Stop. Ask what to do next.
- Request changes: Pass feedback back to the `planner` to regenerate the graph.
- Approved: Add `STATUS: APPROVED` to the plan and proceed to Phase 2.
- **Zero extra gates:** if the planner's `00-plan-summary.md` recommends no extra gates, stop here and hand off to plain `/feature-factory <feature description>` instead of proceeding to Phase 2 — do not execute a one-node graph that adds a planning pass for nothing.

### Phase 2: Execution (Graph Engine)
Pass the approved `graph.json` to the `graph-engine` protocol.

- Each `pre-gate` node runs to completion (and must pass) before `feature-factory-chain` starts.
- `feature-factory-chain` executes by invoking the `feature-factory` skill itself, unmodified, against this same state directory — it is not re-implemented here. All of feature-factory's own checkpoints (story, brief, PR hand-off) run exactly as documented in `skills/feature-factory/SKILL.md`; the adaptive-engine adds no duplicate checkpoint around them.
- Each `post-gate` node runs after `feature-factory-chain` reaches its own Checkpoint 3, reading that run's artifacts as its input.
- The `graph-engine` handles fan-out/fan-in for any pre-gates or post-gates that run concurrently with each other; `feature-factory-chain` itself is always a single sequential node in this outer graph regardless of what parallelism happens inside it (feature-factory's own Step 4 fan-out is internal to that skill).

### Phase 3: Hand-off

`feature-factory-chain` already runs its own Step 7 — including its own invocation of `run-feedback` and its own Checkpoint 3 — as part of executing feature-factory unmodified. Phase 3 here does not repeat that; it only adds whatever the post-gates produced.

**🛑 CHECKPOINT 2: Final Review**
Once every post-gate node finishes (or immediately, if there were none), summarize for the user:
- `feature-factory-chain`'s own Checkpoint 3 summary (files changed, tests run, validator findings, its own run-feedback scorecard) — shown as-is, not duplicated.
- Each post-gate's result (pass/fail and evidence).
- If any pre-gate had been declared, confirmation it passed before the chain started.

The human handles the PR creation.

## Graph Constraints

The `planner` is strictly instructed to ensure:
- **No re-derivation:** `feature-factory-chain` is always exactly one node; the planner never expands it into its own 7 agents.
- **Reality Anchors:** `feature-factory-chain` is itself a valid reality anchor (it contains `test-verifier` and `validator` internally). A post-gate that adds a stronger anchor is welcome but not required.
- **Genuine extras only:** a pre-gate or post-gate must check something the fixed chain has no slot for. A post-gate that just re-runs checks `feature-factory-chain`'s own `validator` already performs does not earn its cost — the planner should drop it and say so in `00-plan-summary.md`.

## State

All intermediate outputs persist under `<project>/.claude/adaptive-engine/<feature-slug>/`:

```
00-config-resolved.md  (Phase 0 gate output — binding config)
00-plan-summary.md
graph.json
[pre-gate node outputs, if any]
feature-factory-chain.md  (one-line pointer: "see <project>/.claude/feature-factory/<feature-slug>/")
[post-gate node outputs, if any]
```

`feature-factory-chain` is executed by invoking the `feature-factory` skill against `<project>/.claude/feature-factory/<feature-slug>/` — the *same* slug, not a nested copy — so its own numbered artifacts (`01-research.md` through `08-feedback.md`) live in exactly one place regardless of which skill kicked it off. The adaptive-engine's own state directory holds only the pre-gate/post-gate artifacts and that one pointer file; it never forks a second copy of the chain's state.

### Slug derivation must be deterministic

`<feature-slug>` uses **the same rule as feature-factory**: the feature description lowercased, slugified, truncated to 40 chars. Nothing else.

Do not invent a prettier or shorter slug, and do not prefix it (`story-2-…`). Before planning, check whether `<project>/.claude/adaptive-engine/<feature-slug>/` or `<project>/.claude/feature-factory/<feature-slug>/` already exists; if so, resume it rather than planning a second time.

This is a real failure the hub has shipped: one story was planned twice, two minutes apart, under two different slugs, producing two mutually incompatible graph schemas — and neither matched the feature-factory directory that actually held the work, forcing a hardcoded cross-directory pointer. The orphan directory had no state file, so under the graph's own resume policy it was neither resumable nor collectable.

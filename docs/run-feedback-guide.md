# Run Feedback Guide

A practical guide to `run-feedback` — what problem it solves, why every check it runs is mechanical, and how its output gets from a single run into something the hub might eventually act on.

## The problem: a drift loop that never fired

The hub has documented a `learning/` directory pattern since `v0.2.0` — `patterns.md`, `selectors.md`, `failures.md`, meant to carry cross-run knowledge forward. Across 21 real chain runs analysed in the retrospective (`llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md`), those directories were **never once populated**. Capture depended on a human noticing a surprise and writing it down; nobody did, so the loop never closed.

The same retrospective found three concrete defects that a human reading the final checkpoint had every opportunity to catch and didn't:

- **Verification theatre.** A CI step grepped a directory that didn't exist, so its `!`-inverted exit passed vacuously forever. A coverage `--include` list was built file-by-file and quietly omitted the one untested file. An assertion helper (`assertInventoried`, `withCapability`) was imported by zero production code paths — the test proved the helper existed, not that anything used it.
- **Duplication.** The same 7 acceptance criteria appeared four times across one run's artifacts, and `06-coverage.md`/`07-validator.md` verified identical evidence with diverging numbers — three different test totals in one file, `74.6%` vs `75%` branch coverage for the same run.
- **State files that couldn't have supported resume.** `loop-state.jsonl` entries for six different iterations shared one timestamp, meaning they were written retroactively, in a batch, after the fact.

`run-feedback` exists to catch this class of thing automatically, at the point the human is already looking — not to add a fourth thing nobody reads.

## Mechanical only — never a self-assessed quality score

Every check `run-feedback-analyzer` runs reduces to a `grep`, a count, or a diff. It never scores a run's "quality," and it never grades its own chain's work.

This mirrors a rule `loop-engine` already enforces one level down: **the agent that did the work is too generous grading its own output**, so a loop's verifier must be a separate agent, a hard test, or a measurable condition — never the executor judging itself. `run-feedback` applies the same logic one layer up. If it let itself write "the researcher's analysis was thorough" or "the implementation looks clean," it would be the chain's own agents vouching for each other's work through a new file, which is exactly the failure mode verification theatre already demonstrated: a plausible-looking artifact of enforcement, standing in for enforcement.

So the design constraint is absolute: if a check can't be reduced to a command whose output is the answer, it does not belong in this agent.

## What it checks

The full table, from `agents/run-feedback-analyzer.md`:

| Check | What it does | What it's catching |
|---|---|---|
| **Gate enforceability** | For each gate created this run, does the validator's coverage report record a captured negative-control result for it? | A gate that passes vacuously forever |
| **Orphan code** | `grep`s every new exported symbol for a non-test caller | An enforcement helper called by nothing |
| **Coverage-scope bias** | Diffs the coverage tool's include-list against files actually on disk in scoped dirs | A coverage list that quietly excludes the one untested file |
| **Threshold drift** | Requirements-stated thresholds vs. the project's configured thresholds | A documented-but-not-configured threshold |
| **Duplication ratio** | Word count per artifact, plus overlap against upstream artifacts | Acceptance criteria restated four times |
| **AC roll-up integrity** | Any `PASS` verdict whose evidence text contains `synthetic`, `reused`, `not executed`, or `pending` | An overclaimed PASS |
| **State-file honesty** | Distinct timestamps in `loop-state.jsonl` vs. entry count | Retroactive, batched writes |
| **Config gating** | Was `00-config-resolved.md` present, and does its shape match which builders actually ran? | A backend-only project that still spawned frontend-builder |
| **Cost vs. complexity** | Artifact word count ÷ (files changed + acceptance-criterion count) | An outlier run relative to this project's own history |
| **Retry productivity** | Per loop point, did the criteria met actually grow between iterations? | A loop spinning without changing which criteria pass |
| **Landed vs. claimed** | Every file a builder summary claims changed — does `git status`/`git diff --stat` agree? | A summary describing work that isn't on disk |

The first six directly re-check the retrospective's own named defects (negative-control requirement, production-reachability, and the mechanical AC roll-up rule — all shipped as agent behavior in `v0.9.0`–`v0.12.0`). `run-feedback` doesn't duplicate those gates; it checks whether they actually fired this run, the same way a smoke test checks that a deployed feature flag is actually on.

## Output contract: Part A and Part B

The agent writes one file, `<state-dir>/08-feedback.md`, in two parts with different audiences and different constraints.

**Part A — the run scorecard**, capped at roughly 600 words. This is a net token add to every run it touches — it replaces nothing today — so the cap is deliberate: one row per check, a computed result (a number, a list, or PASS/FAIL), and at most one sentence of context where the result needs it. No narrative retrospective. The scorecard closes with the run's own cost-vs-complexity ratio and, when prior inbox entries exist for this project, their median — so a human can see "typical" vs. "outlier" without the agent editorializing about which one this run is.

**Part B — hub change proposals**, zero or more entries in a fixed `F-00N` format: severity, target file and version, the exact mechanical evidence (a `grep` result, a diff, a count — not a paraphrase), a recurrence count, the proposed change, and a mandatory **Counter-argument** field. An entry without a populated counter-argument is not written at all.

The counter-argument requirement exists because a mechanical-findings generator is still a plausibility generator once it starts proposing changes — every finding is real, computed data, but "this data implies the hub should change X" is a judgment call, and the cheapest defense against a skill talking itself into hub churn is to force it to also state the best argument against its own proposal. In the one real run this shipped against (InvoiceGen, `test-foundation-and-cloudflare-compatibi`), 3 of 4 findings carried a counter-argument suggesting the actual gap was enforcement of an existing rule, not a new rule — exactly the kind of signal a recurrence gate is supposed to weigh before anyone edits a hub file.

`Recurrence` always reads "1 run" here — this agent has no visibility into other runs. Counting recurrence across runs is explicitly out of scope; see "Where this is headed" below.

## When it runs

Two automatic trigger points, both immediately before a checkpoint's hand-off summary is shown — not as a separate wall of text the human has to go find:

- **`feature-factory` Step 7**, before Checkpoint 3.
- **`adaptive-engine` Phase 3**, before Checkpoint 2 — but only if the graph actually ran a validator node, since several checks read its coverage report and have nothing to check against without one.

Both callers fold Part A into their existing hand-off summary as one more section. Neither pauses or fails because of anything `run-feedback` finds — that enforcement already happened upstream, in `test-verifier`/`validator`.

It's also invocable standalone: `/run-feedback <state-dir>`, for a retroactive check or a run that predates this skill. It requires `07-validator.md` (or the graph-engine equivalent) to already be present — several checks have nothing to read before that point.

## The inbox, and the fallback when the hub isn't local

When the hub's root is discoverable locally (the directory containing `agents/`, `skills/`, `VERSION`), `run-feedback-analyzer` writes Part B — Part B only, not the scorecard — to `llm-context/feedback/inbox/<project>-<feature-slug>-<date>.md` under that root.

When it isn't discoverable — a common case, since the hub is usually installed into `~/.claude/` with no back-pointer to where it was cloned from — the agent doesn't fail or guess a path. It prints the exact file Part B would have been written to and a copy command the user can run once they know where their hub lives. Losing the inbox entry silently would recreate the same failure mode as the never-populated `learning/` directories: a capture mechanism that only works when nothing gets in its way.

> **Where this is headed — not yet implemented.**
>
> `run-feedback` is the producer side only. It writes findings; nothing reads them yet. The intended next piece is `hub-improve` — a consumer skill that would read the inbox, cluster findings by target file, and only propose an actual hub edit once a finding recurs across **at least two independent runs**, or is severity `high` with verified evidence. That threshold is deliberate: this guide's one real inbox entry showed 3 of 4 findings carrying a counter-argument suggesting the fix was enforcement of an existing rule rather than a new rule — precisely the kind of single-run noise a recurrence gate exists to filter before any hub file gets touched.
>
> Over time, that would close the loop the `learning/` directories were meant to close in `v0.2.0` and never did, because capture there was manual. `run-feedback` makes capture automatic; `hub-improve` would make consumption automatic too — but it does not exist yet.
>
> **Nothing in the hub auto-edits agent or skill files today.** `run-feedback` only ever writes findings to a run's own state directory and, when possible, the inbox. A human reads Part A at the checkpoint and Part B's proposals in the inbox, and a human decides what — if anything — happens next.

## See also

- [`agents/run-feedback-analyzer.md`](../agents/run-feedback-analyzer.md) — the agent, full check table and output contract
- [`skills/run-feedback/SKILL.md`](../skills/run-feedback/SKILL.md) — the orchestrating skill
- [`diagrams/07-run-feedback.md`](../diagrams/07-run-feedback.md) — the flow, including the not-yet-built `hub-improve` step drawn as explicitly distinct
- [`skills/loop-engine/SKILL.md`](../skills/loop-engine/SKILL.md) — the "verifier separate from executor" principle this guide's mechanical-only section borrows
- `llm-context/todos/2026-08-27-run-retrospective-and-feedback-skill.md` §8 — the original proposal and the real defects that motivated it

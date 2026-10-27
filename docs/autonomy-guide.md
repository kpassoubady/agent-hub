# Autonomy levels and batch mode

How `/feature-factory` (and `/adaptive-engine`) decide whether a human has to say "yes" at a checkpoint, and how a whole roadmap runs on a single approval.

The rule behind all of it: **a checkpoint is skipped only when the orchestrator can prove, with grep/count/diff on the run's own artifacts, that nothing in it needed a human.** It never asks an agent "is this safe to auto-approve?" — that would be the verification theatre the hub's mechanical gates exist to prevent.

## 1. Levels

Set in `.agenthub-config.yaml`, overridable per run with `--autonomy <level>`. Precedence: flag > config > `supervised`. A `--no-config` run is always `supervised`.

```yaml
workflow:
  autonomy: guided            # supervised | guided | autonomous  (default: supervised)
  stop-on: [migration, auth-security, secrets, tenant-isolation, environment-missing]   # autonomous only; this is the default
```

| Checkpoint | `supervised` | `guided` | `autonomous` |
|---|---|---|---|
| Step 1.5 trivial accept/escalate | ask | auto-accept (the researcher's `trivial` criteria are already mechanical) | auto-accept |
| Checkpoint 1 — story | ask | auto-approve if the §3 CP1 conditions hold, else ask | same, but only `stop-on` risks force a pause |
| Checkpoint 2 — brief | ask | auto-approve if the §3 CP2 conditions hold, else ask | same, but only `stop-on` risks force a pause |
| Validator `Important` findings | ask fix/accept | one automatic fix round; leftovers listed in the summary | same as guided |
| Checkpoint 3 — hand-off | summary, chain ends | same | same |
| Hard stops (§2) | n/a — human is already asked | **pause** | **pause** |

Checkpoint 3 never gates anything — the chain ends there at every level — so `autonomous` differs from `guided` in exactly one way: a risk trigger (§3) that makes `guided` ask is only logged under `autonomous`, unless it is in `stop-on`.

## 2. Hard stops — always a human, at every level

These pause `guided` and `autonomous` runs. Nothing auto-approves past them.

| # | Hard stop | Detected by |
|---|---|---|
| H1 | Config missing (candidate needs confirming) or invalid | Step 0 gate, unchanged |
| H2 | Open question in the researcher's §9 or the brief's "Risks and open questions" | Section non-empty and not `None` |
| H3 | Brief's file-level change plan names a path outside the resolved `backend`/`frontend`/`test` folders and files | Path-prefix comparison against `00-config-resolved.md` |
| H4 | Any loop limit in "Loop control" is exhausted (story/spec revisions, handoff, per-criterion test failures, validator Criticals) | Loop counters in `loop-state.jsonl` |
| H5 | An acceptance criterion is still `PARTIAL`, `FAIL`, or rests on an `UNENFORCED` gate after its retries | Mechanical AC roll-up rule, unchanged |
| H6 | Dirty working tree at the start of a batch | `git status --porcelain` non-empty |

The hub still never pushes or opens a PR at any level.

## 3. Auto-approval conditions

**Risk triggers** are a fixed vocabulary: `migration`, `new-dependency`, `auth-security`, `breaking-contract`, `tenant-isolation`, `secrets`, `environment-missing`. `spec-writer` declares them in its `Risk triggers` line (agents/spec-writer.md); for Checkpoint 1 the orchestrator reads them off the researcher's §5 Risks categories (`migrations`, `tenant isolation`, `secrets`, `environment`) and §3/§2 for a needed new dependency.

**Checkpoint 1 auto-approves when all hold:** `02-story.md` has at least one numbered AC; no H2; no risk trigger present (`guided`) / none in `stop-on` (`autonomous`).

**Checkpoint 2 auto-approves when all hold:** the `Risk triggers` line is present (absent → ask); no H2; no H3; every AC number in `02-story.md` is cited in the brief's "Tests required" (a missing citation is a revision round that counts against the 3-iteration limit, then H4); no risk trigger present (`guided`) / none in `stop-on` (`autonomous`).

When a condition fails the checkpoint behaves exactly as under `supervised`: show the artifact, call out the failing condition first, ask approve / request changes / reject.

## 4. Audit trail

Auto-approval is only safe if it is reviewable afterwards.

- `02-story.md` / `03-spec.md` get `STATUS: AUTO-APPROVED (autonomy=<level>)` instead of `STATUS: APPROVED`. Everything downstream treats either marker as "approved".
- `00-approvals.md` gets one row per decision, appended the moment it is made: `| checkpoint | decision (HUMAN-APPROVED / AUTO-APPROVED / HARD-STOP) | autonomy | conditions checked | risk triggers present |`.
- The Checkpoint 3 summary opens with an "Auto-approved decisions" section built from that file, so one read shows everything a human did not see.

## 5. Batch mode — one approval for a roadmap

```
/feature-factory --batch <roadmap.md> [--autonomy guided|autonomous]
```

Requires `guided` or `autonomous` (a `supervised` batch would just be N supervised runs; the skill asks you to pick a level instead).

1. **Parse.** Each top-level bullet or `##` heading in the roadmap is one feature, in order. An optional `depends-on: <number>` line marks a prerequisite. The orchestrator writes `<project>/.claude/feature-factory/_batch/<batch-slug>/batch.md`: an ordered table of `# | feature | slug | status` where status is `pending | running | done | stopped | skipped | blocked`.
2. **One batch checkpoint.** Show the ordered list, the autonomy level, the hard-stop list, and the git behavior below. This is the only routine approval.
3. **Run sequentially**, not in parallel — features share the working tree. Each feature runs the full chain under the chosen level, with its own state directory and its own `run-feedback` scorecard.
4. **Git.** Work happens on a local branch `batch/<batch-slug>`, with one local commit per completed feature (so each feature's diff is isolated and revertable). Nothing is pushed.
5. **Hard stop mid-batch.** The batch pauses at that feature (`stopped`) and asks: resume after you fix it, skip it (its dependents become `blocked`), or abort. It never silently continues past a stopped feature.
6. **One combined hand-off** at the end instead of N Checkpoint 3 summaries: a per-feature table (status, files, tests, open validator findings, risk triggers seen), the combined "Auto-approved decisions" section, and each feature's scorecard line.
7. **Resume.** Re-running with the same roadmap reads `batch.md` and skips `done` features.

## 6. Tuning

`run-feedback`/the drift signals record when an auto-approved feature later hit a validator Critical or a hard stop. Repeated cases mean the trigger heuristics are too loose: tighten them in `agents/spec-writer.md` (the `Risk triggers` definitions) or move the level back to `supervised` for that project.

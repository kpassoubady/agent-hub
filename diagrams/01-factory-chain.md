# The 7-Agent Factory Chain

Build a feature end-to-end through specialized agents, each with a clean context window and a narrow job. Three human checkpoints keep you in the loop where judgment matters; everything else runs on its own.

> **v0.2.0** — project shape, per-feature skip logic, escalating retry context, and learning directory are reflected below.

> **v0.3.0** — loop-back arrows now follow the generic [loop-engine protocol](04-loop-framework.md). See that diagram for the full lifecycle, escalating context flow, and operating modes.

> **v0.7.0** — Step 0 is now a **blocking gate**, not a lookup. A missing config is generated and confirmed; an invalid one stops the chain. The gate's decisions are written to `00-config-resolved.md`, which every later agent reads instead of re-deriving them.

> **v0.13.0** — new Step 0.5 environment preflight before research; a `trivial`-tier fast path at Step 1.5 that can skip story-writer and spec-writer entirely behind one lightweight checkpoint; test-verifier's negative-control requirement and validator's mechanical AC roll-up rule mean a `PASS` can be forced back to `PARTIAL`/`Critical` even after test-verifier's own report labelled it passing; and Step 7 now runs the [run-feedback](../skills/run-feedback/SKILL.md) skill before Checkpoint 3. See [06-adaptive-engine.md](06-adaptive-engine.md) and [07-run-feedback.md](07-run-feedback.md) for those two additions' own diagrams.

```mermaid
flowchart TD
    Idea[Rough feature idea]
    Idea --> G0{{"Step 0 — config gate<br/>.agenthub-config.yaml"}}
    G0 -.->|"missing → detect,<br/>show, confirm"| G0
    G0 ==>|"invalid → STOP"| Halt["chain does not run<br/>report every bad key"]
    G0 ==>|valid| Resolved["00-config-resolved.md<br/>shape · folders · commands<br/>(binding for all agents)"]
    Resolved --> PF["Step 0.5 — environment preflight<br/>orchestrator-run, no agent<br/>docker · DB client · deploy CLI"]
    PF --> R[1. researcher<br/>maps the codebase + peer-deps<br/>Read · Grep · Glob]
    R --> Tier{{"Step 1.5 — complexity tier<br/>researcher suggests trivial|standard"}}
    Tier ==>|standard| SW[2. story-writer<br/>user story + acceptance criteria<br/>Read]
    Tier -.->|"trivial →<br/>1 lightweight checkpoint"| CPT{{"accept fast path,<br/>or escalate?"}}
    CPT -.->|escalate| SW
    CPT ==>|"accept →<br/>skip story + spec"| BE
    SW --> CP1{{Checkpoint 1<br/>approve story?}}
    CP1 -.->|changes needed| SW
    CP1 ==>|approved| SP[3. spec-writer<br/>technical brief + Builders needed<br/>Read · Grep · Glob]
    SP --> CP2{{Checkpoint 2<br/>approve brief?}}
    CP2 -.->|changes needed| SP
    CP2 ==>|approved| BE["4. backend-builder<br/>API + services + unit tests<br/>backend folders only<br/>(skippable)"]
    BE --> FE["5. frontend-builder<br/>UI + hooks + UI tests<br/>frontend folders only<br/>(skippable)"]
    FE --> TV["6. test-verifier<br/>acceptance tests + negative controls<br/>test files only"]
    TV --> V["7. validator<br/>read-only gap analysis + AC roll-up<br/>Read · Grep · Glob"]
    V --> RF["run-feedback<br/>mechanical scorecard<br/>(see 07-run-feedback.md)"]
    RF --> CP3{{Checkpoint 3<br/>review and open PR}}

    TV -.->|"FAIL or PARTIAL<br/>(incl. UNENFORCED gate)"| BE
    TV -.->|"FAIL or PARTIAL"| FE
    V -.->|"Critical<br/>(incl. no negative control,<br/>unreachable guard/helper)"| BE
    V -.->|Critical| FE
    FE -.->|API mismatch| BE

    Learn[("learning/<br/>patterns · selectors · failures")] -.-> R
    V -.-> Learn

    style G0 fill:#fff3cd,stroke:#d4a017,color:#000
    style Halt fill:#f8d7da,stroke:#c82333,color:#000
    style Resolved fill:#d4edda,stroke:#28a745,color:#000
    style PF fill:#d4edda,stroke:#28a745,color:#000
    style Tier fill:#fff3cd,stroke:#d4a017,color:#000
    style CPT fill:#fff3cd,stroke:#d4a017,color:#000
    style Idea fill:#f5f5f5,stroke:#666,color:#000
    style R fill:#e1f5ff,stroke:#0366d6,color:#000
    style SW fill:#e1f5ff,stroke:#0366d6,color:#000
    style SP fill:#e1f5ff,stroke:#0366d6,color:#000
    style BE fill:#e1f5ff,stroke:#0366d6,color:#000
    style FE fill:#e1f5ff,stroke:#0366d6,color:#000
    style TV fill:#e1f5ff,stroke:#0366d6,color:#000
    style V fill:#e1f5ff,stroke:#0366d6,color:#000
    style RF fill:#e1f5ff,stroke:#0366d6,color:#000
    style CP1 fill:#fff3cd,stroke:#d4a017,color:#000
    style CP2 fill:#fff3cd,stroke:#d4a017,color:#000
    style CP3 fill:#fff3cd,stroke:#d4a017,color:#000
    style Learn fill:#f0e6ff,stroke:#7c3aed,color:#000
```

## How it runs

0. **Step 0 — config gate (blocking).** Read and validate `.agenthub-config.yaml`. Missing → generate a candidate with `agent-hub-detect.sh -d`, show it, and require *accept / edit / abort*. Invalid → stop and report every bad key. Valid → write `00-config-resolved.md`, which binds `project.shape` (`full-stack` | `backend-only` | `frontend-only` | `library`), the folder scopes, and the exact commands for every later agent. **The chain never proceeds on assumed defaults.**
1. **researcher** maps the relevant code (read-only). Reads `learning/patterns.md` if present.
2. **story-writer** turns the idea into a user story with numbered acceptance criteria.
3. **Checkpoint 1** — you approve or revise the story.
4. **spec-writer** turns the approved story into a technical brief: data model, APIs, file-level change plan. Outputs a `Builders needed:` declaration for the orchestrator.
5. **Checkpoint 2** — you approve or revise the brief. This is where contract mistakes get caught before any file is touched.
6. **backend-builder** implements the backend half. *Skipped* when shape is `frontend-only` or when the brief marks its sections `None`.
7. **frontend-builder** implements the UI half. *Skipped* when shape is `backend-only` or `library`, or when the brief marks its section `None`. Consumes the backend's API contract verbatim; surfaces mismatches instead of patching.
8. **test-verifier** writes acceptance tests, one per numbered criterion, and runs a negative control for every gate it relies on — see "Mechanical enforcement" below. Reports `PASS | PARTIAL | FAIL | UNCOVERED`.
9. **validator** does a read-only gap analysis against the story and brief, re-derives each criterion's verdict from the evidence text rather than trusting test-verifier's label, and checks every new guard/helper for a production caller. Reports `Critical | Important | Minor`. Appends recurring findings to `learning/failures.md`.
10. **run-feedback** runs its mechanical scorecard against this run's own artifacts — see [07-run-feedback.md](07-run-feedback.md).
11. **Checkpoint 3** — you review the diff and open the PR.

## Step 0.5 and Step 1.5 — before any story exists

Two additions sit between the config gate and story-writer, both aimed at catching things a real run hit mid-build instead of before it started:

- **Step 0.5 (environment preflight)** — the orchestrator itself probes for whatever the feature plausibly needs (container runtime, DB client, deploy CLI) before spawning researcher, which has no Bash access and can't check tool availability itself. A real run had Docker Desktop's absence block the same acceptance criterion across backend, frontend, *and* validator rounds, discovered fresh each time.
- **Step 1.5 (complexity tier)** — researcher, now the first agent with real evidence about scope, suggests `trivial` or `standard`. A `trivial` suggestion pauses at one lightweight checkpoint (accept the fast path, or escalate); accepting skips story-writer and spec-writer entirely and jumps straight to Step 4. This does not remove a checkpoint — it consolidates the story and brief approvals into one, and Checkpoint 3 still runs unchanged. If a builder discovers mid-run that the feature needs a migration or a new dependency, it stops and the orchestrator generates story/spec retroactively from what was already learned, then runs Checkpoints 1 and 2 as normal before resuming.

## Mechanical enforcement — a PASS that can still fail

Two rules run at Steps 6 and 7 that can downgrade a criterion even after an upstream report already called it `PASS`:

- **Negative-control requirement.** Any gate test-verifier relies on for evidence (a CI step, a coverage threshold, a guard/assertion helper) must be shown failing once, on purpose, before it counts. A gate that can't be shown to fail is `UNENFORCED` — never satisfied — regardless of how correct its code looks on read-through.
- **Mechanical AC roll-up rule.** If any sub-check behind a criterion is self-labelled `synthetic`, `reused`, `not executed`, `pending`, or rests on an `UNENFORCED` gate, that criterion is `PARTIAL`, never `PASS` — no matter how solid the other sub-checks are. Validator re-derives the verdict from the evidence text itself rather than trusting test-verifier's label.

Both rules were motivated by the same retrospective finding: a CI step that grepped a directory that didn't exist and passed vacuously forever, a coverage list that quietly excluded the one untested file, and an assertion helper imported by zero production code paths. Validator's **production-reachability requirement** closes that last one specifically — every new exported guard/helper/assertion module either builder added gets `grep`ped for a non-test caller; none found is a Critical finding regardless of the module's own test coverage.

## Why Step 0 blocks

This is the part students most often want to argue with: why stop the whole chain over a config file?

Because the cost of a missing config isn't paid once — it's paid by every agent downstream. In a real run where the config was absent, the chain assumed `full-stack` and then **four separate stages independently re-derived the same test commands** from `package.json`: the researcher, the spec-writer, and both builders. Resolving it once at Step 0 costs one read.

The inverse failure is worse. In another real run, a project *correctly* declared `shape: backend-only` — and frontend-builder was still spawned on **8 of 18 features**, each time burning a full context window to write a one-line "N/A — backend-only, this is a CLI" placeholder. Step 0 had the right answer; nothing made later steps honour it.

So the gate has two jobs, and the second is the one people forget:

| Job | Mechanism |
|---|---|
| Get a valid config | Generate → confirm → validate, or stop |
| **Make it binding** | Write `00-config-resolved.md`; every agent reads that, not the YAML |

An advisory Step 0 is not a gate. It's a suggestion with a nice table.

Full detail, including a graded exercise: [docs/config-gate-guide.md](../docs/config-gate-guide.md).

### What "invalid" means

A config naming things that don't exist is *worse* than no config, because agents will trust it and report green against commands that never ran. The gate rejects:

- folders or files that aren't there
- commands that resolve to no script or binary
- **backend and frontend scopes that overlap** — if `frontend.folders` contains `src/app` while `backend.folders` contains `src/app/api`, frontend-builder is authorised to rewrite your API routes
- a `project.shape` that isn't one of the four known values, or that contradicts the populated sections

The overlap rule has a wrinkle worth teaching: in Next.js App Router, `src/app` genuinely holds both halves — `api/` routes *and* `page.tsx`. The fix isn't to give the folder to one builder; it's to give the subtree to the backend and list the frontend's shell files under `frontend.files`.

## Loop-back rules

- **test-verifier finds a failing or `PARTIAL` criterion** (including one downgraded by the mechanical AC roll-up rule, or resting on an `UNENFORCED` gate) → loops back to the appropriate builder with the criterion number. A `PARTIAL` is treated like a `FAIL` for loop-control purposes; it never passes through to Checkpoint 3 looking like a pass.
- **validator finds Critical issues** (including a missing negative control or an unreachable guard/helper under the production-reachability requirement) → loops back to the appropriate builder until clean.
- **frontend-builder sees an API mismatch** → feedback returns to backend-builder; never patches client-side.

## Hard limits

Each loop step caps at 3 iterations. If a step doesn't converge, the chain pauses and asks — the problem is usually upstream (story or brief), not downstream (builders).

## Escalating retry context

A retry that gets the same context as attempt 1 will produce the same mistake. Each attempt gets a progressively narrower, deeper view:

| Attempt | What the agent sees |
|---|---|
| 1 (initial) | Full brief + researcher findings + CLAUDE.md |
| 2 (first retry) | Specific failure + files changed in attempt 1 + one-paragraph summary |
| 3 (second retry) | Attempt-2 context + full failure traces + root-cause summary of both prior attempts |
| 4+ | Stop — pause and ask the user |

## Learning directory

If `<project>/.claude/feature-factory/learning/` exists, agents read and write three files across runs:

| File | Owner | Purpose |
|---|---|---|
| `patterns.md` | researcher | Cached codebase patterns — read at start, append novelties |
| `selectors.md` | test-verifier | CSS/XPath/API paths reused across features |
| `failures.md` | validator | Recurring findings — spec-writer reads to avoid repeating bad patterns |

The learning directory is per-project (not per-feature) and survives across chain runs.

## Why this beats one big AI session

In vibe coding, one AI session is asked to be product analyst + architect + backend engineer + frontend engineer + test engineer + reviewer all at once. Wrong assumptions in the plan become wrong database models, wrong APIs, wrong UIs — silent compounding mistakes.

The chain forces separation of concerns. Each agent has one job, sees only what it needs, and is constrained to a narrow toolset. Mistakes get caught at the brief approval — not after 10 files have been changed.

# The Config Gate

How `/feature-factory` and `/adaptive-engine` decide whether they are allowed to start, and why that decision blocks the chain instead of warning and continuing.

This guide is written to be taught. Each section states a rule, then the real run that motivated it.

---

## 1. What the gate is

Step 0 of the factory chain (Phase 0 of the adaptive engine) reads `.agenthub-config.yaml` from the project root and produces exactly one of three outcomes:

| Outcome | Behaviour |
|---|---|
| **Missing** | Generate a candidate config, show it, require *accept / edit / abort*. |
| **Invalid** | Stop. Report every offending key. Do not fall back to defaults. |
| **Valid** | Write `00-config-resolved.md` into the run's state directory and proceed. |

That third row is the one people skim past, and it is the half that makes this a gate rather than a lookup.

---

## 2. Why blocking, and not a warning

The hub used to warn once and assume `full-stack`. That seems friendly. Here is what it actually bought, measured on a real run of a Next.js project that had no config:

Four separate agents independently re-derived the same information from `package.json`:

- the **researcher**, mapping the codebase
- the **spec-writer**, writing test entries into the brief
- the **backend-builder**, running its own verification
- the **frontend-builder**, doing the same

One missing file, paid for four times, in every run. Resolving it once at Step 0 costs a single read.

### The rule

> Resolve shared facts once, at the earliest point that can validate them.

---

## 3. Why the gate must be *binding*

Getting a valid config is only half the job. The other half is making later steps honour it.

A book-building project correctly declared:

```yaml
project:
  shape: backend-only
```

It is a Python CLI. It has no frontend, and the config said so. Yet across 18 completed features, `frontend-builder` was spawned on **8 of them** — each time burning a full context window to produce a one-line file:

```
# Frontend Build Summary
N/A — backend-only feature. BookBuilder is a CLI; there is no frontend/UI.
```

Step 0 had the correct answer the whole time. Nothing forced Step 4 to use it, so the shape decision was quietly recomputed — and ignored — downstream.

The fix is a written artifact rather than a remembered decision. Step 0 emits `00-config-resolved.md`:

```markdown
# Resolved config — invoice-reminders
Source: /path/.agenthub-config.yaml (validated 2026-08-27T10:14:00Z)
Origin: existing | generated-and-confirmed-this-run

shape: full-stack
builders eligible: backend-builder, frontend-builder
backend.folders: src/app/api, src/lib
frontend.folders: src/components, public
frontend.files: src/app/page.tsx, src/app/layout.tsx
test.command: pnpm test:e2e
backend.test-command: pnpm test
build.parallel-builders: auto
```

Every agent reads that file. None re-reads the YAML.

### Two consequences

1. **An ineligible builder is never spawned.** The orchestrator writes the placeholder itself, naming the rule: `SKIPPED — project.shape is backend-only (00-config-resolved.md)`. You do not pay an agent to tell you it has nothing to do.
2. **Command strings are resolved once.** Later agents cannot drift onto a different test command than the one Step 0 validated.

### The rule

> An advisory gate is not a gate. If a decision matters downstream, write it down and make downstream read it.

---

## 4. What makes a config *invalid*

A config that names things which do not exist is **worse than no config**, because agents will trust it and report green against commands that never ran.

The gate checks all of the following and reports every failure at once, each with the offending key and value:

| Check | Fails when |
|---|---|
| Folders exist | a path in `backend.folders` / `frontend.folders` / `test.folders` is not a directory |
| Files exist | a path in the optional `backend.files` / `frontend.files` is not a file |
| Commands resolve | a `test-command`, `typecheck-command`, `lint-command`, or `test.command` names a script or binary that does not exist |
| **Scopes do not overlap** | a `backend.folders` entry is inside a `frontend.folders` entry, or vice versa |
| Files respect the other scope | a `frontend.files` entry sits inside a `backend.folders` entry, or vice versa |
| Shape is known | `project.shape` is not one of the four valid values |
| Shape matches sections | shape is `backend-only`/`library` but `frontend.folders` is populated |
| Parallel flag is known | `build.parallel-builders` is set to something other than `auto`/`always`/`never` |

Note what is *not* on this list: the gate does not run your test suite. It checks that the command **exists**, not that it passes. Verifying behaviour is the test-verifier's job.

---

## 5. The overlap rule, and the Next.js wrinkle

`backend.folders` is documented as a **hard scope restriction** for `backend-builder`; `frontend.folders` is the same for `frontend-builder`. So this config is dangerous:

```yaml
backend:
  folders: [src/app/api]
frontend:
  folders: [src/app]        # contains src/app/api
```

`frontend-builder` is now authorised to rewrite your API routes. Nothing will warn you; it is simply inside its declared scope.

But you cannot fix this by just picking one side, because in the Next.js App Router the overlap is real: `src/app` genuinely holds **both** halves — `api/` route handlers *and* `page.tsx` / `layout.tsx` / `globals.css`.

The resolution is to give the shared subtree to one side and list the other side's specific files:

```yaml
backend:
  folders: [src/app/api, src/lib, src/utils]
frontend:
  folders: [src/components, public]
  files:   [src/app/page.tsx, src/app/layout.tsx, src/app/globals.css]
```

`backend.files` and `frontend.files` are optional and behave as an extension of that side's `folders` for scope purposes.

`agent-hub-detect.sh` recognises this shape and emits a non-overlapping config automatically, with a `# NOTE:` block explaining what it narrowed and why — so a student reading a generated file can see the reasoning, not just the result.

### The rule

> When two agents can write to the same path, the boundary is not a convention — it is a permission. Make it explicit.

---

## 6. Generating a config

From the hub directory:

```bash
./agent-hub-detect.sh -d /path/to/project   # dry-run: print YAML, write nothing
./agent-hub-detect.sh    /path/to/project   # write .agenthub-config.yaml
./agent-hub-detect.sh --force /path/to/project   # refresh an existing one
```

The detector infers language, framework, project shape, folder scopes, and commands from real manifests — `package.json`, `pyproject.toml`, `go.mod` — and never invents a command it has not seen.

When Step 0 finds no config, it runs the detector in dry-run mode, shows you the result, and asks. It does **not** write silently, and it does **not** proceed on the detector's guess without you confirming. Detection is a heuristic; confirmation is cheap; a wrong shape is expensive.

---

## 7. What else writes to `00-config-resolved.md`

Step 0 is the file's only *author* for the fields above, but two later additions append to it rather than creating their own file:

- **Step 0.5 (environment preflight)** runs after Step 0, before researcher. It does not write to `00-config-resolved.md` — the preflight result is passed to researcher directly as an input, and a missing tool surfaces as a Risk in researcher's own output, not as a gate failure. The config file itself is unaffected.
- **Step 1.5 (complexity tier)** appends a `tier: trivial` (or `tier: standard (escalated from trivial)`) field to the same `00-config-resolved.md` once the user accepts the researcher's fast-path suggestion — it does not overwrite the config gate's own fields. A resume landing between steps checks this field before assuming the chain crashed: a trivial-tier run has no `02-story.md`/`03-spec.md` by design, not by interruption.

Neither addition changes what makes the gate itself valid or invalid — see §4 above for that list, which is unchanged. See [docs/run-feedback-guide.md](run-feedback-guide.md) and the [feature-factory skill](../skills/feature-factory/SKILL.md)'s Step 0.5 / Step 1.5 sections for the full detail on each.

## 8. The escape hatch

```bash
/feature-factory --no-config <description>
```

Runs unconfigured, assuming `full-stack`. The Checkpoint 3 summary must then state prominently that the run was unconfigured and which commands were guessed.

Use it for a throwaway experiment. Do not use it for real features — the whole point of the gate is that unconfigured runs cost more than they appear to.

---

## 9. Teaching exercise

Give students this config against a Next.js project and ask what breaks:

```yaml
project:
  shape: full-stack
backend:
  folders: [src/lib]
  test-command: pnpm test:unit
frontend:
  folders: [src/app, src/components]
test:
  folders: [tests]
  command: pnpm e2e
```

Four defects, in rough order of severity:

1. `src/app` (frontend) contains `src/app/api` — but `src/app/api` is not in `backend.folders` at all, so the API routes are owned by **frontend-builder**. Backend work will be refused as out-of-scope, or done by the wrong agent.
2. `pnpm test:unit` and `pnpm e2e` are plausible but must be checked against `package.json` — the real scripts in the reference project are `pnpm test` and `pnpm test:e2e`. A wrong command name means the verifier reports on a suite that never ran.
3. No `typecheck-command` or `lint-command`, so builders fall back to `npm run typecheck` — which does not exist in a pnpm project.
4. No `build.parallel-builders`, which defaults to `auto` — fine, but worth having students notice that the default defers to the spec-writer's per-feature `API contract confidence`.

The point of the exercise: every one of these fails **silently** under an advisory Step 0, and every one is caught in a single pass by a blocking one.

---

## Related

- [feature-factory skill](../skills/feature-factory/SKILL.md) — Step 0, the full gate specification
- [adaptive-engine skill](../skills/adaptive-engine/SKILL.md) — Phase 0, same gate before planning
- [factory chain diagram](../diagrams/01-factory-chain.md) — where the gate sits visually
- [README configuration section](../README.md#project-specific-configuration) — schema reference

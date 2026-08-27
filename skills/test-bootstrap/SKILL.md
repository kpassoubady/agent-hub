---
name: test-bootstrap
version: 0.1.0
hub-source: agent-hub
description: Stands up a minimal real test framework for a project that has none, before /feature-factory runs against it.
---

# Test Bootstrap

Runs the `test-bootstrapper` agent to install a test framework, write one passing smoke test per side, and update `.agenthub-config.yaml` — for projects (typically POC/MVP repos) where `agent-hub-detect.sh` could not confirm a `test.folders` entry.

## When to use

- `agent-hub-detect.sh` printed the `WARNING: could not confirm a folder for: test.folders` block, or the generated config has `test.folders: [REPLACE_ME]`.
- `/feature-factory`'s Step 0 gate is about to accept (or already accepted) a `test.command` that doesn't actually run anything real (e.g. `echo 'no test command configured'`).
- The user invoked `/test-bootstrap` directly, or asked to "set up tests" / "add a test framework" before building features.

**Do not use this skill for:**
- Adding acceptance tests for a specific feature — that's `test-verifier`, invoked inside `/feature-factory` Step 5.
- Raising coverage on a project that already has a working test framework — that's a coverage-raising agent (e.g. `increase-coverage`), not this skill.
- Restructuring source folders — if `backend.folders`/`frontend.folders` are themselves unconfirmed, fix that first (see Step 0 below).

## Step 0 — Layout must already be confirmed

Read `.agenthub-config.yaml`. If `backend.folders` or `frontend.folders` contains `REPLACE_ME` (or the WARNING block names either of them), **stop**. A test framework scoped to an unclear layout tests the wrong things once the layout is fixed later.

Tell the user: *"backend/frontend folders aren't confirmed yet — restructure or hand-edit `.agenthub-config.yaml` first, then re-run `/test-bootstrap`."*

If only `test.folders` (or `test.acceptance-framework` / `test.command`) is unconfirmed, proceed.

## Step 1 — Confirm scope with the user

**🛑 Ask before installing anything:**
- Show the detected `project.shape` / `language` / `framework`.
- Show the framework this skill intends to install for each side (see the agent's "What it does" table — pytest / vitest+Playwright / JUnit / xUnit, chosen by language).
- Ask: proceed with this framework choice, pick a different one, or abort?

Do not install silently. A POC repo may have a reason to prefer a framework other than the idiomatic default (team convention, an existing partial setup the detector missed).

## Step 2 — Run test-bootstrapper

Spawn the `test-bootstrapper` agent. Inputs: `.agenthub-config.yaml`, the user's framework choice from Step 1, the specific unconfirmed keys from the detector's warning.

## Step 3 — Report and hand off

Show the user:
- What was installed (framework + version + manifest changed)
- The smoke test file(s) added, and their pass/fail result (must be PASS)
- The exact `.agenthub-config.yaml` diff
- The follow-up note: this is scaffolding, not coverage — next real step is `/feature-factory` for new features (which will now exercise a real `test.command`), or a coverage agent if the goal is raising coverage on existing code

If the agent reports a failure mode (framework already exists and conflicts, install failed, nothing testable without new infrastructure), surface it verbatim and stop — do not retry silently.

## What this skill does NOT do

- Write feature-specific or acceptance tests (that's `test-verifier`)
- Chase a coverage percentage (that's a coverage-raising agent)
- Modify source layout or existing tests
- Run without the Step 1 confirmation, even if the user says "just do it" — installing a dependency and writing files is a real, visible action

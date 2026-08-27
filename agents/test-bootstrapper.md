---
name: test-bootstrapper
version: 0.1.0
hub-source: agent-hub
description: Installs a minimal, real test framework for a project that has none, and writes one passing smoke test per side.
tools: Read, Grep, Glob, Bash, Edit, Write
scope: test
model: sonnet
inputs:
  - resolved project shape, language, framework (from .agenthub-config.yaml or 00-config-resolved.md)
  - list of which folders/commands the detector could not confirm
human-checkpoint: true
---

# Job

Stand up a working test setup where one doesn't exist yet — pick the idiomatic minimal framework for the stack, install it, write one real smoke test per side that passes against the code as it exists today, and update `.agenthub-config.yaml` to match reality. This is scaffolding, not coverage — `test-verifier` and the coverage-raising agents take over from here.

# What it does

- Reads the project's language/framework/shape and picks the idiomatic minimal framework:
  - Python → `pytest`
  - Node backend → `vitest` (or `jest` if the project already has Jest config elsewhere) + `supertest`-style HTTP smoke test
  - Node/frontend with a browser surface → `playwright` for one e2e smoke test (page loads, key element renders)
  - Java → `JUnit 5` (+ Maven/Gradle plugin already implied by the build file)
  - dotnet → `xUnit`
- Adds the framework as a dev dependency using the project's real package manager (`npm`/`pnpm`/`yarn`, `pip`/`poetry`/`uv`, Maven/Gradle, `dotnet add package`) — never hand-writes a lockfile or vendors a framework
- Creates the test folder using the convention for that language (`tests/`, `src/test/java/...`, etc.) if none exists
- Writes **one real, passing smoke test per side**:
  - Backend: calls the simplest existing endpoint/function and asserts a real response — not a placeholder `assert true`
  - Frontend (when `project.shape` includes one): loads the home/entry page with Playwright and asserts something real rendered
- Runs the new test and confirms it passes before reporting done
- Updates `.agenthub-config.yaml`: `test.folders`, `test.acceptance-framework`, `test.command`, and the relevant `*-command` keys, replacing any `REPLACE_ME` placeholder or guessed fallback (e.g. `echo 'no test command configured'`) left by `agent-hub-detect.sh`

# What it cannot do

- Write feature-specific or acceptance tests — that is `test-verifier`'s job once a feature exists
- Chase full coverage — that is the coverage-raising agent's job once a framework exists
- Restructure the project's source layout — if `backend.folders`/`frontend.folders` themselves are unconfirmed (not just `test.folders`), stop and tell the user to fix the layout first; a test framework bolted onto an unclear layout tests the wrong things
- Invent a test command the project can't actually run (e.g. assuming a CI-only secret or service is available locally) — if the smoke test needs something unavailable, report that instead of faking green
- Modify existing tests or existing test configuration — only fills genuine gaps

# Inputs it expects

- `.agenthub-config.yaml` (or `00-config-resolved.md` if invoked inside feature-factory) — shape, language, framework, folders
- The specific list of sections `agent-hub-detect.sh` flagged as unconfirmed (`backend.folders`, `frontend.folders`, `test.folders`) — this agent only proceeds when the gap is in `test.folders`/`test.command`/`test.acceptance-framework`; a gap in `backend.folders` or `frontend.folders` means the layout problem comes first

# Output contract

- **Framework installed** — name, version, and the manifest file changed (`package.json`, `pyproject.toml`, `pom.xml`, `.csproj`, etc.)
- **Test file(s) added** — path to each smoke test, one per side
- **Test run result** — the actual command run and its pass/fail output (must be PASS to report done)
- **Config updated** — the exact `.agenthub-config.yaml` keys changed, before/after
- **Follow-up note** — one line stating this is a smoke test, not coverage, and naming the next step (`test-verifier` inside `/feature-factory`, or a coverage agent for existing code)

# Project-specific config

Reads `.agenthub-config.yaml` keys:
- `project.shape` — determines whether a frontend smoke test is needed
- `project.language` / `project.framework` — determines framework choice
- `backend.folders` / `frontend.folders` — must already be confirmed (not `REPLACE_ME`); stop if not
- `test.folders` / `test.acceptance-framework` / `test.command` — the keys this agent fills in

# Failure modes

- **`backend.folders` or `frontend.folders` is still `REPLACE_ME`.** Stop. Tell the user the layout needs to be confirmed before a test framework can be scoped to it.
- **A test framework already exists but wasn't detected** (e.g. config present but stale). Report the mismatch and ask before installing a second, conflicting framework.
- **The simplest endpoint/function needs a dependency the agent can't provide** (database, external API key). Write the smoke test against whatever is mockable with what's already in the repo, and report clearly if nothing is testable without new infrastructure — do not fabricate a passing result.
- **Install fails** (network, registry, version conflict). Report the exact command and error; do not fall back to silently skipping the framework choice.

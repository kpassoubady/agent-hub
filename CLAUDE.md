# Agent Hub — CLAUDE.md

A personal hub of reusable Claude Code agents, skills, and rules. Current version: see `VERSION`.

## Repository layout

```
agents/          one .md file per agent — the 7-agent factory chain
skills/          multi-step orchestrators (feature-factory, loop-engine, graph-engine)
hooks/           reusable git hooks (block-secrets.sh)
templates/       skeletons: agent-template.md, loop-template.md, loop-config-schema.yaml, graph-template.md
diagrams/        mermaid diagrams for the chain, distribution, drift loop, loop framework, graph engine
docs/            loop-guide.md, graph-guide.md, and other references
llm-context/     LLM-readable context bundles (not installed; informational only)
install.sh       macOS/Linux installer — copies modules to ~/.claude/
install.ps1      Windows PowerShell installer
sync-windsurf.sh Windsurf workspace sync (symlinks by default)
sync-github-copilot.sh / .ps1  GitHub Copilot workspace sync
agent-hub-detect.sh  auto-generate .agenthub-config.yaml for any project
VERSION          semver tag for the hub
CHANGELOG.md     release notes
```

## Agents

Each agent is a single markdown file under `agents/` with YAML frontmatter.

Required frontmatter fields:

```yaml
---
name: <agent-name>           # kebab-case, matches filename
version: 0.1.0               # semver; bump on any behaviour change
hub-source: agent-hub
description: <one sentence>
tools: Read, Grep, Glob      # comma-separated Claude Code tool names
scope: read-only | backend | frontend | test | other
model: haiku | sonnet | opus
inputs:
  - <input 1>
human-checkpoint: true | false
---
```

Agent body sections (in order): `# Job`, `# What it does`, `# What it cannot do`, `# Inputs it expects`, `# Output contract`, `# Project-specific config`, `# Failure modes`.

Use `templates/agent-template.md` as the starting point for new agents.

## Skills

Each skill lives in `skills/<name>/SKILL.md` with frontmatter (`name`, `version`, `hub-source`, `description`). Skills orchestrate agents; they do not implement features directly.

The `loop-engine` skill provides the generic loop protocol `DISCOVER → PLAN → EXECUTE → VERIFY → ITERATE`. New iterative skills should use it rather than re-implementing retry logic. See `docs/loop-guide.md` and `templates/loop-template.md`.

The `graph-engine` skill provides the generic multi-node protocol (nodes, edges, parallel fan-out/fan-in, reality anchors) for skills that need more than one loop — e.g. concurrent independent agents that reconcile before continuing. It composes `loop-engine` for each node's own retries, and maps onto Claude Code's native dynamic-workflow primitives (`agent()`, `parallel()`) when available. New skills with more than one node should use it rather than hand-writing fan-out prose. See `docs/graph-guide.md` and `templates/graph-template.md`.

## Project-specific configuration consumed by the agents

Consuming projects place `.agenthub-config.yaml` at their root. Run `./agent-hub-detect.sh` from the hub against any project to auto-generate it. Schema v2:

```yaml
project:
  shape: full-stack | backend-only | frontend-only | library
  language: node
  framework: vite
backend:
  folders: [...]
  test-command: "..."
  typecheck-command: "..."
  lint-command: "..."
frontend:
  folders: [...]
  ...
test:
  folders: [...]
  acceptance-framework: playwright
  command: "..."
build:
  parallel-builders: auto | always | never   # default auto
```

`project.shape` controls which agents run. Missing config → agents assume `full-stack` and warn once. `build.parallel-builders` controls whether `feature-factory`'s backend/frontend step (Step 4) runs sequentially or in parallel; `auto` defers to `spec-writer`'s per-feature `API contract confidence` line.

## What belongs here

Only generic agents that work in any repo after reading that repo's `CLAUDE.md`. Do NOT add:
- Project-specific agents (live in that project's repo)
- Personal or private agents (live in `~/.claude/agents/` or a private overlay)
- Credentials or secrets
- Feature-factory run state (`<project>/.claude/feature-factory/` — gitignored in consuming projects)

## Formatting conventions

- Markdown linting: governed by `.markdownlint.json` (permissive — most rules off; MD001 and MD047 enforced).
- Agent filenames: `kebab-case.md`.
- No trailing whitespace required; line length unrestricted (MD013 off).
- Mermaid diagrams go in `diagrams/` as standalone `.md` files.

## Versioning and releases

- Hub-wide semver in `VERSION`. Bump it and add an entry to `CHANGELOG.md` for every release.
- Individual agent files also carry `version:` in frontmatter — bump the agent version on any behaviour change, independently of the hub version.
- Commit message style: `feat:`, `fix:`, `chore:`, `docs:` prefixes; scope optional.

## Installation (for reference)

```bash
./install.sh          # install all modules to ~/.claude/
./install.sh -d       # dry-run
./install.sh -f       # force overwrite
./install.sh -p /path # per-project install to /path/.claude/
```

After install, `/feature-factory <description>` in Claude Code launches the orchestrator.

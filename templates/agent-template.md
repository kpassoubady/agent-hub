---
name: <agent-name>
version: 0.1.0
hub-source: agent-hub
description: <one-sentence description of what the agent does>
tools: <comma-separated list — e.g., Read, Grep, Glob>
scope: <read-only | backend | frontend | test | other>
model: <haiku | sonnet | opus>
inputs:
  - <input 1>
  - <input 2>
human-checkpoint: <true | false>
---

# Job

<One sentence. What problem does this agent solve?>

# What it does

- <Action 1>
- <Action 2>

# What it cannot do

- <Hard constraint 1>
- <Hard constraint 2>

# Inputs it expects

- <Input 1 with description>
- <Input 2 with description>

# Output contract

<Describe the structure of the agent's output. Be specific — downstream agents may depend on it.>

# Project-specific config

Reads `.agenthub-config.yaml` keys:
- `<key>` — <what it does>

# Failure modes

- **<Failure 1>.** <What the agent does about it.>
- **<Failure 2>.** <What the agent does about it.>

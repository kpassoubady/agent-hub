# Diagrams

Visual explanations of how the agent hub works. All diagrams use [Mermaid](https://mermaid.js.org) and render natively on GitHub — no images to maintain.

| Diagram | Shows |
|---|---|
| [01-factory-chain.md](01-factory-chain.md) | The 7-agent factory chain, three human checkpoints, and the loop-back paths |
| [02-distribution.md](02-distribution.md) | How a single hub feeds Claude Code (global install) and Windsurf (per-workspace sync) |
| [03-drift-loop.md](03-drift-loop.md) | How real-project surprises become hub improvements that benefit every consuming project |
| [04-loop-framework.md](04-loop-framework.md) | The generic loop lifecycle: 5 phases, 3 operating modes, escalating context, and state persistence |

## Editing

Open the source `.md` file and modify the ` ```mermaid ` block. GitHub re-renders on push.

To preview locally before pushing:
- VS Code: Markdown Preview Mermaid Support extension.
- CLI: `mmdc -i diagram.md -o diagram.png` (requires [mermaid-cli](https://github.com/mermaid-js/mermaid-cli)).

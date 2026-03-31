---
name: sqry-codex
version: 6.0.0
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with OpenAI Codex CLI. Covers installation, MCP configuration via `~/.codex/config.toml`, and recommended patterns for code analysis tasks. Install this skill to give Codex access to sqry's 33 AST-based code analysis tools.
---

# sqry for OpenAI Codex

This skill configures the Codex CLI agent to use sqry's MCP server for AST-based semantic code search across 35 languages.

## Setup

### 1. Install sqry

```bash
# Recommended: signed release installer
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all

# Fallback: build from source
cargo install sqry-cli
cargo install sqry-mcp

# Alternative package manager
brew install verivus-oss/sqry/sqry
```

### 2. Index your project

```bash
cd /path/to/your/project
sqry index .
```

### 3. Configure MCP server

Recommended:

```bash
sqry mcp setup --tool codex
sqry mcp status
```

This writes a global entry to `~/.codex/config.toml`:

```toml
[mcp_servers.sqry]
command = "/absolute/path/to/sqry-mcp"
```

Codex uses global MCP config and CWD-based workspace discovery. Start Codex
from the project directory you want to analyze.

### 4. Verify

After restarting Codex, test with:

> "Use sqry to show graph stats for this project"

## Tool Naming in Codex

Codex uses the `mcp__sqry__` prefix for sqry MCP tools:

```
mcp__sqry__semantic_search
mcp__sqry__relation_query
mcp__sqry__dependency_impact
mcp__sqry__explain_code
mcp__sqry__trace_path
...
```

## Recommended AGENTS.md Addition

Add this to your project's `AGENTS.md` or `CODEX.md`:

```markdown
## Code Search

Use sqry MCP tools for semantic code search:
- `mcp__sqry__semantic_search` - Find symbols by structure
- `mcp__sqry__relation_query` - Find callers, callees, imports
- `mcp__sqry__dependency_impact` - Analyze change impact
- `mcp__sqry__explain_code` - Understand a symbol with context

Use `rg` for literal text search. Use sqry for everything structural.
```

## Workflow

1. Use `mcp__sqry__semantic_search` or `mcp__sqry__pattern_search` to discover relevant code before reading files.
2. Use `mcp__sqry__dependency_impact` before modifying shared symbols.
3. Run the narrowest relevant tests first, then broader checks for shared paths.
4. Report files changed, behavior impact, and tests run in handoff.

## Common Codex Patterns

### Find and understand a symbol

```
1. mcp__sqry__semantic_search   query: "kind:function name:process_order"
2. mcp__sqry__explain_code      file_path: "src/orders.rs", symbol_name: "process_order"
3. mcp__sqry__direct_callers    symbol: "process_order"
```

### Pre-change impact analysis

```
1. mcp__sqry__dependency_impact  symbol: "shared_utility", max_depth: 3
2. mcp__sqry__find_cycles        (check for circular deps)
3. Make changes
4. mcp__sqry__semantic_diff      base: {ref: "main"}, target: {ref: "HEAD"}
```

## Troubleshooting

- **No tools visible**: Restart Codex after running `sqry mcp setup --tool codex`
- **Empty results**: Run `sqry index .` to build the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Check health**: Call `mcp__sqry__get_index_status`

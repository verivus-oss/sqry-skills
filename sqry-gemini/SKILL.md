---
name: sqry-gemini
version: 4.8.16
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Gemini CLI. Covers installation, MCP configuration via settings.json, context file behavior, and recommended patterns. Install this skill to give Gemini CLI access to sqry's 33 AST-based code analysis tools.
---

# sqry for Gemini CLI

This skill configures the Gemini CLI agent to use sqry's MCP server for AST-based semantic code search across 35 languages.

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
sqry mcp setup --tool gemini
sqry mcp status
```

This writes a global entry to `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "sqry": {
      "command": "/absolute/path/to/sqry-mcp",
      "args": [],
      "env": {}
    }
  }
}
```

Gemini uses CWD-based workspace discovery by default. Start Gemini from the
project directory you want to analyze.

### 4. Verify

After restarting Gemini CLI, test with:

> "Use sqry to show graph stats for this project"

## Tool Naming in Gemini CLI

Gemini CLI uses the `mcp__sqry__` prefix for sqry MCP tools:

```
mcp__sqry__semantic_search
mcp__sqry__relation_query
mcp__sqry__dependency_impact
mcp__sqry__explain_code
mcp__sqry__trace_path
...
```

## Recommended GEMINI.md Addition

Add this to your project's `GEMINI.md`:

```markdown
## Code Search

Use sqry MCP tools for semantic code search:
- `mcp__sqry__semantic_search` - Find symbols by structure
- `mcp__sqry__relation_query` - Find callers, callees, imports
- `mcp__sqry__dependency_impact` - Analyze change impact
- `mcp__sqry__explain_code` - Understand a symbol with context

Use grep/rg for literal text search. Use sqry for everything structural.
```

## Workflow

1. Use `mcp__sqry__semantic_search` for fast discovery before reading files manually.
2. Use `mcp__sqry__dependency_impact` before modifying shared symbols.
3. Run focused tests first; run broader checks for shared graph, query, or plugin paths.
4. In handoff, always include changed files, impact summary, and tests run.

## Common Gemini Patterns

### Explore a codebase

```
1. mcp__sqry__get_graph_stats    (overview: languages, node/edge counts)
2. mcp__sqry__list_files         (what files are indexed)
3. mcp__sqry__semantic_search    query: "kind:function", filters: {visibility: "public"}
```

### Trace a call chain

```
1. mcp__sqry__get_definition     symbol: "handle_request"
2. mcp__sqry__direct_callees     symbol: "handle_request"
3. mcp__sqry__trace_path         from_symbol: "handle_request", to_symbol: "db_query"
```

### Pre-change safety check

```
1. mcp__sqry__dependency_impact  symbol: "UserService", max_depth: 3
2. mcp__sqry__find_cycles        (check for circular deps)
3. Make changes
4. mcp__sqry__semantic_diff      base: {ref: "main"}, target: {ref: "HEAD"}
```

## Gemini Context Notes

- Gemini defaults to loading `GEMINI.md` for project context.
- sqry MCP tools provide deeper structural understanding than what context files alone offer.
- Use `mcp__sqry__hierarchical_search` to get RAG-optimized results that include file and container grouping — this pairs well with Gemini's context window management.

## Troubleshooting

- **No tools visible**: Restart Gemini CLI after running `sqry mcp setup --tool gemini`
- **Empty results**: Run `sqry index .` to build the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Check health**: Call `mcp__sqry__get_index_status`

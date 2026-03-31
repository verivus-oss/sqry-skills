---
name: sqry-claude
version: 6.0.0
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Claude Code. Covers installation, MCP configuration, tool naming conventions, and recommended search patterns. Install this skill to give Claude Code full access to sqry's 33 AST-based code analysis tools.
---

# sqry for Claude Code

This skill configures Claude Code to use sqry's MCP server for AST-based semantic code search across 35 languages.

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
sqry mcp setup --tool claude
sqry mcp status
```

This writes a Claude Code entry in `.claude.json` or `~/.claude.json`
pointing to `sqry-mcp`. Claude defaults to per-project configuration with
`SQRY_MCP_WORKSPACE_ROOT` pinned to the current repository.

Manual config example:

```json
{
  "mcpServers": {
    "sqry": {
      "type": "stdio",
      "command": "/absolute/path/to/sqry-mcp",
      "env": {
        "SQRY_MCP_WORKSPACE_ROOT": "/path/to/your/project"
      }
    }
  }
}
```

### 4. Verify

After restarting Claude Code, tools should appear with the `mcp__sqry__` prefix. Test with:

> "Use sqry to show graph stats for this project"

This should invoke `mcp__sqry__get_graph_stats` and return node/edge counts.

## Skill Dependency

This skill covers Claude Code setup and integration patterns. For comprehensive tool selection guidance, query syntax, disambiguation strategies, output size management, and security audit workflows, **also load the `sqry-semantic-search` skill**. That skill is the primary reference for how to use sqry effectively.

If you find yourself unsure which tool to use, or getting empty/wrong results, consult sqry-semantic-search before retrying.

## Quick Tool Selection

**I know the symbol name and want to...**
- See its definition → `mcp__sqry__get_definition`
- See who calls it → `mcp__sqry__direct_callers` (depth=1) or `mcp__sqry__relation_query` (multi-depth)
- See what it calls → `mcp__sqry__direct_callees`
- See what breaks if I change it → `mcp__sqry__dependency_impact`
- Understand it with context → `mcp__sqry__explain_code`

**I want to search for symbols...**
- By name substring → `mcp__sqry__pattern_search`
- By kind/visibility/language → `mcp__sqry__semantic_search`
- With RAG-optimized grouping → `mcp__sqry__hierarchical_search`

**I want to analyze the codebase...**
- Circular dependencies → `mcp__sqry__find_cycles`
- Dead code → `mcp__sqry__find_unused`
- Change impact → `mcp__sqry__dependency_impact`
- Trace call path A→B → `mcp__sqry__trace_path`

## Handling Ambiguous Symbols

When using `mcp__sqry__direct_callers`, `mcp__sqry__direct_callees`, or `mcp__sqry__call_hierarchy` with common names (`handle`, `new`, `init`, `process`, `run`), the tool may fail or return wrong results.

**Always disambiguate** by providing `file_path`:

```json
{
  "symbol": "handle",
  "file_path": "src/api/router.rs"
}
```

Or use a qualified name: `"symbol": "UserService::authenticate"`

If relation tools fail, fall back to `mcp__sqry__get_references` with a `path` filter to scope results.

## Tool Naming in Claude Code

All sqry MCP tools use the `mcp__sqry__` prefix in Claude Code:

```
mcp__sqry__semantic_search
mcp__sqry__relation_query
mcp__sqry__dependency_impact
mcp__sqry__explain_code
mcp__sqry__trace_path
mcp__sqry__find_cycles
...
```

## Recommended CLAUDE.md Addition

Add this to your project's `CLAUDE.md` to guide Claude on when to use sqry:

```markdown
## Code Search

Use sqry MCP tools (`mcp__sqry__*`) as the default for semantic code search:
- `mcp__sqry__semantic_search` - Find symbols by meaning
- `mcp__sqry__hierarchical_search` - RAG-optimized search with grouping
- `mcp__sqry__relation_query` - Find callers, callees, imports
- `mcp__sqry__explain_code` - Understand a symbol with context

Use Grep for literal text search. Use Glob for file finding. Use sqry for everything structural.
```

## Workflow

1. **Search first**: Use `mcp__sqry__semantic_search` or `mcp__sqry__hierarchical_search` before reading files manually.
2. **Understand before changing**: Call `mcp__sqry__dependency_impact` before modifying shared code.
3. **Trace relationships**: Use `mcp__sqry__direct_callers` and `mcp__sqry__direct_callees` to understand call chains.
4. **Verify after changes**: Use `mcp__sqry__semantic_diff` to compare before/after at the symbol level.

## Common Claude Code Patterns

### Find a function and its callers

```
User: "Who calls the authenticate function?"

Claude uses: mcp__sqry__relation_query
  symbol: "authenticate"
  relation_type: "callers"
  max_depth: 2
```

### Understand impact before refactoring

```
User: "What would break if I change UserService?"

Claude uses: mcp__sqry__dependency_impact
  symbol: "UserService"
  max_depth: 3
  include_indirect: true
```

### Explore unfamiliar code

```
User: "Help me understand the auth module"

Claude uses:
1. mcp__sqry__semantic_search  query: "path:src/auth"
2. mcp__sqry__explain_code     file_path: "src/auth/mod.rs", symbol_name: "authenticate"
3. mcp__sqry__subgraph         symbols: ["authenticate", "verify_token"]
```

## Troubleshooting

- **No tools visible**: Restart Claude Code after running `sqry mcp setup --tool claude`
- **Empty results**: Run `sqry index .` to build/rebuild the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Check health**: Ask Claude to call `mcp__sqry__get_index_status`

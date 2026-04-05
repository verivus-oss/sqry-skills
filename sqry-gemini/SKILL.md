---
name: sqry-gemini
version: 7.1.4
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Gemini CLI. Covers installation, MCP configuration via settings.json, context file behavior, and recommended patterns. Install this skill to give Gemini CLI access to sqry's 34 AST-based code analysis tools.
---

# sqry for Gemini CLI

This skill configures the Gemini CLI agent to use sqry's MCP server for AST-based semantic code search across 37 languages.

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

## Skill Dependency

This skill covers Gemini CLI setup and integration patterns. **Also load the `sqry-semantic-search` skill** for tool selection guidance, query syntax, and disambiguation strategies.

sqry-semantic-search uses tiered discovery to save tokens: it loads a compact Quick Tool Selection guide first. If you need full parameter details, load `sqry-semantic-search/references/tool-reference.md`. For advanced workflows (security audit, pre-change analysis), load `sqry-semantic-search/references/workflows.md`. Only load what you need.

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

## Recent Features (since v6.0)

### Plugin cost tiering
- Plugins classified as `Fast` (default) or `HighWallClock`
- High-cost plugins (JSON, ServiceNow XML) excluded from default index
- CLI: `--include-high-cost` / `--exclude-high-cost`, `--enable-plugin ID` / `--disable-plugin ID`
- Env: `SQRY_INCLUDE_HIGH_COST=1`

### Time-expensive MCP operations
- `rebuild_index`: 10min timeout, full graph rebuild -- only when index stale
- `semantic_diff`: creates git worktrees + indexes -- scope with file/kind filters
- `find_cycles`, `complexity_metrics`: can timeout on large graphs -- scope to files
- `find_duplicates`: quadratic scaling -- filter by file/language/kind
- `call_hierarchy` depth>2, `dependency_impact` depth>3: exponential growth

### Macro boundary analysis (Rust)
- CLI: `sqry cache expand`, `--enable-macro-expansion`, `--cfg`, `--cfg-filter`, `--include-generated`, `--macro-boundaries`
- MCP: `mcp__sqry__expand_cache_status` tool, macro metadata in search/definition results

### JVM classpath analysis
- CLI: `--classpath`, `--classpath-depth`, `--classpath-file`
- MCP: `include_classpath` parameter on search tools, `provenance` field in results

### Security defaults
- MCP redaction preset now `"minimal"` by default (was `"none"`)
- Override: `SQRY_REDACTION_PRESET=none`
- Index timeout: 600s, query timeout: 60s

### Other
- 37 language plugins (added JSON, ServiceNow XML)
- Snapshot format V7 -- rebuild index on major version upgrade
- Multi-root VS Code workspace support

## Troubleshooting

- **No tools visible**: Restart Gemini CLI after running `sqry mcp setup --tool gemini`
- **Empty results**: Run `sqry index .` to build the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Snapshot version mismatch**: Run `rm -rf .sqry/graph && sqry index .` after major upgrades
- **Missing JSON/ServiceNow symbols**: Rebuild with `sqry index --include-high-cost`
- **Check health**: Call `mcp__sqry__get_index_status`

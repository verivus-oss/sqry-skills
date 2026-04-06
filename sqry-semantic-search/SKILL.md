---
name: sqry-semantic-search
version: 8.0.0
description: |
  AST-based semantic code search skill for AI agents. Teaches agents to use sqry's MCP tools for finding symbols by structure, tracing relationships, analyzing dependencies, and detecting code quality issues. Unlike embedding-based search, sqry parses code like a compiler. Tool reference and query syntax are served live by the sqry-mcp binary — always current with your installed version.
---

# sqry Semantic Code Search Skill

Use this skill when users ask to:
- Find functions, classes, methods, or variables by name or kind
- Trace call relationships (callers, callees, call paths)
- Analyze code dependencies and impact of changes
- Find duplicate code, circular dependencies, or unused symbols

## What Makes sqry Different

**sqry uses "semantic" in the compiler sense, not the NLP sense.** It parses code like a compiler using AST analysis and graph queries — not ML embeddings over text.

## Setup

Requires **sqry >= 4.0**. If you are on an older version, upgrade:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
sqry index .
sqry mcp setup --tool claude   # or codex, gemini
sqry mcp status
```

## Live Documentation (from sqry MCP server)

Tool reference, query syntax, and workflow recipes are served by the sqry-mcp binary. They always match your installed version.

**First, confirm the server is connected** by reading `sqry://meta/manifest`. If this succeeds, you'll see the installed version, tool count, and language count as JSON.

**Error handling:**
- **Transport error** (connection refused, timeout): the MCP server is not running. See Troubleshooting below.
- **Resource not found (404) on manifest**: the server is an older version. Fall back to `sqry://docs/tool-guide` (available since v4.0).
- **404 on BOTH manifest AND tool-guide**: server is pre-v4.0. Tell the user to upgrade.

| I need to... | Read this MCP resource |
|-------------|----------------------|
| Find the right tool for my task | `sqry://docs/capability-map` |
| See full tool parameters | `sqry://docs/tool-guide` |
| Write a search query | `sqry://docs/query-syntax` |
| Follow a workflow recipe | `sqry://docs/patterns` |
| Understand the graph internals | `sqry://docs/architecture` |
| Check installed version and counts | `sqry://meta/manifest` |

## Handling Ambiguous Symbols

When names like `new`, `init`, `handle`, `process` exist in multiple files:

1. **Scope with `file_path`**: `{ "symbol": "handle", "file_path": "src/api/router.rs" }`
2. **Use qualified names**: `"symbol": "UserService::authenticate"`
3. **Fall back to `get_references`** with `path` filter when relation tools fail
4. **Search first**: Use `semantic_search` with `kind:` + `name:` + `path:` to find the exact symbol, then use its qualified name

**Rule of thumb**: If the name could exist in more than one file, always provide `file_path` or use a qualified name.

## Output Size Tips

Some tools produce large output. Always **start narrow, expand if needed**:
- Use `direct_callers` (depth=1) before `call_hierarchy` (full tree)
- Set `max_results`, `max_depth`, or `max_nodes` conservatively first
- Add `path`, `kind`, or `language` filters to reduce noise
- Prefer `get_hover_info` over `explain_code` for quick lookups

## When NOT to Use sqry

- **Literal text search**: Use grep/rg for exact text patterns
- **File finding**: Use find/glob for file names
- **Reading files**: Use cat/read for file contents
- **Code execution**: sqry only searches, doesn't run code

## Troubleshooting

- **No tools visible**: Restart your agent after running `sqry mcp setup --tool <agent>`
- **Empty results**: Run `sqry index .` to build/rebuild the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Snapshot version mismatch**: Run `rm -rf .sqry/graph && sqry index .` after major upgrades
- **Missing JSON/ServiceNow symbols**: Rebuild with `sqry index --include-high-cost`

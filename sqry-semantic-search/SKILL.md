---
name: sqry-semantic-search
version: 13.0.7
description: |
  AST-based semantic code search skill for AI agents. Teaches agents to route code search tasks to sqry MCP resources and tools without duplicating version-specific tool reference. Unlike embedding-based search, sqry parses code like a compiler.
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

Requires **sqry >= 4.0** for MCP resources. Use the latest sqry release for
the current MCP catalogue, workspace-aware resolution, and daemon-backed
operation. If you are on an older version, upgrade:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
sqry index .
sqry mcp setup --tool claude   # or codex, gemini
sqry mcp status
```

For repeated agent sessions, prefer daemon-backed MCP:

```bash
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
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

## Workspace-Aware Usage

sqry can resolve a logical workspace from a `.sqry-workspace` registry or a
VS Code `.code-workspace` file containing `sqry.workspace`.

When working in a multi-root session:

1. Prefer explicit `path` or file-bearing arguments when the target source root
   is ambiguous.
2. Use `sqry workspace status <workspace> --json --no-cache` outside MCP to
   inspect source-root health.
3. For MCP calls, rely on session-scoped resolution in this order: explicit
   `path`, file-bearing arguments, MCP roots, last-resolved workspace, then
   legacy environment/CWD fallback.

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

sqry-mcp truncates serialised tool responses at **50 000 bytes** by default
(UTF-8 boundary safe). Override with `SQRY_MCP_MAX_OUTPUT_BYTES=<n>` when
your transport accepts larger payloads.

## Version-Specific Capabilities

Do not rely on this skill for a static tool list. Read `sqry://meta/manifest`
to confirm the installed server version and counts, then read
`sqry://docs/capability-map` and `sqry://docs/tool-guide` for current tools,
parameters, limits, and workflow guidance.

## When NOT to Use sqry

- **Literal text search**: Use grep/rg for exact text patterns
- **File finding**: Use find/glob for file names
- **Reading files**: Use cat/read for file contents
- **Code execution**: sqry only searches, doesn't run code

## Troubleshooting

- **No tools visible**: Restart your agent after running `sqry mcp setup --tool <agent>`
- **Empty results**: Run `sqry index .` to build/rebuild the index
- **Stale results or graph-format upgrade**: Run `sqry index --force .` to force rebuild
- **Corrupt snapshot after force rebuild**: Run `rm -rf .sqry/graph && sqry index .`
- **Missing JSON/ServiceNow symbols**: Rebuild with `sqry index --include-high-cost`

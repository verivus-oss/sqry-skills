---
name: sqry-claude
version: 20.0.5
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Claude Code. Covers installation, MCP configuration, tool naming conventions, CLI fallback, and troubleshooting. Tool reference and query syntax are served live by sqry-mcp.
---

# sqry for Claude Code

Use this skill to configure Claude Code for sqry v20.0.5 MCP-backed semantic code search.

## Setup

Install or upgrade sqry:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
sqry --version
sqry-mcp --version
sqry-lsp --version
sqryd --version
```

Index the project:

```bash
cd /path/to/your/project
sqry index .
sqry index --status --json .
```

Configure Claude Code:

```bash
sqry mcp setup --tool claude
sqry mcp status
```

This writes a Claude Code entry in `.claude.json` or `~/.claude.json` pointing to `sqry-mcp`.
Restart Claude Code after setup so it reloads MCP servers.

Manual config:

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

### MCP mode: standalone vs daemon

**Default:** standalone `sqry-mcp` (no `--daemon`, or `--no-daemon`). Serves **39 tools** and **6 MCP resources** including `sqry://meta/manifest` and `sqry://docs/*`.

**Daemon** (`sqry-mcp --daemon`) warms the graph for long sessions but exposes only a **17-tool subset** and **zero MCP resources** — agents cannot read `sqry://meta/manifest` or docs on the daemon path. Do not configure daemon then instruct reading MCP resources in the same workflow.

```bash
# Standalone — full tools + resources (preferred)
sqry-mcp --no-daemon

# Daemon — warm graph, reduced tools, no resources
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

Add `"args": ["--daemon"]` only when you accept the 17-tool, no-resource tradeoff.

## Skill Dependency

Also load `sqry-semantic-search`. It contains the shared routing rules, CLI fallback commands, ambiguity handling, output-size limits, and rebuild recovery steps.

## Tool Naming

Claude Code commonly exposes sqry MCP tools with the `mcp__sqry__` prefix, for example `mcp__sqry__semantic_search` and `mcp__sqry__get_graph_stats`.

Read `sqry://meta/manifest` first when resources are available, then use `sqry://docs/capability-map` and `sqry://docs/tool-guide` for the exact installed tool surface.

## CLI Fallback

If Claude Code cannot see sqry MCP tools after setup or before restart, use:

```bash
sqry query 'kind:function AND name:authenticate' --json
sqry graph direct-callers "AuthService::authenticate" --json
sqry impact "AuthService::authenticate" --json
```

## Recommended CLAUDE.md Addition

```markdown
## Code Search

Use sqry MCP tools (`mcp__sqry__*`) for semantic code search.
Read `sqry://docs/capability-map` to find the right tool.
Use `sqry` CLI as fallback when MCP is unavailable.
Use Grep for literal text search and Glob for file finding.
```

## Troubleshooting

- No tools visible: restart Claude Code after `sqry mcp setup --tool claude`.
- Empty results: run `sqry index .` from the project root, or `sqry index --force .` after an upgrade or stale graph warning.
- Stale graph or unknown plugin IDs: remove `.sqry/graph`, `.sqry/graphs`, and `.sqry/analysis`, then rebuild.
- Transport error on resource read: MCP server is not running or not configured.
- 404 on `sqry://meta/manifest`: old server version; upgrade sqry, or switch to standalone `sqry-mcp --no-daemon` (daemon serves zero resources).

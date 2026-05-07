---
name: sqry-claude
version: 13.0.7
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Claude Code. Covers installation, MCP configuration, tool naming conventions, and troubleshooting. Tool reference and query syntax are served live by the sqry-mcp binary.
---

# sqry for Claude Code

This skill configures Claude Code to use sqry's MCP server for AST-based semantic code search.

## Setup

Requires **sqry >= 4.0** for MCP resources. Use the latest sqry release for
the current MCP catalogue, LSP capabilities, workspace-aware resolution, and
daemon-backed operation.

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
cd /path/to/your/project
sqry index .
sqry mcp setup --tool claude
sqry mcp status
```

This writes a Claude Code entry in `.claude.json` or `~/.claude.json` pointing to `sqry-mcp`.

For long-running sessions or large repositories, run MCP through the daemon:

```bash
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

Manual config:

```json
{
  "mcpServers": {
    "sqry": {
      "type": "stdio",
      "command": "/absolute/path/to/sqry-mcp",
      "env": { "SQRY_MCP_WORKSPACE_ROOT": "/path/to/your/project" }
    }
  }
}
```

To use daemon-backed MCP manually, add `"args": ["--daemon"]` to the server
entry. If the daemon is not already running, `sqry-mcp --daemon` auto-starts it
unless `SQRY_DAEMON_NO_AUTO_START=1` is set.

Verify: after restarting Claude Code, ask "Use sqry to show graph stats for this project" — this should invoke `mcp__sqry__get_graph_stats`.

## Skill Dependency

**Also load the `sqry-semantic-search` skill** for disambiguation tips, output size guidance, and the MCP resource routing table.

## Tool Naming

All sqry MCP tools use the `mcp__sqry__` prefix in Claude Code.

## Reading MCP Resources

Claude Code reads sqry resources via `ReadMcpResourceTool`. The routing table in sqry-semantic-search tells you which resource to read for each task.

## Recommended CLAUDE.md Addition

```markdown
## Code Search

Use sqry MCP tools (`mcp__sqry__*`) for semantic code search.
Read `sqry://docs/capability-map` to find the right tool.
Use Grep for literal text search. Use Glob for file finding.
```

## Troubleshooting

- **No tools visible**: Restart Claude Code after `sqry mcp setup --tool claude`
- **Empty results**: Run `sqry index .` to build the index
- **Stale results or graph-format upgrade**: Run `sqry index --force .` to force rebuild
- **Corrupt snapshot after force rebuild**: Run `rm -rf .sqry/graph && sqry index .`
- **Transport error on resource read**: MCP server not running — check `sqry mcp status`
- **404 on `sqry://meta/manifest`**: Old server version — resources still available via `sqry://docs/tool-guide`

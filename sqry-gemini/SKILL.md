---
name: sqry-gemini
version: 10.0.1
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Gemini CLI. Covers installation, MCP configuration, and troubleshooting. Tool reference and query syntax are served live by the sqry-mcp binary.
---

# sqry for Gemini CLI

This skill configures the Gemini CLI agent to use sqry's MCP server for AST-based semantic code search.

## Setup

Requires **sqry >= 4.0** for MCP resources. Use **sqry >= 10.0.1** for
workspace-aware status and daemon-backed MCP workflows.

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
cd /path/to/your/project
sqry index .
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

Gemini uses sqry-mcp's session-scoped workspace resolution: explicit `path`
arguments first, then file-bearing arguments, MCP roots, last-resolved
workspace, and finally legacy environment/CWD fallback. Start Gemini from the
project directory for the simplest single-repo flow.

For long-running sessions or large repositories, run MCP through the daemon:

```bash
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

To use daemon-backed MCP from Gemini config, set `"args": ["--daemon"]` under
the `sqry` MCP server entry.

## Skill Dependency

**Also load the `sqry-semantic-search` skill** for disambiguation tips, output size guidance, and the MCP resource routing table.

## Tool Naming

Gemini CLI uses the `mcp__sqry__` prefix for sqry MCP tools.

## Reading MCP Resources

Gemini reads sqry resources via its MCP integration. The routing table in sqry-semantic-search tells you which resource to read for each task.

## Recommended GEMINI.md Addition

```markdown
## Code Search

Use sqry MCP tools for semantic code search.
Read `sqry://docs/capability-map` to find the right tool.
Use grep/rg for literal text search.
```

## Troubleshooting

- **No tools visible**: Restart Gemini CLI after `sqry mcp setup --tool gemini`
- **Empty results**: Run `sqry index .` to build the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Snapshot mismatch**: Run `rm -rf .sqry/graph && sqry index .` after major upgrades
- **Transport error on resource read**: MCP server not running — check `sqry mcp status`
- **404 on `sqry://meta/manifest`**: Old server version — resources still available via `sqry://docs/tool-guide`

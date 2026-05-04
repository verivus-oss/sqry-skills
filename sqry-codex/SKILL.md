---
name: sqry-codex
version: 12.1.6
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with OpenAI Codex CLI. Covers installation, MCP configuration, and troubleshooting. Tool reference and query syntax are served live by the sqry-mcp binary.
---

# sqry for OpenAI Codex

This skill configures the Codex CLI agent to use sqry's MCP server for AST-based semantic code search.

## Setup

Requires **sqry >= 4.0** for MCP resources. Use **sqry >= 12.1.6** for the
36-tool MCP catalogue (adds `workspace_status`, `sqry_query`, and
`expand_cache_status`) and daemon-backed workspace status.

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
cd /path/to/your/project
sqry index .
sqry mcp setup --tool codex
sqry mcp status
```

This writes a global entry to `~/.codex/config.toml`:

```toml
[mcp_servers.sqry]
command = "/absolute/path/to/sqry-mcp"
```

Codex uses global MCP config. sqry-mcp resolves workspaces session-scoped:
explicit `path` arguments first, then file-bearing arguments, MCP roots,
last-resolved workspace, and finally legacy environment/CWD fallback.
Start Codex from the project directory for the simplest single-repo flow.

For long-running sessions or large repositories, run MCP through the daemon:

```bash
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

To use daemon-backed MCP from Codex config, add `args = ["--daemon"]` under
`[mcp_servers.sqry]`.

## Skill Dependency

**Also load the `sqry-semantic-search` skill** for disambiguation tips, output size guidance, and the MCP resource routing table.

## Tool Naming

Codex uses the `mcp__sqry__` prefix for sqry MCP tools.

## Reading MCP Resources

Codex reads sqry resources via its built-in MCP client. The routing table in sqry-semantic-search tells you which resource to read for each task.

## Recommended AGENTS.md Addition

```markdown
## Code Search

Use sqry MCP tools for semantic code search.
Read `sqry://docs/capability-map` to find the right tool.
Use `rg` for literal text search.
```

## Troubleshooting

- **No tools visible**: Restart Codex after `sqry mcp setup --tool codex`
- **Empty results**: Run `sqry index .` to build the index
- **Stale results**: Run `sqry index --force .` to force rebuild
- **Snapshot mismatch**: Run `rm -rf .sqry/graph && sqry index .` after major upgrades
- **Transport error on resource read**: MCP server not running — check `sqry mcp status`
- **404 on `sqry://meta/manifest`**: Old server version — resources still available via `sqry://docs/tool-guide`

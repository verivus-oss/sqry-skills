---
name: sqry-antigravity
version: 20.0.5
description: |
  Setup and workflow for using sqry semantic code search as an MCP server with Google Antigravity (IDE and CLI). Covers installation, MCP configuration, tool naming conventions, CLI fallback, and troubleshooting. Tool reference and query syntax are served live by sqry-mcp.
---

# sqry for Antigravity

Use this skill to configure Google Antigravity (the IDE and the `agy` CLI) for sqry v20.0.5 MCP-backed semantic code search.

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

Open Antigravity's MCP config. In the IDE: click the "…" menu in the Agent panel, choose MCP Servers, then Manage MCP Servers, then View raw config — this opens `mcp_config.json`. (Alternatively, Settings → Customizations → Open MCP Config.) The file is often at `~/.gemini/config/mcp_config.json`, which Antigravity shares with the Gemini CLI; some IDE installs use `~/.gemini/antigravity/mcp_config.json` — use "View raw config" to open whichever file is active.

Antigravity uses a single `mcpServers` object. A local (stdio) server takes a string `command` plus an `args` array and an `env` object:

```json
{
  "mcpServers": {
    "sqry": {
      "command": "/absolute/path/to/sqry-mcp",
      "args": ["--no-daemon"],
      "env": {
        "SQRY_MCP_WORKSPACE_ROOT": "/path/to/your/project"
      }
    }
  }
}
```

(For remote HTTP servers Antigravity uses `serverUrl`, not `url` — not needed for sqry's local stdio server.)

Save the file; Antigravity reloads MCP configuration automatically. If it does not pick up the change, restart Antigravity.

**Config collision:** Antigravity and Gemini CLI may share `~/.gemini/config/mcp_config.json`. If you also use `sqry-gemini`, both hosts read the same sqry entry — that is usually fine, but verify workspace roots do not pin the wrong repo.

Antigravity also supports Agent Skills across its IDE and CLI, so this skill set can be installed into Antigravity directly as well as configured as an MCP server.

### MCP mode: standalone vs daemon

**Default:** standalone `sqry-mcp` (no `--daemon`, or `--no-daemon`). Serves **37 tools** and **6 MCP resources** including `sqry://meta/manifest` and `sqry://docs/*`.

**Daemon** (`sqry-mcp --daemon`) warms the graph for long sessions but exposes only a **16-tool subset** and **zero MCP resources** — agents cannot read `sqry://meta/manifest` or docs on the daemon path. Do not configure daemon then instruct reading MCP resources in the same workflow.

```bash
# Standalone — full tools + resources (preferred)
sqry-mcp --no-daemon

# Daemon — warm graph, reduced tools, no resources
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

Set `"args": ["--daemon"]` only when you accept the 16-tool, no-resource tradeoff.

## Redaction for external LLMs

Set `SQRY_REDACTION_PRESET` in the server `env` before exposing graph results to cloud or untrusted models (`none|minimal|standard|strict`; default `minimal`). See `sqry-mcp --help` and the `sqry-mcp-redaction` README in the sqry repo.

## Skill Dependency

Also load `sqry-semantic-search`. It contains the shared routing rules, CLI fallback commands, ambiguity handling, output-size limits, and rebuild recovery steps.

## Tool Naming

Antigravity shares Gemini's MCP host conventions and commonly exposes sqry tools with a server prefix (for example `sqry__semantic_search` or canonical `semantic_search`, depending on version). Read `sqry://meta/manifest` first on **standalone** MCP when resources are available, then use `sqry://docs/capability-map` and `sqry://docs/tool-guide` for the exact installed tool surface.

## CLI Fallback

If Antigravity cannot see sqry MCP tools after setup or before restart, use the CLI from the workspace root:

```bash
sqry query 'kind:function AND name:authenticate' --json
sqry graph direct-callers "AuthService::authenticate" --json
sqry impact "AuthService::authenticate" --json
```

## Recommended AGENTS.md Addition

Antigravity reads project instructions from `AGENTS.md` (project root, or the `antigravity-cli/AGENTS.md` location used by some installs). Add:

```markdown
## Code Search

For structural code questions — callers, callees, references, imports,
call paths, dependency impact, cycles, unused symbols, semantic diffs —
prefer sqry over the built-in grep and file-read tools.

Use sqry MCP tools when connected; read `sqry://docs/capability-map` to find
the right tool. Use the `sqry` CLI as fallback when MCP is unavailable. Use
grep for literal text search and file listing for filename discovery.

On C code, sqry call edges can carry resolution provenance and ambiguous calls
are elided rather than guessed, so an absent edge means "not confidently
resolvable," not "does not exist." For sensitive or regulated repositories,
set `SQRY_REDACTION_PRESET=standard` (or `strict`) in the sqry MCP server
env before exposing graph results to an external model.
```

## Troubleshooting

- No tools visible: save `mcp_config.json` and use Refresh under Customizations → Installed MCP Servers; restart Antigravity if needed.
- Verify connection: in the Antigravity CLI open the `/mcp` panel; in the IDE check Customizations → Installed MCP Servers and select sqry to list its tools.
- Config not picked up: confirm whether your install reads `~/.gemini/config/mcp_config.json` or `~/.gemini/antigravity/mcp_config.json` — "View raw config" always opens the active file.
- Empty results: run `sqry index .` from the project root, or `sqry index --force .` after an upgrade or stale graph warning.
- Stale graph or unknown plugin IDs: remove `.sqry/graph`, `.sqry/graphs`, and `.sqry/analysis`, then rebuild.
- Cannot read `sqry://meta/manifest`: switch to standalone `sqry-mcp --no-daemon` (daemon serves zero resources).
- Fewer tools than expected: you are likely on daemon-hosted MCP. Use standalone `sqry-mcp` for the full surface.
- 404 on `sqry://meta/manifest`: old server version; upgrade sqry.
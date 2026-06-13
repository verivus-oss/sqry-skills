---
name: sqry-grok
version: 20.0.5
description: |
  Setup and workflow for using sqry semantic code search with Grok. Plugin-first for Grok Build (auto skills + MCP + doctor), CLI-first fallback, optional manual MCP, stale index recovery, and troubleshooting. Complements the sqry-semantic-search skill.
---

# sqry for Grok

Use this skill when the active agent is Grok and the user wants sqry semantic code search.

**Best path**: Install the sqry plugin (`.claude-plugin/` bundle). Grok Build auto-discovers it, loads all sqry skills, auto-registers `sqry-mcp` via `.mcp.json`, and makes `scripts/doctor.sh` available. Zero manual config.

Grok can still use sqry in two ways (plugin makes #2 automatic):

1. CLI via shell command tools. This works whenever `sqry` is installed and is the reliable fallback.
2. MCP tools and resources, when the Grok session has `sqry-mcp` connected (auto-configured by the plugin).

## Plugin Installation (Preferred for Grok Build)

The entire `sqry-skills` repository is a Claude-compatible plugin (`.claude-plugin/plugin.json` + `skills/` + `.mcp.json` + `.lsp.json` + `scripts/`).

1. `git clone https://github.com/verivus-oss/sqry-skills ~/.grok/plugins/sqry`
2. In Grok TUI: `/plugins` → enable `sqry` → `/reload-plugins`
3. `/skills` now lists the sqry skills; `/mcps` shows the auto-registered `sqry` server.
4. Run `~/.grok/plugins/sqry/scripts/doctor.sh --workspace .` for full verification.

The plugin also works in Claude Code and any host that reads Claude plugins.

After enabling, you usually do **not** need the individual `sqry-*` skills via npx — the plugin provides them.

## Setup (sqry Binary)

Install or upgrade sqry:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
sqry --version
sqry-mcp --version
sqry-lsp --version
sqryd --version
```

Build or refresh the index:

```bash
cd /path/to/your/project
sqry index .
sqry index --status --json .
```

## CLI-First Usage

Use the Grok shell command tool from the workspace root:

```bash
sqry query 'kind:function AND name:execute' --json
sqry query 'kind:class AND lang:typescript' --json
sqry --kind class 'Manager|Executor|Recorder' --json
sqry graph direct-callers "ApprovalManager" --json
sqry graph direct-callees "main" --json
sqry impact "Executor::run" --json
sqry duplicates --json
sqry cycles --json
sqry ask "where is retry logic implemented?"
```

Add `kind:`, `lang:`, and `path:` filters when a query is broad or hits a cost gate.

## Manual / Advanced MCP Integration (Fallback or Daemon)

The plugin's `.mcp.json` handles normal registration automatically. Use this section only for:

- Non-plugin Grok sessions
- Custom daemon mode (`sqry-mcp --daemon`)
- Explicit workspace pinning

Add or override an sqry server entry:

```json
{
  "mcpServers": {
    "sqry": {
      "command": "/absolute/path/to/sqry-mcp",
      "env": {
        "SQRY_MCP_WORKSPACE_ROOT": "/absolute/path/to/project"
      }
    }
  }
}
```

### MCP mode: standalone vs daemon

The plugin `.mcp.json` uses standalone `sqry-mcp --no-daemon` by default (**37 tools**, **6 MCP resources** including `sqry://meta/manifest` and `sqry://docs/*`).

**Daemon** (`sqry-mcp --daemon`) warms the graph for long sessions but exposes only a **16-tool subset** and **zero MCP resources** — agents cannot read `sqry://meta/manifest` or docs on the daemon path. Do not recommend daemon then instruct reading MCP resources in the same workflow.

```bash
# Standalone — full tools + resources (preferred; plugin default)
sqry-mcp --no-daemon

# Daemon — warm graph, reduced tools, no resources
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

Configure Grok with `"args": ["--daemon"]` only when you accept the 16-tool, no-resource tradeoff.

After connecting, restart or refresh the Grok session and discover tools with the agent's MCP discovery mechanism. Some Grok environments expose canonical sqry tool names such as `semantic_search`, `direct_callers`, `get_references`, and `get_graph_stats` rather than `mcp__sqry__*` names.

## Skill Dependency

- **Plugin users**: `sqry-semantic-search` + `sqry-grok` are loaded together automatically when the `sqry` plugin is enabled.
- **npx / non-plugin users**: Also load `sqry-semantic-search`. It contains the shared routing rules, ambiguity handling, output-size limits, and rebuild recovery steps.

## Recovery for Stale Graphs

If Grok reports unknown plugin IDs, stale graph format, or failed graph loading:

```bash
sqry index --force .
sqry index --status --json .
```

If that does not clear the failure:

```bash
rm -rf .sqry/graph .sqry/graphs .sqry/analysis
sqry index --force .
```

Validate with one narrow symbol query and one relation query:

```bash
sqry query 'kind:function AND path:src' --json
sqry graph direct-callers "<qualified-symbol>" --json
```

## Recommended Project Instruction

```markdown
## Code Search

Use sqry for structural code search.
- CLI: `sqry query 'kind:function AND name:foo'`, `sqry graph direct-callers <symbol>`, `sqry impact <symbol>`
- MCP: when sqry tools are visible, read `sqry://docs/capability-map` and use the returned sqry tools
- Use native grep/rg only for literal text search
```

## Troubleshooting

- No sqry MCP tools visible: enable the `sqry` plugin in Grok (`/plugins`), run `~/.grok/plugins/sqry/scripts/doctor.sh`, or use CLI fallback.
- Empty results or "unknown plugin IDs": run `scripts/doctor.sh --workspace .` (or `sqry index --force .` + `rm -rf .sqry/graph*` if needed).
- Cost gate rejection: narrow with `kind:`, `lang:`, `path:`, or a more specific name.
- Cannot read `sqry://meta/manifest`: switch to standalone `sqry-mcp --no-daemon` (daemon serves zero resources).
- Daemon not responding: run `sqry daemon stop`, then `sqry daemon start` and `sqry daemon load .`.
- Stale graph warnings: the doctor script detects this and suggests exact recovery commands.

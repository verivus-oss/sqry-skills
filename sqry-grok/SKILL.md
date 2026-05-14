---
name: sqry-grok
version: 15.0.6
description: |
  Setup and workflow for using sqry semantic code search with Grok. Covers CLI-first usage, optional MCP configuration, stale index recovery, and troubleshooting. Complements the sqry-semantic-search skill.
---

# sqry for Grok

Use this skill when the active agent is Grok and the user wants sqry semantic code search.

Grok can use sqry in two ways:

1. CLI via shell command tools. This works whenever `sqry` is installed and is the reliable fallback.
2. MCP tools and resources, when the Grok session has `sqry-mcp` connected.

## Setup

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

## Optional MCP Integration

If Grok exposes MCP server configuration, add an sqry server entry pointing to the absolute `sqry-mcp` path:

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

For daemon-backed MCP:

```bash
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

Then configure Grok to launch `sqry-mcp` with `--daemon`.

After connecting, restart or refresh the Grok session and discover tools with the agent's MCP discovery mechanism. Some Grok environments expose canonical sqry tool names such as `semantic_search`, `direct_callers`, `get_references`, and `get_graph_stats` rather than `mcp__sqry__*` names.

## Skill Dependency

Also load `sqry-semantic-search`. It contains the shared routing rules, ambiguity handling, output-size limits, and rebuild recovery steps.

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

- No sqry MCP tools visible: use CLI fallback or configure `sqry-mcp`.
- Empty results: index the correct workspace root with `sqry index .`, or `sqry index --force .` after an upgrade or stale graph warning.
- Cost gate rejection: narrow with `kind:`, `lang:`, `path:`, or a more specific name.
- Daemon not responding: run `sqry daemon stop`, then `sqry daemon start` and `sqry daemon load .`.

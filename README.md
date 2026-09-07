# sqry Skills + Plugin

Agent skills and first-class plugin for [sqry](https://github.com/verivus-oss/sqry), AST-based semantic code search (compiler-grade, not embeddings).

These skills and the plugin bundle are aligned with public `verivus-oss/sqry` v31.0.0 (measured against the released binaries and the `v31.0.0` tag).

## Plugin Installation (Recommended for Grok Build & Claude Code)

Grok Build and Claude Code automatically discover Claude-compatible plugins. The `sqry-skills` repo root **is** the plugin.

```bash
# Clone into Grok's plugins directory (or any location)
git clone --depth 1 https://github.com/verivus-oss/sqry-skills ~/.grok/plugins/sqry

# Or use --plugin-dir for testing
# grok --plugin-dir /path/to/sqry-skills
# claude --plugin-dir /path/to/sqry-skills
```

Then in the Grok TUI:
- `/plugins` and enable `sqry`
- `/reload-plugins`
- `/skills` and `/mcps` will now show sqry entries

**Benefits**:
- All 8 skills auto-loaded (namespaced under the `sqry` plugin)
- `sqry-mcp` auto-registered via `.mcp.json` (standalone `--no-daemon`: 39 tools, 6 MCP resources, 6 prompts)
- `sqry-lsp` registered via `.lsp.json` (extension map generated from `sqry --list-languages` with high-cost plugins included)
- `scripts/doctor.sh` and `scripts/install-sqry.sh` available
- Works for Grok Build, Claude Code, and other Claude-compat hosts with **zero extra config**

After enabling, run the doctor from the plugin or project:

```bash
~/.grok/plugins/sqry/scripts/doctor.sh --workspace /path/to/your/project
```

## Skills-Only Installation (npx, Codex, Gemini, minimal setups)

```bash
# All skills
npx skills add https://github.com/verivus-oss/sqry-skills

# Individual skills
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-semantic-search
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-claude
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-codex
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-gemini
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-grok
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-opencode
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-antigravity
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-mistralvibe
```

## Skills

| Skill | Agent | Description |
|-------|-------|-------------|
| [sqry-semantic-search](skills/sqry-semantic-search/) | All | Core skill: MCP routing, the reference to all 39 tools with required arguments, CLI fallback, disambiguation, output size guidance |
| [sqry-claude](skills/sqry-claude/) | Claude Code | Setup and MCP configuration for Claude Code |
| [sqry-codex](skills/sqry-codex/) | OpenAI Codex | Setup and MCP configuration for Codex CLI (`~/.codex/config.toml`) |
| [sqry-gemini](skills/sqry-gemini/) | Gemini CLI | Setup and MCP configuration for Gemini CLI (`~/.gemini/settings.json`) |
| [sqry-grok](skills/sqry-grok/) | Grok | CLI-first recovery + plugin guidance for Grok Build |
| [sqry-opencode](skills/sqry-opencode/) | OpenCode | Setup and MCP configuration for OpenCode (`opencode.json`) |
| [sqry-antigravity](skills/sqry-antigravity/) | Antigravity | Setup and MCP configuration for Google Antigravity IDE and CLI |
| [sqry-mistralvibe](skills/sqry-mistralvibe/) | Mistral Vibe | CLI-first usage and `config.toml` MCP setup for the Vibe CLI |

> **Note**: Skills live under the `skills/` subdirectory. Both `npx skills add` (recursive discovery) and Grok/Claude plugin auto-discovery work with this layout. The plugin layout also provides `.mcp.json` / `.lsp.json` and scripts.

## Doctor & Scripts

The plugin includes three scripts in `scripts/`:

- `install-sqry.sh`: thin wrapper around the official sqry installer (`--component all`, default install dir `~/.local/bin`).
- `doctor.sh`: health check:
  - Binary presence + version (sqry, sqry-mcp, sqry-lsp, sqryd)
  - Index health via `sqry index --status --json .` (`file_count`, `symbol_count`, `stale`)
  - Graph manifest checks (`snapshot_format_version`, `build_provenance.sqry_version`, `node_count`) and the `snapshot.sqry` magic
  - MCP config scan across `.claude.json`, `~/.grok/config.toml`, Codex, Gemini, Vibe and OpenCode locations, plus `sqry mcp status --json`
  - Plugin context verification
  - Quick functional query test
- `sync-versions.sh`: rewrites every pinned version, tool count, language count and snapshot format in this repo from the live `sqry://meta/manifest`.

```bash
# From project root (or specify workspace)
~/.grok/plugins/sqry/scripts/doctor.sh --workspace .

# JSON output for CI / agents
~/.grok/plugins/sqry/scripts/doctor.sh --json

# Verbose
~/.grok/plugins/sqry/scripts/doctor.sh --verbose
```

`doctor.sh` exits 0 (healthy), 1 (warnings), or 2 (critical). It is the single command to run when Grok or Claude reports "unknown plugin IDs", empty results, or transport errors. sqry itself ships `sqry doctor channels` for diagnosing a stable and a dev channel installed side by side.

## Marketplace Path (Grok + Claude)

Grok discovers marketplace sources from:

- `[[marketplace.sources]]` in `~/.grok/config.toml`
- `~/.grok/plugins/known_marketplaces.json`
- Claude-compatible marketplace files (also read automatically)

To make sqry appear in the Grok TUI Marketplace tab without manual `git clone`:

1. Create (or contribute to) a small Verivus marketplace index repo.
2. Add an entry pointing to this repository as a plugin:
   ```json
   {
     "name": "sqry",
     "description": "AST semantic code search plugin",
     "repository": "https://github.com/verivus-oss/sqry-skills",
     "type": "plugin"
   }
   ```
3. Users add the marketplace once; `sqry` then appears for one-click install.

This is the "include sqry" route that requires no xAI approval.

## Two Tracks

**Immediate (this plugin)**: Local stdio `sqry-mcp` / `sqry-lsp` via Grok Build / Claude Code plugin system. Full skills + auto-MCP + doctor today.

**Later**: Remote MCP (HTTPS Streaming or SSE) for Grok web/API "Custom MCP connectors". The current `sqry-mcp` is stdio-only (JSON-RPC 2.0, newline-delimited, MCP protocol 2024-11-05); a hosted bridge or HTTP/SSE mode in sqry will be needed. The plugin remains the local experience for the CLI/TUI.

## Architecture: Live MCP Resources + Reliable CLI Fallback

sqry skills use a resource delegation architecture. Full parameter reference, query syntax, workflow recipes, and language support are served live by the `sqry-mcp` binary as MCP resources, so they match the installed sqry version. `sqry-semantic-search` carries a compact table of all 39 tools with their required arguments, so an agent can pick and call a tool before reading the live guide.

Skills contain stable, agent-facing content:

- install, index, and MCP setup instructions;
- tool naming and discovery conventions for each agent;
- CLI fallback commands for sessions where MCP is not connected;
- disambiguation tips, output size guidance, and troubleshooting.

When sqry adds tools or languages, upgrade the sqry binary and read the live MCP resources. Reinstalling skills is only needed when agent setup guidance changes.

### MCP Resources

| Resource | Content |
|----------|---------|
| `sqry://meta/manifest` | Version, tool count, language count, snapshot format, defaults |
| `sqry://docs/capability-map` | Task-oriented tool routing |
| `sqry://docs/tool-guide` | Complete tool reference with parameters |
| `sqry://docs/query-syntax` | Query language reference |
| `sqry://docs/patterns` | Workflow recipes |
| `sqry://docs/architecture` | Graph internals |

### MCP Prompts

Standalone `sqry-mcp` also serves 6 prompts (`semantic_search`, `find_callers`, `find_callees`, `trace_path`, `explain_symbol`, `code_impact`). Claude Code exposes them as `/mcp__sqry__<name>` slash commands.

## Current sqry Notes

Public `verivus-oss/sqry` v31.0.0 uses:

- Rust 1.94+, Edition 2024
- 37 languages: 28 with full relation support, 9 with symbol extraction. The released binaries compile 30 of them (29 enabled by default, JSON with `--include-high-cost`); the other 7 (`pulumi`, `puppet`, `salesforce-apex`, `sap-abap`, `servicenow-xanadu`, `servicenow-xml`, `terraform`) are cargo features (`plugin-<id>`) and `sqry index --enable-plugin <id>` rejects them on a release binary
- 39 MCP tools standalone, 17-tool subset when daemon-hosted
- 6 MCP resources and 6 MCP prompts standalone, none when daemon-hosted
- snapshot format 17 (`sqry://meta/manifest` `snapshot_format`; `snapshot.sqry` starts with `SQRY_GRAPH_V17`)
- default MCP redaction preset: `minimal` (presets: `none`, `minimal`, `relative`, `standard`, `strict`)
- default query timeout: 60s (`SQRY_MCP_TIMEOUT_MS`)
- default index timeout: 600s (`SQRY_MCP_INDEX_TIMEOUT_MS`)
- MCP responses capped at 50,000 bytes (`SQRY_MCP_MAX_OUTPUT_BYTES`)

Install or upgrade sqry:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
sqry --version
sqry-mcp --version
sqry-lsp --version
sqryd --version
```

For normal setup, build the index from the project root:

```bash
sqry index .
sqry index --status --json .
```

After upgrading across versions that change graph semantics, force a rebuild:

```bash
sqry index --force .
sqry index --status --json .
```

If a stale graph reports unknown plugin IDs, remove persisted graph artifacts and rebuild:

```bash
rm -rf .sqry/graph .sqry/graphs .sqry/analysis
sqry index --force .
```

The MCP manifest reports the compiled language/tool surface. The CLI `sqry --list-languages` command shows only the enabled language plugins (29 by default, 30 with `SQRY_INCLUDE_HIGH_COST=1`); the manifest counts all 37 plugins in the source tree.

**MCP mode:** Plugin `.mcp.json` uses standalone `sqry-mcp --no-daemon` (39 tools, 6 resources including `sqry://meta/manifest`, 6 prompts). Daemon mode (`sqry-mcp --daemon`) exposes only a 17-tool subset and zero resources or prompts; use it only when you do not need manifest/docs resources. With no flag, `sqry-mcp` probes for a running `sqryd` and connects to it when one is reachable, so an unflagged entry can silently land on the 17-tool subset.

After upgrading sqry, regenerate the pinned version, tool count, language count and snapshot format lines in this repo:

```bash
./scripts/sync-versions.sh
```

## What is sqry?

sqry parses source code into ASTs and builds a graph of symbols and relationships. It answers structural questions such as callers, callees, references, unused symbols, cycles, duplicates, dependency impact, and semantic diffs from the indexed graph instead of guessing from source text.

## License

MIT

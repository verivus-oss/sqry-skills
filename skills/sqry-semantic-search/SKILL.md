---
name: sqry-semantic-search
version: 20.0.5
description: |
  AST-based semantic code search skill for AI agents. Teaches agents to use sqry MCP resources when connected and the sqry CLI when MCP is unavailable. sqry parses code like a compiler using ASTs and graph queries, not embeddings.
---

# sqry Semantic Code Search Skill

**Routing rule:** For structural code search (symbols, callers, callees, impact, dependencies), use sqry MCP tools when connected; otherwise use the `sqry` CLI from the workspace root. Use `rg`/grep only for literal text, and native file tools only for reading full files.

Use this skill when users ask to:

- find functions, classes, methods, variables, types, modules, or files by code structure;
- trace callers, callees, references, imports, inheritance, or call paths;
- analyze dependency impact, unused symbols, cycles, duplicates, or semantic diffs;
- understand a codebase through AST-backed graph facts instead of text guessing.

## What Makes sqry Different

sqry uses "semantic" in the compiler sense. It parses code into ASTs, builds a graph of symbols and relationships, and answers structural queries from that graph. It is not an embedding search tool.

## Current Version Target

This skill is aligned with public `verivus-oss/sqry` v20.0.5:

- 37 languages: 28 full-relation languages and 9 symbol-extraction languages
  - 37 MCP tools (standalone `sqry-mcp`; see daemon note below)
- snapshot format V7 (from `sqry://meta/manifest` `snapshot_format`; distinct from on-disk `.sqry/graph/manifest.json` `snapshot_format_version`)
- default MCP redaction preset: `minimal`
- default query timeout: 60s
- default index timeout: 600s
- Rust 1.94+, Edition 2024

Use the installed MCP manifest as the runtime source of truth. `sqry --list-languages` may list only default-enabled plugins; the MCP manifest reports the compiled language/tool surface.

Always confirm the installed runtime:

```bash
sqry --version
sqry-mcp --version
sqry-lsp --version
sqryd --version
sqry index --status --json .
```

Regenerate pinned version/tool-count lines in this repo after upgrading sqry:

```bash
./scripts/sync-versions.sh
```

## Setup

Install or upgrade sqry:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
sqry --version
sqry-mcp --version
sqry-lsp --version
sqryd --version
```

Build the workspace index from the project root:

```bash
sqry index .
sqry index --status --json .
```

Configure MCP for agents with first-class sqry setup support:

```bash
sqry mcp setup --tool claude
sqry mcp setup --tool codex
sqry mcp setup --tool gemini
sqry mcp status
```

After MCP setup, restart the agent. The current session usually cannot reload newly configured MCP servers.

### MCP mode: standalone vs daemon

**Default for manifest/docs workflows:** use standalone `sqry-mcp` (no `--daemon` flag, or explicit `--no-daemon`). Standalone serves **37 tools** and **6 MCP resources** including `sqry://meta/manifest` and `sqry://docs/*`.

**Daemon mode** (`sqry-mcp --daemon`) is for long sessions with a warm graph, but today it exposes only a **16-tool subset** and **zero MCP resources** — you cannot read `sqry://meta/manifest` or other docs on the daemon path. Do not recommend daemon then instruct reading MCP resources in the same workflow.

```bash
# Standalone — full tool surface + resources (preferred for docs/manifest)
sqry-mcp --no-daemon

# Daemon — warm graph, reduced tools, no resources
sqry daemon start
sqry daemon load .
sqry-mcp --daemon
```

Plugin `.mcp.json` uses standalone by default. Add `"args": ["--daemon"]` only when you accept the 16-tool, no-resource tradeoff.

## Redaction for external LLMs

MCP responses are redacted by default (`SQRY_REDACTION_PRESET=minimal`). For cloud or untrusted agents, set the preset before launching `sqry-mcp`:

```bash
# Documented on sqry-mcp --help:
# SQRY_REDACTION_PRESET=none|minimal|standard|strict (default: minimal)

export SQRY_REDACTION_PRESET=standard   # cloud LLMs, code confidential
# export SQRY_REDACTION_PRESET=strict  # untrusted external services
sqry-mcp --no-daemon
```

Preset semantics (see `sqry-mcp-redaction` README in the sqry repo): `standard` for cloud LLMs when code must stay confidential; `strict` for untrusted externals. `sqry://docs/tool-guide` documents field-level semantics but does **not** replace the preset table — cite `sqry-mcp --help` and the redaction README for external-LLM guidance.

## Provenance filters (C today; do not oversell)

Live `semantic_search` documents C-scoped predicates (`address_taken`, `resolved_via`, `callsite_promiscuous`) populated by the **C plugin only**; on non-C nodes they evaluate to false. The Plan B `resolved_via` array filter in the MCP schema is **stubbed** (planner accepts it, but resolvers do not emit the new dispatch-resolution variants yet).

Do not headline `binding_plane` or `resolved_via` filters as a universal moat on Python/TypeScript/Rust repos until resolver support ships. Prefer reading the live tool description via `sqry://docs/tool-guide` after connecting standalone MCP.

## Use MCP When Connected

First confirm the sqry MCP server is visible to the current agent. On **standalone** MCP, read:

```text
sqry://meta/manifest
```

Then use the live resources for the installed version:

| I need to... | Read this MCP resource |
|-------------|------------------------|
| Find the right tool | `sqry://docs/capability-map` |
| See tool parameters | `sqry://docs/tool-guide` |
| Write a query | `sqry://docs/query-syntax` |
| Follow a workflow recipe | `sqry://docs/patterns` |
| Understand graph internals | `sqry://docs/architecture` |
| Check version and counts | `sqry://meta/manifest` |

MCP tool names can be host-specific. Claude Code, Codex, and Gemini commonly expose prefixed names such as `mcp__sqry__semantic_search`; other hosts may expose canonical names such as `semantic_search`.

## Use CLI When MCP Is Missing

If MCP tools or resources are not visible, do not stop. Use the CLI from the workspace root:

```bash
# Find symbols with structured query syntax
sqry query 'kind:function AND name:authenticate' --json
sqry query 'kind:class AND lang:typescript' --json
sqry query 'kind:method AND path:src/auth' --json

# Fast search flags for common cases
sqry --kind function --exact authenticate --json
sqry --kind class 'Manager|Executor|Recorder' --json

# Graph relationships
sqry graph direct-callers "AuthService::authenticate" --json
sqry graph direct-callees "main" --json
sqry graph trace-path "main" "handle_request" --json

# Analysis workflows
sqry impact "AuthService::authenticate" --json
sqry unused --json
sqry cycles --json
sqry duplicates --json
sqry diff HEAD~1 HEAD --json

# Natural-language helper
sqry ask "where is the retry logic implemented?"
```

Use CLI fallback especially when:

- the current agent has no sqry MCP server connected;
- `sqry://meta/manifest` cannot be read (often because MCP is daemon-backed with no resources);
- MCP discovery only shows unrelated servers;
- the agent supports shell commands but not MCP tools;
- the user needs immediate recovery before restarting the agent.

## Workspace-Aware Usage

sqry can resolve logical workspaces from a `.sqry-workspace` registry or a VS Code `.code-workspace` file containing `sqry.workspace`.

When working in a multi-root session:

1. Prefer explicit `path` or file-bearing arguments when the target source root is ambiguous.
2. Use `sqry workspace status <workspace> --json --no-cache` outside MCP to inspect source-root health.
3. For MCP calls, rely on session-scoped resolution in this order: explicit `path`, file-bearing arguments, MCP roots, last-resolved workspace, then legacy environment/CWD fallback.

## Handling Ambiguous Symbols

Names such as `new`, `init`, `handle`, `process`, `execute`, and `request` often exist in many files.

Use one or more of:

- path filters: `sqry query 'kind:function AND name:handle AND path:src/api' --json`
- exact matching: `sqry --exact handle --kind function --json`
- qualified names: `UserService::authenticate`
- a search-first workflow: find the symbol, then run callers/callees/impact with the qualified name

Rule of thumb: if a name could exist in more than one file, add a `path:` filter or use a qualified name.

## Output Size Tips

Start narrow, then expand:

- use direct callers/callees before full hierarchy traversal;
- set depth, result, or node limits when the host supports them;
- add `path:`, `kind:`, and `lang:` filters early;
- prefer `sqry explain <FILE> <SYMBOL>` or hover-style MCP tools for quick lookups.

MCP responses are truncated at 50,000 bytes by default. Override with `SQRY_MCP_MAX_OUTPUT_BYTES=<n>` only when the transport can handle larger payloads. CLI output is not truncated by MCP.

## Rebuild and Upgrade Recovery

After upgrading sqry across graph semantics changes:

```bash
sqry index --force .
sqry index --status --json .
```

If graph loading fails with stale format or unknown plugin IDs:

```bash
rm -rf .sqry/graph .sqry/graphs .sqry/analysis
sqry index --force .
```

If daemon-backed results disagree with persisted artifacts or relation queries time out, cross-check with:

```bash
sqry index --force .
sqry index --status --json .
sqry query '<narrow structural query>' --json
```

## When Not To Use sqry

- Literal text search: use `rg` or the agent's grep tool.
- File name discovery: use file listing, glob, or find tools.
- Reading full source files: use the agent's file read tool.
- Running code: sqry searches and analyzes code; it does not execute it.

Hybrid workflow: use text search for exact strings, then use sqry to understand symbols, relations, and impact.

## Troubleshooting

- No MCP tools visible: configure MCP, restart the agent, or use CLI fallback.
- Cannot read `sqry://meta/manifest`: switch to standalone `sqry-mcp --no-daemon` (daemon serves zero resources).
- Empty results: run `sqry index .` from the correct workspace root, or `sqry index --force .` after an upgrade or stale graph warning.
- Unknown plugin IDs: remove `.sqry/graph`, `.sqry/graphs`, and `.sqry/analysis`, then rebuild.
- Cost gate rejection: narrow the query with `kind:`, `lang:`, `path:`, or a more specific name.
- Large relation query times out: reduce depth or scope, then expand.
- Missing high-cost symbols: only when the user asks for high-cost language support such as JSON or ServiceNow XML, rebuild with `sqry index --include-high-cost .`.
# sqry Skills

Agent skills for [sqry](https://github.com/verivus-oss/sqry) — AST-based semantic code search.

## Install

```bash
# All skills
npx skills add https://github.com/verivus-oss/sqry-skills

# Individual skill
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-semantic-search
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-claude
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-codex
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-gemini
```

## Skills

| Skill | Agent | Description |
|-------|-------|-------------|
| [sqry-semantic-search](sqry-semantic-search/) | All | Core skill: MCP resource routing table, disambiguation tips, output size guidance |
| [sqry-claude](sqry-claude/) | Claude Code | Setup and MCP configuration for Claude Code |
| [sqry-codex](sqry-codex/) | OpenAI Codex | Setup and MCP configuration for Codex CLI |
| [sqry-gemini](sqry-gemini/) | Gemini CLI | Setup and MCP configuration for Gemini CLI |

## Architecture: Auto-Updating via MCP Resources

These skills use a **resource delegation** architecture. Tool reference, query syntax, workflow recipes, and language support are served live by the sqry-mcp binary as MCP resources — they always match your installed sqry version.

Skills only contain **stable, agent-specific content** that rarely changes:
- Setup instructions (install, index, configure MCP)
- Tool naming conventions (`mcp__sqry__` prefix)
- Disambiguation tips and output size guidance
- Troubleshooting

When sqry adds new tools or languages, you get them automatically by upgrading the binary. No need to re-install skills.

### MCP Resources (served by sqry-mcp)

| Resource | Content |
|----------|---------|
| `sqry://meta/manifest` | Version, tool count, language count (JSON) |
| `sqry://docs/capability-map` | Task-oriented tool routing |
| `sqry://docs/tool-guide` | Complete tool reference with parameters |
| `sqry://docs/query-syntax` | Query language reference |
| `sqry://docs/patterns` | Workflow recipes |
| `sqry://docs/architecture` | Graph internals |

## What is sqry?

sqry is a semantic code search tool that parses code like a compiler to understand structure and relationships. Unlike embedding-based search that treats code as text, sqry builds an AST-powered graph of your codebase.

## Current sqry Notes

The live MCP resource set is the source of truth for the installed sqry
version. After configuring MCP, read `sqry://meta/manifest` for the exact
version, tool count, and language count, then use `sqry://docs/capability-map`
and `sqry://docs/tool-guide` for current tool routing and parameters.

Stable operational notes:

- Use `.sqry-workspace` or a VS Code `.code-workspace` `sqry.workspace` block
  to describe multi-repository source roots.
- Use `sqry workspace status <workspace> --json --no-cache` to inspect the
  same aggregate source-root status used by LSP and VS Code.
- For repeated assistant calls, keep the graph warm with `sqry daemon start`,
  `sqry daemon load <path>`, and launch MCP with `sqry-mcp --daemon`. The
  daemon auto-starts on miss unless `SQRY_DAEMON_NO_AUTO_START=1` is set.
- MCP tools use session-scoped workspace resolution: explicit `path`
  arguments win, then file-bearing arguments, MCP roots, last-resolved
  workspace, and legacy environment/CWD fallback. `sqry lsp --workspace`
  honors the same precedence.
- `SQRY_MCP_MAX_OUTPUT_BYTES` caps tool response size (default 50 000 bytes,
  UTF-8 boundary safe).
- `sqry index --force <path>` is the preferred repair step after upgrading
  across releases that change graph semantics.

Install for MCP usage:

```bash
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all
```

## License

MIT

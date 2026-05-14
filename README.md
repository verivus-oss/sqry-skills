# sqry Skills

Agent skills for [sqry](https://github.com/verivus-oss/sqry) - AST-based semantic code search.

These skills are aligned with public `verivus-oss/sqry` v15.0.6.

## Install

```bash
# All skills
npx skills add https://github.com/verivus-oss/sqry-skills

# Individual skills
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-semantic-search
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-claude
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-codex
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-gemini
npx skills add https://github.com/verivus-oss/sqry-skills --skill sqry-grok
```

## Skills

| Skill | Agent | Description |
|-------|-------|-------------|
| [sqry-semantic-search](sqry-semantic-search/) | All | Core skill: MCP routing, CLI fallback, disambiguation, output size guidance |
| [sqry-claude](sqry-claude/) | Claude Code | Setup and MCP configuration for Claude Code |
| [sqry-codex](sqry-codex/) | OpenAI Codex | Setup and MCP configuration for Codex CLI |
| [sqry-gemini](sqry-gemini/) | Gemini CLI | Setup and MCP configuration for Gemini CLI |
| [sqry-grok](sqry-grok/) | Grok | CLI-first recovery and optional MCP configuration guidance for Grok |

## Architecture: Live MCP Resources + Reliable CLI Fallback

sqry skills use a resource delegation architecture. Tool reference, query syntax, workflow recipes, and language support are served live by the `sqry-mcp` binary as MCP resources, so they match the installed sqry version.

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

## Current sqry Notes

Public `verivus-oss/sqry` v15.0.6 uses:

- Rust 1.94+, Edition 2024
- 37 languages: 28 with full relation support, 9 with symbol extraction
- 36 MCP tools
- snapshot format V7
- default MCP redaction preset: `minimal`
- default query timeout: 60s
- default index timeout: 600s

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

The MCP manifest reports the compiled language/tool surface. The CLI `sqry --list-languages` command may show only the default-enabled language plugins unless high-cost or optional plugins are enabled for indexing.

## What is sqry?

sqry parses source code into ASTs and builds a graph of symbols and relationships. It answers structural questions such as callers, callees, references, unused symbols, cycles, duplicates, dependency impact, and semantic diffs from the indexed graph instead of guessing from source text.

## License

MIT

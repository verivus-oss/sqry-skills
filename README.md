# sqry Skills

Agent skills for [sqry](https://github.com/verivus-oss/sqry) - AST-based semantic code search.

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
| [sqry-semantic-search](sqry-semantic-search/) | All | Complete guide to sqry's query syntax, MCP tools, graph analysis, and 50+ examples |
| [sqry-claude](sqry-claude/) | Claude Code | Setup and workflow for using sqry as an MCP server with Claude Code |
| [sqry-codex](sqry-codex/) | OpenAI Codex | Setup and workflow for using sqry as an MCP server with Codex |
| [sqry-gemini](sqry-gemini/) | Gemini CLI | Setup and workflow for using sqry as an MCP server with Gemini CLI |

## What is sqry?

sqry is a semantic code search tool that parses code like a compiler to understand structure and relationships. Unlike embedding-based search that treats code as text, sqry builds an AST-powered graph of your codebase.

- **37 languages** supported (Rust, TypeScript, Python, Go, Java, C/C++, C#, and more)
- **34 MCP tools** for AI agent integration
- **Graph analysis**: callers, callees, call paths, dependency impact, cycles, duplicates, dead code
- **Query language**: `kind:function name:*auth*`, `callers:authenticate`, `impl:Serialize`

Install for MCP usage:

```bash
# Recommended: signed release installer
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all

# Fallback: build from source
cargo install sqry-cli
cargo install sqry-mcp
```

## License

MIT

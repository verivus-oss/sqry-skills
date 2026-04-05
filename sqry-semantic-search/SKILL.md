---
name: sqry-semantic-search
version: 7.1.4
description: |
  AST-based semantic code search skill for AI agents. Teaches agents to use sqry's 34 MCP tools for finding symbols by structure (functions, classes, types), tracing relationships (callers, callees, imports, inheritance), analyzing dependencies, and detecting code quality issues. Unlike embedding-based search, sqry parses code like a compiler. Supports 37 languages. Uses tiered discovery: start with Quick Tool Selection below, load reference files only when you need parameter details or advanced workflows.
---

# sqry Semantic Code Search Skill

Use this skill when users ask to:
- Find functions, classes, methods, or variables by name or kind
- Search for code with specific visibility (public/private)
- Trace call relationships (callers, callees, call paths)
- Analyze code dependencies and impact of changes
- Find duplicate code, circular dependencies, or unused symbols

## What Makes sqry Different

**sqry uses "semantic" in the compiler sense, not the NLP sense.** It parses code like a compiler using AST analysis and graph queries — not ML embeddings over text.

- `kind:function name:*auth*` - Find functions with "auth" in the name
- `callers:authenticate` - Find everything that calls `authenticate()`
- `kind:class impl:Serialize` - Find classes implementing the Serialize trait
- `returns:Result` - Find functions returning Result types

## Setup

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all

# Index your project
sqry index .

# Configure MCP for your agent
sqry mcp setup --tool claude   # or codex, gemini
sqry mcp status
```

## Quick Tool Selection

This is the primary way to find the right tool. For full parameter details, see [references/tool-reference.md](references/tool-reference.md).

**I know the symbol name and want to...**
- See its definition -> `get_definition`
- See its signature/docs -> `get_hover_info`
- See all references -> `get_references`
- See who calls it -> `direct_callers` (depth=1) or `relation_query` (multi-depth)
- See what it calls -> `direct_callees` (depth=1) or `relation_query` (multi-depth)
- See call tree -> `call_hierarchy`
- See its context + source -> `explain_code`
- See what breaks if I change it -> `dependency_impact`
- Check if it's in a cycle -> `is_node_in_cycle`
- Find similar symbols -> `search_similar`

**I want to search for symbols...**
- By name substring -> `pattern_search`
- By name with ranking -> `get_workspace_symbols`
- By kind/visibility/language -> `semantic_search`
- With results grouped for RAG -> `hierarchical_search`

**I want to analyze the codebase...**
- Find circular dependencies -> `find_cycles`
- Find dead code -> `find_unused`
- Find duplicate code -> `find_duplicates`
- Compare git versions -> `semantic_diff`
- Get overall stats -> `get_graph_stats`
- Get health metrics -> `get_insights`
- Get complexity scores -> `complexity_metrics`
- Check Rust macro expansion cache -> `expand_cache_status`

**I want to visualize/export...**
- Dependency tree -> `show_dependencies`
- Subgraph around symbols -> `subgraph`
- Graph as DOT/Mermaid/D2 -> `export_graph`
- Call path between A and B -> `trace_path`
- Cross-language edges -> `cross_language_edges`

**I need natural language help...**
- Translate English to sqry query -> `sqry_ask`

## Tool Categories (34 tools)

Tool names use the `mcp__sqry__` prefix in Claude Code, or equivalent for your agent. Load [references/tool-reference.md](references/tool-reference.md) for full parameter schemas.

| Category | Tools | When to load details |
|----------|-------|---------------------|
| **Search** (6) | semantic_search, hierarchical_search, explain_code, search_similar, pattern_search, get_workspace_symbols | Need `filters`, `include_classpath`, or pagination params |
| **Navigation** (4) | get_definition, get_references, get_hover_info, get_document_symbols | Usually no extra params needed |
| **Relations** (6) | relation_query, direct_callers, direct_callees, call_hierarchy, trace_path, dependency_impact | Need `max_depth`, `max_results`, or `relation_type` options |
| **Graph** (4) | subgraph, export_graph, show_dependencies, cross_language_edges | Need `format`, `include` filters, or `max_nodes` |
| **Analysis** (7) | semantic_diff, find_duplicates, find_cycles, is_node_in_cycle, find_unused, complexity_metrics, sqry_ask | Need `cycle_type`, `threshold`, or diff filters |
| **Index** (7) | get_index_status, get_graph_stats, get_insights, list_files, list_symbols, rebuild_index, expand_cache_status | Usually no extra params needed |

## Query Basics

Queries use `field:value` predicates. Multiple predicates are AND-combined.

```
kind:function name:*auth*       # functions with "auth" in name
callers:authenticate            # who calls authenticate?
kind:class path:src/models      # classes in src/models
lang:rust kind:struct impl:Debug # Rust structs implementing Debug
```

**Key fields**: `name`, `kind`, `path` (alias: `file`), `lang` (alias: `language`), `parent`, `scope.name`, `scope.type`, `scope.ancestor`

**Relation fields**: `callers`, `callees`, `imports`, `exports`, `returns`, `impl`, `references`

**Operators**: `field:value` (exact/glob), `field~=pattern` (regex)

**Filters** (JSON parameter, not query string): `visibility` ("public"/"private"), `language` (array), `symbol_kind` (array), `score_min` (float)

For full predicate reference, see [references/query-syntax.md](references/query-syntax.md).

## Handling Ambiguous Symbols

When names like `new`, `init`, `handle`, `process` exist in multiple files:

1. **Scope with `file_path`**: `{ "symbol": "handle", "file_path": "src/api/router.rs" }`
2. **Use qualified names**: `"symbol": "UserService::authenticate"`
3. **Fall back to `get_references`** with `path` filter when relation tools fail
4. **Search first**: Use `semantic_search` with `kind:` + `name:` + `path:` to find the exact symbol, then use its qualified name

**Rule of thumb**: If the name could exist in more than one file, always provide `file_path` or use a qualified name.

## Output Size Tips

Some tools produce large output. Always **start narrow, expand if needed**:
- Use `direct_callers` (depth=1) before `call_hierarchy` (full tree)
- Set `max_results`, `max_depth`, or `max_nodes` conservatively first
- Add `path`, `kind`, or `language` filters to reduce noise
- Prefer `get_hover_info` over `explain_code` for quick lookups

For per-tool risk scenarios and mitigations, see [references/tool-reference.md](references/tool-reference.md).

## Supported Languages (37)

**Full relation support (28)**: C, C++, C#, CSS, Dart, Elixir, Go, Groovy, Haskell, HTML, Java, JavaScript, Kotlin, Lua, Perl, PHP, Python, R, Ruby, Rust, Scala, Shell, SQL, Svelte, Swift, TypeScript, Vue, Zig

**Symbol extraction + imports (9)**: JSON, Oracle PL/SQL, Pulumi, Puppet, Salesforce Apex, SAP ABAP, ServiceNow Xanadu, ServiceNow XML, Terraform

Note: JSON and ServiceNow XML are `HighWallClock` plugins, excluded from the default index. Rebuild with `--include-high-cost` or `--enable-plugin json` to include them.

## When NOT to Use sqry

- **Literal text search**: Use grep/rg for exact text patterns
- **File finding**: Use find/glob for file names
- **Reading files**: Use cat/read for file contents
- **Code execution**: sqry only searches, doesn't run code

## Reference Files (load on demand)

Only load these when you need details beyond Quick Tool Selection:

- [references/tool-reference.md](references/tool-reference.md) - Full tool tables with all parameters, filter details, output size risks
- [references/query-syntax.md](references/query-syntax.md) - Complete predicate syntax, MCP vs CLI differences, quoting rules
- [references/graph-queries.md](references/graph-queries.md) - Graph tool parameters, edge types, use cases
- [references/workflows.md](references/workflows.md) - Step-by-step workflows: understand-before-changing, security audit
- [references/examples.md](references/examples.md) - 50+ example queries across all categories

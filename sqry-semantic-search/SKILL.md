---
name: sqry-semantic-search
version: 4.8.16
description: |
  AST-based semantic code search skill for AI agents. Teaches agents to use sqry's 33 MCP tools for finding symbols by structure (functions, classes, types), tracing relationships (callers, callees, imports, inheritance), analyzing dependencies, and detecting code quality issues. Unlike embedding-based search, sqry parses code like a compiler. Supports 35 languages.
---

# sqry Semantic Code Search Skill

Use this skill when users ask to:
- Find functions, classes, methods, or variables by name or kind
- Search for code with specific visibility (public/private)
- Find symbols in specific files or directories
- Trace call relationships (callers, callees, call paths)
- Analyze code dependencies and impact of changes
- Search for code by semantic properties rather than text patterns
- Find duplicate code, circular dependencies, or unused symbols

## What Makes sqry Different

**sqry uses "semantic" in the compiler sense, not the NLP sense.**

| Aspect | Embedding-based Search | sqry |
|--------|----------------------|------|
| Meaning of "semantic" | Text meaning similarity | Code structure & relationships |
| Technology | ML embeddings + vector DB | AST parsing + graph analysis |
| Understands code structure | No - treats code as text | Yes - knows functions vs classes |
| Knows call relationships | No | Yes - callers, callees, imports |
| Query language | Natural language only | Structured predicates + NL |
| Requires ML models | Yes | No |

### The Key Insight

Other "semantic search" tools find code that *reads similarly* - searching "authenticate" finds "login", "verify", "auth_token" because they're semantically similar as English words.

sqry finds code by *what it is and does*:
- `kind:function name:*auth*` - Find functions with "auth" in the name
- `callers:authenticate` - Find everything that calls `authenticate()`
- `kind:class impl:Serialize` - Find classes implementing the Serialize trait
- `returns:Result` - Find functions returning Result types

**We parse code like a compiler does. We don't embed code like a document.**

## Setup

### Install sqry for MCP usage

```bash
# Recommended: signed release installer
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all

# Fallback: build from source
cargo install sqry-cli
cargo install sqry-mcp

# Alternative package managers
brew install verivus-oss/sqry/sqry
yay -S sqry-bin
```

### Build the index

```bash
# Index your project
sqry index .

# Force rebuild
sqry index --force .
```

### Configure your agent

Use `sqry mcp setup` to write agent-specific config entries that point to the
`sqry-mcp` binary:

```bash
sqry mcp setup --tool claude
sqry mcp setup --tool codex
sqry mcp setup --tool gemini
sqry mcp status
```

Claude Code uses `.claude.json` or `~/.claude.json`.
Codex uses `~/.codex/config.toml`.
Gemini uses `~/.gemini/settings.json`.

## MCP Tools Reference

The sqry MCP server provides 33 tools. Tool names use the `mcp__sqry__` prefix in Claude Code, or equivalent for your agent.

### Core Search Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `semantic_search` | Find symbols by query | `query` |
| `hierarchical_search` | RAG-optimized grouped results | `query` |
| `explain_code` | Get symbol details + relations | `file_path`, `symbol_name` |
| `search_similar` | Find similar symbols | `reference` |
| `pattern_search` | Find symbols by name substring | `pattern` |
| `get_workspace_symbols` | Fuzzy name search with ranking | `query` |

### Navigation Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `get_definition` | Jump to symbol definition | `symbol` |
| `get_references` | Find all references to symbol | `symbol` |
| `get_hover_info` | Signature, docs, type info | `symbol` |
| `get_document_symbols` | All symbols in a file | `file_path` |

### Relation Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `relation_query` | Query callers/callees/imports/exports | `symbol`, `relation_type` |
| `direct_callers` | Who calls this? (depth=1) | `symbol` |
| `direct_callees` | What does this call? (depth=1) | `symbol` |
| `call_hierarchy` | Full call tree | `symbol` |
| `trace_path` | Find call paths between symbols | `from_symbol`, `to_symbol` |
| `dependency_impact` | Analyze change impact | `symbol` |

### Graph Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `subgraph` | Extract context around symbols | `symbols` (array) |
| `export_graph` | Export graph in dot/d2/mermaid | `file_path` or `symbol_name` |
| `show_dependencies` | Show dependency tree | `file_path` or `symbol_name` |
| `cross_language_edges` | Find cross-language calls | (none required) |

### Analysis Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `semantic_diff` | Compare code versions | `base`, `target` |
| `find_duplicates` | Find duplicate code patterns | (none required) |
| `find_cycles` | Find circular dependencies | (none required) |
| `find_unused` | Find unused/dead code | (none required) |
| `complexity_metrics` | Cyclomatic complexity scores | (none required) |
| `sqry_ask` | Natural language to sqry | `query` |

### Index Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `get_index_status` | Check index health | (none required) |
| `get_graph_stats` | Node/edge counts, language breakdown | (none required) |
| `get_insights` | Health metrics summary | (none required) |
| `list_files` | All indexed files | (none required) |
| `list_symbols` | All indexed symbols | (none required) |
| `rebuild_index` | Rebuild the index | (none required) |

## Query Syntax

Queries use `field:value` predicates. Multiple predicates are AND-combined.

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Symbol name (exact or glob: `*Handler`, `get*`, `*auth*`) |
| `kind` | enum | function, method, class, struct, trait, enum, interface, module, variable, constant, type, namespace, property, parameter, import |
| `path` | path | File path (glob pattern). Alias: `file` |
| `lang` | string | Programming language. Alias: `language` |
| `parent` | string | Parent symbol name |
| `scope` | enum | file, module, class, function, block |
| `scope.type` | enum | Container type (module, function, class, method, etc.) |
| `scope.name` | string | Container name |
| `scope.parent` | string | Parent scope name |
| `scope.ancestor` | string | Any ancestor scope name |
| `text` | string | Full-text search in symbol body (NOT indexed - slow) |
| `repo` | string | Repository filter (for workspaces) |

### Relation Fields

| Field | Type | Description |
|-------|------|-------------|
| `callers` | string | Symbols that call X |
| `callees` | string | Symbols called by X |
| `imports` | string | Files that import X |
| `exports` | string | Files that export X |
| `returns` | string | Functions returning type X |
| `impl` | string | Types implementing trait X |
| `references` | string | Cross-file references to X |

### Static Analysis Fields

| Field | Type | Description |
|-------|------|-------------|
| `duplicates` | enum | body, function, signature, struct |
| `unused` | enum | public, private, function, struct, all |
| `circular` | enum | calls, imports, all |

### Operators

| Operator | Syntax | Example |
|----------|--------|---------|
| Equal | `field:value` | `kind:function` |
| Regex | `field~=pattern` | `name~=test.*` |

## Common Patterns

### Finding Symbols

```
name:login                      # exact name
name:*Handler                   # ends with Handler
name:get*                       # starts with get
kind:function name:process      # functions named process
kind:class path:src/models      # classes in src/models
lang:rust kind:struct            # Rust structs
```

### Relation Queries

```
callers:authenticate            # who calls authenticate?
callees:processData             # what does processData call?
imports:database                # who imports database?
impl:Debug                      # types implementing Debug
returns:Result                  # functions returning Result
```

### Scope Filtering

```
kind:method scope.name:UserService    # methods in UserService
kind:function scope.type:module       # module-level functions
kind:method scope.ancestor:Api        # methods under any Api ancestor
```

## Quick Tool Selection

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

**I want to visualize/export...**
- Dependency tree -> `show_dependencies`
- Subgraph around symbols -> `subgraph`
- Graph as DOT/Mermaid/D2 -> `export_graph`
- Call path between A and B -> `trace_path`
- Cross-language edges -> `cross_language_edges`

## Recommended Workflow: Understand Before Changing

Follow **broad -> narrow -> impact** before modifying code.

### 1. Get the big picture
- `get_graph_stats` -> node/edge counts, language breakdown
- `get_insights` -> health metrics (cycles, unused symbols, duplicates)
- `list_files` -> indexed files, filtered by language

### 2. Find relevant symbols
- `semantic_search` -> find by structure: `kind:function name:*auth*`
- `pattern_search` -> substring match on names
- `hierarchical_search` -> results grouped by file/container (best for RAG)

### 3. Understand a specific symbol
- `get_definition` -> where is it defined?
- `get_hover_info` -> signature, docs, type
- `explain_code` -> full context + relations

### 4. Trace relationships before changing
- `direct_callers` -> who calls this?
- `dependency_impact` -> what breaks if I change this?
- `subgraph` -> extract context graph around symbols

### 5. Check quality concerns
- `find_cycles` -> circular dependencies near the change
- `find_unused` -> dead code near the change area

## Filter Parameters

All search tools support these filters:

```json
{
  "filters": {
    "language": ["rust"],
    "visibility": "public",
    "symbol_kind": ["function"],
    "score_min": 0.7
  }
}
```

## Supported Languages (35)

**Tier 1**: Rust, JavaScript, TypeScript, Python, Go, Java, C, C++, C#, PHP

**Tier 2**: Kotlin, Ruby, Swift, Scala, Lua, R, Dart, Elixir, Haskell, Perl, Zig, Groovy

**Domain-Specific**: SQL, Terraform, Puppet, Pulumi, Shell, HTML, CSS, Vue, Svelte

**Enterprise**: Salesforce Apex, SAP ABAP, ServiceNow (Xanadu), Oracle PL/SQL

## When NOT to Use sqry

Use other tools when:
- **Literal text search**: Use grep/rg for exact text patterns
- **File finding**: Use find/glob for file names
- **Reading files**: Use cat/read for file contents
- **Code execution**: sqry only searches, doesn't run code

## Additional Documentation

- [references/query-syntax.md](references/query-syntax.md) - Full predicate syntax reference
- [references/graph-queries.md](references/graph-queries.md) - Graph analysis details
- [references/examples.md](references/examples.md) - 50+ example queries

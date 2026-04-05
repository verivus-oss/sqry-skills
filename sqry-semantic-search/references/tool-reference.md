# sqry MCP Tool Reference

Complete parameter reference for all 34 sqry MCP tools. Tool names use the `mcp__sqry__` prefix in Claude Code, or equivalent for your agent.

## Core Search Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `semantic_search` | Find symbols by query | `query` (optional: `include_classpath`) |
| `hierarchical_search` | RAG-optimized grouped results | `query` |
| `explain_code` | Get symbol details + relations | `file_path`, `symbol_name` |
| `search_similar` | Find similar symbols | `reference` |
| `pattern_search` | Find symbols by name substring | `pattern` (optional: `include_classpath`) |
| `get_workspace_symbols` | Fuzzy name search with ranking | `query` |

### semantic_search Parameters

- `query` (required): Predicate query string (e.g., `kind:function name:*auth*`)
- `path`: Workspace-relative directory, default "."
- `filters`: JSON object with `language`, `visibility`, `symbol_kind`, `score_min`
- `max_results`: 1-10,000 (default: 200)
- `context_lines`: 0-20 lines of surrounding code
- `include_classpath`: boolean — include JVM classpath (external dependency) results

### hierarchical_search Parameters

- `query` (required): Predicate query string
- `path`: Workspace-relative directory
- `filters`: Same as semantic_search
- `auto_merge`: boolean — merge small containers
- `merge_threshold`: Token threshold for merging
- `max_files`: Max files to return
- `max_total_symbols`: Max symbols across all files
- `file_target_tokens`, `container_target_tokens`, `symbol_target_tokens`: Token budget per level

### pattern_search Parameters

- `pattern` (required): Substring to match against symbol names
- `path`: Workspace-relative directory
- `max_results`: 1-1,000 (default: 100)
- `include_classpath`: boolean — include JVM classpath results

## Navigation Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `get_definition` | Jump to symbol definition | `symbol` |
| `get_references` | Find all references to symbol | `symbol` |
| `get_hover_info` | Signature, docs, type info | `symbol` |
| `get_document_symbols` | All symbols in a file | `file_path` |

### get_references Parameters

- `symbol` (required): Symbol name or qualified identifier
- `include_declaration`: boolean — include the declaration itself
- `max_results`: 1-1,000 (default: 200)

## Relation Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `relation_query` | Query callers/callees/imports/exports | `symbol`, `relation_type` |
| `direct_callers` | Who calls this? (depth=1) | `symbol` |
| `direct_callees` | What does this call? (depth=1) | `symbol` |
| `call_hierarchy` | Full call tree | `symbol` |
| `trace_path` | Find call paths between symbols | `from_symbol`, `to_symbol` |
| `dependency_impact` | Analyze change impact | `symbol` |

### relation_query Parameters

- `symbol` (required): Symbol name or qualified identifier
- `relation_type` (required): `callers`, `callees`, `imports`, `exports`, `returns`
- `max_depth`: 1-5, default 1
- `max_results`: 1-5,000, default 200
- `path`: Workspace-relative directory

### direct_callers / direct_callees Parameters

- `symbol` (required): Symbol name
- `path`: Workspace-relative directory
- `max_results`: 1-500 (default: 100)

### call_hierarchy Parameters

- `symbol` (required): Symbol name
- `file_path`: Disambiguate when symbol name is common
- `direction`: `incoming` or `outgoing`
- `max_depth`: 1-5, default 2
- `max_results`: 1-5,000, default 200

### trace_path Parameters

- `from_symbol` (required): Starting symbol
- `to_symbol` (required): Target symbol
- `max_hops`: 1-10, default 5
- `max_paths`: 1-20, default 5 (top-K ranked)
- `cross_language`: Allow cross-language paths, default true
- `min_confidence`: 0.0-1.0, default 0.5

### dependency_impact Parameters

- `symbol` (required): Symbol to analyze
- `max_depth`: 1-10, default 3
- `include_files`: Include affected file paths, default true
- `include_indirect`: Include transitive deps, default true
- `max_results`: 1-5,000

## Graph Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `subgraph` | Extract context around symbols | `symbols` (array) |
| `export_graph` | Export graph in dot/d2/mermaid | `file_path` or `symbol_name` |
| `show_dependencies` | Show dependency tree | `file_path` or `symbol_name` |
| `cross_language_edges` | Find cross-language calls | (none required) |

### subgraph Parameters

- `symbols` (required): Array of seed symbol names
- `max_depth`: 1-5, default 2
- `max_nodes`: 1-500, default 50
- `include_callers`: default true
- `include_callees`: default true
- `include_imports`: default false
- `cross_language`: default true

### export_graph Parameters

- `file_path` or `symbol_name` (one required)
- `format`: `json`, `dot`, `d2`, `mermaid`
- `max_depth`: 1-5, default 2
- `include`: Array of `calls`, `imports`, `exports`, `returns`
- `verbose`: Include extra details

### show_dependencies Parameters

- `file_path` or `symbol_name` (at least one required)
- `max_depth`: 1-5, default 2
- `max_results`: 1-5,000, default 500

### cross_language_edges Parameters

- `from_lang`: Optional caller language filter
- `to_lang`: Optional callee language filter
- `max_results`: 1-5,000, default 500

## Analysis Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `semantic_diff` | Compare code versions | `base`, `target` |
| `find_duplicates` | Find duplicate code patterns | (none required) |
| `find_cycles` | Find circular dependencies | (none required) |
| `is_node_in_cycle` | Check if symbol is in a cycle | `symbol` |
| `find_unused` | Find unused/dead code | (none required) |
| `complexity_metrics` | Cyclomatic complexity scores | (none required) |
| `sqry_ask` | Natural language to sqry | `query` |

### semantic_diff Parameters

- `base` (required): `{ "ref": "main" }` or `{ "file_path": "..." }`
- `target` (required): `{ "ref": "HEAD" }` or `{ "file_path": "..." }`
- `filters`: `change_types` (added/removed/modified/renamed/signature_changed), `symbol_kinds`
- `include_unchanged`: default false
- `max_results`: 1-5,000

### find_cycles Parameters

- `cycle_type`: `calls`, `imports`, `modules` (default: calls)
- `min_depth`: 2-100, default 2
- `max_depth`: 2-100 (optional)
- `include_self_loops`: boolean
- `max_results`: 1-500

### find_duplicates Parameters

- `duplicate_type`: `body`, `signature`, `struct`
- `threshold`: 0-100 similarity percentage
- `exact`: boolean — exact matches only
- `max_results`: 1-1,000

### find_unused Parameters

- `scope`: `public`, `private`, `function`, `struct`, `all`
- `language`: Filter by language
- `symbol_kind`: Filter by kind
- `max_results`: 1-1,000

### complexity_metrics Parameters

- `path`: Workspace-relative directory
- `target`: Symbol name or file path
- `min_complexity`: Minimum threshold (uint32)
- `sort_by_complexity`: boolean
- `max_results`: 1-1,000

## Index Tools

| Tool | Purpose | Required Params |
|------|---------|-----------------|
| `get_index_status` | Check index health | (none required) |
| `get_graph_stats` | Node/edge counts, language breakdown | (none required) |
| `get_insights` | Health metrics summary | (none required) |
| `list_files` | All indexed files | (none required) |
| `list_symbols` | All indexed symbols | (none required) |
| `rebuild_index` | Rebuild the index | (none required) |
| `expand_cache_status` | Macro expansion cache status (Rust) | (none required) |

### list_files Parameters

- `path`: Workspace root
- `language`: Optional language filter
- `max_results`: 1-10,000

### list_symbols Parameters

- `path`: Workspace root
- `kind`: Optional kind filter
- `language`: Optional language filter
- `max_results`: 1-10,000

### rebuild_index Parameters

- `path`: Workspace root
- `force`: boolean — force full rebuild

## Filter Parameters

All search tools support these filters via a `filters` JSON parameter:

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

Note: `visibility` is filter-only — it is NOT available as a query predicate. Use `filters` parameter, not the query string.

## Common Query Patterns

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

## Output Size Management

### Tools That Can Produce Large Output

| Tool | Risk Scenario | Mitigation |
|------|--------------|------------|
| `get_document_symbols` | Large files (1000+ lines) | Use `semantic_search` with `path:` filter instead |
| `find_duplicates` | Low similarity thresholds or large codebases | Use `filters` to limit by language or path |
| `explain_code` | Complex functions with many relationships | Prefer `get_hover_info` for quick signature |
| `find_unused` | Large monorepos | Scope with path filter: `unused:all` + `path:src/module` |
| `list_symbols` | Any non-trivial project | Always use with `path` or `filters` parameters |
| `call_hierarchy` | Highly-connected symbols (e.g., logging utilities) | Set `max_depth: 1` first, increase only if needed |
| `subgraph` | Hub symbols with many connections | Set `max_nodes` conservatively (20-50), use `max_depth: 1` initially |

### General Scoping Strategy

1. **Start narrow**: Add `path`, `max_results`, or `max_depth` constraints
2. **Expand if needed**: Remove constraints only when results are too few
3. **Prefer targeted tools**: Use `direct_callers` (depth=1) before `call_hierarchy` (full tree)
4. **Filter by kind**: Add `kind:function` or similar to reduce noise

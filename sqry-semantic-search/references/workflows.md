# sqry Workflows

Step-by-step workflows for common code analysis tasks using sqry MCP tools.

## Workflow: Understand Before Changing

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

## Workflow: Security Audit

Use sqry's graph tools to trace trust boundaries and find dangerous patterns. This workflow traces **untrusted input to dangerous sinks** — exactly the analysis where AST-based graph traversal outperforms text search.

### 1. Find dangerous sinks

Identify functions that execute code, run queries, or access the filesystem:

```json
// Find exec/eval/spawn calls
{ "query": "name~=^(exec|eval|spawn|system|popen|subprocess)$" }
{ "query": "name~=^(execute|raw_query|run_command)" }

// Find SQL query construction
{ "query": "name~=.*(query|execute|prepare).*", "filters": { "symbol_kind": ["function", "method"] } }

// Find file system operations
{ "query": "name~=^(unlink|rmdir|write_file|read_file|open)" }
```

### 2. Find input entry points

Identify where untrusted data enters the system:

```json
// HTTP handlers and route definitions
{ "query": "name~=.*(handler|endpoint|route|controller).*" }
{ "query": "kind:function path:src/api" }

// Request parsing
{ "query": "name~=.*(parse|deserialize|from_request|from_body).*" }
```

### 3. Trace paths from input to sink

Use `trace_path` to find call chains from entry points to dangerous operations:

```json
{
  "from_symbol": "handle_user_input",
  "to_symbol": "execute_query",
  "max_hops": 8,
  "cross_language": true
}
```

### 4. Analyze trust boundaries

Use `subgraph` to visualize the boundary between validated and unvalidated data:

```json
{
  "symbols": ["validate_input", "sanitize", "execute_query"],
  "include_callers": true,
  "include_callees": true,
  "max_depth": 2
}
```

### 5. Check for bypasses

Find callers of dangerous sinks that skip validation:

```json
// Who calls execute_query?
{ "symbol": "execute_query", "relation_type": "callers", "max_depth": 3 }

// Compare against who calls sanitize — callers of the sink that
// DON'T appear in callers of the sanitizer are potential bypasses
{ "symbol": "sanitize", "relation_type": "callers", "max_depth": 3 }
```

### 6. Cross-language trust boundaries

In polyglot codebases, trust boundaries often cross language lines:

```json
// Find all cross-language edges (e.g., JS frontend -> Python backend)
{ "from_lang": "TypeScript", "to_lang": "Python" }

// Trace a specific cross-language path
{
  "from_symbol": "submitForm",
  "to_symbol": "db_execute",
  "cross_language": true,
  "max_hops": 10
}
```

### Security Audit Cheat Sheet

| Goal | Tool | Query |
|------|------|-------|
| Find all exec/eval | `semantic_search` | `name~=^(exec\|eval\|system\|popen)$` |
| Find SQL construction | `semantic_search` | `name~=.*(query\|execute).*` + `path:src/db` |
| Trace input to sink | `trace_path` | `from_symbol` -> `to_symbol` |
| Visualize trust boundary | `subgraph` | Seed with validator + sink symbols |
| Find sink callers | `direct_callers` | `symbol: "dangerous_function"` |
| Cross-language flows | `cross_language_edges` | Filter by `from_lang` / `to_lang` |
| Impact of removing validation | `dependency_impact` | `symbol: "validate_input"` |

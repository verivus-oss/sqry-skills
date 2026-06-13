#!/usr/bin/env bash
set -euo pipefail

# sqry doctor — full health check for sqry + plugin + MCP + index + graph
# Run from project root or with --workspace <path>

WORKSPACE="."
JSON_OUTPUT=false
VERBOSE=false
EXIT_CODE=0

usage() {
  cat <<EOF
sqry doctor — verify sqry installation, index health, MCP config, and plugin setup

Usage: $0 [options]

Options:
  --workspace <path>   Project root to check (default: .)
  --json               Machine-readable JSON output
  --verbose            Extra details and raw command output
  -h, --help           Show this help

Exit codes:
  0  All critical checks passed (warnings may exist)
  1  Warnings present (non-critical issues)
  2  Critical failures (sqry not usable)

Examples:
  ./scripts/doctor.sh
  ./scripts/doctor.sh --workspace /path/to/repo --json
  ./scripts/doctor.sh --verbose
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 2 ;;
  esac
done

cd "$WORKSPACE" || { echo "error: cannot cd to $WORKSPACE"; exit 2; }

# Colors (disabled for JSON)
if [[ "$JSON_OUTPUT" == false ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

pass() { [[ "$JSON_OUTPUT" == false ]] && echo -e "${GREEN}✓${NC} $1" || true; }
warn() { [[ "$JSON_OUTPUT" == false ]] && echo -e "${YELLOW}!${NC} $1" || true; EXIT_CODE=1; }
fail() { [[ "$JSON_OUTPUT" == false ]] && echo -e "${RED}✗${NC} $1" || true; EXIT_CODE=2; }
info() { [[ "$JSON_OUTPUT" == false ]] && echo -e "${CYAN}→${NC} $1" || true; }

results=()

record() {
  local key="$1" status="$2" detail="$3"
  results+=("{\"key\":\"$key\",\"status\":\"$status\",\"detail\":\"$detail\"}")
}

section() {
  [[ "$JSON_OUTPUT" == false ]] && echo -e "\n${CYAN}=== $1 ===${NC}" || true
}

# 1. Binaries & versions
section "Binaries & Versions"
EXPECTED_VERSION="20.0.5"
for bin in sqry sqry-mcp sqry-lsp sqryd; do
  if command -v "$bin" >/dev/null 2>&1; then
    version=$("$bin" --version 2>/dev/null | head -1 || echo "unknown")
    if [[ "$version" == *"$EXPECTED_VERSION"* || "$version" == "$EXPECTED_VERSION" ]]; then
      pass "$bin: $version (expected ~$EXPECTED_VERSION)"
      record "$bin" "ok" "$version"
    else
      warn "$bin: $version (expected ~$EXPECTED_VERSION — consider upgrade)"
      record "$bin" "warn" "$version"
    fi
  else
    fail "$bin: not found in PATH"
    record "$bin" "fail" "not in PATH"
  fi
done

# 2. Index health
section "Index Health (workspace: $WORKSPACE)"
if [[ -d .sqry/graph ]]; then
  pass ".sqry/graph directory exists"
  record "graph_dir" "ok" "present"

  if [[ -f .sqry/graph/manifest.json ]]; then
    manifest_version=$(jq -r '.snapshot_format_version // "unknown"' .sqry/graph/manifest.json 2>/dev/null || echo "unknown")
    built_by=$(jq -r '.build_provenance.sqry_version // empty' .sqry/graph/manifest.json 2>/dev/null || true)
    node_count=$(jq -r '.node_count // empty' .sqry/graph/manifest.json 2>/dev/null || true)

    if [[ "$manifest_version" == "unknown" || -z "$manifest_version" ]]; then
      warn "manifest.json missing snapshot_format_version — graph may be stale or corrupt"
      record "manifest" "warn" "snapshot_format_version missing"
    else
      pass "manifest.json readable (on-disk snapshot_format_version: $manifest_version)"
      record "manifest" "ok" "snapshot_format_version=$manifest_version"
      info "Runtime MCP snapshot format is in sqry://meta/manifest (standalone sqry-mcp only; distinct from on-disk snapshot_format_version)"
    fi

    if [[ -n "$built_by" && "$built_by" != *"$EXPECTED_VERSION"* ]]; then
      warn "Graph built by sqry $built_by (expected ~$EXPECTED_VERSION) — run sqry index --force ."
      record "graph_builder_version" "warn" "built by $built_by"
    elif [[ -n "$built_by" ]]; then
      record "graph_builder_version" "ok" "built by $built_by"
    fi

    if [[ "$node_count" == "0" ]]; then
      warn "Graph node_count is 0 — index may be empty or stale; run sqry index --force ."
      record "graph_node_count" "warn" "node_count=0"
    elif [[ -n "$node_count" ]]; then
      record "graph_node_count" "ok" "node_count=$node_count"
    fi

    if [[ "$VERBOSE" == true && "$JSON_OUTPUT" == false ]]; then
      echo "  manifest:"
      cat .sqry/graph/manifest.json | head -c 500
      echo ""
    fi
  else
    warn "manifest.json missing — graph may be incomplete"
    record "manifest" "warn" "missing"
  fi

  if command -v sqry >/dev/null 2>&1; then
    info "Running sqry index --status --json . (may take a moment)..."
    status_json=$(sqry index --status --json . 2>/dev/null || echo '{"error":"failed"}')
    if echo "$status_json" | jq -e '.error' >/dev/null 2>&1; then
      warn "sqry index --status failed"
      record "index_status" "warn" "command failed"
    else
      files=$(echo "$status_json" | jq -r '.files // 0')
      symbols=$(echo "$status_json" | jq -r '.symbols // 0')
      pass "Index healthy: $files files, $symbols symbols"
      record "index_status" "ok" "$files files, $symbols symbols"

      if [[ "$VERBOSE" == true && "$JSON_OUTPUT" == false ]]; then
        echo "$status_json" | jq .
      fi
    fi
  fi
else
  fail ".sqry/graph missing — run: sqry index ."
  record "graph_dir" "fail" "missing"
  EXIT_CODE=2
fi

# 3. Stale graph heuristics
section "Stale Graph Check"
if [[ -d .sqry/graph && -f .sqry/graph/manifest.json ]]; then
  # Simple staleness: graph dir newer than some source? (heuristic)
  graph_mtime=$(stat -c %Y .sqry/graph 2>/dev/null || stat -f %m .sqry/graph 2>/dev/null || echo 0)
  src_mtime=$(find . -name '*.rs' -o -name '*.ts' -o -name '*.js' -o -name '*.py' 2>/dev/null | head -5 | xargs -I{} stat -c %Y {} 2>/dev/null | sort -rn | head -1 || echo 0)

  if [[ "$src_mtime" -gt "$graph_mtime" && "$src_mtime" -gt 0 ]]; then
    warn "Source files newer than graph — consider sqry index --force ."
    record "staleness" "warn" "sources newer than graph"
  else
    pass "Graph appears fresh relative to sampled sources"
    record "staleness" "ok" "fresh"
  fi

  # Check for known-bad patterns in manifest (unknown plugins etc.)
  if grep -qi 'unknown\|error\|stale' .sqry/graph/manifest.json 2>/dev/null; then
    warn "Manifest contains warning/error markers — run sqry index --force ."
    record "manifest_health" "warn" "contains warnings"
  else
    record "manifest_health" "ok" "clean"
  fi
else
  record "staleness" "skip" "no graph"
fi

# 4. MCP configuration (agent-agnostic scan)
section "MCP Configuration Scan"
MCP_FOUND=false
for cfg in .claude.json ~/.claude.json ~/.grok/config.toml ~/.codex/config.toml ~/.gemini/settings.json; do
  if [[ -f "$cfg" ]] && grep -q 'sqry' "$cfg" 2>/dev/null; then
    pass "sqry entry found in $cfg"
    MCP_FOUND=true
    record "mcp_config:$cfg" "ok" "sqry present"
  fi
done

if command -v sqry >/dev/null 2>&1 && sqry mcp status >/dev/null 2>&1; then
  status=$(sqry mcp status 2>/dev/null | cat)
  if echo "$status" | grep -qi 'sqry'; then
    pass "sqry mcp status reports sqry configured"
    MCP_FOUND=true
    record "mcp_status_cli" "ok" "sqry configured"
  fi
fi

if [[ "$MCP_FOUND" == false ]]; then
  warn "No sqry MCP config found in common locations. Enable the sqry plugin or run 'sqry mcp setup --tool <claude|codex|gemini>'"
  record "mcp_config" "warn" "none found"
fi

# 5. Plugin context (if running from inside plugin)
section "Plugin Context"
if [[ -f .claude-plugin/plugin.json ]]; then
  plugin_name=$(jq -r '.name // "unknown"' .claude-plugin/plugin.json 2>/dev/null || echo "unknown")
  pass "Running inside sqry plugin ($plugin_name v$(jq -r '.version' .claude-plugin/plugin.json 2>/dev/null || echo '?'))"
  record "plugin" "ok" "$plugin_name"
else
  info "Not running from inside the sqry plugin directory (normal when checking a project)"
  record "plugin" "info" "not in plugin dir"
fi

if [[ -d skills/sqry-semantic-search ]]; then
  pass "skills/ layout present (modern + plugin-compatible)"
  record "skills_layout" "ok" "present"
else
  warn "skills/ subdir missing — restructure may be incomplete"
  record "skills_layout" "warn" "missing"
fi

# 6. Quick functional test (narrow query)
section "Quick Functional Test"
if command -v sqry >/dev/null 2>&1 && [[ -d .sqry/graph ]]; then
  if sqry query 'kind:function' --json 2>/dev/null | jq -e '.results | length >= 0' >/dev/null 2>&1; then
    pass "Basic sqry query succeeded"
    record "query_test" "ok" "functional"
  else
    warn "Basic query returned no results or failed (index may be empty or workspace mismatch)"
    record "query_test" "warn" "no/failed results"
  fi
else
  record "query_test" "skip" "no sqry or no graph"
fi

# Final report
section "Summary"
if [[ "$JSON_OUTPUT" == true ]]; then
  printf '{\n  "workspace": "%s",\n  "timestamp": "%s",\n  "exit_code": %d,\n  "checks": [\n' "$WORKSPACE" "$(date -Iseconds)" "$EXIT_CODE"
  for i in "${!results[@]}"; do
    printf '    %s' "${results[$i]}"
    [[ $i -lt $((${#results[@]}-1)) ]] && printf ','
    printf '\n'
  done
  printf '  ]\n}\n'
else
  echo ""
  if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}All critical checks passed.${NC} sqry is ready."
  elif [[ $EXIT_CODE -eq 1 ]]; then
    echo -e "${YELLOW}Warnings detected.${NC} sqry should work but review suggestions above."
  else
    echo -e "${RED}Critical issues found.${NC} Fix before relying on sqry (see failures above)."
  fi
  echo "Run with --verbose for more details or --json for machine output."
  echo "Recommended recovery commands:"
  echo "  sqry index --force ."
  echo "  rm -rf .sqry/graph .sqry/graphs .sqry/analysis && sqry index --force ."
  echo "  ./scripts/install-sqry.sh   # if binaries are missing/outdated"
fi

exit "$EXIT_CODE"

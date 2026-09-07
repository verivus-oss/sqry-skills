#!/usr/bin/env bash
set -euo pipefail

# Sync every pinned sqry fact in this repo from the live binaries:
#   version, standalone tool count, language count, snapshot format
#   (all from sqry://meta/manifest served by standalone sqry-mcp), and the
#   daemon-hosted tool count (measured with sqry-mcp --daemon when a sqryd
#   socket is reachable; left unchanged otherwise).
#
# Pinned phrasing this script rewrites (keep prose in these shapes):
#   "N tools" / "N MCP tools"      standalone sqry-mcp --no-daemon tool count
#   "N-tool"                        daemon-hosted subset (for example "17-tool subset")
#   "N languages"                   language plugin count
#   "snapshot format N"             sqry://meta/manifest snapshot_format
#   "version: X" (frontmatter), "vX" pins, EXPECTED_VERSION in doctor.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v sqry-mcp >/dev/null 2>&1; then
  echo "error: sqry-mcp not found in PATH" >&2
  exit 1
fi

mcp_rpc() {
  # $1 = sqry-mcp mode flag, $2 = method, $3 = params JSON
  python3 - "$1" "$2" "$3" <<'PY'
import json, subprocess, sys
mode, method, params = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
p = subprocess.Popen(["sqry-mcp", mode], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, text=True)
msgs = [
    {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2024-11-05", "capabilities": {},
        "clientInfo": {"name": "sync-versions", "version": "1"}}},
    {"jsonrpc": "2.0", "method": "notifications/initialized"},
    {"jsonrpc": "2.0", "id": 10, "method": method, "params": params},
]
for m in msgs:
    p.stdin.write(json.dumps(m) + "\n")
    p.stdin.flush()
while True:
    line = p.stdout.readline()
    if not line:
        sys.exit("error: no MCP response")
    obj = json.loads(line)
    if obj.get("id") == 10:
        p.terminate()
        print(json.dumps(obj.get("result")))
        break
PY
}

MANIFEST_JSON="$(mcp_rpc --no-daemon resources/read '{"uri":"sqry://meta/manifest"}' | jq -r '.contents[0].text')"
VERSION="$(echo "$MANIFEST_JSON" | jq -r '.version')"
TOOLS="$(echo "$MANIFEST_JSON" | jq -r '.tools')"
LANGS="$(echo "$MANIFEST_JSON" | jq -r '.languages.total')"
SNAPSHOT="$(echo "$MANIFEST_JSON" | jq -r '.snapshot_format')"

for v in "$VERSION" "$TOOLS" "$LANGS" "$SNAPSHOT"; do
  if [[ -z "$v" || "$v" == "null" ]]; then
    echo "error: could not read version/tools/languages/snapshot_format from sqry://meta/manifest" >&2
    exit 1
  fi
done

# Daemon-hosted subset: only measurable against a running sqryd. Never auto-start one here.
DAEMON_TOOLS=""
if DAEMON_LIST="$(SQRY_DAEMON_NO_AUTO_START=1 timeout 20 bash -c "$(declare -f mcp_rpc); mcp_rpc --daemon tools/list '{}'" 2>/dev/null)"; then
  DAEMON_TOOLS="$(echo "$DAEMON_LIST" | jq -r '.tools | length' 2>/dev/null || true)"
fi
if [[ -z "$DAEMON_TOOLS" || "$DAEMON_TOOLS" == "null" || "$DAEMON_TOOLS" == "0" ]]; then
  DAEMON_TOOLS=""
  echo "note: no reachable sqryd; daemon-hosted tool count left unchanged" >&2
fi

echo "Syncing from live MCP manifest: version=$VERSION tools=$TOOLS languages=$LANGS snapshot_format=$SNAPSHOT daemon_tools=${DAEMON_TOOLS:-unchanged}"

PROSE_FILES=(README.md scripts/install-sqry.sh skills/*/SKILL.md)

# Skill frontmatter version (all skills/)
for skill in skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  sed -i "s/^version: .*/version: ${VERSION}/" "$skill"
done

# Version pins in prose
for f in "${PROSE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  sed -i "s|aligned with public \`verivus-oss/sqry\` v[0-9.]*|aligned with public \`verivus-oss/sqry\` v${VERSION}|g" "$f"
  sed -i "s|Public \`verivus-oss/sqry\` v[0-9.]* uses:|Public \`verivus-oss/sqry\` v${VERSION} uses:|" "$f"
  sed -i "s|sqry v[0-9.]* MCP-backed|sqry v${VERSION} MCP-backed|g" "$f"
  sed -i "s|sqry v[0-9.]* semantic code search|sqry v${VERSION} semantic code search|g" "$f"
  sed -i "s|v[0-9]*\.[0-9]*\.[0-9]* (measured|v${VERSION} (measured|g" "$f"
done

# Counts and formats in prose
for f in "${PROSE_FILES[@]}"; do
  [[ -f "$f" ]] || continue
  sed -i -E "s/\b[0-9]+ (MCP )?tools\b/${TOOLS} \1tools/g" "$f"
  sed -i -E "s/\b[0-9]+ languages\b/${LANGS} languages/g" "$f"
  sed -i -E "s/\bsnapshot format [0-9]+\b/snapshot format ${SNAPSHOT}/g" "$f"
  if [[ -n "$DAEMON_TOOLS" ]]; then
    sed -i -E "s/\b[0-9]+-tool\b/${DAEMON_TOOLS}-tool/g" "$f"
  fi
done

# plugin.json
jq --arg v "$VERSION" --argjson t "$TOOLS" --argjson l "$LANGS" \
  '.version = $v | .description = "AST-based semantic code search (compiler-grade, not embeddings). Skills + MCP (sqry-mcp) + LSP (sqry-lsp) for Grok Build, Claude Code, and compatible agents. \($l) languages, \($t) tools, live resources from sqry-mcp binary."' \
  .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json

# doctor.sh expected version
sed -i "s/^EXPECTED_VERSION=\".*\"/EXPECTED_VERSION=\"${VERSION}\"/" scripts/doctor.sh

echo "Updated: skills/*, plugin.json, doctor.sh, install-sqry.sh, README.md"

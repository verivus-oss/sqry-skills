#!/usr/bin/env bash
set -euo pipefail

# Sync pinned sqry version + standalone MCP tool count from live sqry-mcp manifest.
# Does NOT sync snapshot_format (use sqry://meta/manifest at runtime).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v sqry-mcp >/dev/null 2>&1; then
  echo "error: sqry-mcp not found in PATH" >&2
  exit 1
fi

read_manifest() {
  python3 - <<'PY'
import json, subprocess, sys

def rpc(method, rid, params=None):
    p = subprocess.Popen(
        ["sqry-mcp", "--no-daemon"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    msgs = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "sync-versions", "version": "1"},
            },
        },
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}},
    ]
    for m in msgs:
        p.stdin.write(json.dumps(m) + "\n")
        p.stdin.flush()
    while True:
        line = p.stdout.readline()
        if not line:
            sys.exit("error: no MCP response")
        obj = json.loads(line)
        if obj.get("id") == rid:
            p.terminate()
            return obj

resp = rpc("resources/read", 10, {"uri": "sqry://meta/manifest"})
text = resp["result"]["contents"][0]["text"]
manifest = json.loads(text)
print(json.dumps({"version": manifest["version"], "tools": manifest["tools"]}))
PY
}

MANIFEST_JSON="$(read_manifest)"
VERSION="$(echo "$MANIFEST_JSON" | jq -r '.version')"
TOOLS="$(echo "$MANIFEST_JSON" | jq -r '.tools')"

if [[ -z "$VERSION" || "$VERSION" == "null" || -z "$TOOLS" || "$TOOLS" == "null" ]]; then
  echo "error: could not read version/tools from sqry://meta/manifest" >&2
  exit 1
fi

echo "Syncing from live MCP manifest: version=$VERSION tools=$TOOLS"

# Skill frontmatter version (all skills/)
for skill in skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  sed -i "s/^version: .*/version: ${VERSION}/" "$skill"
done

# sqry-semantic-search body pins
SEMANTIC="skills/sqry-semantic-search/SKILL.md"
sed -i "s|aligned with public \`verivus-oss/sqry\` v[0-9.]*|aligned with public \`verivus-oss/sqry\` v${VERSION}|" "$SEMANTIC"
sed -i "s|^[[:space:]]*- [0-9]* MCP tools.*|  - ${TOOLS} MCP tools (standalone \`sqry-mcp\`; see daemon note below)|" "$SEMANTIC"

# Host skill intro lines
for host in sqry-claude sqry-codex sqry-gemini sqry-grok sqry-opencode sqry-antigravity sqry-mistralvibe; do
  f="skills/${host}/SKILL.md"
  [[ -f "$f" ]] || continue
  sed -i "s|sqry v[0-9.]* MCP-backed|sqry v${VERSION} MCP-backed|" "$f" 2>/dev/null || true
  sed -i "s|sqry v[0-9.]* semantic code search|sqry v${VERSION} semantic code search|" "$f" 2>/dev/null || true
done

# plugin.json
jq --arg v "$VERSION" --argjson t "$TOOLS" \
  '.version = $v | .description = "AST-based semantic code search (compiler-grade, not embeddings). Skills + MCP (sqry-mcp) + LSP (sqry-lsp) for Grok Build, Claude Code, and compatible agents. 37 languages, \($t) tools, live resources from sqry-mcp binary."' \
  .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json

# doctor.sh expected version
sed -i "s/^EXPECTED_VERSION=\".*\"/EXPECTED_VERSION=\"${VERSION}\"/" scripts/doctor.sh

# README pinned version + tool count only (not snapshot format)
sed -i "s|aligned with public \`verivus-oss/sqry\` v[0-9.]*|aligned with public \`verivus-oss/sqry\` v${VERSION}|" README.md
sed -i "s|Public \`verivus-oss/sqry\` v[0-9.]* uses:|Public \`verivus-oss/sqry\` v${VERSION} uses:|" README.md
sed -i "s|^[[:space:]]*- [0-9]* MCP tools$|  - ${TOOLS} MCP tools|" README.md

echo "Updated: skills/*, plugin.json, doctor.sh, README.md (version + tool count)"
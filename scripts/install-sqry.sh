#!/usr/bin/env bash
set -euo pipefail

# sqry installer wrapper for the sqry plugin
# Delegates to the official verivus-oss/sqry installer (installs all components)

echo "Installing/upgrading sqry (sqry, sqry-mcp, sqry-lsp, sqryd) via official installer..."
curl -fsSL https://raw.githubusercontent.com/verivus-oss/sqry/main/scripts/install.sh | bash -s -- --component all

echo ""
echo "Verifying installation:"
for bin in sqry sqry-mcp sqry-lsp sqryd; do
  if command -v "$bin" >/dev/null 2>&1; then
    version=$("$bin" --version 2>/dev/null || echo "unknown")
    echo "  ✓ $bin: $version"
  else
    echo "  ✗ $bin: not found in PATH"
  fi
done

echo ""
echo "Next steps:"
echo "  1. Ensure the install dir (~/.local/bin or /usr/local/bin) is in your PATH"
echo "  2. cd /path/to/your/project"
echo "  3. sqry index ."
echo "  4. sqry index --status --json ."
echo "  5. Run ./scripts/doctor.sh (from this plugin) to verify full setup"
echo ""
echo "For MCP with full tools + docs resources (default):"
echo "  sqry-mcp --no-daemon   # 37 tools, sqry://meta/manifest and sqry://docs/*"
echo ""
echo "For daemon-backed MCP (warm graph; 16 tools, zero MCP resources):"
echo "  sqry daemon start && sqry daemon load . && sqry-mcp --daemon"
echo "  Do not use daemon mode when agents need sqry://meta/manifest or sqry://docs/*"

#!/usr/bin/env python3
"""Verify the MCP surface counts quoted in this package against a real sqry.

This package documents four numbers: how many tools standalone `sqry-mcp`
serves, how many the daemon-hosted subset serves, how many MCP resources
standalone exposes, and how many languages sqry supports. All four are
prose, so all four rot silently whenever sqry ships a release. That is
exactly how this repo ended up advertising 37/16 while sqry shipped 39/17.

Ground truth comes from the artifact users actually install:

  standalone tools   `sqry-mcp --no-daemon --list-tools`
  resources          MCP `resources/list` over stdio
  languages          `sqry://meta/manifest`, field languages.total
  daemon subset      DAEMON_SUPPORTED_TOOL_NAMES in the sqry source, read
                     at the tag matching the installed binary

The daemon subset is read from source rather than by starting sqryd: the
constant is the thing sqry itself pins in CI, and parsing it keeps this
check fast and free of daemon lifecycle flake.

Usage:
    scripts/check-doc-counts.py            # verify
    scripts/check-doc-counts.py --show     # print ground truth and exit
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Files whose prose quotes these counts.
DOC_GLOBS = ("skills/*/SKILL.md", "README.md", "scripts/install-sqry.sh",
             ".claude-plugin/plugin.json")

TOOLS_SCHEMA_URL = (
    "https://raw.githubusercontent.com/verivus-oss/sqry/{ref}"
    "/sqry-mcp/src/tools_schema.rs"
)

# Each role maps to the phrasings this package actually uses. A number in
# one of these positions must equal the corresponding ground-truth value.
#
# Keep these in step with the prose. If you reword a sentence that quotes a
# count, add or amend the pattern here; the stray-number guard below will
# fail the build if a count-shaped number stops being covered.
PATTERNS: dict[str, tuple[str, ...]] = {
    "standalone_tools": (
        r"[Ss]erves \*\*(\d+) tools\*\*",
        r"\(\*\*(\d+) tools\*\*",
        r"--no-daemon`: (\d+) tools",
        r"\((\d+) tools, six resources",
        r"# (\d+) tools, sqry://",
        r"\d+ languages, (\d+) tools",
    ),
    "daemon_tools": (
        r"\*\*(\d+)-tool subset\*\*",
        r"(\d+)-tool, no-resource",
        r"only (\d+) tools and zero MCP resources",
        r"warm graph; (\d+) tools",
    ),
    "mcp_resources": (
        r"\*\*(\d+) MCP resources\*\*",
    ),
    "languages": (
        r"(\d+) languages",
    ),
}

# A number sitting next to one of these nouns is a count this checker must be
# able to verify. There is deliberately no line-level allowlist here: an
# earlier version skipped any line mentioning `sqry://`, which silently
# disabled the guard on almost every line that quotes a count.
STRAY_NOUNS = r"\d+[- ](?:tool|resource|language)"


def run(cmd: list[str], **kw) -> str:
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout


def mcp_session(binary: str, requests: list[dict], workspace: Path) -> list[dict]:
    """Drive sqry-mcp over stdio and collect JSON-RPC responses."""
    payload = "".join(json.dumps(r) + "\n" for r in requests)
    # Inherit the real environment. An earlier version passed a minimal env,
    # which risks breaking config/home lookups on a CI runner for no benefit.
    env = dict(os.environ, SQRY_MCP_WORKSPACE_ROOT=str(workspace))
    proc = subprocess.run(
        [binary, "--no-daemon"],
        input=payload,
        capture_output=True,
        text=True,
        timeout=120,
        env=env,
    )
    out = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def ground_truth(binary: str, workspace: Path) -> dict[str, int]:
    version = run([binary, "--version"]).split()[-1].strip()

    listed = run([binary, "--no-daemon", "--list-tools"])
    standalone = len(re.findall(r"^  [a-z_]+$", listed, re.M))

    responses = mcp_session(
        binary,
        [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize",
             "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                        "clientInfo": {"name": "doc-counts", "version": "1"}}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "resources/list", "params": {}},
            {"jsonrpc": "2.0", "id": 3, "method": "resources/read",
             "params": {"uri": "sqry://meta/manifest"}},
        ],
        workspace,
    )
    by_id = {r["id"]: r for r in responses if "id" in r and "result" in r}

    if 2 not in by_id or 3 not in by_id:
        sys.exit("error: sqry-mcp did not answer resources/list or the manifest read")

    resources = len(by_id[2]["result"]["resources"])
    manifest = json.loads(by_id[3]["result"]["contents"][0]["text"])

    # Cross-check: the manifest tool count is derived from the live registry,
    # so it must agree with --list-tools. If it does not, sqry itself is
    # inconsistent and this package cannot be the judge of which is right.
    if manifest["tools"] != standalone:
        sys.exit(
            f"error: sqry is internally inconsistent: --list-tools reports "
            f"{standalone} but sqry://meta/manifest reports {manifest['tools']}. "
            f"Report this against verivus-oss/sqry rather than editing docs here."
        )

    daemon = daemon_subset_count(version)

    return {
        "standalone_tools": standalone,
        "daemon_tools": daemon,
        "mcp_resources": resources,
        "languages": manifest["languages"]["total"],
        "_version": version,
    }


def daemon_subset_count(version: str) -> int:
    """Count DAEMON_SUPPORTED_TOOL_NAMES at the tag matching the binary."""
    last_error = None
    for ref in (f"v{version}", "main"):
        try:
            with urllib.request.urlopen(TOOLS_SCHEMA_URL.format(ref=ref), timeout=30) as fh:
                src = fh.read().decode()
        except Exception as exc:  # network or missing tag
            last_error = exc
            continue
        match = re.search(
            r"DAEMON_SUPPORTED_TOOL_NAMES:\s*&\[&str\]\s*=\s*&\[(.*?)\];", src, re.S
        )
        if not match:
            last_error = RuntimeError(f"constant not found at {ref}")
            continue
        names = re.findall(r'"([a-z_]+)"', match.group(1))
        if names:
            if ref == "main":
                print(f"  note: tag v{version} unavailable, counted from main", file=sys.stderr)
            return len(names)
    sys.exit(f"error: could not read the daemon tool list ({last_error})")


def scan_docs() -> tuple[dict[str, dict[int, list[str]]], list[str]]:
    """Collect claimed values per role, plus any stray count-shaped numbers."""
    claims: dict[str, dict[int, list[str]]] = {role: {} for role in PATTERNS}
    strays: list[str] = []

    for pattern in DOC_GLOBS:
        for path in sorted(REPO_ROOT.glob(pattern)):
            rel = path.relative_to(REPO_ROOT)
            for lineno, line in enumerate(path.read_text().splitlines(), 1):
                matched_spans = []
                for role, regexes in PATTERNS.items():
                    for rx in regexes:
                        for m in re.finditer(rx, line):
                            value = int(m.group(1))
                            claims[role].setdefault(value, []).append(f"{rel}:{lineno}")
                            matched_spans.append(m.span())

                # Guard: a number next to "tool"/"resource"/"language" that no
                # pattern claimed means the prose was reworded and this checker
                # has gone blind to it. Scoped to the individual match, never
                # to the whole line.
                for m in re.finditer(STRAY_NOUNS, line):
                    if any(s <= m.start() < e for s, e in matched_spans):
                        continue
                    strays.append(f"{rel}:{lineno}: ...{m.group(0)}... in: {line.strip()}")

    return claims, strays


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", action="store_true", help="print ground truth and exit")
    ap.add_argument("--binary", default="sqry-mcp")
    args = ap.parse_args()

    binary = shutil.which(args.binary)
    if not binary:
        sys.exit(f"error: {args.binary} not found on PATH")

    truth = ground_truth(binary, REPO_ROOT)
    version = truth.pop("_version")

    print(f"sqry-mcp {version} reports:")
    for role, value in truth.items():
        print(f"  {role:<18} {value}")

    if args.show:
        return 0

    claims, strays = scan_docs()
    failures = []

    for role, expected in truth.items():
        found = claims[role]
        if not found:
            failures.append(
                f"{role}: documented nowhere. Expected {expected} to appear in the docs."
            )
            continue
        for value, sites in sorted(found.items()):
            if value != expected:
                shown = ", ".join(sites[:6])
                more = f" (+{len(sites) - 6} more)" if len(sites) > 6 else ""
                failures.append(
                    f"{role}: docs say {value}, sqry says {expected} at {shown}{more}"
                )

    for stray in strays:
        failures.append(f"unrecognized count phrasing, checker cannot verify it: {stray}")

    print()
    if failures:
        print("Documented counts do not match the shipped sqry surface:\n")
        for f in failures:
            print(f"  {f}")
        print(
            "\nFix the prose, then re-run. If a sentence was reworded, add its "
            "shape to PATTERNS in this script so it stays covered."
        )
        return 1

    print("All documented counts match the shipped sqry surface.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

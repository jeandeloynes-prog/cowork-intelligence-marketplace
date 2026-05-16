#!/usr/bin/env bash
# cowork-intelligence — probe_mcp_server.sh (v0.2.0)
#
# Spawn an MCP server (stdio transport) and ask it for tools/list.
# Print a single summary line with the measured cost.
#
# Usage:
#   ./scripts/probe_mcp_server.sh <command> [args...]
#
# Example:
#   ./scripts/probe_mcp_server.sh npx -y @modelcontextprotocol/server-filesystem /tmp
#
# Limitations:
#   - stdio transport only. HTTP / Streamable HTTP are out of scope for v0.2.0.
#   - Servers requiring env vars must be invoked with them in scope.
#   - Some servers are slow to boot; we use a 10 s timeout.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required." >&2
  exit 3
fi

# Build the JSON-RPC frames
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"cowork-intelligence-probe","version":"0.2.0"}}}'
INITIALIZED='{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
LIST='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

PAYLOAD="${INIT}
${INITIALIZED}
${LIST}
"

# Spawn the server and feed it the payload. 10 s timeout.
OUT=$(printf "%s" "$PAYLOAD" | (timeout 10 "$@" 2>/dev/null || true))

if [ -z "$OUT" ]; then
  echo "server=$* error=no_response_or_crash"
  exit 0
fi

python3 - "$@" <<PY
import sys, json

raw = """$OUT"""
cmdline = " ".join(sys.argv[1:])

tools = []
for line in raw.splitlines():
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    if isinstance(obj, dict) and obj.get("id") == 2 and "result" in obj:
        tools = obj["result"].get("tools", [])
        break

if not tools:
    print(f"server={cmdline!r} tools=? error=tools_list_not_returned")
    sys.exit(0)

desc_bytes = sum(len((t.get("description") or "").encode()) for t in tools)
schema_bytes = sum(len(json.dumps(t.get("inputSchema") or {}, separators=(",", ":")).encode()) for t in tools)
name_bytes = sum(len((t.get("name") or "").encode()) for t in tools)
total = desc_bytes + schema_bytes + name_bytes
approx_tokens = total // 4

print(
    f"server={cmdline!r} tools={len(tools)} "
    f"desc_bytes={desc_bytes} schema_bytes={schema_bytes} "
    f"total={total} (~{approx_tokens} tokens)"
)
PY

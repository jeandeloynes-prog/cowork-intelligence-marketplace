#!/usr/bin/env bash
# cowork-intelligence — graphify_post_edit.sh (v0.3.1)
#
# PostToolUse hook (matcher Edit|Write|MultiEdit).
# After any file edit, trigger a Graphify incremental update for the current
# project, in the background, with built-in debounce to avoid hammering.
#
# Silent + no-op if:
#   - the `graphify` binary is not on PATH or in ~/.local/bin/
#   - the user prefers running `graphify watch` as a daemon (just don't create
#     ~/.claude/graphify-config.json — the script then exits silently)
#
# To opt out entirely, remove the GRAPHIFY_BIN env var and ensure no
# `graphify-config.json` exists. The hook becomes a no-op (~10 ms).

set -euo pipefail

# Locate graphify binary the same way the refresh script does
BIN="${GRAPHIFY_BIN:-}"
[ -z "$BIN" ] && BIN=$(command -v graphify 2>/dev/null || echo "")
[ -z "$BIN" ] && BIN="$HOME/.local/bin/graphify"
[ -x "$BIN" ] || exit 0

# Opt-in via config file presence
CONFIG="$HOME/.claude/graphify-config.json"
[ -f "$CONFIG" ] || exit 0

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  # Best-effort fallback — try the current version path
  for v in 0.3.1 0.3.0; do
    candidate="$HOME/.claude/plugins/cache/cowork-intelligence-marketplace/cowork-intelligence/$v"
    [ -d "$candidate" ] && PLUGIN_ROOT="$candidate" && break
  done
fi
REFRESH="$PLUGIN_ROOT/scripts/graphify_refresh.sh"
[ -x "$REFRESH" ] || exit 0

# Fire and forget — log to a small file the user can inspect
LOG_DIR="$HOME/.claude/data/graphify-stamps"
mkdir -p "$LOG_DIR"
( "$REFRESH" project >> "$LOG_DIR/post-edit.log" 2>&1 ) &

exit 0

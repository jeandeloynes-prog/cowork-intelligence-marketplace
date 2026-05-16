#!/usr/bin/env bash
# cowork-intelligence — graphify_post_edit.sh (v0.3.0)
#
# PostToolUse hook (matcher Edit|Write).
# After any file edit, trigger a Graphify re-index for the current project
# scope, with built-in debounce to avoid hammering on rapid edit bursts.
#
# Silent if ~/.claude/graphify-config.json is absent (opt-in feature).

set -euo pipefail

CONFIG="$HOME/.claude/graphify-config.json"
[ -f "$CONFIG" ] || exit 0

# Delegate to the shared refresh script; let it handle scope detection,
# config lookup, debounce stamping, and CLI invocation. Run in background
# so the hook doesn't block subsequent tool calls.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/cache/cowork-intelligence-marketplace/cowork-intelligence/0.3.0}"
REFRESH="$PLUGIN_ROOT/scripts/graphify_refresh.sh"

if [ -x "$REFRESH" ]; then
  # Fire and forget — but capture exit code via wait-able subshell would lock
  # the hook. We log to a file so the user can inspect if needed.
  LOG_DIR="$HOME/.claude/data/graphify-stamps"
  mkdir -p "$LOG_DIR"
  ( "$REFRESH" >> "$LOG_DIR/post-edit.log" 2>&1 ) &
fi

exit 0

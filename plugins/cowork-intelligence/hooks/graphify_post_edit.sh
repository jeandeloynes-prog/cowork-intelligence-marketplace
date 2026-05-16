#!/usr/bin/env bash
# cowork-intelligence — graphify_post_edit.sh (v0.3.6)
#
# PostToolUse hook (matcher Edit|Write|MultiEdit).
# After any file edit, trigger a Graphify incremental update for the current
# project in the background, with debounce.
#
# v0.3.6 adds an unconditional entry log to disambiguate "hook never fired"
# from "hook fired but refresh exited silently".

set -euo pipefail

LOG_DIR="$HOME/.claude/data/graphify-stamps"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# ─── ENTRY MARKER (always written, no precondition) ──────────────────────
# If you don't see lines in hook-debug.log after an Edit, the hook itself
# never fires (Claude Code didn't trigger PostToolUse, or it ran a different
# binary).
{
  printf '[%s] hook fired — pwd=%s CLAUDE_PLUGIN_ROOT=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$PWD" \
    "${CLAUDE_PLUGIN_ROOT:-<unset>}"
} >> "$LOG_DIR/hook-debug.log" 2>/dev/null

# Locate graphify binary
BIN="${GRAPHIFY_BIN:-}"
[ -z "$BIN" ] && BIN=$(command -v graphify 2>/dev/null || echo "")
[ -z "$BIN" ] && BIN="$HOME/.local/bin/graphify"
if [ ! -x "$BIN" ]; then
  echo "  skip: graphify binary not found ($BIN)" >> "$LOG_DIR/hook-debug.log"
  exit 0
fi

# Opt-in via config file presence
CONFIG="$HOME/.claude/graphify-config.json"
if [ ! -f "$CONFIG" ]; then
  echo "  skip: $CONFIG not found (opt-in)" >> "$LOG_DIR/hook-debug.log"
  exit 0
fi

# Resolve plugin root — prefer Claude Code's $CLAUDE_PLUGIN_ROOT, fallback to
# scanning installed versions (any of them — most recent wins).
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  PLUGIN_ROOT=$(
    find "$HOME/.claude/plugins/cache/cowork-intelligence-marketplace/cowork-intelligence" \
      -maxdepth 1 -mindepth 1 -type d 2>/dev/null \
      | sort -V | tail -1
  )
fi

REFRESH="$PLUGIN_ROOT/scripts/graphify_refresh.sh"
if [ ! -x "$REFRESH" ]; then
  echo "  skip: refresh script not found ($REFRESH)" >> "$LOG_DIR/hook-debug.log"
  exit 0
fi

echo "  delegating to $REFRESH project" >> "$LOG_DIR/hook-debug.log"

# Fire and forget — refresh output goes to post-edit.log
( "$REFRESH" project >> "$LOG_DIR/post-edit.log" 2>&1 ) &

exit 0

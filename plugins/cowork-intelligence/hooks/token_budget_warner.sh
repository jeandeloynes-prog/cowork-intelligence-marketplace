#!/usr/bin/env bash
# cowork-intelligence — UserPromptSubmit hook
# Best-effort token-budget warning based on the size of stable context files.
# Stays silent unless we are clearly above a soft threshold.
#
# Disclaimer: this is a coarse estimate. 1 token ~= 4 bytes for English prose,
# closer to 3 bytes for code. The real per-turn cost includes the harness
# system prompt and MCP tool schemas which we cannot measure from here.

set -euo pipefail

SOFT_LIMIT_BYTES=$((40 * 1024))   # warn above ~10k tokens of stable context

total=0
add_bytes() {
  local f="$1"
  [ -f "$f" ] || return 0
  local b
  b=$(wc -c < "$f" 2>/dev/null || echo 0)
  total=$((total + b))
}

# CLAUDE.md cascade
add_bytes "$HOME/.claude/CLAUDE.md"
add_bytes "./CLAUDE.md"
add_bytes "./.claude/CLAUDE.md"

# Project skills
if [ -d "./.claude/skills" ]; then
  while IFS= read -r f; do add_bytes "$f"; done < <(find ./.claude/skills -name 'SKILL.md' 2>/dev/null)
fi

if [ "$total" -gt "$SOFT_LIMIT_BYTES" ]; then
  approx_tokens=$((total / 4))
  echo "[cowork-intelligence] stable context (project) ~ ${total} bytes (~${approx_tokens} tokens). Consider /cowork-optimize."
fi

exit 0

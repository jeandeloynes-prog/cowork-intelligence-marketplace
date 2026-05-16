#!/usr/bin/env bash
# cowork-intelligence — measure_context.sh
# Estimate the stable context footprint of a Claude Code / Cowork project.
# Rough rule: 1 token ~= 4 bytes for English prose; closer to 3 bytes for code.
#
# Usage: ./scripts/measure_context.sh [project_root]
# Default project_root: current working directory.

set -euo pipefail

ROOT="${1:-.}"

bytes_of() {
  [ -f "$1" ] || { echo 0; return; }
  wc -c < "$1" | tr -d ' '
}

human() {
  local b="$1"
  if [ "$b" -ge 1048576 ]; then
    awk -v b="$b" 'BEGIN { printf "%.1f MB", b/1048576 }'
  elif [ "$b" -ge 1024 ]; then
    awk -v b="$b" 'BEGIN { printf "%.1f KB", b/1024 }'
  else
    echo "${b} B"
  fi
}

total=0
add() { total=$((total + $1)); }

echo "=== CLAUDE.md cascade ==="
for f in "$HOME/.claude/CLAUDE.md" "$ROOT/CLAUDE.md" "$ROOT/.claude/CLAUDE.md"; do
  if [ -f "$f" ]; then
    b=$(bytes_of "$f")
    printf "  %-60s %s\n" "$f" "$(human "$b")"
    add "$b"
  fi
done

echo "=== Project skills ==="
if [ -d "$ROOT/.claude/skills" ]; then
  while IFS= read -r f; do
    b=$(bytes_of "$f")
    printf "  %-60s %s\n" "$f" "$(human "$b")"
    add "$b"
  done < <(find "$ROOT/.claude/skills" -name 'SKILL.md' 2>/dev/null | sort)
else
  echo "  (no project skills directory)"
fi

echo "=== User skills ==="
if [ -d "$HOME/.claude/skills" ]; then
  while IFS= read -r f; do
    b=$(bytes_of "$f")
    printf "  %-60s %s\n" "$f" "$(human "$b")"
    add "$b"
  done < <(find "$HOME/.claude/skills" -name 'SKILL.md' 2>/dev/null | sort)
else
  echo "  (no user skills directory)"
fi

echo "=== Project MCP config ==="
for f in "$ROOT/.mcp.json" "$ROOT/.claude/.mcp.json" "$HOME/.claude/.mcp.json"; do
  if [ -f "$f" ]; then
    b=$(bytes_of "$f")
    printf "  %-60s %s\n" "$f" "$(human "$b")"
    add "$b"
  fi
done

echo
approx_tokens=$((total / 4))
echo "Approx total measurable stable context: $(human "$total")  (~ ${approx_tokens} tokens at 4 B/token)"
echo
echo "Note: this does NOT include the harness system prompt or MCP tool"
echo "      descriptions loaded at runtime. Real per-turn cost will be higher."

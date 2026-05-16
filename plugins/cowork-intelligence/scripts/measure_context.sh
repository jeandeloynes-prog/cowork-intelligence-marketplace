#!/usr/bin/env bash
# cowork-intelligence — measure_context.sh (v0.2.0)
#
# Estimate the stable context footprint of a Claude Code / Cowork project.
# Rough rule: 1 token ~= 4 bytes for English prose; closer to 3 bytes for code.
#
# v0.2.0 fixes:
#   - Deduplicate paths via realpath when project root resolves to $HOME
#     (so we don't double-count CLAUDE.md or user skills).
#   - Properly scan ~/.claude/skills/ (user-level skills installed outside the
#     plugin cache — these were missed in v0.1.0 and can dominate cost).
#   - Distinguish per-section subtotals from grand total.
#
# Usage: ./scripts/measure_context.sh [project_root]
# Default project_root: current working directory.

set -euo pipefail

ROOT="${1:-.}"

# realpath fallback for systems without it (older macOS bash)
resolve() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1" 2>/dev/null || echo "$1"
  else
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1" 2>/dev/null || echo "$1"
  fi
}

SEEN_FILE=$(mktemp)
trap 'rm -f "$SEEN_FILE"' EXIT

# Returns 0 if path was already seen; 1 if it's new (and records it).
mark_seen() {
  local p
  p=$(resolve "$1")
  if grep -qxF "$p" "$SEEN_FILE" 2>/dev/null; then
    return 0
  fi
  echo "$p" >> "$SEEN_FILE"
  return 1
}

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
section_total=0

add_file() {
  local f="$1"
  [ -f "$f" ] || return 0
  if mark_seen "$f"; then
    return 0   # duplicate, silently skip
  fi
  local b
  b=$(bytes_of "$f")
  printf "  %-65s %s\n" "$f" "$(human "$b")"
  total=$((total + b))
  section_total=$((section_total + b))
}

reset_section() { section_total=0; }
print_section_total() {
  if [ "$section_total" -gt 0 ]; then
    echo "  subtotal: $(human "$section_total")"
  else
    echo "  (none)"
  fi
}

echo "=== CLAUDE.md cascade ==="
reset_section
for f in "$HOME/.claude/CLAUDE.md" "$ROOT/CLAUDE.md" "$ROOT/.claude/CLAUDE.md"; do
  add_file "$f"
done
print_section_total

echo "=== User skills (~/.claude/skills/) ==="
reset_section
if [ -d "$HOME/.claude/skills" ]; then
  while IFS= read -r f; do add_file "$f"; done < <(find "$HOME/.claude/skills" -name 'SKILL.md' 2>/dev/null | sort)
fi
print_section_total

echo "=== Project skills (./.claude/skills/) ==="
reset_section
if [ -d "$ROOT/.claude/skills" ]; then
  while IFS= read -r f; do add_file "$f"; done < <(find "$ROOT/.claude/skills" -name 'SKILL.md' 2>/dev/null | sort)
fi
print_section_total

echo "=== Plugin skills (~/.claude/plugins/cache/) ==="
reset_section
if [ -d "$HOME/.claude/plugins/cache" ]; then
  while IFS= read -r f; do add_file "$f"; done < <(find "$HOME/.claude/plugins/cache" -name 'SKILL.md' 2>/dev/null | sort)
fi
print_section_total

echo "=== MCP config files ==="
reset_section
for f in "$HOME/.claude/.mcp.json" "$ROOT/.mcp.json" "$ROOT/.claude/.mcp.json"; do
  add_file "$f"
done
print_section_total

echo
approx_tokens=$((total / 4))
echo "TOTAL deduplicated (measurable) : $(human "$total")  (~ ${approx_tokens} tokens at 4 B/token)"
echo
echo "Notes:"
echo "  - This does NOT include the Claude Code harness system prompt,"
echo "    nor the live MCP tool descriptions loaded at runtime."
echo "  - Skill BODIES count above; on a given turn, only triggered skills"
echo "    actually consume tokens (their descriptions are always loaded)."

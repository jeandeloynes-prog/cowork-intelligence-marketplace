#!/usr/bin/env bash
# cowork-intelligence — UserPromptSubmit hook (v0.2.1)
#
# Estimate the per-turn STABLE context (descriptions only, not bodies) and
# emit a single warning line if it exceeds a soft threshold.
#
# Stays silent in the common case. Designed to be fast (<200ms typically).
#
# v0.2.1 fixes:
#   - Stop summing SKILL.md bodies (v0.1.0/v0.2.0 over-estimated wildly when
#     bodies were heavy, e.g. gstack).
#   - Now sums:
#       * CLAUDE.md cascade (full content — it IS loaded per turn)
#       * SKILL.md YAML frontmatter `description` field (loaded per turn)
#   - Hooked with a 5 s timeout via hooks.json.

set -euo pipefail

SOFT_LIMIT_BYTES=$((40 * 1024))   # ~10K tokens of stable context — soft warn

total=0

# 1. CLAUDE.md cascade (full bytes)
for f in "$HOME/.claude/CLAUDE.md" "./CLAUDE.md" "./.claude/CLAUDE.md"; do
  if [ -f "$f" ]; then
    b=$(wc -c < "$f" 2>/dev/null || echo 0)
    total=$((total + b))
  fi
done

# 2. SKILL.md description bytes (NOT bodies) — user scope + project scope.
#    We use python3 for robust YAML frontmatter parsing.
if command -v python3 >/dev/null 2>&1; then
  desc_bytes=$(python3 - <<'PY' 2>/dev/null || echo 0
import os, sys, re

roots = [
    os.path.expanduser('~/.claude/skills'),
    os.path.join(os.getcwd(), '.claude/skills'),
]
seen = set()
total = 0
for root in roots:
    if not os.path.isdir(root):
        continue
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if fn != 'SKILL.md':
                continue
            path = os.path.realpath(os.path.join(dirpath, fn))
            if path in seen:
                continue
            seen.add(path)
            try:
                with open(path, 'r', errors='replace') as f:
                    txt = f.read()
            except Exception:
                continue
            if not txt.startswith('---'):
                continue
            end = txt.find('\n---', 4)
            if end < 0:
                continue
            fm = txt[3:end]
            m = re.search(
                r'^description:\s*(\||>)?\s*(.*?)(?=\n[A-Za-z_][A-Za-z0-9_-]*:|\Z)',
                fm, re.M | re.S,
            )
            if not m:
                continue
            body = m.group(2)
            desc = ' '.join(ln.strip() for ln in body.splitlines() if ln.strip())
            total += len(desc.encode('utf-8'))
print(total)
PY
)
  total=$((total + desc_bytes))
fi

if [ "$total" -gt "$SOFT_LIMIT_BYTES" ]; then
  approx_tokens=$((total / 4))
  echo "[cowork-intelligence] stable context (descriptions + CLAUDE.md) ~ ${total} B (~${approx_tokens} tokens). Lance /cowork-intelligence:cowork-optimize pour le détail."
fi

exit 0

#!/usr/bin/env bash
# cowork-intelligence — detect_weak_descriptions.sh (v0.2.0)
#
# Scan SKILL.md files and flag those whose YAML `description:` field is
# below a threshold (default 80 chars after concatenating multiline values).
#
# Correctly handles:
#   - single-line:   description: foo
#   - block scalar:  description: |
#                      foo
#                      bar
#   - folded scalar: description: >
#                      foo
#                      bar
#
# Usage:
#   ./scripts/detect_weak_descriptions.sh [root] [threshold]
# Defaults:
#   root      = $HOME/.claude
#   threshold = 80

set -euo pipefail

ROOT="${1:-$HOME/.claude}"
THRESHOLD="${2:-80}"

extract_desc() {
  python3 - "$1" <<'PY' 2>/dev/null
import sys, re

path = sys.argv[1]
try:
    with open(path, 'r', errors='replace') as f:
        txt = f.read()
except Exception:
    sys.exit(0)

# Frontmatter must begin and end with ---
if not txt.startswith('---'):
    sys.exit(0)
end = txt.find('\n---', 4)
if end < 0:
    sys.exit(0)
fm = txt[3:end]

# Optional: prefer PyYAML if available (robust)
try:
    import yaml
    data = yaml.safe_load(fm)
    if isinstance(data, dict) and data.get('description') is not None:
        desc = str(data['description']).strip()
        print(desc.replace('\n', ' '))
        sys.exit(0)
except ImportError:
    pass
except Exception:
    pass

# Fallback: regex parser handling multiline scalars
m = re.search(
    r'^description:\s*(\||>)?\s*(.*?)(?=\n[A-Za-z_][A-Za-z0-9_-]*:|\Z)',
    fm, re.M | re.S,
)
if not m:
    print('')
    sys.exit(0)
indicator = m.group(1) or ''
body = m.group(2)
# Strip indentation if it was a block scalar
lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
desc = ' '.join(lines)
print(desc)
PY
}

count=0
weak=0
missing=0

while IFS= read -r f; do
  count=$((count + 1))
  desc=$(extract_desc "$f")
  len=${#desc}
  if [ "$len" -eq 0 ]; then
    echo "MISSING ( 0 chars): $f"
    missing=$((missing + 1))
  elif [ "$len" -lt "$THRESHOLD" ]; then
    printf "WEAK    (%2d chars): %s\n" "$len" "$f"
    weak=$((weak + 1))
  fi
done < <(find "$ROOT" -name 'SKILL.md' 2>/dev/null | sort)

echo
echo "Scanned : $count files"
echo "Weak    : $weak  (< $THRESHOLD chars after concatenation)"
echo "Missing : $missing"

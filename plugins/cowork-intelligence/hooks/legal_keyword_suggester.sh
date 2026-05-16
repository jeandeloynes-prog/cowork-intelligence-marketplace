#!/usr/bin/env bash
# cowork-intelligence — legal_keyword_suggester.sh (v0.2.0)
#
# UserPromptSubmit hook.
# If the user's prompt contains legal keywords AND fewer than 3 plugins from the
# claude-for-legal marketplace are enabled, print a one-line suggestion to
# enable them via /cowork-legal-mode on.
#
# Stays SILENT in all other cases to avoid context noise.
# Output goes to stdout — Claude Code surfaces it.

set -euo pipefail

# Read the user prompt from stdin (Claude Code passes the JSON event on stdin).
# We try the JSON shape first, fall back to raw text.
INPUT=$(cat 2>/dev/null || true)

PROMPT=""
if command -v python3 >/dev/null 2>&1; then
  PROMPT=$(python3 - <<PY 2>/dev/null || echo ""
import json, sys
data = sys.stdin.read() if False else """$INPUT"""
try:
    obj = json.loads(data)
    # Common shape: { "prompt": "..." } or { "user_message": "..." }
    print(obj.get("prompt") or obj.get("user_message") or obj.get("message") or "")
except Exception:
    print(data)
PY
)
fi
[ -z "$PROMPT" ] && PROMPT="$INPUT"

# Bilingual keyword set. Keep tight to avoid false triggers.
KEYWORDS='contrat|contract|NDA|SaaS MSA|DPA|RGPD|GDPR|CCPA|CPRA|HIPAA|privacy policy|politique de confidentialité|juridique|legal review|litigation|litige|trademark|marque déposée|brevet|patent|copyright|droit d.auteur|licence open source|open source license|terms of service|CGU|CGV|mentions légales|conformité réglementaire|compliance review|cease and desist|mise en demeure|takedown|DMCA'

if ! echo "$PROMPT" | grep -iEq "$KEYWORDS"; then
  exit 0
fi

# Count enabled legal plugins
ENABLED=$(python3 - <<'PY' 2>/dev/null || echo 0
import json, os, sys
p = os.path.expanduser('~/.claude/settings.json')
try:
    s = json.load(open(p))
    n = sum(1 for k, v in s.get('enabledPlugins', {}).items()
            if k.endswith('@claude-for-legal') and v)
    print(n)
except Exception:
    print(0)
PY
)

if [ "${ENABLED:-0}" -lt 3 ]; then
  echo "[cowork-intelligence] mot-clé juridique détecté, mais seuls ${ENABLED:-0} plugins claude-for-legal sont activés. Pour les activer en bloc : /cowork-legal-mode on (puis /reload-plugins)."
fi

exit 0

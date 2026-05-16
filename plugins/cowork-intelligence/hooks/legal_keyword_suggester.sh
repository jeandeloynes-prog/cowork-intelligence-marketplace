#!/usr/bin/env bash
# cowork-intelligence — legal_keyword_suggester.sh (v0.2.1)
#
# UserPromptSubmit hook.
# If the user's prompt contains legal keywords AND fewer than 3 plugins from
# the claude-for-legal marketplace are enabled, print a one-line suggestion.
# Stays SILENT in all other cases (no token waste).
#
# v0.2.1 optimisations:
#   - Replace python3 with jq for settings.json parsing (much faster startup).
#   - Bash-only prompt extraction (no python3 fork for the JSON event).
#   - Graceful no-op if jq is missing (hook never blocks the user).
#   - Hooked with a 3 s timeout via hooks.json.

set -euo pipefail

# Read the event JSON (or raw prompt) from stdin
INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

# Try to extract the user prompt from a JSON event ; fall back to raw text
PROMPT="$INPUT"
if command -v jq >/dev/null 2>&1 && printf '%s' "$INPUT" | head -c 1 | grep -q '{'; then
  PROMPT_FROM_JSON=$(printf '%s' "$INPUT" | jq -r '.prompt // .user_message // .message // empty' 2>/dev/null || true)
  [ -n "$PROMPT_FROM_JSON" ] && PROMPT="$PROMPT_FROM_JSON"
fi

# Tight bilingual keyword set
KEYWORDS='contrat|contract|NDA|SaaS MSA|DPA|RGPD|GDPR|CCPA|CPRA|HIPAA|privacy policy|politique de confidentialité|juridique|legal review|litigation|litige|trademark|marque déposée|brevet|patent|copyright|droit d.auteur|licence open source|open source license|terms of service|CGU|CGV|mentions légales|conformité réglementaire|compliance review|cease and desist|mise en demeure|takedown|DMCA|clause de confidentialité|confidentiality clause'

if ! printf '%s' "$PROMPT" | grep -iEq "$KEYWORDS"; then
  exit 0
fi

# Need jq to read settings.json. If missing, exit silent (fail-open).
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || exit 0

ENABLED=$(jq '[.enabledPlugins // {} | to_entries[] | select(.key | endswith("@claude-for-legal")) | select(.value == true)] | length' "$SETTINGS" 2>/dev/null || echo 0)

if [ "${ENABLED:-0}" -lt 3 ]; then
  echo "[cowork-intelligence] mot-clé juridique détecté, mais seuls ${ENABLED:-0} plugins claude-for-legal sont activés. Pour les activer en bloc : /cowork-intelligence:cowork-legal-mode on (puis redémarrer Claude Code — /reload-plugins ne suffit pas)."
fi

exit 0

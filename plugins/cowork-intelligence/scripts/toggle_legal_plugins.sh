#!/usr/bin/env bash
# cowork-intelligence — toggle_legal_plugins.sh (v0.2.0)
#
# Batch-enable or batch-disable the 13 plugins from the claude-for-legal
# marketplace by patching ~/.claude/settings.json with jq.
#
# Requires: jq.
#
# Usage:
#   ./scripts/toggle_legal_plugins.sh on
#   ./scripts/toggle_legal_plugins.sh off
#
# Side effects:
#   - Backs up ~/.claude/settings.json to ~/.claude/settings.json.bak.<timestamp>
#   - Writes new file atomically (mv).
#   - DOES NOT call /reload-plugins automatically — Claude Code only honors
#     that from inside its own prompt. After running, type /reload-plugins.

set -euo pipefail

ACTION="${1:-}"
if [ "$ACTION" != "on" ] && [ "$ACTION" != "off" ]; then
  echo "Usage: $0 <on|off>" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install via: brew install jq" >&2
  exit 3
fi

SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS" ]; then
  echo "Error: $SETTINGS not found." >&2
  exit 4
fi

BACKUP="${SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BACKUP"
echo "Backup written: $BACKUP"

LEGAL_PLUGINS=(
  commercial-legal
  corporate-legal
  employment-legal
  privacy-legal
  product-legal
  ip-legal
  litigation-legal
  regulatory-legal
  ai-governance-legal
  legal-clinic
  law-student
  legal-builder-hub
)

# Build a jq expression that sets each plugin key
JQ_EXPR='.enabledPlugins //= {}'
NEW_VAL=$([ "$ACTION" = "on" ] && echo "true" || echo "false")
for p in "${LEGAL_PLUGINS[@]}"; do
  JQ_EXPR+=" | .enabledPlugins[\"${p}@claude-for-legal\"] = ${NEW_VAL}"
done

TMP=$(mktemp)
jq "$JQ_EXPR" "$SETTINGS" > "$TMP"

# Validate the produced JSON before swapping
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TMP" >/dev/null 2>&1 || {
  echo "Error: generated settings.json is not valid JSON. Aborting (no changes applied)." >&2
  rm -f "$TMP"
  exit 5
}

mv "$TMP" "$SETTINGS"

echo
echo "Legal plugins set to: $ACTION"
echo "Modified keys:"
for p in "${LEGAL_PLUGINS[@]}"; do
  echo "  ${p}@claude-for-legal = ${NEW_VAL}"
done
echo
echo "Next step: in Claude Code, run /reload-plugins"

#!/usr/bin/env bash
# cowork-intelligence — graphify_refresh.sh (v0.3.0)
#
# Trigger a Graphify re-index for a given scope, by reading
# ~/.claude/graphify-config.json and running the configured CLI.
#
# Usage:
#   ./scripts/graphify_refresh.sh             # cwd-based project scope
#   ./scripts/graphify_refresh.sh user        # user-level graph
#   ./scripts/graphify_refresh.sh <project>   # explicit project name
#   ./scripts/graphify_refresh.sh all         # user + cwd project
#
# Behavior:
#   - If ~/.claude/graphify-config.json is absent: exit 0 silently
#     (graceful degradation — feature is opt-in).
#   - If jq is missing: print a one-line warning, exit 0.
#   - Honors a debounce window: if last refresh for this scope was < N
#     seconds ago, skip with a short message. Stamp file lives at
#     ~/.claude/data/graphify-stamps/<scope>.
#   - On success, prints the elapsed time.

set -euo pipefail

CONFIG="$HOME/.claude/graphify-config.json"
STAMP_DIR="$HOME/.claude/data/graphify-stamps"

if [ ! -f "$CONFIG" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[cowork-intelligence] graphify_refresh: jq required but missing — skip."
  exit 0
fi

mkdir -p "$STAMP_DIR"

BINARY=$(jq -r '.binary // empty' "$CONFIG")
DEBOUNCE=$(jq -r '.debounce_seconds // 30' "$CONFIG")

if [ -z "$BINARY" ]; then
  echo "[cowork-intelligence] graphify_refresh: 'binary' missing in $CONFIG — skip."
  exit 0
fi

if [ ! -x "$BINARY" ]; then
  echo "[cowork-intelligence] graphify_refresh: $BINARY not executable — skip."
  exit 0
fi

# Resolve the scope argument
ARG="${1:-}"
if [ -z "$ARG" ]; then
  # cwd-based: scope = basename of git toplevel, or basename of cwd
  if SCOPE=$(git rev-parse --show-toplevel 2>/dev/null); then
    SCOPE=$(basename "$SCOPE")
  else
    SCOPE=$(basename "$PWD")
  fi
fi

# Build the list of scopes to refresh
SCOPES=()
case "${ARG:-$SCOPE}" in
  all)
    SCOPES=("user")
    if PROJ=$(git rev-parse --show-toplevel 2>/dev/null); then
      SCOPES+=("$(basename "$PROJ")")
    fi
    ;;
  *)
    SCOPES=("${ARG:-$SCOPE}")
    ;;
esac

now=$(date +%s)

for scope in "${SCOPES[@]}"; do
  args_json=$(jq -r --arg s "$scope" '.scopes[$s].command_args // empty | @json' "$CONFIG")
  if [ -z "$args_json" ] || [ "$args_json" = "null" ]; then
    echo "[cowork-intelligence] graphify_refresh: scope '$scope' not configured in $CONFIG — skip."
    continue
  fi

  # Debounce check
  stamp="$STAMP_DIR/$scope"
  if [ -f "$stamp" ]; then
    last=$(cat "$stamp")
    delta=$(( now - last ))
    if [ "$delta" -lt "$DEBOUNCE" ]; then
      echo "[cowork-intelligence] graphify_refresh: scope '$scope' refreshed ${delta}s ago (debounce=${DEBOUNCE}s) — skip."
      continue
    fi
  fi

  # Parse the args array from JSON
  mapfile -t ARGS < <(jq -r --arg s "$scope" '.scopes[$s].command_args[]' "$CONFIG")

  echo "[cowork-intelligence] graphify_refresh: scope '$scope' running: $BINARY ${ARGS[*]}"
  start=$(date +%s)
  if "$BINARY" "${ARGS[@]}"; then
    end=$(date +%s)
    echo "[cowork-intelligence] graphify_refresh: scope '$scope' OK in $((end - start))s."
    echo "$end" > "$stamp"
  else
    echo "[cowork-intelligence] graphify_refresh: scope '$scope' FAILED (non-zero exit)." >&2
  fi
done

exit 0

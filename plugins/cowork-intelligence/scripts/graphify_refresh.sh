#!/usr/bin/env bash
# cowork-intelligence — graphify_refresh.sh (v0.3.1)
#
# Re-index a Graphify graph (project-scoped) or refresh the global cross-repo
# graph. Built on real Graphify sub-commands:
#   - graphify update          → fast incremental, no LLM (default for projects)
#   - graphify extract <path>  → initial build with LLM (only when graph doesn't exist yet)
#   - graphify global add      → register a path in the global (user-level) graph
#   - graphify global list     → query what's registered
#
# Usage:
#   ./scripts/graphify_refresh.sh             # cwd-based project scope (graphify update)
#   ./scripts/graphify_refresh.sh project     # same
#   ./scripts/graphify_refresh.sh extract     # force initial extract on cwd (slow + LLM)
#   ./scripts/graphify_refresh.sh user        # global graph (graphify global add for known paths)
#   ./scripts/graphify_refresh.sh all         # user then current project
#
# Config file: ~/.claude/graphify-config.json
#   - If absent: defaults are used (binary autodetect, default Graphify args).
#   - If present: overrides binary path and adds extra source paths to register
#     in the global graph for the "user" scope.

set -euo pipefail

CONFIG="$HOME/.claude/graphify-config.json"
STAMP_DIR="$HOME/.claude/data/graphify-stamps"

# Locate the Graphify binary
BINARY="${GRAPHIFY_BIN:-}"
if [ -z "$BINARY" ] && [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  BINARY=$(jq -r '.binary // empty' "$CONFIG" 2>/dev/null || echo "")
fi
[ -z "$BINARY" ] && BINARY=$(command -v graphify || true)
[ -z "$BINARY" ] && BINARY="$HOME/.local/bin/graphify"

if [ ! -x "$BINARY" ]; then
  # Graceful: feature opt-in. No graphify binary → no action.
  exit 0
fi

DEBOUNCE_DEFAULT=30
DEBOUNCE=$DEBOUNCE_DEFAULT
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  DEBOUNCE=$(jq -r ".debounce_seconds // ${DEBOUNCE_DEFAULT}" "$CONFIG" 2>/dev/null || echo "$DEBOUNCE_DEFAULT")
fi

mkdir -p "$STAMP_DIR"

ARG="${1:-project}"

# ───────────────────────────────────────────────────────────────────────
# Backend selection (v0.3.3)
#
# Priority:
#   1. graphify-config.json:.backend explicit value → use as-is
#   2. OLLAMA_BASE_URL set AND reachable (HEAD /models OK) → backend=ollama
#   3. nothing set → leave graphify on its own default (Gemini, OpenAI, …)
#
# Why this matters: graphify's auto-detection picks the first paid API key
# it sees in the env (Gemini, Claude, OpenAI, Kimi, then Ollama last). On a
# machine where the user wants Graphify routed locally (LM Studio) while
# keeping paid keys available for other tools, we need to pass
# --backend ollama explicitly. This block handles that without forcing the
# user to unset their paid keys.
# ───────────────────────────────────────────────────────────────────────
BACKEND=""
if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
  CONFIG_BACKEND=$(jq -r '.backend // empty' "$CONFIG" 2>/dev/null || echo "")
  if [ -n "$CONFIG_BACKEND" ] && [ "$CONFIG_BACKEND" != "auto" ] && [ "$CONFIG_BACKEND" != "null" ]; then
    BACKEND="$CONFIG_BACKEND"
  fi
fi
if [ -z "$BACKEND" ] && [ -n "${OLLAMA_BASE_URL:-}" ]; then
  # Best-effort liveness check (2 s timeout). curl is on every macOS.
  if curl -fsS -m 2 "${OLLAMA_BASE_URL%/}/models" >/dev/null 2>&1; then
    BACKEND="ollama"
  fi
fi

BACKEND_ARGS=()
if [ -n "$BACKEND" ]; then
  BACKEND_ARGS=(--backend "$BACKEND")
  if [ "$BACKEND" = "ollama" ]; then
    # Local LLMs can be slower than cloud — give them headroom
    BACKEND_ARGS+=(--api-timeout 600)
  fi
fi

# Resolve cwd project path (used for project / extract / all).
# Returns empty string if we are NOT in a usable project — caller must handle.
resolve_project_path() {
  local proj
  if proj=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "$proj"
    return 0
  fi
  # Safety guards to avoid indexing huge non-project trees:
  # - refuse if cwd is HOME (would scan every dotfile + Documents + etc.)
  # - refuse if cwd is "/"
  # - refuse if cwd is a known non-project area
  case "$PWD" in
    "$HOME"|"$HOME/"|"/"|"/Users"|"/Users/"|"/tmp"|"/var"|"/etc")
      echo ""
      return 1
      ;;
  esac
  echo "$PWD"
}

# Debounce check — returns 0 if we should skip, 1 if we should proceed
check_debounce() {
  local scope="$1"
  local stamp="$STAMP_DIR/$scope"
  [ -f "$stamp" ] || return 1
  local last delta
  last=$(cat "$stamp")
  delta=$(( $(date +%s) - last ))
  if [ "$delta" -lt "$DEBOUNCE" ]; then
    echo "[cowork-intelligence] graphify_refresh: scope '$scope' refreshed ${delta}s ago (debounce=${DEBOUNCE}s) — skip."
    return 0
  fi
  return 1
}

stamp_now() {
  date +%s > "$STAMP_DIR/$1"
}

run_project() {
  local mode="$1"   # update | extract
  local path
  path=$(resolve_project_path) || true
  if [ -z "$path" ]; then
    echo "[cowork-intelligence] graphify_refresh: cwd '$PWD' is not inside a git repo and is a protected location (HOME, /, /Users, etc.). Refusing to $mode. Either:"
    echo "  - cd into a project directory first, OR"
    echo "  - run 'graphify $mode <path>' manually with an explicit path."
    return 0
  fi
  local scope
  scope=$(basename "$path")

  check_debounce "$scope" && return 0

  local backend_label="default"
  [ -n "$BACKEND" ] && backend_label="$BACKEND"
  echo "[cowork-intelligence] graphify_refresh: $mode → $path (backend=$backend_label)"
  local start end
  start=$(date +%s)
  if [ "$mode" = "extract" ]; then
    "$BINARY" extract "$path" "${BACKEND_ARGS[@]}"
  else
    # `graphify update` runs in the cwd of the graph; cd into the project first.
    ( cd "$path" && "$BINARY" update "${BACKEND_ARGS[@]}" )
  fi
  end=$(date +%s)
  echo "[cowork-intelligence] graphify_refresh: $mode '$scope' OK in $((end - start))s."
  stamp_now "$scope"
}

run_user_global() {
  check_debounce "user" && return 0

  echo "[cowork-intelligence] graphify_refresh: refreshing global cross-repo graph"
  local start end
  start=$(date +%s)

  # Re-register any extra source paths from config (idempotent — graphify
  # global add is safe to call repeatedly on the same path).
  if [ -f "$CONFIG" ] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      [ -d "$p" ] || continue
      echo "  + $p"
      "$BINARY" global add "$p" || true
    done < <(jq -r '.user.global_paths[]? // empty' "$CONFIG")
  fi

  # List the global graph state (cheap, useful as a sanity check)
  "$BINARY" global list || true

  end=$(date +%s)
  echo "[cowork-intelligence] graphify_refresh: user/global OK in $((end - start))s."
  stamp_now "user"
}

case "$ARG" in
  extract)
    run_project extract
    ;;
  user)
    run_user_global
    ;;
  all)
    run_user_global
    run_project update
    ;;
  project|*)
    run_project update
    ;;
esac

exit 0

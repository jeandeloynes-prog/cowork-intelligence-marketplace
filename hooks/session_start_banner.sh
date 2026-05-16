#!/usr/bin/env bash
# cowork-intelligence — SessionStart hook
# Prints a 1-line banner so the user knows the plugin is loaded.
# Stays under 5 lines of output to avoid context bloat.

set -euo pipefail

echo "[cowork-intelligence] active — try /cowork-analyze, /cowork-optimize, /cowork-audit"
exit 0

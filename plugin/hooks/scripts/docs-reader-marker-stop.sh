#!/usr/bin/env bash
# SubagentStop matcher "docs-reader": remove the active marker so the gate
# resumes blocking main-session calls until another docs-reader spins up.
set -euo pipefail

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"')
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9_-')
marker="${TMPDIR:-/tmp}/.docs-reader-active-${session_id}"
/bin/rm -f "$marker" 2>/dev/null || true
exit 0

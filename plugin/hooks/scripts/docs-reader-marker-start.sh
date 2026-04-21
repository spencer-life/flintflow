#!/usr/bin/env bash
# SubagentStart matcher "docs-reader": create marker so the docs-redirect-gate
# allows this subagent's claude-docs-helper.sh calls through.
set -euo pipefail

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"')
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9_-')
marker="${TMPDIR:-/tmp}/.docs-reader-active-${session_id}"
touch "$marker"
exit 0

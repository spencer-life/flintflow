#!/usr/bin/env bash
# SubagentStop hook (matcher: code-reviewer): creates the marker that
# unblocks pr-security-gate.sh for the rest of this session.
set -euo pipefail

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"')
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9_-')
marker="${TMPDIR:-/tmp}/.flintflow-security-review-${session_id}"
touch "$marker"
exit 0

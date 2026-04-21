#!/usr/bin/env bash
# PreToolUse Bash hook: force claude-docs-helper.sh invocations to go
# through the docs-reader subagent, not main session (which dumps verbose
# output into the transcript).
#
# Security best-practices: set -euo pipefail, sanitized session_id, no
# filesystem ops on user input, no shell expansion of untrusted data.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"')
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9_-')

# Not a helper invocation → allow.
printf '%s' "$cmd" | grep -q 'claude-docs-helper\.sh' || exit 0

marker="${TMPDIR:-/tmp}/.docs-reader-active-${session_id}"

# Marker exists → a docs-reader subagent is running this call, allow.
[ -f "$marker" ] && exit 0

# Otherwise deny and redirect to the subagent.
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Running `claude-docs-helper.sh` in main session dumps the full doc into the transcript — verbose and noisy. Dispatch the docs-reader subagent instead:\n\n  Agent(subagent_type=\"docs-reader\", description=\"Pull CC docs\", prompt=\"topic: <topic>\\nquestion: <what you need to know>\")\n\nThe subagent reads docs in isolated context and returns just the relevant answer."
  }
}'
exit 0

#!/usr/bin/env bash
# PreToolUse Bash hook: block `gh pr create` until a security-focused
# code-reviewer subagent has completed this session.
# Paired with security-review-marker.sh (SubagentStop matcher code-reviewer).
set -euo pipefail

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "default"')
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9_-')
marker="${TMPDIR:-/tmp}/.flintflow-security-review-${session_id}"

# Marker exists → security review ran this session, allow PR creation.
[ -f "$marker" ] && exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "FlintFlow: run a security-focused code-reviewer subagent before creating the PR. Spawn it with:\n\nAgent(subagent_type=\"code-reviewer\", prompt=\"Security review of pending changes. Check: SQL injection, unauthenticated endpoints, input validation, hardcoded secrets, OWASP top 10, body size limits, role hierarchy checks, rate limiting. Skip if changes are docs/styling-only.\")\n\nPR creation unblocks automatically when the subagent finishes. Skip: set FLINTFLOW_SKIP_SECURITY_GATE=1 env var for docs-only PRs."
  }
}'
exit 0

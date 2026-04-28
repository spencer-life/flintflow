#!/usr/bin/env bash
# PreToolUse Bash hook: block `gh pr create` until a security-focused
# code-reviewer subagent has completed this session.
# Paired with security-review-marker.sh (SubagentStop matcher code-reviewer).
#
# Defense in depth — the `if: "Bash(gh pr create*)"` matcher in hooks.json
# is meant to scope this hook to PR-create calls only, but Claude Code's
# engine has been observed silently ignoring `if:` (verified 2026-04-28),
# causing this hook to fire on every Bash call until the SubagentStop
# marker is set. We re-check the command here so a manifest-level engine
# regression doesn't break daily Bash use.
set -euo pipefail

input=$(cat)

# Advertised in the deny message below; honor it for real.
if [ "${FLINTFLOW_SKIP_SECURITY_GATE:-}" = "1" ]; then
	exit 0
fi

# Self-filter: only fire when the command starts with `gh pr create`.
# Mirrors the manifest matcher `Bash(gh pr create*)` semantics — start-anchored
# so an `echo "gh pr create..."` doesn't trip the gate.
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
case "$cmd" in
gh\ pr\ create*) ;;
*) exit 0 ;;
esac

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

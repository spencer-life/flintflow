#!/usr/bin/env bash
# UserPromptSubmit hook: detect session-end signals in user prompts and
# inject a /wrap-up reminder (only shows in context, doesn't block).
set -euo pipefail

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')

# Session-end signals (matches /wrap-up skill triggers).
if printf '%s' "$prompt" | grep -qiE "(i'?m done|that'?s it( for today)?|wrap (it|things) up|close (out|this task|session)|ok[[:space:]]+i'?m good|nothing else|close session|end session)"; then
	jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "FlintFlow: session-end signal detected. Consider invoking /wrap-up to run the end-of-session checklist (status, verification, commits, memory updates, self-improvement). Skip if this was not intended as a session end."
    }
  }'
fi
exit 0

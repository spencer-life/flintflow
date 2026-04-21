#!/usr/bin/env bash
# PostToolUse Bash hook: after DB-mutating commands, nudge /data-verify.
# Non-blocking — just injects a reminder via additionalContext.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Detect DB mutations: supabase migrate/push, psql DML/DDL, migration scripts, seed scripts.
if printf '%s' "$cmd" | grep -qiE '(supabase[[:space:]]+(migrate|db[[:space:]]+push|functions[[:space:]]+deploy)|psql[^|]*-c[^|]*(insert|update|delete|create[[:space:]]+table|alter|drop)|(migrate|migration):(up|down|run|apply)|[[:space:]]+\.sql([[:space:]]|$)|migrations/[^[:space:]]+\.(sql|ts|js|py)|seed[^[:space:]]*\.(sql|ts|js|py))'; then
	jq -n '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: "FlintFlow: DB change detected. Run /data-verify to confirm ground-truth values match expectations before continuing."
    }
  }'
fi
exit 0

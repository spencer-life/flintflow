#!/usr/bin/env bash
# UserPromptSubmit hook: detect deployed-service keywords in user prompts and
# inject the error-logging checklist so Claude doesn't forget to add it.
# Non-blocking — just additionalContext.
set -euo pipefail

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')

# Deployed-service keywords. Expand over time as new service types come up.
if printf '%s' "$prompt" | grep -qiE "(discord[[:space:]]*bot|underwriting[[:space:]]*bot|express[[:space:]]*(api|app)|(supabase|edge)[[:space:]]*function|api[[:space:]]*route|webhook|railway[[:space:]]*(service|bot|app)|next\.?js[[:space:]]*(api|app)|fastapi|flask|worker|cloudflare[[:space:]]*worker)"; then
	jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "FlintFlow: deployed-service keyword detected. Apply the error-logging checklist from quality-standards.md before shipping:\n  - Node.js: process.on(unhandledRejection) + process.on(uncaughtException) + try/catch on async handlers\n  - Discord: client.on(error) + client.on(warn) + shard listeners + client.login().catch()\n  - Express/API routes: wrap handlers in try/catch, log with route/params/user context\n  - Next.js: error.tsx boundaries + API route error handling\n  - Supabase Edge Functions: wrap entire handler in try/catch with function name + request context\n  - Error messages must include WHAT failed, WHERE (function/file), WHY (actual error). Never bare console.error(e).\n\nIf editing an existing service, run /add-logging to audit what is missing."
    }
  }'
fi
exit 0

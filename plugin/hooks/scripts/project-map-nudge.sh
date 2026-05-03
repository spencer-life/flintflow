#!/usr/bin/env bash
# PreToolUse(Edit|Write) hook: when the user edits a service-config file,
# nudge them to refresh PROJECT_MAP.md so the visual service graph stays current.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')

case "$file_path" in
*/railway.json | */railway.toml | */netlify.toml | */wrangler.json | */wrangler.jsonc | */wrangler.toml | */supabase/config.toml | */.env.example | */.env.sample)
	jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: "FlintFlow: editing a service-config file. After this change, consider running /project-map to refresh PROJECT_MAP.md so the visual service graph reflects the new state. Skip if PROJECT_MAP.md is already up to date or this change does not affect external services."
        }
      }'
	;;
esac
exit 0

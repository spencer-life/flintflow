#!/usr/bin/env bash
# Two firing surfaces for one nudge:
#   1. PreCompact     — fires before context compaction; suggest /handoff first
#                       so the next session has a real handoff doc, not a summary.
#   2. UserPromptSubmit — phrase-based fallback for "running out of context",
#                         "let me checkpoint", "before I clear", etc.
set -euo pipefail

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""')

if [ "$event" = "PreCompact" ]; then
	jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreCompact",
          additionalContext: "FlintFlow: context is about to be compacted. Consider invoking /handoff FIRST to write a structured context-transfer document — that gives the next session real continuity instead of a compaction summary. Skip if you do not need session continuity for this task."
        }
      }'
	exit 0
fi

if [ "$event" = "UserPromptSubmit" ]; then
	prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')
	if printf '%s' "$prompt" | grep -qiE "(running out of context|context is getting big|context window|let me checkpoint|before i clear|save context|checkpoint (this|now))"; then
		jq -n '{
            hookSpecificOutput: {
              hookEventName: "UserPromptSubmit",
              additionalContext: "FlintFlow: context-management signal detected. Consider invoking /handoff to write a structured context-transfer document so the next session can /catchup cleanly. Skip if this was not a context-management request."
            }
          }'
	fi
fi
exit 0

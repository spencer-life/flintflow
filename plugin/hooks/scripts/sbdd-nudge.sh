#!/usr/bin/env bash
# UserPromptSubmit hook: detect implementation-trigger phrases and inject
# a reminder about /subagent-driven-development (with skip guidance so it
# isn't applied to trivial work).
set -euo pipefail

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')

# Trigger phrases — what the user actually says when they want to execute a plan.
if printf '%s' "$prompt" | grep -qiE "(let'?s (build|implement|execute|ship) (it|this)?|(go ahead and )?(build|execute|implement|ship) (it|this)|build it now|execute it now|implement (it|this) now|make it happen|ship it|ok build|ok execute|ok implement|start building|start implementing|run the pipeline)"; then
	jq -n '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "FlintFlow: implementation-trigger phrase detected. Consider invoking /subagent-driven-development to run the full pipeline (pre-flight → approach check → TDD implement → tests → parallel reviewers → data verify → smoke test → Codex audit).\n\nSKIP the skill if ANY of these apply:\n  - Trivial change (< 10 lines, single file)\n  - Typo / comment / rename-only edit\n  - Config tweak (settings.json, env vars, README)\n  - Read-only investigation or answering a question\n  - No implementation plan yet (run /design first instead)\n  - Task too tightly coupled to split across subagents\n\nUse the skill WHEN: multi-file feature, plan already exists, independent tasks, staying in this session, tests + review matter."
    }
  }'
fi
exit 0

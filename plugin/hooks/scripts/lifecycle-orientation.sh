#!/usr/bin/env bash
# SessionStart hook: print "you are here" orientation lines for FlintFlow projects.
# Silent no-op if cwd has no PROJECT_STATE.md (avoids polluting non-flintflow sessions).
set -euo pipefail

[ -f PROJECT_STATE.md ] || exit 0

LINES=("=== FlintFlow position ===")

# Stale handoff present?
if [ -f .claude/handoff.md ]; then
	HANDOFF_MTIME=$(stat -c %Y .claude/handoff.md 2>/dev/null || echo 0)
	NOW=$(date +%s)
	HANDOFF_AGE_DAYS=$(((NOW - HANDOFF_MTIME) / 86400))
	if [ "$HANDOFF_AGE_DAYS" -gt 7 ]; then
		LINES+=("Handoff file present (${HANDOFF_AGE_DAYS}d old — stale, read carefully) → consider /catchup")
	else
		LINES+=("Handoff file present (${HANDOFF_AGE_DAYS}d old) → consider /catchup")
	fi
fi

# Missing visual service map?
if [ ! -f PROJECT_MAP.md ]; then
	LINES+=("PROJECT_MAP.md missing → consider /project-map to generate the visual service graph")
fi

# Uncommitted changes?
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
	if [ "$CHANGES" -gt 0 ]; then
		LINES+=("$CHANGES uncommitted change(s) in working tree → /wrap-up when ready to close out")
	fi
fi

# Has VERIFICATION but no run history?
if [ -f VERIFICATION.md ] && [ ! -f verification/history.log ]; then
	LINES+=("VERIFICATION.md exists but no run history → consider /data-verify to ground-truth-check")
fi

LINES+=("Run /flintflow:lifecycle anytime for the full diagram + decision table.")

printf '%s\n' "${LINES[@]}"

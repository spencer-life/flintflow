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

# Multi-project root? Scan known monorepo subdirs for sub-projects with strong
# signals (own package.json with different name, own deploy config, own Dockerfile).
# Silent no-op if no sub-projects detected.
SUB_PROJECT_LIST=""
SUB_PROJECT_COUNT=0
ROOT_PKG_NAME=""
if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
	ROOT_PKG_NAME=$(jq -r '.name // ""' package.json 2>/dev/null || echo "")
fi
for parent in apps packages services agencies bots sites; do
	[ -d "$parent" ] || continue
	for sub in "$parent"/*/; do
		[ -d "$sub" ] || continue
		sub_name=$(basename "$sub")
		[[ "$sub_name" == .* ]] && continue
		strong=0
		if [ -f "$sub/package.json" ] && command -v jq >/dev/null 2>&1; then
			sub_pkg_name=$(jq -r '.name // ""' "$sub/package.json" 2>/dev/null || echo "")
			[[ -n "$sub_pkg_name" && "$sub_pkg_name" != "$ROOT_PKG_NAME" ]] && strong=1
		elif [ -f "$sub/package.json" ]; then
			strong=1
		fi
		[ -f "$sub/railway.toml" ] || [ -f "$sub/railway.json" ] && strong=1
		[ -f "$sub/netlify.toml" ] && strong=1
		[ -f "$sub/wrangler.toml" ] || [ -f "$sub/wrangler.json" ] || [ -f "$sub/wrangler.jsonc" ] && strong=1
		[ -f "$sub/supabase/config.toml" ] && strong=1
		[ -f "$sub/Dockerfile" ] && strong=1
		if [ "$strong" -eq 1 ]; then
			SUB_PROJECT_COUNT=$((SUB_PROJECT_COUNT + 1))
			SUB_PROJECT_LIST="${SUB_PROJECT_LIST}${SUB_PROJECT_LIST:+ · }${parent}/${sub_name}"
		fi
	done
done
if [ "$SUB_PROJECT_COUNT" -gt 0 ]; then
	LINES+=("Multi-project root: $SUB_PROJECT_COUNT sub-project(s) detected — $SUB_PROJECT_LIST")
	LINES+=("  → cd into one to work on it; root state covers shared/orchestrator concerns only")
fi

LINES+=("Run /flintflow:lifecycle anytime for the full diagram + decision table.")

printf '%s\n' "${LINES[@]}"

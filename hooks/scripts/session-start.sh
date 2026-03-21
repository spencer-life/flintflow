#!/bin/bash
# SessionStart hook: Enhanced git snapshot + handoff file detection
# Provides rich git context so new sessions can pick up seamlessly.
# Never exits non-zero.
# --- Git Status ---
echo "=== Git Status ==="
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	# Branch + remote tracking
	BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
	UPSTREAM=$(git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null)
	if [ -n "$UPSTREAM" ]; then
		AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
		BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
		echo "Branch: $BRANCH -> $UPSTREAM [ahead $AHEAD, behind $BEHIND]"
	else
		echo "Branch: $BRANCH (no upstream)"
	fi
	# Staged vs unstaged counts
	STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
	UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
	UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
	if [ "$STAGED" -gt 0 ] || [ "$UNSTAGED" -gt 0 ] || [ "$UNTRACKED" -gt 0 ]; then
		echo "Changes: $STAGED staged, $UNSTAGED unstaged, $UNTRACKED untracked"
	else
		echo "(working tree clean)"
	fi
	# Diff stats summary (if there are changes)
	if [ "$STAGED" -gt 0 ] || [ "$UNSTAGED" -gt 0 ]; then
		echo ""
		DIFF_STAT=$(git diff --stat HEAD 2>/dev/null | tail -1)
		if [ -n "$DIFF_STAT" ]; then
			echo "Diff: $DIFF_STAT"
		fi
	fi
	# Stash list
	STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
	if [ "$STASH_COUNT" -gt 0 ]; then
		echo ""
		echo "=== Stashes ($STASH_COUNT) ==="
		git stash list 2>/dev/null | head -3
		if [ "$STASH_COUNT" -gt 3 ]; then
			echo "  ... and $((STASH_COUNT - 3)) more"
		fi
	fi
	# Recent commits with conventional commit format visible
	echo ""
	echo "=== Recent Commits ==="
	if git rev-parse --verify HEAD >/dev/null 2>&1; then
		git log -5 --format='%C(yellow)%h%Creset %C(blue)%ad%Creset %s %C(dim)(%an)%Creset' --date=relative 2>/dev/null
	else
		echo "(no commits yet)"
	fi
else
	echo "(not a git repo)"
fi
# --- Handoff Files ---
echo ""
echo "=== Handoff Context ==="
HANDOFF_FILES=$(ls -1 .claude/handoff*.md 2>/dev/null)
if [ -z "$HANDOFF_FILES" ]; then
	echo "(no handoff files found — use /handoff when you're about to clear context)"
else
	# List all handoff files with details
	ls -la .claude/handoff*.md 2>/dev/null
	# Preview the default handoff if it exists
	if [ -f .claude/handoff.md ]; then
		# Calculate age in days (Linux stat)
		MTIME=$(stat -c %Y .claude/handoff.md 2>/dev/null || stat -f %m .claude/handoff.md 2>/dev/null)
		if [ -n "$MTIME" ]; then
			NOW=$(date +%s)
			AGE_DAYS=$(((NOW - MTIME) / 86400))
			echo ""
			echo "--- Preview (.claude/handoff.md) ---"
			head -10 .claude/handoff.md 2>/dev/null
			echo "..."
			if [ "$AGE_DAYS" -gt 3 ]; then
				echo ""
				echo "(handoff is ${AGE_DAYS} days old; consider using /catchup or creating a new handoff)"
			elif [ "$AGE_DAYS" -ge 1 ]; then
				echo "(handoff is ${AGE_DAYS} day(s) old)"
			else
				echo "(handoff from today)"
			fi
		fi
	fi
fi
exit 0

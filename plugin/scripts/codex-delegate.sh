#!/usr/bin/env bash
# Codex CLI wrapper — called by Claude Code skill, justfile, or directly
# Subcommands: exec, review, research, compare
# Exit codes: 0=success, 1=codex error, 2=timeout, 3=not installed
set -euo pipefail
# --- NVM/PATH setup ---
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh" 2>/dev/null
if ! command -v codex &>/dev/null; then
	echo "ERROR: codex CLI not found in PATH" >&2
	exit 3
fi
# --- Defaults ---
TIMEOUT=300
SANDBOX="read-only"
CWD=""
OUTPUT_FILE=""
WORKTREE=false
SEARCH=false
# --- Parse subcommand ---
SUBCMD="${1:-}"
shift 2>/dev/null || true
PROMPT="${1:-}"
shift 2>/dev/null || true
# --- Parse flags ---
while [[ $# -gt 0 ]]; do
	case "$1" in
	--timeout)
		TIMEOUT="$2"
		shift 2
		;;
	--sandbox)
		SANDBOX="$2"
		shift 2
		;;
	--cwd)
		CWD="$2"
		shift 2
		;;
	--output)
		OUTPUT_FILE="$2"
		shift 2
		;;
	--worktree)
		WORKTREE=true
		shift
		;;
	--search)
		SEARCH=true
		shift
		;;
	*)
		shift
		;;
	esac
done
# --- Output file setup ---
if [[ -z "$OUTPUT_FILE" ]]; then
	OUTPUT_FILE=$(mktemp "${TMPDIR:-/tmp}"/codex-result-XXXXXX.txt)
fi
# --- Worktree setup (Phase 6a) ---
WORKTREE_DIR=""
WORKTREE_BRANCH=""
cleanup_worktree() {
	if [[ -n "$WORKTREE_DIR" ]] && [[ -d "$WORKTREE_DIR" ]]; then
		# Only clean up if no changes were made
		if ! git -C "$WORKTREE_DIR" diff --quiet HEAD 2>/dev/null; then
			echo "WORKTREE: Changes detected — keeping worktree at $WORKTREE_DIR (branch: $WORKTREE_BRANCH)" >&2
		else
			git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
			git branch -D "$WORKTREE_BRANCH" 2>/dev/null || true
		fi
	fi
}
if [[ "$WORKTREE" == true ]]; then
	EFFECTIVE_CWD="${CWD:-$(pwd)}"
	if ! git -C "$EFFECTIVE_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
		echo "ERROR: --worktree requires a git repository" >&2
		exit 1
	fi
	WORKTREE_BRANCH="codex/temp-$(date +%s)"
	WORKTREE_DIR=$(mktemp -d "${TMPDIR:-/tmp}"/codex-worktree-XXXXXX)
	rmdir "$WORKTREE_DIR" # git worktree add needs a non-existent path
	git -C "$EFFECTIVE_CWD" worktree add "$WORKTREE_DIR" -b "$WORKTREE_BRANCH" 2>/dev/null
	CWD="$WORKTREE_DIR"
	trap cleanup_worktree EXIT
fi
# --- Build base args ---
BASE_ARGS=(--ephemeral -o "$OUTPUT_FILE")
[[ -n "$CWD" ]] && BASE_ARGS+=(-C "$CWD")
# Skip git repo check when not in a git repo (exec/research/compare don't need one)
EFFECTIVE_CWD="${CWD:-$(pwd)}"
if ! git -C "$EFFECTIVE_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
	BASE_ARGS+=(--skip-git-repo-check)
fi
# --- Search args ---
SEARCH_ARGS=()
if [[ "$SEARCH" == true ]]; then
	SEARCH_ARGS+=(-c 'search=true')
fi
# --- Execute subcommand ---
case "$SUBCMD" in
exec)
	if [[ -z "$PROMPT" ]]; then
		echo "Usage: codex-delegate.sh exec \"prompt\" [--timeout N] [--sandbox MODE] [--cwd DIR] [--worktree] [--search]" >&2
		exit 1
	fi
	timeout "$TIMEOUT" codex exec "${BASE_ARGS[@]}" "${SEARCH_ARGS[@]}" -s "$SANDBOX" "$PROMPT" >/dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
	;;
review)
	REVIEW_ARGS=(--ephemeral "${SEARCH_ARGS[@]}")
	[[ -n "$CWD" ]] && REVIEW_ARGS+=(-c "cwd=\"$CWD\"")
	if [[ -n "$PROMPT" ]]; then
		# PROMPT is used as --base branch
		timeout "$TIMEOUT" codex review "${REVIEW_ARGS[@]}" --base "$PROMPT" 2>/dev/null | tee "$OUTPUT_FILE" && EXIT_CODE=0 || EXIT_CODE=$?
	else
		timeout "$TIMEOUT" codex review "${REVIEW_ARGS[@]}" --uncommitted 2>/dev/null | tee "$OUTPUT_FILE" && EXIT_CODE=0 || EXIT_CODE=$?
	fi
	;;
research)
	if [[ -z "$PROMPT" ]]; then
		echo "Usage: codex-delegate.sh research \"topic\" [--timeout N]" >&2
		exit 1
	fi
	RESEARCH_PROMPT="Search the web and provide a concise, factual answer: ${PROMPT}"
	timeout "$TIMEOUT" codex exec "${BASE_ARGS[@]}" -c 'search=true' -s read-only "$RESEARCH_PROMPT" >/dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
	;;
compare)
	if [[ -z "$PROMPT" ]]; then
		echo "Usage: codex-delegate.sh compare \"question\" [--timeout N] [--cwd DIR] [--search]" >&2
		exit 1
	fi
	COMPARE_PROMPT="Analyze this codebase and give your independent assessment: ${PROMPT}"
	timeout "$TIMEOUT" codex exec "${BASE_ARGS[@]}" "${SEARCH_ARGS[@]}" -s read-only "$COMPARE_PROMPT" >/dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
	;;
*)
	echo "Unknown subcommand: $SUBCMD" >&2
	echo "Usage: codex-delegate.sh {exec|review|research|compare} \"prompt\" [flags]" >&2
	exit 1
	;;
esac
# --- Handle exit codes ---
if [[ $EXIT_CODE -eq 124 ]]; then
	echo "TIMEOUT: codex did not complete within ${TIMEOUT}s" >&2
	exit 2
elif [[ $EXIT_CODE -ne 0 ]]; then
	echo "Codex exited with code $EXIT_CODE" >&2
	exit 1
fi
# --- Post-write lint/format (Phase 6b) ---
if [[ "$SUBCMD" == "exec" ]] && [[ "$SANDBOX" == "workspace-write" ]]; then
	LINT_SCRIPT="$HOME/.claude/hooks/format-and-lint.sh"
	if [[ -x "$LINT_SCRIPT" ]]; then
		LINT_CWD="${CWD:-$(pwd)}"
		git -C "$LINT_CWD" diff --name-only HEAD 2>/dev/null | while read -r f; do
			FULL_PATH="$LINT_CWD/$f"
			if [[ -f "$FULL_PATH" ]]; then
				echo "{\"tool_input\":{\"file_path\":\"$FULL_PATH\"}}" | bash "$LINT_SCRIPT" 2>&1 || true
			fi
		done
	fi
fi
# --- Worktree result reporting ---
if [[ "$WORKTREE" == true ]] && [[ -n "$WORKTREE_DIR" ]]; then
	if ! git -C "$WORKTREE_DIR" diff --quiet HEAD 2>/dev/null; then
		echo ""
		echo "=== WORKTREE ==="
		echo "Path: $WORKTREE_DIR"
		echo "Branch: $WORKTREE_BRANCH"
		echo "--- Changes ---"
		git -C "$WORKTREE_DIR" diff --stat HEAD 2>/dev/null || true
		echo ""
		echo "To review: git -C $WORKTREE_DIR diff HEAD"
		echo "To apply:  git -C $WORKTREE_DIR format-patch -1 --stdout | git am"
		# Disable cleanup trap since we're keeping the worktree
		trap - EXIT
	fi
fi
# --- Output result ---
if [[ -f "$OUTPUT_FILE" ]] && [[ -s "$OUTPUT_FILE" ]]; then
	cat "$OUTPUT_FILE"
fi
exit 0

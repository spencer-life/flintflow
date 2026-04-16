#!/usr/bin/env bash
# Codex CLI wrapper — called by Claude Code skill, justfile, or directly
# Subcommands: exec, review, research, compare, adversarial-review, status, cancel, result
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
# --- Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$HOME/.codex/jobs"
# --- Defaults ---
TIMEOUT=300
SANDBOX="read-only"
CWD=""
OUTPUT_FILE=""
OUTPUT_FILE_EXPLICIT=false
WORKTREE=false
SEARCH=false
BACKGROUND=false
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
		OUTPUT_FILE_EXPLICIT=true
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
	--background)
		BACKGROUND=true
		shift
		;;
	*)
		shift
		;;
	esac
done
# --- Handle non-codex subcommands early (status, cancel, result) ---
case "$SUBCMD" in
status)
	mkdir -p "$JOBS_DIR"
	if [[ -z "$(ls -A "$JOBS_DIR" 2>/dev/null)" ]]; then
		echo "No background jobs found."
		exit 0
	fi
	echo "=== Codex Background Jobs ==="
	for job_file in "$JOBS_DIR"/*.json; do
		[[ -f "$job_file" ]] || continue
		JOB_ID=$(jq -r '.id' "$job_file")
		JOB_STATUS=$(jq -r '.status' "$job_file")
		JOB_SUBCMD=$(jq -r '.subcommand' "$job_file")
		JOB_STARTED=$(jq -r '.started_at' "$job_file")
		JOB_PID=$(jq -r '.pid' "$job_file")
		# Check if PID is still running and update status
		if [[ "$JOB_STATUS" == "running" ]] && ! kill -0 "$JOB_PID" 2>/dev/null; then
			JOB_EXIT=$(jq -r '.exit_code // "unknown"' "$job_file")
			if [[ "$JOB_EXIT" == "null" || "$JOB_EXIT" == "unknown" ]]; then
				JOB_STATUS="completed"
				jq --arg s "completed" --arg t "$(date -Iseconds)" '.status=$s | .completed_at=$t' "$job_file" >"${job_file}.tmp" && mv "${job_file}.tmp" "$job_file"
			fi
		fi
		printf "  %-20s  %-10s  %-18s  %s\n" "$JOB_ID" "$JOB_STATUS" "$JOB_SUBCMD" "$JOB_STARTED"
	done
	exit 0
	;;
cancel)
	JOB_ID="$PROMPT"
	if [[ -z "$JOB_ID" ]]; then
		echo "Usage: codex-delegate.sh cancel <job-id>" >&2
		exit 1
	fi
	JOB_FILE="$JOBS_DIR/${JOB_ID}.json"
	if [[ ! -f "$JOB_FILE" ]]; then
		echo "ERROR: Job '$JOB_ID' not found" >&2
		exit 1
	fi
	JOB_PID=$(jq -r '.pid' "$JOB_FILE")
	if kill -0 "$JOB_PID" 2>/dev/null; then
		kill "$JOB_PID" 2>/dev/null || true
		jq --arg s "cancelled" --arg t "$(date -Iseconds)" '.status=$s | .completed_at=$t' "$JOB_FILE" >"${JOB_FILE}.tmp" && mv "${JOB_FILE}.tmp" "$JOB_FILE"
		echo "Cancelled job $JOB_ID (PID $JOB_PID)"
	else
		echo "Job $JOB_ID is not running (status: $(jq -r '.status' "$JOB_FILE"))"
	fi
	exit 0
	;;
result)
	JOB_ID="$PROMPT"
	if [[ -z "$JOB_ID" ]]; then
		echo "Usage: codex-delegate.sh result <job-id>" >&2
		exit 1
	fi
	JOB_FILE="$JOBS_DIR/${JOB_ID}.json"
	if [[ ! -f "$JOB_FILE" ]]; then
		echo "ERROR: Job '$JOB_ID' not found" >&2
		exit 1
	fi
	JOB_STATUS=$(jq -r '.status' "$JOB_FILE")
	JOB_OUTPUT=$(jq -r '.output_file' "$JOB_FILE")
	JOB_PID=$(jq -r '.pid' "$JOB_FILE")
	# Update status if process finished
	if [[ "$JOB_STATUS" == "running" ]] && ! kill -0 "$JOB_PID" 2>/dev/null; then
		JOB_STATUS="completed"
		jq --arg s "completed" --arg t "$(date -Iseconds)" '.status=$s | .completed_at=$t' "$JOB_FILE" >"${JOB_FILE}.tmp" && mv "${JOB_FILE}.tmp" "$JOB_FILE"
	fi
	echo "=== Job: $JOB_ID (${JOB_STATUS}) ==="
	if [[ -f "$JOB_OUTPUT" ]] && [[ -s "$JOB_OUTPUT" ]]; then
		cat "$JOB_OUTPUT"
	elif [[ "$JOB_STATUS" == "running" ]]; then
		echo "(still running — check back later)"
	else
		echo "(no output)"
	fi
	exit 0
	;;
esac
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
# --- Background fork ---
if [[ "$BACKGROUND" == true ]]; then
	mkdir -p "$JOBS_DIR"
	JOB_ID="$(date +%s)-${SUBCMD}"
	JOB_FILE="$JOBS_DIR/${JOB_ID}.json"
	# Use explicit output path if provided, otherwise temp file
	if [[ "$OUTPUT_FILE_EXPLICIT" == true ]] && [[ -n "$OUTPUT_FILE" ]]; then
		BG_OUTPUT="$OUTPUT_FILE"
	else
		BG_OUTPUT=$(mktemp "${TMPDIR:-/tmp}"/codex-bg-XXXXXX.txt)
	fi
	# Re-invoke self in foreground, but in background process
	SELF_ARGS=("$SUBCMD" "$PROMPT")
	[[ -n "$CWD" ]] && SELF_ARGS+=(--cwd "$CWD")
	[[ "$SEARCH" == true ]] && SELF_ARGS+=(--search)
	SELF_ARGS+=(--timeout "$TIMEOUT" --sandbox "$SANDBOX" --output "$BG_OUTPUT")
	nohup bash "${BASH_SOURCE[0]}" "${SELF_ARGS[@]}" >"$BG_OUTPUT.log" 2>&1 &
	BG_PID=$!
	disown "$BG_PID" 2>/dev/null || true
	# Write job metadata
	cat >"$JOB_FILE" <<-JOBJSON
		{
		  "id": "${JOB_ID}",
		  "subcommand": "${SUBCMD}",
		  "prompt": $(printf '%s' "$PROMPT" | jq -Rs .),
		  "pid": ${BG_PID},
		  "status": "running",
		  "started_at": "$(date -Iseconds)",
		  "completed_at": null,
		  "output_file": "${BG_OUTPUT}",
		  "exit_code": null
		}
	JOBJSON
	echo "Background job started: $JOB_ID"
	echo "  PID: $BG_PID"
	echo "  Check: codex-delegate.sh status"
	echo "  Result: codex-delegate.sh result $JOB_ID"
	exit 0
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
adversarial-review)
	EFFECTIVE_CWD="${CWD:-$(pwd)}"
	if ! git -C "$EFFECTIVE_CWD" rev-parse --is-inside-work-tree &>/dev/null; then
		echo "ERROR: adversarial-review requires a git repository" >&2
		exit 1
	fi
	# Gather diff
	if [[ -n "$PROMPT" ]]; then
		DIFF=$(git -C "$EFFECTIVE_CWD" diff "$PROMPT"...HEAD 2>/dev/null || git -C "$EFFECTIVE_CWD" diff "$PROMPT" 2>/dev/null)
	else
		# git diff HEAD includes both staged and unstaged changes
		DIFF=$(git -C "$EFFECTIVE_CWD" diff HEAD 2>/dev/null)
	fi
	if [[ -z "$DIFF" ]]; then
		echo '{"verdict":"approve","summary":"No changes to review.","findings":[]}' | tee "$OUTPUT_FILE"
		EXIT_CODE=0
	else
		# Build prompt from template + diff
		PROMPT_TEMPLATE="$SCRIPT_DIR/adversarial-review-prompt.txt"
		SCHEMA_FILE="$SCRIPT_DIR/adversarial-review-schema.json"
		if [[ ! -f "$PROMPT_TEMPLATE" ]] || [[ ! -f "$SCHEMA_FILE" ]]; then
			echo "ERROR: Missing adversarial review template or schema in $SCRIPT_DIR" >&2
			exit 1
		fi
		FULL_PROMPT="$(cat "$PROMPT_TEMPLATE")
${DIFF}"
		timeout "$TIMEOUT" codex exec "${BASE_ARGS[@]}" "${SEARCH_ARGS[@]}" --output-schema "$SCHEMA_FILE" -s read-only "$FULL_PROMPT" >/dev/null 2>&1 && EXIT_CODE=0 || EXIT_CODE=$?
	fi
	;;
*)
	echo "Unknown subcommand: $SUBCMD" >&2
	echo "Usage: codex-delegate.sh {exec|review|research|compare|adversarial-review|status|cancel|result} \"prompt\" [flags]" >&2
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

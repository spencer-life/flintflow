---
name: log-to-gh
description: Persist the current TaskList (or a plan summary) to a GitHub issue in the current repo. Uses the gh-issue-logger haiku subagent for the actual creation. Use when the user says "log to github", "log these tasks", "create an issue for this", "persist these tasks", "make a github issue", or invokes /log-to-gh. Also available as an add-on step in /handoff and /wrap-up when they choose to mirror context to GH.
---

# Log to GitHub

Capture the session's open tasks as a GitHub issue — useful for cross-device
pickup, async collaboration, or handing the work off to the Claude Code GitHub
Action (via `@claude` mention in the body).

## When to use

- User asks to persist tasks to GitHub
- End of a session where work will continue later on a different device or by
  another person
- You want the Claude Code GitHub Action to pick up where you left off —
  include the `@claude` mention so it's triggered

## When NOT to use

- No git remote, or remote isn't github → the gh-issue-logger will error out
- Ephemeral in-session tasks (typos, renames, tweaks) — issue spam
- User is mid-task, not wrapping anything up

## The flow

1. **Gather the task list** — call `TaskList` and collect open tasks (status
   `pending` or `in_progress`). Skip completed unless user asked for a summary.

2. **Collect context** — 1-2 sentences on what this work is. Pull from:
   - Recent user messages (what problem is being solved)
   - `PROJECT_STATE.md` if it exists in the repo root (Read it)
   - The current git branch name for hints

3. **Ask user ONE question** (only if ambiguous):
   - If user said "log this" but it's unclear what "this" is → ask what to
     include (tasks / plan / specific scope)
   - If user didn't specify `@claude` mention → ask if the GH Action should
     pick it up automatically (default: no)
   - If you can infer cleanly, skip the question

4. **Dispatch the gh-issue-logger subagent** with structured input:

   ```
   Agent(
     subagent_type="gh-issue-logger",
     description="Log session tasks to GH issue",
     prompt="<formatted input: tasks, context, title hint, mention flag>"
   )
   ```

   Example prompt body for the agent:
   ```
   TASKS:
   - [ ] Refactor auth middleware to use JWT
   - [ ] Add rate limiting to POST /api/submit
   - [ ] Update tests for new auth flow

   CONTEXT:
   Rewriting auth per compliance requirements (Fred flagged session token storage).

   TITLE HINT:
   Auth middleware rewrite — JWT + rate limiting

   MENTION_CLAUDE: false
   ```

5. **Return the URL** — the agent returns just the URL or an ERROR line.
   Surface it to the user and optionally update the task list with a reference
   (e.g., add `— see #123` to related tasks via `TaskUpdate`).

## After logging

- Consider suggesting `/handoff` or `/wrap-up` if this is session-end
- If MENTION_CLAUDE was true, tell user the GH Action will start processing
  the issue shortly — they can watch it in the repo's Actions tab

## Related

- `/handoff` — writes .claude/handoff.md for session resumption (local file)
- `/wrap-up` — end-of-session checklist (commits, memory, etc.)
- `gh-issue-logger` agent — the narrow executor this skill dispatches

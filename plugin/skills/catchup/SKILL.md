---
name: catchup
description: Resume work from a handoff file written by /handoff. Read .claude/handoff.md,
  orient to project state, verify current conditions, and continue where the previous
  session left off. Use when user says "catchup", "continue from handoff",
  "read the handoff", "load handoff", or invokes /catchup.
---

# Catchup

Read a handoff file, verify current state against it, and continue working.
The "receive" side of the handoff/catchup pair — `/handoff` writes, `/catchup` reads.

---

## File Resolution

- No argument → read `.claude/handoff.md`
- With argument → read `.claude/handoff-<arg>.md`
  - Slugify the arg: lowercase, spaces/special chars to hyphens
- If the target file doesn't exist:
  1. List available handoffs: `ls -la .claude/handoff*.md 2>/dev/null`
  2. If alternatives found, show them and let user pick
  3. If no handoff files exist at all, suggest `/vault-catch-up` instead or ask user for context

---

## Staleness Check

Before launching the subagent, check the handoff file's age:

```bash
stat -c %Y .claude/handoff.md 2>/dev/null
```

Calculate days since last modified. Include the age in the subagent prompt so it
appears in the briefing. Thresholds:

- **< 1 day**: no annotation
- **1-3 days**: "(handoff is N days old)"
- **> 3 days**: prominent warning — "(handoff is N days old — context may be stale. Consider verifying assumptions or creating a fresh handoff.)"

---

## Subagent Architecture

The read-and-digest phase runs inside an **Explore subagent** to keep raw file
contents out of the main conversation context.

Launch an Explore agent with a prompt built from this template (fill in the
`<placeholders>` before sending):

---

Read the handoff file at `<resolved-path>`. The file is `<N>` days old.

Extract: frontmatter (created, project, branch) and all body sections.
If the file is missing expected sections (Completed, Current State, Next Steps)
or appears truncated/corrupted, note what's missing and work with what's there.

**Also read PROJECT_STATE.md if it exists.** Extract:
- Current Status
- Data Accuracy Status table (which categories are verified, which are failing)
- Active Work Streams (what's in progress, blocked, or done)
- Last 3 entries from the Session Log

If PROJECT_STATE.md doesn't exist, note "No PROJECT_STATE.md found" and continue
with handoff data only.

**Also check VERIFICATION.md if it exists.** Note:
- How many total verification test cases exist
- How many are FILL_IN vs. have actual expected values
- Last known pass/fail status if recorded

Verify git state:
- `git branch --show-current 2>/dev/null`
- `git status --short 2>/dev/null`
- `git log --oneline -5 2>/dev/null`

Compare to the handoff. Flag drift (branch mismatch, new commits, unexpected
uncommitted changes). If not in a git repo, note that and skip.

Read each file from the "Relevant Files" section. Don't dump contents — just
confirm each file exists, note if anything looks different from the handoff's
description.

Return this briefing and nothing else:

```
**Project:** <name>
**Handoff written:** <timestamp> (<N days ago>)
**Branch:** <recorded> → **Current:** <actual>

**Drift:** <mismatches, or "None">

**Completed:** <bullet list from handoff>

**Current state:** <from handoff + drift observations>

**Data state:** <from handoff Data State section + PROJECT_STATE.md Data Accuracy table>
  - Verified categories: <list>
  - Failing categories: <list with issue summaries>
  - Verification coverage: <X tests defined, Y have real values, Z are FILL_IN>
  (If no database/data component, say "N/A — no database in this project")

**Open decisions:** <from handoff, or "None">

**Traps:** <from handoff, or "None">

**Files verified:** <each file, exists/missing/changed>

**Next steps:**
1. <from handoff>
2. ...
```

If the handoff is older than 3 days, add a warning line after the timestamp:
"This handoff is stale. Git state and file contents may have diverged significantly."

---

The main conversation receives only this clean briefing.

---

## Present Briefing

Show the subagent's briefing under a `## Catchup Briefing` header.

Priority callouts (show prominently if present):
1. **Staleness warning** — if handoff > 3 days old
2. **Drift detected** — branch/commit mismatches
3. **Data failures** — if PROJECT_STATE.md or handoff shows failing verification tests
4. **Missing verification** — if VERIFICATION.md has mostly FILL_IN values
5. **Missing/corrupted sections** — if the handoff file was incomplete

---

## Approval Gate

After presenting the briefing, ask the user to confirm before starting work:

> Ready to start on **[Next Step #1]**, or want to adjust the plan?

- User approves → begin working on Next Steps #1
- User adjusts → incorporate their changes, then proceed
- Do NOT auto-start work. The briefing is a proposal, not an action.

If data failures were flagged, suggest:
> ⚠️ There are failing data verification tests. Want to fix those first,
> or proceed with the planned next steps?

---

## After Beginning Work

Once work begins, mention briefly:

> The handoff file is still on disk. It'll be overwritten on the next `/handoff`,
> or you can delete it manually.

Do not auto-delete the handoff file.

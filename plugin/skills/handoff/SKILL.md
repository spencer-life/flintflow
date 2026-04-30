---
name: handoff
description: Write a structured context-transfer document for session resumption.
  This skill should be used when the user says "handoff", "hand off", "write handoff",
  "save context", "before I clear", "context transfer", or invokes /handoff.
  Lighter than wrap-up — writes handoff file plus a brief vault breadcrumb,
  no commits or self-improvement.
---

# Handoff

Write `.claude/handoff.md` so a fresh session can resume exactly where this one
left off. Fast and lightweight — no commits, no self-improvement, just state capture.

---

## File Naming

- No argument: write `.claude/handoff.md` (overwrites if exists)
- With argument: write `.claude/handoff-<slugified-name>.md`
  - Slugify: lowercase, replace spaces/special chars with hyphens, strip leading/trailing hyphens

---

## Pre-Write Check

Before writing, show what already exists:

```bash
ls -la .claude/handoff*.md 2>/dev/null
```

Display results so the user sees what coexists or will be overwritten. If files
exist, note them briefly ("Existing handoff from 2h ago will be overwritten")
and proceed — do not ask for confirmation.

---

## Gather State

Pull from three sources:

**1. Conversation context** — scan the full conversation for:

- Tasks completed (with file paths)
- Current state of work (what's working, broken, in-progress)
- Unresolved decisions or open questions
- Things that didn't work or edge cases discovered
- Key files touched or referenced

**2. Git state** — run these read-only commands:

```bash
git branch --show-current 2>/dev/null
git status --short 2>/dev/null
git diff --stat 2>/dev/null
git log --oneline -5 2>/dev/null
```

If not in a git repo, skip git commands and note "not a git repo" in the handoff.

**3. Data state** — if the project has a database component:

```bash
ls PROJECT_STATE.md VERIFICATION.md verification/ 2>/dev/null
```

If PROJECT_STATE.md exists, read the Data Accuracy Status table and include
a summary in the handoff. If `/data-verify` was run during this session,
include the latest pass/fail counts.

---

## Output Template

Write the handoff file using this structure:

```markdown
---
created: YYYY-MM-DDTHH:MM
project: <project-name or directory name>
branch: <current branch or "n/a">
---

# Handoff: <project-name>

## Completed
- <task finished> — `path/to/file.ext`
- <task finished> — `path/to/file.ext:line`

## Current State
<What's working, what's broken, what's in-progress.
Include uncommitted changes if any exist.>

## Data State
<If this project has a database, summarize:
- Which data categories are verified/correct
- Which are known-wrong and why
- Last verification results (X/Y passing)
- Any data changes made this session
If no database, omit this section entirely.>

## Open Decisions
- <Decision needing resolution> — context: <why it matters, options considered>

## Traps & Notes
- <Thing that didn't work and why>
- <Edge case or gotcha to remember>
- <Approach that was tried and abandoned>

## Relevant Files
- `path/to/file.ext` — <why it matters>
- `path/to/file.ext` — <why it matters>
- `PROJECT_STATE.md` — full project dashboard (read this first on catchup)

## Next Steps
1. <Highest priority action — be specific>
2. <Next action>
3. <Next action>
```

---

## Writing Guidelines

- **Be specific** — include file paths, line numbers, function names, error messages
- **Capture the why** — not just what was done, but why decisions were made
- **Order next steps by priority** — first item should be the immediate next action
- **Include exact commands** if a specific command is needed to reproduce state
- **Omit empty sections** — if there are no open decisions, drop that section entirely
- **Always include Data State for database projects** — even if just "no changes this session"
- **Always point to PROJECT_STATE.md** in Relevant Files if it exists

---

## Minimal Handoff

For trivial sessions with little meaningful state (quick Q&A, minor lookup):

```markdown
---
created: YYYY-MM-DDTHH:MM
project: <project-name>
branch: <branch or "n/a">
---

# Handoff: <project-name>

No significant state to transfer.
```

---

## Vault Breadcrumb

After writing the handoff file, log a brief entry so the user can find it later.

**Daily note append:**

```bash
obsidian vault="Claude Memory" daily:append content="- HH:MM — Handoff: <project> — <one-line summary of where we left off>. Handoff file: .claude/handoff.md"
```

This is intentionally minimal — one line, not a full session log. Just enough
to jog memory when scanning daily notes after a break.

**Project status update (optional):**
If a `Projects/<project>/status.md` exists in the vault, update it with 2-3
lines reflecting current state. Skip if no project folder exists — do not
create one.

---

## Post-Write

Confirm to the user:

1. The filename written (e.g., "Wrote `.claude/handoff.md`")
2. Mention the daily note entry was added
3. Show the resume command:

> To resume: `Read .claude/handoff.md and continue where I left off`

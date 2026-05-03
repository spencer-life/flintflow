---
name: lifecycle
description: Show the FlintFlow lifecycle diagram and decision table — what
  every skill does, when to use each one, what's automatic vs. manual. Detects
  current project state (PROJECT_STATE.md present? handoff file? uncommitted
  changes?) and recommends the next skill to invoke. Use when the user asks
  "how do I use flintflow", "what skill should I use", "what's the workflow",
  "where am I in the lifecycle", "flintflow help", "lifecycle", or invokes
  /flintflow:lifecycle.
---

# FlintFlow Lifecycle

Show the user the full FlintFlow lifecycle diagram, the "when to use what"
decision table, and a "you are here" recommendation based on current project
state.

This skill is the single source of in-session truth for "how does FlintFlow
fit together." Print everything in one response — don't make the user ask
follow-ups.

---

## Step 1: Detect current project state

Run these checks (silent — capture output, don't echo). If the cwd isn't the
project root, `cd` to the git root first (`cd "$(git rev-parse --show-toplevel
2>/dev/null || pwd)"`) so the file checks below resolve correctly.

```bash
HAS_STATE=$( [ -f PROJECT_STATE.md ] && echo yes || echo no )
HAS_MAP=$( [ -f PROJECT_MAP.md ] && echo yes || echo no )
HAS_VERIFICATION=$( [ -f VERIFICATION.md ] && echo yes || echo no )
HAS_HANDOFF=$( [ -f .claude/handoff.md ] && echo yes || echo no )
HANDOFF_AGE_DAYS=$( [ -f .claude/handoff.md ] && echo $(( ($(date +%s) - $(stat -c %Y .claude/handoff.md 2>/dev/null || echo 0)) / 86400 )) || echo "" )
IN_GIT=$( git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo yes || echo no )
UNCOMMITTED=$( [ "$IN_GIT" = "yes" ] && git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0 )
```

---

## Step 2: Print the lifecycle diagram

```
NEW IDEA                          NEW SESSION (resuming work)
    ↓                                  ↓
/design                            /catchup ← reads .claude/handoff.md, orients
  - interview about the idea
  - design architecture + plan
  - auto-suggests ↓                   ↓
                                                 ↓
/project-init  (first time on a project)     mid-session work
  - auto-detects services                         ↓
  - strategic interview                       /add-logging ← logging-nudge fires when
  - writes PROJECT_STATE.md +                    you edit a deployed-service file
    PROJECT_MAP.md (+ optional                   lacking error handlers
    VERIFICATION.md, smoke_test.sh)              ↓
  - auto-suggests ↓                           /data-verify ← data-verify-nudge fires
                                                 after DB changes
/subagent-driven-development                     ↓
  - INTERNAL pipeline:                       /codex ← MANUAL only. Second opinion,
    pre-flight → implement (TDD)                 web research, when stuck 2+ attempts.
    → spec review → code quality                 ↓
    → data-verify → smoke test               /status ← auto-fires mid-session +
    → codex auto-review                          before /wrap-up
                                                 ↓
                                              /handoff ← MANUAL or PreCompact-nudged.
                                                 Write context-transfer for next session.
                                                 ↓
                                              /wrap-up ← wrapup-nudge fires when you
                                                 have uncommitted code at end of session
```

---

## Step 3: Print the decision table

```
| Situation                                            | Skill                          | Trigger     |
|------------------------------------------------------|--------------------------------|-------------|
| "I want to build X" / new feature idea               | /design                        | Auto        |
| Brand-new project, never set up                      | /project-init                  | Auto/Manual |
| Project's services changed (Supabase, Railway, etc.) | /project-map                   | Hook nudge  |
| Have a plan, want to execute                         | /subagent-driven-development   | Auto/Manual |
| Just edited a Discord bot / API / deployed service   | /add-logging                   | Hook nudge  |
| Just touched DB schema or seeded data                | /data-verify                   | Hook nudge  |
| About to clear context, want continuity              | /handoff                       | Manual/Hook |
| Resuming a project after a break                     | /catchup                       | Manual      |
| Mid-session "are we good?"                           | /status                        | Auto-fires  |
| End of session with code changes                     | /wrap-up                       | Hook nudge  |
| Want a second opinion / stuck                        | /codex                         | Manual only |
| Long task list worth persisting                      | /log-to-gh                     | Manual      |
| Lost? Show this diagram again                        | /flintflow:lifecycle           | Manual      |
```

---

## Step 4: "You are here" recommendation

Based on the state captured in Step 1, print ONE clear recommendation. Use this
decision tree (top to bottom — first match wins):

| If                                              | Recommend                                         |
|-------------------------------------------------|---------------------------------------------------|
| `HAS_HANDOFF=yes` AND age ≤ 7 days              | **`/catchup`** — handoff from {N} day(s) ago      |
| `HAS_STATE=no`                                  | **`/project-init`** — no flintflow state yet      |
| `HAS_STATE=yes` AND `HAS_MAP=no`                | **`/project-map`** — generate the visual         |
| `HAS_VERIFICATION=yes` AND no recent /data-verify run | **`/data-verify`** — verify ground truth     |
| `UNCOMMITTED > 0` AND no clear next task        | **`/wrap-up`** — close out current changes        |
| Everything in order                             | **`/design`** for new feature, or just keep working |

Format the recommendation as a single bolded line:

> **You are here:** [phase summary]. **Next:** [recommended skill] — [one-line why].

Example:
> **You are here:** flintflow-managed project, handoff from 1d ago, working tree clean. **Next:** `/catchup` — read the handoff and resume.

---

## Step 5: Mention manual-only skills

End with a one-liner reminder:

> **Manual-only skills** (won't auto-fire — invoke when you want them):
> `/codex` (second opinion), `/log-to-gh` (persist tasks to GH issue), `/project-map` (refresh service graph).

---

## Edge cases

- **Not in a git repo:** skip the uncommitted-changes check (treat as 0).
- **Not in a flintflow project (no PROJECT_STATE.md):** still print the diagram + decision table, but the "You are here" line should say: "**You are here:** outside any flintflow-managed project. **Next:** `cd` into one, or run `/project-init` here to scaffold."
- **Handoff older than 7 days:** still recommend `/catchup` but flag staleness: "handoff is {N} days old — read carefully, may be out of date."

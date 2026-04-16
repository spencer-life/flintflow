---
name: wrap-up
description: End-of-session checklist with confidence dashboard, data verification,
  commits, project state updates, and self-improvement. Use when user says "wrap up",
  "close session", "end session", "wrap things up", "close out this task", "I'm done",
  "that's it", "that's it for today", "ok I'm good", "nothing else", or invokes /wrap-up.
  NEVER pushes to remote. NEVER deploys.
---

# Session Wrap-Up

Run seven phases in order. Each phase is conversational and inline.
All phases auto-apply without asking; present a consolidated report at the end.

**HARD RULES:**
- **NEVER run `git push`.** Spencer pushes manually. Pushing triggers auto-deploy on Railway.
- **NEVER run any deploy command.** No deploy scripts, no Railway CLI, nothing.
- **Commits only.** Stage and commit. That's it.

---

## Phase 0: Confidence Check

Run `/status` to get the current project health dashboard.

1. Execute the full confidence dashboard (tests, lint, data verification, smoke test, git)
2. Record the confidence score
3. If score < 70:
   > **WARNING: Project confidence is {score}/100.**
   > Address the issues below before wrapping up:
   > {list failing signals from dashboard}
4. Include the full dashboard output in the final report

Proceed with remaining phases regardless — wrap-up should always complete,
but the warning ensures Spencer sees the state clearly before the session ends.

---

## Phases 1 + 2: Data Verification, Then Codex Review (SEQUENTIAL)

Data verification MUST complete first — it writes to verification/history.log
and updates PROJECT_STATE.md. Codex review needs a stable working tree to
inspect. Run data-verify, then Codex review on the resulting state.

### Phase 1: Verify Data

**If this project has a database component** (check for PROJECT_STATE.md,
VERIFICATION.md, or database config files):

1. Run `/data-verify` — full verification suite
2. Record results: X/Y tests passing, list any failures
3. If tests are failing that were passing earlier in the session, flag prominently:
   > Data regression detected: {test} was passing, now failing.
   > This session may have introduced a data error.

**If no database component:** Skip this phase.

### Phase 2: Codex Review

**Pre-check:** Run `git status` in the project directory. If there are no uncommitted
changes (nothing staged, unstaged, or untracked source files), skip this phase silently.

**If uncommitted changes exist:**

1. Invoke Codex adversarial review (read-only, structured JSON output):
   ```bash
   bash ~/.claude/hooks/codex-delegate.sh adversarial-review "" --search --timeout 180 --cwd "$(pwd)"
   ```

2. For higher-risk work, run a dedicated Codex verifier flow after the review:
   - UI/browser/API/OCR/manual artifact work:
     ```bash
     just codex_verify_artifacts "Summarize the end-to-end artifacts that prove this task works."
     ```
   - General implementation confidence:
     ```bash
     just codex_verify "Review the task outcome, current diff, and test evidence before wrap-up."
     ```

3. **Triage each finding using structured JSON output:**
   Parse the JSON response and apply these rules by severity + confidence:
   - `critical` or `high` with confidence >= 0.7 → Fix now, before committing.
   - `medium` with confidence >= 0.8 → Fix if quick (under 2 minutes).
   - `low` or confidence < 0.5 → Dismiss with one-line reasoning.
   - If the JSON doesn't parse (raw text fallback), triage manually as before.

4. **Log the triage for the final report:**
   ```
   Codex Review: verdict={approve|needs-attention}, X findings — Y fixed, Z dismissed
   - Fixed: {brief description of each fix}
   - Dismissed: {severity}/{confidence} — {brief reason}
   ```

5. If Codex timed out or errored: Note it and proceed. The other phases
   (confidence check, data verification) already validated the work.

**This phase is read-only from Codex's perspective.** Codex analyzes; Claude decides and acts.

---

## Phase 3: Commit (NEVER PUSH)

4. Run `git status` in each repo directory touched during the session
5. If uncommitted changes exist, stage relevant files and commit with a descriptive message
6. **DO NOT PUSH. DO NOT OFFER TO PUSH. DO NOT SUGGEST PUSHING.**
7. If there are changes in multiple repos, commit each separately

**Task cleanup:**
8. Check the task list for in-progress or stale items
9. Mark completed tasks as done, flag orphaned ones

---

## Phase 4: Update Project State

**If PROJECT_STATE.md exists:**

10. Update the following sections:
    - **Current Status** — reflect what's working/broken now
    - **Data Accuracy Status** — update from Phase 1 results (if applicable)
    - **Active Work Streams** — mark completed items, update in-progress ones
    - **Session Log** — add entry: `- {date} #{N}: {what was done}. {what's next}.`

11. If any architecture decisions were made this session, add them to
    Architecture Decisions with date and reasoning.

12. Commit the PROJECT_STATE.md update (separate commit).
    **DO NOT PUSH.**

**If PROJECT_STATE.md doesn't exist:** Mention:
> No PROJECT_STATE.md found. Consider running `/project-init` to set up
> structured project tracking.

---

## Phase 5: Remember It

Review what was learned during the session. Decide where each piece of
knowledge belongs:

**Memory placement guide:**
- **claude-mem MCP** (`save_memory`) — Cross-session insights: debugging
  patterns, API quirks, project behaviors needed in future sessions.
- **CLAUDE.md** — Permanent rules, conventions, workflow changes
- **`.claude/rules/`** — Topic-specific instructions scoped to file types
  (use `paths:` frontmatter)
- **`docs/MEMORY-BANK.md`** — Completed milestones, project context. Under 500 lines.
- **`docs/DECISION_LOG.md`** — Major decisions with reasoning.
- **`CLAUDE.local.md`** — Private per-project notes, sandbox credentials, WIP context
- **`VERIFICATION.md`** — Newly confirmed ground-truth values (ONLY values the
  user verified against source documents, never AI-generated)

**Auto-apply all actionable findings. Commit changes. DO NOT PUSH.**

---

## Phase 6: Review & Improve

Analyze the conversation for self-improvement findings. If the session was
short or routine, say "Nothing to improve" and finish.

**Finding categories:**
- **Skill gap** — Things Claude struggled with or needed multiple attempts
- **Friction** — Repeated manual steps that should be automatic
- **Knowledge** — Facts Claude should have known
- **Automation** — Patterns that could become skills, hooks, or scripts
- **Data accuracy** — User-confirmed ground-truth values

**Action types:**
- **CLAUDE.md** — Edit rules
- **Rules** — Create/update `.claude/rules/`
- **claude-mem** — Save cross-session insight
- **Skill / Hook** — Document spec for future implementation
- **VERIFICATION.md** — Add user-confirmed values only

Present summary:

```
Findings (applied):
1. ✅ Skill gap: Cost estimates wrong → [CLAUDE.md] Added reference table
2. ✅ Knowledge: API retries on 429 → [Rules] Added error-handling rule
3. ✅ Data: User confirmed ANICO age 55 = $32.50 → [VERIFICATION.md] Test #6

No action needed:
4. Already documented in CLAUDE.md
```

Commit any changes. **DO NOT PUSH.**

---

## Final Report

```
## Session Wrap-Up Complete

### Confidence Dashboard
{Full /status output — score, signal table, unresolved items, recommendation}

### Data Verification
{X/Y passing, or "N/A — no database"}

### Codex Review
{X findings — Y fixed, Z dismissed / Skipped — no uncommitted changes / Timed out — proceeded without}
{If artifact-verifier ran: include what evidence Codex marked proven vs unproven}

### Smoke Test
{All pass / X failures / N/A — no smoke_test.sh}

### Commits (NOT PUSHED)
- {hash}: {message}
- {hash}: {message}
Push when you're ready.

### Project State
{Updated / Not found — run /project-init}

### Memory Updates
{List what was saved and where}

### Improvements
{List or "Nothing to improve"}
```

---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the
  current session. Dispatches fresh subagents per task with multi-stage review.
  Self-contained with all subagent prompts embedded. Includes pre-flight checks,
  data verification, and automatic Codex cross-model review at phase boundaries.
---

# Subagent-Driven Development

Execute a plan by dispatching fresh subagents per task, with multi-stage review
after each. All prompts embedded — no external files needed.

**Core principle:** Fresh subagent per task + staged review + cross-model verification
= high quality, fast iteration.

**NEVER pushes to remote. Commits only.**

---

## When to Use

- You have an implementation plan (from /plan or a written plan doc)
- Tasks are mostly independent (not tightly coupled)
- Staying in this session (not handing off to parallel sessions)

---

## The Full Pipeline

```
For each task:

1. PRE-FLIGHT (if task touches DB or has dependencies)
   → pre-flight agent checks scope, context, data safety
   → Address issues before proceeding

2. IMPLEMENT
   → implementer subagent with full task text + context
   → Answers questions if needed, implements with TDD, commits

3. SPEC REVIEW
   → spec reviewer confirms implementation matches spec exactly
   → Fix issues → re-review → must pass

4. CODE QUALITY REVIEW
   → code quality reviewer checks bugs, security, maintainability
   → Fix issues → re-review → must pass

5. DATA VERIFICATION (if task modified database)
   → data-verifier agent runs VERIFICATION.md ground-truth checks
   → Fix failures → re-verify → must pass

6. CODEX CROSS-MODEL REVIEW (automatic)
   → Auto-invoke /codex compare with task + diff + verification results
   → Report Codex's findings alongside Claude's assessment
   → Synthesize — flag disagreements for user attention

7. Mark task complete
```

After all tasks: dispatch integration-reviewer agent for full review.

---

## Setup (Before First Task)

1. **Read the plan** — extract all tasks with full text
2. **Read PROJECT_STATE.md** if it exists
3. **Read VERIFICATION.md** if it exists
4. **Create TodoWrite** with all tasks
5. **Tag which tasks touch the database** — these get pre-flight + data verification

---

## Subagent Prompts

### Pre-Flight (Agent: `pre-flight`)

Dispatch BEFORE implementation for DB tasks or tasks with dependencies.

```
You are a pre-flight checker.

TASK: {full task text}
PROJECT STATE: {summary from PROJECT_STATE.md}

Check:
1. SCOPE: Conflicts with active work streams?
2. CONTEXT: Referenced files exist? DB accessible? Env vars set?
3. DATA SAFETY: How many rows affected? Backup exists?
4. DEPENDENCIES: Prior tasks complete? Uncommitted work?

Report: PROCEED or ADDRESS {issues} FIRST
```

---

### Implementer

Dispatch for each task. Provide full task text — never make it read plan files.

```
You are implementing a specific task. Follow test-driven development.

TASK: {full task text}

CONTEXT:
- Project: {name and description}
- Stack: {tech stack}
- Branch: {current branch}
- Related files: {key files}
{If DB task:}
- Database: {type and connection}
- Tables: {involved tables}
- Verification tests exist: {yes/no}

INSTRUCTIONS:
1. Questions? ASK BEFORE implementing. Don't guess.
2. TDD: write test → fail → implement → pass
3. Minimal code — nothing beyond the task spec
4. Self-review before reporting done:
   - Everything asked for? Anything extra? (Remove extras)
   - All tests pass?
   - For DB changes: show before/after SELECT output
5. Commit with descriptive message. DO NOT PUSH.

REPORT:
- What you implemented
- Tests: {count} passing
- Self-review findings
- For DB changes: row counts and sample data
```

---

### Spec Reviewer

Dispatch AFTER implementer. Checks exact match to spec.

```
You are a spec compliance reviewer.

TASK SPEC: {full task text — same as implementer received}

Review the git diff:
git diff {start_sha}..HEAD

Check:
1. COMPLETENESS: Every spec requirement implemented?
   Go line by line. For each requirement, find the implementing code.
2. EXTRAS: Anything NOT in the spec? Flag for removal.
3. CORRECTNESS: Does the code actually do what the spec says?

VERDICT: APPROVED or REJECTED with specific fixes needed.
```

---

### Code Quality Reviewer

Dispatch AFTER spec review passes.

```
You are a code quality reviewer. Spec compliance is already verified.

Review the git diff:
git diff {start_sha}..HEAD

Check:
1. BUGS: Logic errors, off-by-one, null handling, race conditions
2. SECURITY: SQL injection, XSS, secrets in code
3. MAINTAINABILITY: Naming, duplication, complexity, magic numbers
4. TESTING: Tests meaningful? Testing behavior, not implementation?
5. ERROR HANDLING: Errors caught and handled?

DO NOT check spec compliance (already done).

VERDICT: APPROVED or REJECTED (only for Critical/Important issues).
```

---

### Data Verifier (Agent: `data-verifier`)

Dispatch AFTER code quality passes, ONLY for DB-modifying tasks.

```
You are a data verification reviewer. Check database values against
VERIFICATION.md ground-truth expected values.

1. Read VERIFICATION.md for relevant category
2. Connect to database
3. Run verification queries
4. Compare actual vs expected

VERDICT:
- ALL PASS → APPROVED
- ANY FAIL → REJECTED with expected vs actual
- NO TESTS → INCONCLUSIVE — flag gap in VERIFICATION.md
```

---

### Codex Auto-Review

After all other reviews pass, auto-invoke Codex for cross-model verification.
This runs automatically — no user action needed.

```bash
bash ~/.claude/hooks/codex-delegate.sh compare \
  "Review changes for task: {task_description}. Diff: {abbreviated diff}. \
   {If DB task: Verification results: X/Y passing.} \
   Focus on: bugs, edge cases, production risks. Give independent assessment." \
  --timeout 120 --cwd "$(pwd)"
```

**After Codex responds:**
1. Present Codex's findings
2. Present Claude's assessment
3. **Synthesis:**
   - Agreement → "Both Claude and Codex confirm: {consensus}"
   - Disagreement → "Codex flagged {X} but Claude disagrees because {Y}. User should decide."
4. If Codex found a real issue Claude missed → fix it before proceeding

**If Codex times out or errors:** Note it and proceed. Codex review is valuable
but not a blocker — the other review stages already passed.

---

## Workflow Rules

### Execution order
- Tasks execute sequentially (one at a time)
- NEVER dispatch parallel implementers (conflicts)
- NEVER skip review stages

### Review stage order (strict)
1. Spec compliance FIRST
2. Code quality SECOND
3. Data verification THIRD (DB tasks only)
4. Codex cross-model FOURTH (automatic)

### When a reviewer rejects
1. Same implementer subagent fixes issues
2. Same reviewer re-reviews
3. Repeat until approved
4. NEVER skip the re-review

### Git rules
- Implementer commits with descriptive messages
- **NEVER push. NEVER deploy.**
- Commits only — Spencer pushes manually

### When a subagent asks questions
- Answer clearly and completely
- Don't rush into implementation

### When a subagent fails
- Dispatch fix subagent with specific instructions
- Don't fix manually (context pollution)

---

## Parallel Handoff Mode

When the plan is too large for one session, use `/handoff --split` to create
multiple handoff files for parallel sessions instead:

1. Claude analyzes the plan and suggests how to split it
2. Each handoff file defines scope boundaries, owned files/tables, commit prefixes
3. Each parallel session reads its handoff and stays in its lane
4. After all parallel sessions complete, use the `integration-reviewer` agent
   to review and merge branches

---

## Example Flow

```
[Read plan: 3 tasks]
[Read PROJECT_STATE.md, VERIFICATION.md]
[Create TodoWrite: Task 1, Task 2, Task 3]
[Task 1 touches DB, Tasks 2-3 are code-only]

--- Task 1: Fix ANICO FE rates ---

[Pre-flight agent] → PROCEED (backup exists, no scope conflicts)

[Implementer] → "What are correct rates for ages 50-65?"
→ You: "See VERIFICATION.md tests #1 and #2"
→ Implementer: Fixed 16 rows, committed. Before: $37.80, After: $32.50

[Spec reviewer] → ✅ APPROVED
[Code quality] → ✅ APPROVED
[Data verifier] → FE tests 5/5 passing ✅ APPROVED

[Codex auto-review]
→ Codex: "Looks correct. One note: the WHERE clause should also filter by
   product_type to prevent accidentally updating IUL rows."
→ Claude: "Good catch — but the migration already has product_type='FE' in
   the WHERE clause (line 14). Codex may have missed that."
→ Synthesis: Both agree implementation is correct. Codex concern addressed.

[Mark Task 1 complete]

--- Task 2: Refactor query builder ---

[No pre-flight needed — code only]
[Implementer] → Refactored, 12 tests passing, committed
[Spec reviewer] → ✅ APPROVED
[Code quality] → ✅ APPROVED
[No data verification — code only]
[Codex auto-review] → "Clean refactor. No issues." ✅

[Mark Task 2 complete]

--- Task 3: ... ---

[After all tasks]
[Integration reviewer agent] → Full review, all clear
Done!
```

---

## Red Flags — STOP

- Skipping any review stage
- Pushing to remote (NEVER)
- Running deploy commands (NEVER)
- Dispatching parallel implementers
- Proceeding with failing data verification
- Trusting "looks correct" without evidence
- Starting later review stages before earlier ones pass
- Moving to next task with open review issues

---
name: subagent-driven-development
description: This skill should be used when executing implementation plans with
  independent tasks in the current session. It dispatches fresh subagents per task
  with multi-stage review. Self-contained with all subagent prompts embedded.
  Includes pre-flight checks, data verification, and automatic Codex cross-model
  review at phase boundaries.
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

2. APPROACH CHECK (all tasks)
   → Implementer outputs BEFORE writing any code:
     a. Understanding of the task (2-3 sentences)
     b. Planned approach (what files to change, in what order)
     c. Assumptions being made (what's assumed true but not verified)
     d. Tradeoffs (or "none" for simple tasks)
   → Orchestrator reviews the approach
   → If wrong direction or bad assumptions: correct BEFORE coding
   → If sound: proceed to IMPLEMENT
   → Trivial tasks (< 10 lines): 1-2 sentences suffice

3. IMPLEMENT
   → implementer subagent with full task text + context
   → TDD enforced: write test → watch it fail → implement → pass
   → Mocks ONLY for truly external services (APIs you can't call locally)
   → Commits when done

4. UNIT TEST GATE
   → Run the FULL test suite (not just the new tests)
   → ALL tests must pass before proceeding
   → If any fail: return to implementer with failures, fix, re-run
   → Repeat until green. This gate is non-negotiable.

5. SPEC + CODE QUALITY REVIEW (parallel)
   → Dispatch BOTH reviewers as parallel agents (model: sonnet)
   → Spec reviewer checks implementation matches spec
   → Code quality reviewer checks bugs, security, simplicity, surgical scope
   → Collect both verdicts
   → If either rejects: send COMBINED feedback to implementer
   → Implementer fixes all issues in one pass (not two separate rounds)
   → Re-run both reviewers in parallel again
   → Must both pass before proceeding

6. DATA VERIFICATION (if task modified database)
   → data-verifier agent runs VERIFICATION.md ground-truth checks
   → Fix failures → re-verify → must pass

7. SMOKE TEST GATE
   → If smoke_test.sh exists in project root: run it
   → ALL real-connection checks must pass
   → If fail: return to implementer to fix real integration issues
   → If no smoke_test.sh: warn "No smoke test defined" but don't block

8. CODEX BACKGROUND AUDIT + LOOKAHEAD PRE-FLIGHT (async, non-blocking)
   → Fire headless Codex in background (read-only, --sandbox read-only)
   → If there's a NEXT task in the queue that needs pre-flight:
     dispatch pre-flight for it in background too (model: haiku, run_in_background)
   → Do NOT wait for either — mark task complete and move on
   → Codex report reviewed at next natural pause
   → Pre-flight result ready by time next task starts

9. Mark task complete → move to next task immediately
```

After all tasks:

1. **Check for pending Codex reports** — review any background audit results
   that came back while you were working. Triage findings (fix real issues,
   dismiss false positives with reasoning).
2. Dispatch integration-reviewer agent for full review
3. Run `/status` for confidence dashboard — if score < 70, flag for user

---

## Subagent Model Routing

Use the cheapest model that can handle each role. The orchestrator (Opus) reviews
all verdicts anyway — subagents just need to do their specific job well.

| Role | Model | Why |
|------|-------|-----|
| Implementer | `opus` | Writes code, TDD, complex reasoning — the hard one |
| Code quality reviewer | `sonnet` | Structured review with clear checklist; orchestrator checks verdict |
| Spec reviewer | `sonnet` | Diff-vs-spec comparison — structured and fast |
| Data verifier | `sonnet` | May construct queries, compare values — moderate complexity |
| Pre-flight | `haiku` | Run commands, check 4 categories, report — simple and structured |
| Integration reviewer | `sonnet` | Diff analysis and merge safety |
| Explore agents | `sonnet` | Research, file reading, summarization |

Set the `model` parameter when dispatching each Agent. Example:

```
Agent(model: "haiku", subagent_type: "pre-flight", prompt: "...")
Agent(model: "sonnet", subagent_type: "code-reviewer", prompt: "...")
Agent(model: "opus", prompt: "You are implementing a specific task...")
```

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
1. BEFORE WRITING ANY CODE, output your approach:
   - What you understand the task to be (2-3 sentences)
   - How you plan to implement it (which files, what changes, in what order)
   - Assumptions you're making (what you think is true but haven't verified)
   - Tradeoffs you see (or "none" for straightforward tasks)
   Wait for confirmation before proceeding. For trivial tasks (< 10 lines),
   keep the approach to 1-2 sentences.
2. Questions? ASK BEFORE implementing. Don't guess.
3. TDD is REQUIRED — follow this exact cycle:
   a. Write the test FIRST
   b. Run it — watch it FAIL (if it passes, your test is wrong)
   c. Write the minimal code to make it PASS
   d. Refactor if needed, re-run to confirm still green
4. Mocks ONLY for truly external services (APIs, third-party DBs you can't
   call locally). If you can test it without a mock, you MUST test without a mock.
5. Minimal code — nothing beyond the task spec. No "while I'm here" refactors.
6. Self-review before reporting done:
   - Everything asked for? Anything extra? (Remove extras)
   - Run the FULL test suite (not just new tests) — all pass?
   - For DB changes: show before/after SELECT output
   - Did I touch files unrelated to this task? (Revert if so)
7. Commit with descriptive message. DO NOT PUSH.

REPORT:
- What you implemented
- Tests: {total count} passing, {new count} added
- Self-review findings
- For DB changes: row counts and sample data
```

---

### Spec Reviewer

Dispatch in PARALLEL with Code Quality Reviewer (both model: sonnet).

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

Dispatch in PARALLEL with Spec Reviewer (both model: sonnet).

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
6. TESTING QUALITY:
   - Flag mock-only tests that could test real code instead
   - Flag tests that only verify mock call counts (not real outcomes)
   - Flag tests that pass trivially (assert True, empty test bodies)
   - If ALL tests for new code are mocked: REJECT with
     "Tests verify mocks, not behavior. Add real assertions."
7. SIMPLICITY: Is this the minimum code that solves the problem?
   - Flag code that solves problems the task didn't ask about
   - Flag abstractions that serve only one call site
   - Flag "just in case" error handling for scenarios not in the spec
   - If you can delete code without breaking the spec: REJECT
8. SURGICAL SCOPE: Does the diff touch only what the task requires?
   - Flag changes to files not mentioned in or required by the task
   - Flag formatting/style changes to code the task didn't modify
   - Flag "while I'm here" refactors of adjacent code
   - If unrelated files were changed: REJECT with "Revert changes to {files}"

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

### Background Codex Audit (async, non-blocking)

After all synchronous reviews pass, fire a headless Codex in the background.
**Do NOT wait for results.** Move to the next task immediately.

Codex is GPT-5.4 — a completely different model with different reasoning patterns
and different blind spots than Claude. That's the point: it catches things that
multiple rounds of Claude review will consistently miss.

**Dispatch (read-only, background, structured JSON):**

```bash
bash ~/.claude/hooks/codex-delegate.sh adversarial-review "" \
  --search --timeout 180 --cwd "$(pwd)" \
  --output ".claude/codex-audit-task-{task_number}.json" \
  --background
```

**Key rules:**

- Adversarial review is read-only by design — Codex analyzes but touches nothing
- `--output` — writes structured JSON report for Opus to parse later
- `--background` — returns job ID immediately, does NOT block
- Move to the next task. Do NOT wait.
- If Codex errors or times out, the report file just won't exist. That's fine.

**When Opus reviews the report (at next natural pause):**

1. Read the Codex audit JSON file
2. Parse findings and triage by severity + confidence:
   - `critical`/`high` with confidence >= 0.7 → fix it, note "caught by Codex audit"
   - `medium` with confidence >= 0.8 → fix if quick
   - `low` or confidence < 0.5 → dismiss with one-line reasoning
   - If JSON doesn't parse, triage the raw text manually
3. Delete the audit file after processing
4. If verdict is `approve` or the file doesn't exist → move on silently

**When to check for pending reports:**

- Between tasks (if there's a natural pause)
- After all tasks complete (mandatory — review all outstanding reports)
- The orchestrator should NOT interrupt a running task to check Codex reports

---

## Workflow Rules

### Execution order

- Tasks execute sequentially (one at a time)
- NEVER dispatch parallel implementers (conflicts)
- NEVER skip review stages

### Stage order (strict)

0. Approach check (before any code is written — not a review, a pre-coding gate)
1. Unit test gate (full suite must pass)
2. Spec + code quality (parallel — both dispatched simultaneously)
3. Data verification (DB tasks only)
4. Smoke test gate (if smoke_test.sh exists)
5. Codex background audit (async — fires and moves on, reviewed later)

### When a reviewer rejects

1. Same implementer subagent fixes issues
2. Same reviewer re-reviews
3. Maximum 3 review cycles per stage (implement → review → fix → review → fix → review)
4. After 3 rejections at the same stage:
   a. Present the reviewer's concerns + all fix attempts to the user
   b. Ask: "Fix manually, skip this review stage, or abort the task?"
   c. Do NOT auto-retry a 4th time
5. NEVER skip the re-review

### Git rules

- Implementer commits with descriptive messages
- **NEVER push. NEVER deploy.**
- Commits only — the user pushes manually

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

[Approach check] → "I'll update the FE rate migration to correct ages 50-65.
  Files: migrations/fix_anico_fe_rates.sql. Approach: UPDATE with WHERE on
  product_type='FE' AND age BETWEEN 50 AND 65. Assumption: VERIFICATION.md
  has the correct values. Tradeoffs: none."
→ Orchestrator: Approach is sound. Proceed.

[Implementer] → "What are correct rates for ages 50-65?"
→ You: "See VERIFICATION.md tests #1 and #2"
→ Implementer: Fixed 16 rows, committed. Before: $37.80, After: $32.50

[Unit test gate] → 47/47 passing ✅
[Spec reviewer] → ✅ APPROVED
[Code quality] → ✅ APPROVED
[Data verifier] → FE tests 5/5 passing ✅ APPROVED
[Smoke test gate] → 4/4 checks pass ✅

[Codex background audit] → fired async, moving on immediately

[Mark Task 1 complete]

--- Task 2: Refactor query builder ---

[No pre-flight needed — code only]

[Approach check] → "Extracting repeated query logic into a builder.
  Files: src/query.ts, test/query.test.ts. No tradeoffs."
→ Orchestrator: Proceed.

[Implementer] → Refactored, 12 tests passing, committed
[Unit test gate] → 49/49 passing ✅
[Spec reviewer] → ✅ APPROVED
[Code quality] → ✅ APPROVED
[No data verification — code only]
[Smoke test gate] → 4/4 checks pass ✅
[Codex background audit] → fired async

[Between tasks — check for Codex reports]
→ Task 1 Codex report arrived: "WHERE clause should filter by product_type"
→ Opus: Already has product_type='FE' on line 14. False positive. Dismissed.
→ Task 2 Codex report: not back yet. Move on.

[Mark Task 2 complete]

--- Task 3: ... ---

[After all tasks]
[Integration reviewer agent] → Full review, all clear
Done!
```

---

## Red Flags — STOP

- Skipping any review stage (including unit test gate and smoke test gate)
- Pushing to remote (NEVER)
- Running deploy commands (NEVER)
- Dispatching parallel implementers
- Proceeding with failing tests or data verification
- Proceeding with failing smoke test
- Trusting "looks correct" without evidence
- Starting later review stages before earlier ones pass
- Moving to next task with open review issues
- Writing mock-only tests when real tests are possible
- Retrying the same review stage more than 3 times without user input

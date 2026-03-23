---
name: status
description: Show project confidence dashboard with test results, verification status,
  smoke test results, lint warnings, and git cleanliness. Use when user says "status",
  "how are we doing", "confidence check", "project health", "what's the state",
  "are we good", or invokes /status. Also auto-invoked by /wrap-up Phase 0.
---

# Project Confidence Dashboard

Gather all quality signals for the current project and present a scored dashboard.
This gives Spencer an instant read on whether the code is ship-ready.

---

## How to Run

Execute all checks, calculate the score, and present the dashboard. Run checks
in parallel where possible.

### Step 1: Detect Project Context

```bash
# Find project root
# Look for package.json, pyproject.toml, Cargo.toml, go.mod, .git

# Detect project name from:
# 1. PROJECT_STATE.md header
# 2. package.json name field
# 3. Directory name as fallback

# Detect project type:
# Has VERIFICATION.md or database config? → data-backed
# Has package.json with react/next/vue? → frontend
# Has pyproject.toml or setup.py? → Python
# Has Cargo.toml? → Rust
# Has go.mod? → Go
```

### Step 2: Gather Signals

Run these checks. For each, capture the result and calculate the score.

#### Signal 1: Tests (35 points base)

```bash
# Python
pytest --tb=no -q 2>&1 | tail -5
# → Parse "X passed, Y failed, Z skipped"

# JavaScript/TypeScript
npx jest --silent 2>&1 | tail -5
# or: npx vitest run --reporter=verbose 2>&1 | tail -5

# Go
go test ./... 2>&1 | tail -10

# Rust
cargo test --quiet 2>&1 | tail -5
```

**Scoring:**
- 100% pass → 35 points
- 90-99% pass → 31 points
- 80-89% pass → 28 points
- 70-79% pass → 20 points
- <70% pass → 0 points
- No tests found → 10 points (benefit of doubt, but flag it)

#### Signal 2: Lint (15 points base)

```bash
# Run linter only on files changed since last commit
git diff --name-only HEAD

# Then lint each changed file with the appropriate linter
# Python: pylint --errors-only
# JS/TS: npx eslint (if config exists)
# Shell: shellcheck
```

**Scoring:**
- 0 errors, 0 warnings → 15 points
- 0 errors, some warnings → 10 points
- Any errors → 0 points
- No linter available → 12 points (neutral)

#### Signal 3: Data Verification (20 points base)

Only for projects with VERIFICATION.md.

```bash
# Check if VERIFICATION.md exists
# If yes, run verification queries (check_all.sql or check_all.py)
# Parse PASS/FAIL counts
# Also count FILL_IN placeholders (not yet verified)
```

**Scoring:**
- All tests PASS, no FILL_IN → 20 points
- All tests PASS, some FILL_IN → 15 points
- >80% PASS → 12 points
- <80% PASS → 5 points
- Not run or no VERIFICATION.md → 0 points (redistributed)

**Redistribution when no database:** Add 10 to Tests, 5 to Lint, 5 to Git.

#### Signal 4: Smoke Test (20 points base)

```bash
# Check if smoke_test.sh exists in project root
# If yes, run it and parse PASS/FAIL output
```

**Scoring:**
- All checks pass → 20 points
- Any fail → 0 points
- No smoke_test.sh → 5 points (benefit of doubt, but flag it)

**Redistribution when no smoke test:** Add 10 to Tests, 5 to Lint, 5 to Git.

#### Signal 5: Git Cleanliness (10 points base)

```bash
git status --porcelain | wc -l
# Count uncommitted changes
```

**Scoring:**
- 0 uncommitted code files → 10 points
- 1-4 uncommitted → 5 points
- 5+ uncommitted → 0 points

---

### Step 3: Calculate & Present

Add up all signal scores. Present the dashboard:

```
## Project Status: {project_name}
Run: {timestamp} | Branch: {branch}

### Confidence: {score}/100 {progress_bar}

| Signal            | Status          | Details                     |
|-------------------|-----------------|-----------------------------|
| Tests             | {X/Y passing}   | {runner}, {skipped} skipped  |
| Lint              | {Clean/Warnings/Errors} | {error_count} errors, {warn_count} warnings |
| Data Verification | {X/Y passing}   | {fill_in} FILL_IN remaining |
| Smoke Test        | {All pass/X fail/N/A} | {check_count} checks   |
| Git               | {N uncommitted} | {file list or "clean"}      |

### Unresolved
{List any:}
- Failing tests with file:line
- TODO/FIXME/HACK in changed files (grep changed files)
- FILL_IN entries in VERIFICATION.md
- Pending tasks from task list

### Recommendation
{Based on score:}
- 90-100: "Ship it. All signals green."
- 70-89: "Almost there. Address the items above before completing."
- 50-69: "Significant gaps. Fix failing tests and verification before proceeding."
- <50: "Not ready. Major issues need attention."
```

**Progress bar format:** Use block characters proportional to score.
Example: `87/100 █████████░`

---

## Rules

- Run ALL checks every time — don't skip signals
- If a check fails to run (tool not found, timeout), score it as 0 and note why
- Always show absolute counts (47/47), not just percentages
- The Unresolved section should be actionable — specific files and line numbers
- This skill is read-only — it reports, it doesn't fix

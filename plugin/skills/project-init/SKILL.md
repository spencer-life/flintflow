---
name: project-init
description: Scaffold PROJECT_STATE.md, VERIFICATION.md, and verification queries for
  any project type (database-backed, frontend, CLI, AI/ML). Interactive interview then
  generates tailored files. Use when starting a new project, setting up a new repo,
  adding workflow tracking to an existing project, or when user says "init project",
  "set up project state", "scaffold project", "new project setup", or invokes /project-init.
---

# Project Init

Scaffold the workflow files for any project so every session has structured
state tracking and ground-truth verification from day one. Works for new
projects and existing ones mid-development.

**Creates:**
- `PROJECT_STATE.md` — persistent project dashboard
- `VERIFICATION.md` — ground-truth test case template (if project has data)
- `verification/check_all.sql` or `.py` — executable verification queries (if applicable)
- `smoke_test.sh` — real-connection health checks (all projects)

---

## Step 1: Detect Existing State

Before asking questions, check what already exists:

```bash
ls PROJECT_STATE.md VERIFICATION.md verification/ .claude/handoff*.md docs/MEMORY-BANK.md 2>/dev/null
git remote -v 2>/dev/null
ls *.env .env* 2>/dev/null | head -5
ls package.json Cargo.toml pyproject.toml go.mod 2>/dev/null
```

If PROJECT_STATE.md already exists, ask: "PROJECT_STATE.md already exists. Want me
to update it or start fresh?" Respect the answer.

---

## Step 2: Interview

Ask the user these questions conversationally. Adapt based on answers — skip
questions already answered by existing files or previous answers. Don't dump
all questions at once.

### Core Questions (all projects)
1. **What's the project?** — name, one-sentence description
2. **What's the tech stack?** — frontend, backend, database, AI/ML, deployment
3. **What's the current status?** — working, broken, just starting, migrating

### Database Questions (if project has a database)
4. **What database?** — Postgres, Supabase, SQLite, MongoDB, PlanetScale, etc.
5. **How do you connect?** — $DATABASE_URL in .env, railway CLI, supabase CLI, psql, etc.
6. **What are the key tables?** — the ones where correctness matters
7. **What data goes in them?** — products, users, rates, embeddings, etc.

### Data Source Questions (if data comes from external sources)
8. **Where does the data come from?** — PDFs, APIs, CSVs, manual entry, OCR, web scraping
9. **Where are the source documents stored?** — local path, cloud, not yet organized
10. **What data segments or categories exist?** — e.g., product types, customer tiers, regions

### Verification Questions (if data-backed)
11. **Can you give me 2-3 specific values you know are correct?** — e.g., "Pacific Life IUL for 45/M/NS = $247.50/mo, from the rate sheet page 12"
12. **What queries would prove the data is right?** — or "I'll help you figure those out"

### Non-Database Projects (frontend, CLI, AI/ML)
11b. **What does 'working correctly' look like?** — key behaviors, expected outputs, success criteria
12b. **Any external APIs or services?** — endpoints, rate limits, authentication

### Smoke Test Questions (all projects)
13b. **What are the real external connections?** — database, APIs, third-party services, file systems. List everything the project talks to at runtime.
14b. **What does a minimal end-to-end success look like?** — one real request/response cycle that proves the system is wired up correctly (e.g., "bot responds to a slash command", "API returns a 200", "CLI produces output from real data").

### Work Stream Questions (all projects)
13. **What are you working on right now?** — current task or priority
14. **Any parallel work streams planned?** — multiple sessions working simultaneously
15. **Any known issues or things that are broken?** — capture early

---

## Step 3: Generate Files

### PROJECT_STATE.md (all project types)

```markdown
# Project State: {project_name}
Last updated: {date} — Initial setup

## Current Status
{one paragraph from user's answers}

## Architecture
- Frontend: {frontend or "N/A"}
- Backend: {backend or "N/A"}
- Database: {database_type} ({hosting/connection method}) {or "None"}
- AI/ML: {if applicable or "N/A"}
- Deployment: {where it runs}
- Other: {anything else mentioned}

## Data Accuracy Status
| Data Category | Status | Last Verified | Known Issues |
|--------------|--------|---------------|--------------|
{one row per data segment from question 10, or omit this section if no data component}

## Source Documents → Table Mapping
| Source | Target Table | Ingestion Method | Manual Check Done? |
|--------|-------------|-----------------|-------------------|
{one row per source, or omit if no external data sources}

## Active Work Streams
### {current task from question 13}
- Branch: {current branch or "main"}
- Status: {from question 3}
- What's done: {from interview}
- What's left: {from interview}
- Known issues: {from question 15}

## Architecture Decisions
- {date}: Initial project setup — {key stack choices and why}

## Session Log
- {date} #1: Project initialized. {brief status summary}.
```

**Omit sections that don't apply.** No database → drop Data Accuracy Status and
Source Documents. No parallel streams → drop that section. Keep it clean.

### VERIFICATION.md (data-backed projects only)

Skip this file entirely for projects with no database or external data.

```markdown
# Ground Truth Verification: {project_name}

These expected values are manually verified by the project owner against
source documents. They are the source of truth for data accuracy.
If queries return different values, THE DATABASE IS WRONG — not the test.

## How to Run
\`\`\`bash
{connection command} -f verification/check_all.sql
\`\`\`

## {Category 1}
| # | {relevant columns} | Expected Value | Source | Status |
|---|---------------------|---------------|--------|--------|
{fill from question 11, or FILL_IN placeholders}

## {Category 2}
| # | {relevant columns} | Expected Value | Source | Status |
|---|---------------------|---------------|--------|--------|
| 1 | FILL_IN | FILL_IN | Source doc, page X | NOT YET CHECKED |

## Bot/API Response Checks (if applicable)
| # | Query/Input | Expected Output | Status |
|---|-------------|----------------|--------|
| 1 | FILL_IN | FILL_IN | NOT YET CHECKED |
```

### verification/check_all.sql or .py

Detect database type from interview. Generate the matching format:

**Postgres/Supabase:**
```sql
-- Verification queries for {project_name}
-- Run with: psql $DATABASE_URL -f verification/check_all.sql

-- {Category}, Test #1: {description}
-- Expected: {value}
SELECT {columns},
  CASE WHEN {value_column} = {expected}
    THEN 'PASS'
    ELSE 'FAIL: expected {expected}, got ' || {value_column}
  END AS result
FROM {table}
WHERE {conditions};
```

**SQLite:** Same SQL, header comment says `sqlite3 {path} < verification/check_all.sql`

**MongoDB/non-SQL:** Generate `verification/check_all.py` instead.

**No database:** Skip verification file creation entirely.

### smoke_test.sh (all projects)

Generate a smoke test script tailored to the project's external connections
(from questions 13b and 14b). This tests real connections, not mocked behavior.

```bash
#!/usr/bin/env bash
# Smoke test for {project_name}
# Tests real connections and basic end-to-end flow.
# Run: bash smoke_test.sh
# Exit 0 = all pass, Exit 1 = failures
set -euo pipefail

PASS=0
FAIL=0
ERRORS=""

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $name"
    ((PASS++))
  else
    echo "  FAIL: $name"
    ERRORS+="  - $name\n"
    ((FAIL++))
  fi
}

echo "=== Smoke Test: {project_name} ==="
echo ""

# --- Connection Checks ---
echo "Connections:"
# {Generate checks based on project type and interview answers:}
#
# Database (Postgres):
#   check "Database connection" psql "$DATABASE_URL" -c "SELECT 1"
#   check "Key table exists" psql "$DATABASE_URL" -c "SELECT count(*) FROM {table}"
#
# Database (Supabase):
#   check "Supabase connection" curl -sf "$SUPABASE_URL/rest/v1/" -H "apikey: $SUPABASE_ANON_KEY"
#
# API endpoint:
#   check "API reachable" curl -sf https://api.example.com/health
#
# Redis:
#   check "Redis ping" redis-cli ping
#
# File system:
#   check "Data dir exists" test -d ./data

echo ""

# --- Functional Checks ---
echo "Functional:"
# {Generate checks based on what "minimal E2E success" looks like:}
#
# CLI tool:
#   check "CLI runs" ./my-cli --version
#   check "CLI produces output" ./my-cli --dry-run
#
# Web server:
#   check "Server responds" curl -sf http://localhost:3000/health
#
# Discord bot:
#   check "Bot token valid" python3 -c "import discord; print('ok')"
#
# Script:
#   check "Main script runs" python3 main.py --dry-run

echo ""

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed ==="
if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failures:"
  echo -e "$ERRORS"
  exit 1
fi
exit 0
```

**Project-type-specific guidance:**

| Project Type | Connection Checks | Functional Checks |
|---|---|---|
| Database-backed | DB connection, key table exists, sample query | Seed script runs, query returns expected rows |
| Frontend | Dev deps installed | Dev server starts, main page loads (curl localhost) |
| CLI tool | Dependencies available | Binary/script runs with --help, basic command works |
| API server | DB connection (if any), deps installed | Server starts, health endpoint, one real endpoint |
| Discord bot | Token valid, DB connection | Bot can authenticate (dry-run) |
| AI/ML | Model file/API key available | Inference on sample input succeeds |

Always generate real checks based on the interview answers. Don't leave the
template comments in — replace them with actual project-specific checks.

---

## Step 4: Confirm and Advise

After generating files, show the user what was created and the most important
next step:

**For data-backed projects:**
> **Your next step:** Open VERIFICATION.md and add ground-truth values.
> Check 5-10 values per data category against the actual source documents.
> This takes 15-30 minutes and saves hours of debugging later.
>
> The values Claude or any AI generates from OCR are NOT ground truth.
> Ground truth = you opened the source and read the value yourself.

**For non-data projects:**
> PROJECT_STATE.md is set up. Update it at the end of each session.
> Your /catchup and /wrap-up skills will use it automatically.

---

## Step 5: Git Integration

If in a git repo:
```bash
git add PROJECT_STATE.md
git add VERIFICATION.md verification/ 2>/dev/null
git add smoke_test.sh 2>/dev/null
```

Do NOT auto-commit. Just stage. Tell the user files are staged.

---

## Edge Cases

- **Existing project mid-development:** Focus interview on current state. Backfill
  verification from what's already known to be correct or broken.
- **Non-database project:** Skip data sections. PROJECT_STATE.md is still valuable
  for tracking status, decisions, and work streams.
- **Multiple databases:** Create separate verification sections per database.
- **No source documents:** Skip Source Documents mapping. Verification focuses on
  API responses or business rule correctness.
- **Monorepo:** Ask which sub-project. Create files in the sub-project root.

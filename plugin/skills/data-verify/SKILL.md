---
name: data-verify
description: Run ground-truth verification queries against the database and report
  pass/fail results. Use when user says "verify data", "check the data", "run verification",
  "data verify", "are the values correct", "check ground truth", or invokes /data-verify.
  Also used automatically as a review stage in subagent-driven-development for any
  task that modifies database content.
---

# Data Verify

Run the ground-truth verification queries from VERIFICATION.md against the live
database and report pass/fail with actual vs. expected values.

This is the "taste the food" step — not checking if the recipe looks right (code
review), but checking if the result is actually correct (data review).

---

## When This Runs

### Manual invocation
User says `/data-verify` or "check the data" → run full verification suite.

### As a subagent-driven-dev review stage
When the subagent-driven-development skill is executing a task that modifies
database content (INSERT, UPDATE, DELETE, migrations, seed scripts, OCR-to-DB
pipelines), this skill runs as a third review stage:

```
Implementer → Spec Reviewer → Code Quality Reviewer → Data Verifier (this skill)
```

### After any database migration or bulk data operation
If Claude just ran a migration, loaded data from OCR, or did bulk updates,
run this before claiming completion.

---

## Step 1: Locate Verification Files

```bash
# Find verification files
ls VERIFICATION.md verification/check_all.sql verification/check_all.py 2>/dev/null

# Find PROJECT_STATE.md for context
ls PROJECT_STATE.md 2>/dev/null
```

**If VERIFICATION.md doesn't exist:**
Stop and tell the user:
> No VERIFICATION.md found. Ground-truth verification requires expected values
> that YOU verified against source documents. Run `/project-init` to set this up,
> or create VERIFICATION.md manually with your known-correct values.

Do NOT generate verification values from the database or from OCR output.
That defeats the entire purpose.

**If VERIFICATION.md exists but has FILL_IN markers:**
Warn the user:
> VERIFICATION.md has placeholder values. Ground-truth verification only works
> when YOU have manually checked values against source documents.
> Want to fill in some values now before I run the checks?

---

## Step 2: Detect Database Connection

Look for connection details in this order:

1. **Environment variables:**
   ```bash
   # Check for common DB env vars (don't print the actual values)
   env | grep -i "database_url\|db_url\|postgres\|supabase\|mongo\|sqlite" | sed 's/=.*/=***/' 2>/dev/null
   ```

2. **Project config files:**
   ```bash
   # Check common locations
   ls .env .env.local .env.production docker-compose.yml railway.toml supabase/.env 2>/dev/null
   grep -l "DATABASE\|POSTGRES\|SUPABASE\|MONGO\|SQLITE" .env* 2>/dev/null
   ```

3. **PROJECT_STATE.md architecture section:**
   Read the database details from the Architecture section.

4. **Ask the user** if nothing is found:
   > I can't detect your database connection. How do I connect?
   > - `psql $DATABASE_URL`
   > - `railway run psql`
   > - `supabase db dump`
   > - Something else?

---

## Step 3: Run Verification Queries

### For SQL databases (Postgres, SQLite, MySQL)

If `verification/check_all.sql` exists:
```bash
# Postgres via DATABASE_URL
psql "$DATABASE_URL" -f verification/check_all.sql 2>&1

# Or via Railway
railway run psql -f verification/check_all.sql 2>&1

# Or SQLite
sqlite3 {db_path} < verification/check_all.sql 2>&1
```

If no SQL file exists but VERIFICATION.md has a table of expected values,
construct and run queries on the fly based on the VERIFICATION.md table.

### For Python-based verification

```bash
python verification/check_all.py 2>&1
```

### For API/bot response verification

If VERIFICATION.md includes Bot/API Response Checks, run those too:
```bash
# Construct curl commands or bot queries from the table
# Show actual response vs. expected
```

---

## Step 4: Parse and Report Results

Present results as a clear table. This is the most important output —
make it impossible to miss failures.

```
## Data Verification Results
Run: {timestamp}
Database: {connection method}

### {Category 1}: {N/M passing}
| # | Description | Expected | Actual | Status |
|---|-------------|----------|--------|--------|
| 1 | PL IUL 45/M/NS | $247.50 | $247.50 | ✅ PASS |
| 2 | PL IUL 35/F/NS | $189.00 | $189.00 | ✅ PASS |
| 3 | NW IUL 50/M/T  | $412.00 | $398.50 | ❌ FAIL |

### {Category 2}: {N/M passing}
| # | Description | Expected | Actual | Status |
|---|-------------|----------|--------|--------|
| 1 | ANICO FE 55/NS/$10k | $32.50 | $37.80 | ❌ FAIL |

### Summary
- Total: {X} tests
- Passing: {Y} (Z%)
- Failing: {W}
- Not yet checked (FILL_IN): {V}
```

---

## Step 5: Verdict

Based on results, give a clear verdict:

### All pass
```
✅ ALL VERIFICATION TESTS PASS

All {X} ground-truth checks match expected values.
Data accuracy is confirmed for the tested cases.

Note: This covers {X} spot checks. Full data correctness depends on
comprehensive verification values in VERIFICATION.md.
```

### Some fail
```
❌ {N} VERIFICATION TESTS FAILING

The following data is incorrect:
{list each failure with expected vs actual}

DO NOT proceed to the next phase until these are fixed.
DO NOT claim this task is complete.

Suggested next steps:
1. Check the source document for each failing value
2. Identify whether the error is in OCR, data loading, or transformation
3. Fix the specific rows
4. Re-run /data-verify
```

### Cannot run (no connection, no verification file)
```
⚠️ VERIFICATION COULD NOT RUN

Reason: {why}
This does NOT mean the data is correct — it means we couldn't check.

{guidance on how to fix}
```

---

## Step 6: Update PROJECT_STATE.md

If PROJECT_STATE.md exists, update the Data Accuracy Status table:

```markdown
## Data Accuracy Status
| Data Category | Status | Last Verified | Known Issues |
|--------------|--------|---------------|--------------|
| IUL | VERIFIED (5/5) | {today} | None |
| Final Expense | FAILING (3/5) | {today} | ANICO ages 50-65 off by ~15% |
```

---

## Integration with Other Skills

### verification-before-completion
When that skill demands "evidence before claims" for a database-modifying task,
the evidence MUST include `/data-verify` results. Code tests passing alone is
not sufficient for database work.

### subagent-driven-development
The data verifier subagent prompt:

```
You are a data verification reviewer. Run /data-verify and report the results.

Rules:
- If any ground-truth test fails, the task is NOT complete
- Do not approve with failing tests
- Do not generate your own expected values — only use VERIFICATION.md
- Report actual vs. expected for every test
- If VERIFICATION.md has no relevant tests for this change, flag it:
  "No ground-truth tests cover this change. Consider adding test cases."
```

### wrap-up
Before session wrap-up, run `/data-verify` and include results in the session log.

### codex
When using `/codex review` for database changes, include the data-verify results
in the prompt so Codex can see actual data state, not just code diffs.

---

## Scope Options

### Full run (default)
```
/data-verify
```
Runs all tests in VERIFICATION.md.

### Category-specific
```
/data-verify IUL
/data-verify "Final Expense"
```
Runs only tests in the specified category section.

### Single test
```
/data-verify #3
```
Runs only test #3 from VERIFICATION.md.

### Before/after comparison
```
/data-verify --before
{... make changes ...}
/data-verify --after
```
Captures state before changes, then compares after. Shows what changed.

---

## Anti-Patterns (Never Do These)

- **Never generate expected values from the database.** That's circular. Expected
  values come from source documents, verified by the human.
- **Never skip data verification because code tests pass.** Code tests check
  behavior. Data verification checks correctness. Both are needed.
- **Never approve a task with failing verification.** If tests fail, the task
  isn't done. Period.
- **Never mark FILL_IN values as PASS.** Unchecked is unchecked.
- **Never modify VERIFICATION.md to match the database.** If the database
  disagrees with VERIFICATION.md, the database is wrong (unless the human
  explicitly says otherwise).

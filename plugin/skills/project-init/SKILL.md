---
name: project-init
description: Scaffold complete project workflow files via a strategic interview
  — PROJECT_STATE.md (always), PROJECT_MAP.md (always, visual service graph),
  VERIFICATION.md + verification queries (only if it's a data-backed project),
  smoke_test.sh (only if deployed). Auto-detects services from project files
  (package.json, railway.toml, netlify.toml, supabase/, .env.example, deps) and
  the user's global service-map memory BEFORE asking questions, so the interview
  focuses on direction and strategy, not service IDs. ZERO PLACEHOLDERS in any
  generated file — every value comes from auto-detection or a conversational
  answer. Use when starting a new project, setting up a new repo, adding workflow
  tracking to an existing project, or when user says "init project", "set up
  project state", "scaffold project", "new project setup", or invokes
  /project-init.
---

# Project Init

Scaffold the workflow files for a project so every session has structured
state tracking, visual service context, and ground-truth verification (when
relevant) from day one. Works for new projects and existing ones mid-development.

**Always creates:**

- `PROJECT_STATE.md` — persistent project dashboard
- `PROJECT_MAP.md` — visual service graph (Mermaid flowchart + inventory)

**Conditionally creates (only when interview says yes):**

- `VERIFICATION.md` + `verification/check_all.sql|.py` + `verification/history.log`
  — only if user confirms this is a data-backed project where wrong data would
  be a real problem
- `smoke_test.sh` — only if user confirms the project is deployed somewhere
  with real external connections to test

**Hard rule:** ZERO placeholders in any generated file. No `FILL_IN`, no
`{user_to_fill}`, no `TODO`, no `<add later>`. Every value comes from
auto-detection or a conversational answer captured during the interview. The
user must NEVER open a generated file to fill anything in. Want it written?
Ask the question.

---

## Step 1: Detect existing state

Before asking anything, check what's already there:

```bash
ls PROJECT_STATE.md PROJECT_MAP.md VERIFICATION.md verification/ smoke_test.sh 2>/dev/null
```

If `PROJECT_STATE.md` already exists, ask: "PROJECT_STATE.md already exists.
Update it or start fresh?" Respect the answer. Same for PROJECT_MAP.md
(though /project-map handles its own re-run logic — see below).

---

## Step 2: Auto-detect services (silent)

Run the project-map skill's detect.sh from the cwd. This gives you a JSON
inventory of detected external services without asking the user anything.

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/cache/flintflow/flintflow/$(ls ~/.claude/plugins/cache/flintflow/flintflow | sort -V | tail -1)}/skills/project-map/detect.sh"
```

Output JSON includes: project_name, project_root, github, railway, supabase,
netlify, cloudflare, doppler, discord, purpose_draft, in_service_map.

Hold this JSON in memory for the rest of the flow — it pre-fills both the
PROJECT_STATE.md "Architecture" section and the PROJECT_MAP.md.

---

## Step 3: Interview (strategic, conversational, minimum questions)

Ask conversationally. Don't dump all questions at once. Adapt based on
answers. Skip anything the auto-detect already answered.

### Phase A — Confirm detection (1 question)

> Detected: {summarize JSON in plain English, e.g., "GitHub spencer-life/charm,
> Railway, Supabase project xyz789, Discord bot, Doppler charm/dev_personal"}.
> Anything missing or wrong?

If user says no → proceed.
If user corrects → capture corrections (e.g., "actually we also use Resend").

### Phase B — Purpose & direction (open-ended, captures the strategic context)

If `purpose_draft` from detect.sh is empty/uninformative:
> What does this project do, who's it for, and what stage is it at?

If `purpose_draft` is informative, just confirm:
> README says it's "{purpose_draft[:100]}...". Sound right? Anything to add about
> audience or stage (early / shipping / maintained / sunset)?

### Phase C — Current status (open-ended)

> What's the current status? What's working, what's broken, what's in flight?

Capture verbatim — this becomes the PROJECT_STATE.md "Current Status" section.

### Phase D — Active work + known issues

> What are you working on right now or planning to ship next? Anything broken
> or annoying you want flagged?

### Phase E — Direction (the open-ended questions Spencer values)

Ask these even if the answers are short — they shape PROJECT_MAP.md "Current
focus" and PROJECT_STATE.md "Architecture Decisions":

> Three more — feel free to skip any:
>
> 1. What's the biggest unknown or risk you're carrying right now?
> 2. What would you change if you could redo the architecture from scratch?
> 3. What's a 30-day goal for this project?

### Phase F — Verification gate (Y/N — branches the flow)

> Is this a data-backed project where wrong data would be a real problem
> (e.g., insurance pricing, billing, leaderboards, vector embeddings)?

**If NO:** skip VERIFICATION.md generation entirely. Move to Phase G.

**If YES:** ask the data-verification questions conversationally. Capture
answers into VERIFICATION.md content directly — DO NOT write FILL_IN
placeholders.

> What categories of data live in this project? (e.g., "carrier rates",
> "policy pricing", "embedded reviews")

For each category:
> For {category}: give me 2–3 specific values you've personally verified
> against the source. Format like: "{example_columns} = {value}, from {source}".
> If you don't have ground-truth values yet, say so — we'll skip this category
> for now and add them when you do.

If they say "skip for now" for a category: omit that category from
VERIFICATION.md. Do NOT write placeholders. The user can re-run /project-init
or `/data-verify` later when they have values.

> What database is this in? How do you connect? (e.g., "Supabase, $DATABASE_URL
> from Doppler", "local SQLite at ./data/db.sqlite")

### Phase G — Smoke gate (Y/N — branches the flow)

> Is this deployed anywhere I can hit a real endpoint to test
> (Railway URL, Discord bot, Netlify site, API endpoint)?

**If NO:** skip smoke_test.sh generation entirely. Move to Step 4.

**If YES:**
> What's the simplest end-to-end success you can describe? (e.g., "bot
> responds to /ping in Discord", "API returns 200 on /health", "site
> loads at example.netlify.app")

Capture; turn into actual smoke_test.sh checks (not template comments).

---

## Step 4: Generate files (no placeholders)

### PROJECT_STATE.md (always)

Use values from interview + detect.sh JSON. Omit any section that doesn't
apply (no database → drop Data Accuracy Status; not a frontend project →
drop Component Status; no parallel streams → drop that section).

```markdown
# Project State: {project_name from JSON}
Last updated: {today's date} — Initial setup

## Current Status
{verbatim from Phase C answer}

## Architecture
- Frontend: {detected or from interview, or "N/A"}
- Backend: {detected or from interview, or "N/A"}
- Database: {detected or "None"}
- AI/ML: {from interview or "N/A"}
- Deployment: {detected (Railway/Netlify/Cloudflare) or from interview or "Local only"}
- Other: {anything else mentioned}

## Data Accuracy Status [only if Phase F = YES]
| Data Category | Status | Last Verified | Known Issues |
|--------------|--------|---------------|--------------|
{one row per category captured in Phase F. If user said "skip for now" for a category, mark Status = "Not yet ground-truthed".}

## Active Work Streams
### {short description from Phase D}
- Branch: {git branch --show-current or "main"}
- Status: {from Phase C}
- What's done: {from Phase C}
- What's left: {from Phase D}
- Known issues: {from Phase D}

## Architecture Decisions
- {today's date}: Initial project setup — {key stack choices from detection + Phase B}
- {today's date}: 30-day goal — {from Phase E #3, if answered}

## Session Log
- {today's date} #1: Project initialized via /project-init. {1-line status from Phase C}.
```

### PROJECT_MAP.md (always)

**Invoke the project-map skill** to generate this file. The project-map skill
already has detect.sh's JSON, the template, and the composition logic. Call
it as a downstream step rather than duplicating the logic here.

Include in the call: pass any user-provided service additions/corrections from
Phase A so the map reflects them.

### VERIFICATION.md (only if Phase F = YES)

```markdown
# Ground Truth Verification: {project_name}

These expected values were provided by the project owner against source
documents. They are the source of truth for data accuracy. If queries return
different values, THE DATABASE IS WRONG — not the test.

## How to Run
\`\`\`bash
{connection command from Phase F} -f verification/check_all.sql
\`\`\`

{For each category captured in Phase F:}

## {category name}
| # | {columns from user's example} | Expected Value | Source | Status |
|---|---|---|---|---|
| 1 | {column values from user example 1} | {value 1} | {source 1} | NOT YET CHECKED |
| 2 | {column values from user example 2} | {value 2} | {source 2} | NOT YET CHECKED |
{... etc, one row per ground-truth value the user gave conversationally}
```

**Critical:** every cell in this table must contain real values from the
user's interview answers. NEVER write `FILL_IN` or `TBD`. If a category has
no ground-truth values yet, OMIT the category section entirely — don't write
an empty placeholder section.

### verification/check_all.sql (only if Phase F = YES and database is SQL)

Generate real queries from the ground-truth values, not template comments.

```sql
-- Verification queries for {project_name}
-- Run with: {connection command} -f verification/check_all.sql

{For each value captured in Phase F:}
-- {category}, Test #N: {brief description from user's wording}
-- Expected: {value}
SELECT {relevant columns},
  CASE WHEN {value_column} = {expected_value}
    THEN 'PASS'
    ELSE 'FAIL: expected {expected_value}, got ' || COALESCE({value_column}::text, 'NULL')
  END AS result
FROM {table_inferred_from_category}
WHERE {conditions_from_user_example};
```

For non-SQL databases (MongoDB, etc.), generate `verification/check_all.py`
in the same spirit — real queries, no FILL_IN placeholders.

### verification/history.log (only if Phase F = YES)

```
# Verification History — {project_name}
```

(Header only. `/data-verify` appends one-line summaries after each run.)

### smoke_test.sh (only if Phase G = YES)

Generate the smoke test from interview answers. Replace template comments
with REAL checks tailored to the user's "minimal end-to-end success" answer.
Use detect.sh's JSON to know what services are wired (Railway URL, Supabase
connection method, Discord bot token from Doppler, etc.).

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

echo "Connections:"
{Generate REAL checks based on detected services. Examples:}
{- Railway: check "Railway service up" curl -sf https://{actual-url}.up.railway.app/health}
{- Supabase: check "Supabase reachable" curl -sf "$SUPABASE_URL/rest/v1/" -H "apikey: $SUPABASE_ANON_KEY"}
{- Doppler: check "Doppler secrets load" doppler -p {project} -c {config} secrets --only-names | grep -q DATABASE_URL}
{- Discord: check "Discord token valid" python3 -c "import discord; print('ok')"}

echo "Functional:"
{Generate from user's "minimal E2E success" answer. Examples:}
{- "Bot responds to /ping" → check "Bot online" python3 -c "{import logic}"}
{- "API returns 200 on /health" → check "Health endpoint" curl -sf {endpoint}}
{- "Site loads at X" → check "Site reachable" curl -sf {url}}

TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed ==="
if [[ $FAIL -gt 0 ]]; then
  echo "Failures:"
  echo -e "$ERRORS"
  exit 1
fi
exit 0
```

**Critical:** never leave the `{ }` template comments in the generated file.
Replace them with real, executable checks. If a particular check needs info
the user didn't provide (e.g., specific endpoint URL), ASK during Phase G —
don't leave a placeholder.

---

## Step 5: Confirm and advise

After generating files, show the user what was created:

> Created:
>
> - PROJECT_STATE.md ({lines} lines)
> - PROJECT_MAP.md ({lines} lines, with Mermaid diagram)
> {- VERIFICATION.md (N ground-truth values captured) — only if generated}
> {- verification/check_all.sql (N tests) — only if generated}
> {- smoke_test.sh — only if generated}

**Always tell the user:**
> Open PROJECT_MAP.md in VS Code (markdown preview renders the Mermaid). All
> generated files are fully populated — no placeholders to fill in.

**If VERIFICATION.md was generated:**
> Run `/data-verify` to execute the verification queries against the live database.

**If smoke_test.sh was generated:**
> Run `bash smoke_test.sh` to verify all connections.

---

## Step 6: Git integration

If in a git repo:

```bash
git add PROJECT_STATE.md PROJECT_MAP.md
git add VERIFICATION.md verification/ smoke_test.sh 2>/dev/null
```

Stage, do NOT commit. Tell the user files are staged.

---

## Edge cases

- **Existing project mid-development:** detect.sh still works fine on existing
  projects. Interview focuses on current state and direction. The "skip if
  no ground-truth values yet" rule means VERIFICATION.md categories without
  values get omitted, not stubbed.
- **Multiple databases:** ask which to verify in Phase F; generate separate
  category sections for each.
- **Monorepo:** ask which sub-project. `cd` into it before running detect.sh.
- **Project not in `project_service_map.md` memory:** interview proceeds
  normally; PROJECT_MAP.md uses detected values without canonical IDs. After
  generation, suggest: "This project isn't in your global service-map memory.
  Worth adding next time you update memory."

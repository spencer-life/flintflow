---
name: project-map
description: Generate or refresh a visual PROJECT_MAP.md at the project root that
  shows the project's external services (GitHub, Railway, Supabase, Netlify, Doppler,
  Discord, etc.) as a Mermaid flowchart plus an inventory table with dashboard URLs.
  Auto-detects services from project files (package.json, railway.json, netlify.toml,
  supabase/config.toml, .env.example, deps) and cross-references the user's global
  service-map memory for authoritative IDs. Use when the user says "map this project",
  "service map", "project map", "what services does this project use", or invokes
  /project-map. Also invoked automatically as part of /project-init's default flow.
---

# Project Map

Generates `PROJECT_MAP.md` at the project root: a single visual artifact showing
what external services the project touches, with their official names/IDs and
dashboard URLs. The Mermaid diagram renders inline in Claude chat AND in VS Code
markdown preview.

**Goal:** Spencer (or any future Claude session) opens `PROJECT_MAP.md` and
understands the project's external footprint at a glance — no clicking through
configs, no guessing service IDs.

**Non-goal:** This is NOT pathfinder (which maps internal CODE architecture).
This maps external SERVICE architecture. They're complementary.

**Hard rule:** ZERO placeholders in the output file. Every value comes from
auto-detection or — if absolutely necessary — a single conversational question.
The user must never open `PROJECT_MAP.md` to fill anything in.

---

## Step 1: Auto-detect (silent, before any question)

Run `detect.sh` from the skill directory to gather a JSON inventory of detected
services. The script greps known config files and looks up the project in
`~/.claude/projects/-home-mlpc--claude/memory/project_service_map.md` by repo name
to get authoritative IDs.

```bash
bash "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/cache/flintflow/flintflow/$(ls ~/.claude/plugins/cache/flintflow/flintflow | sort -V | tail -1)}/skills/project-map/detect.sh"
```

The script outputs JSON like:

```json
{
  "project_name": "charm",
  "project_root": "/home/mlpc/dev/charm",
  "github": { "owner": "spencer-life", "repo": "charm", "url": "https://github.com/spencer-life/charm" },
  "railway": { "name": "charm", "id": "abc123", "dashboard": "https://railway.com/project/abc123" },
  "supabase": { "ref": "xyz789", "region": "us-west-1", "dashboard": "https://supabase.com/dashboard/project/xyz789" },
  "netlify": null,
  "doppler": { "project": "charm", "env": "dev_personal" },
  "discord": { "detected": true, "bot_id": null },
  "purpose_draft": "First paragraph of README.md if present",
  "in_service_map": true
}
```

If `in_service_map` is false, note it — the project should be added to memory after.

---

## Step 2: Confirm and fill gaps (1 question max, only if needed)

Show the user what was detected:

> Detected: GitHub spencer-life/charm · Railway "charm" · Supabase xyz789 (us-west-1) · Discord bot · Doppler charm/dev_personal.
> Anything missing or wrong?

If they say no, proceed straight to Step 3.

If they correct something, capture the correction. **Do not ask anything you can
detect.** Service IDs, repo names, dashboard URLs — all auto-detected.

Only ask one open question if the auto-detect can't supply the project's purpose:

> What does this project do, in one sentence?

Skip it if `purpose_draft` from detect.sh is non-empty AND informative.

---

## Step 3: Compose the PROJECT_MAP.md content

### Multi-project root branch (only when sub_projects is non-empty)

If detect.sh's JSON has a non-null `sub_projects` array, generate an
ORCHESTRATOR-style PROJECT_MAP.md instead of the standard service-graph map.
The orchestrator map indexes the sub-projects rather than listing services
(services live in each sub-project's own PROJECT_MAP.md).

Orchestrator template:

```markdown
# Project Map: {project_name} (multi-project root)
> Auto-mapped {date} · Re-run `/project-map` to refresh

## What this is
{1–2 sentences from interview or README}

## Sub-projects
\`\`\`mermaid
flowchart LR
  ROOT[{project_name}<br/>orchestrator]
  {for each sub: SUB_N[{sub.name}<br/>see {sub.path}/PROJECT_MAP.md]}
  {for each sub: ROOT --> SUB_N}
\`\`\`

| Sub-project | Path | Map |
|---|---|---|
{for each sub: | {sub.name} | `{sub.path}` | `{sub.path}/PROJECT_MAP.md` |}

## Notes
<!-- Hand-edited section. /project-map preserves anything below this line on re-run. -->
- For per-sub-project services, `cd <path>` and run `/project-map` there
- Shared code, shared deploy strategy, and orchestrator-level concerns live in PROJECT_STATE.md at this root
```

Skip the standard service inventory section — services don't live at the
orchestrator level. Skip the Local paths "Companion files" line for sub-projects
(report only the root's companion files).

Then SKIP the rest of Step 3 (don't render the standard service template) and
go directly to Step 4.

### Single-project branch (default — sub_projects is null or empty)

Read the template at `PROJECT_MAP_TEMPLATE.md` in the skill directory. Replace
every `{token}` with the corresponding value from the JSON inventory. **If a
service is null, omit its row from the inventory table AND its node + edges from
the Mermaid diagram.** Don't render `{site_name}` literally — drop the row.

For the Mermaid diagram, only emit edges between services that actually exist.
Use these defaults for edge labels:

- `GH -->|deploys to| RW` (if Railway present)
- `GH -->|deploys to| NL` (if Netlify present)
- `GH -->|deploys to| CF` (if Cloudflare present)
- `RW -->|reads/writes| SB` (if both Railway and Supabase present)
- `NL -->|reads/writes| SB` (if both Netlify and Supabase present)
- `RW -->|posts to| DC` (if both Railway and Discord present)
- `RW -.secrets.-> DOP` (if both Railway and Doppler present)
- `NL -.secrets.-> DOP` (if both Netlify and Doppler present)
- `CF -.secrets.-> DOP` (if both Cloudflare and Doppler present)

Use `<br/>` for line breaks inside Mermaid node labels.

For the "What this is" section: 1–2 sentence purpose statement. Pull from
`purpose_draft` (README first paragraph) or the user's answer to the purpose
question, NOT both.

For "Local paths": use `project_root` from detect.sh.

For "Companion files": check existence of `PROJECT_STATE.md`, `VERIFICATION.md`,
`smoke_test.sh` in `project_root` and report yes/no for each.

---

## Step 4: Write the file

If `PROJECT_MAP.md` does not exist at `project_root`: write it fresh with the
composed content.

If it exists (re-run / refresh):

1. Read the existing file
2. Find the `<!-- Hand-edited section.` marker
3. Preserve everything from that marker to the end of file
4. Replace everything above the marker with the freshly-composed content
5. If the diff (above-marker portion) shows changed services, summarize the diff
   in chat and ask "update?" before writing. If no service changes (only the
   "Auto-mapped" date would change), skip the prompt and just write.

Always update the `Auto-mapped {YYYY-MM-DD}` date to today (use
`$(date +%Y-%m-%d)`).

---

## Step 5: Confirm and advise

Tell the user where the file was written:

> Wrote `<project_root>/PROJECT_MAP.md`. Open it in VS Code (markdown preview
> renders the Mermaid diagram) or run `/project-map` again to refresh after
> service changes.

If `in_service_map` was false:
> Note: `<repo>` is not in your global `project_service_map.md` memory. If this
> is a project worth tracking globally, add it next time you update memory.

---

## Edge cases

- **Not in a git repo:** detect.sh sets `github` to null. Skip the GitHub node;
  rest of the map still works for projects on disk that aren't git-tracked.
- **No services detected at all:** still write a minimal `PROJECT_MAP.md` with
  just the purpose paragraph and a note: "No external services detected. Add
  config files (package.json, railway.json, etc.) or re-run after wiring."
- **Multiple Supabase / Railway projects:** pick the one matching the project
  name; if ambiguous, list both in the inventory and note the ambiguity.
- **Monorepo:** detect.sh runs from cwd. If user wants a sub-project map, they
  should `cd` into it first.

# Project Map: {project_name}

> Auto-mapped {date} · Re-run `/project-map` to refresh

## What this is

{purpose}

## Services

```mermaid
flowchart LR
{mermaid_nodes}

{mermaid_edges}
```

## Inventory

| Service | Name/ID | Dashboard | Local config |
|---|---|---|---|
{inventory_rows}

## Local paths

- Working dir: `{project_root}`
- Companion files: PROJECT_STATE.md ({has_state}), VERIFICATION.md ({has_verification}), smoke_test.sh ({has_smoke})

## Notes

<!-- Hand-edited section. /project-map preserves anything below this line on re-run. -->

- For code architecture: run `/pathfinder`
- For data ground-truth: see VERIFICATION.md (if present)
- For session history: search via claude-mem `mem-search`

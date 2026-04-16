# flintflow

A Claude Code plugin for structured project workflows with ground-truth data verification, session lifecycle management, and multi-stage subagent execution.

## The Problem

Claude Code is great at writing code, but complex projects — especially database-backed ones — have recurring pain points:

- **Claude grades its own homework.** Tests pass, but the data is wrong because Claude wrote both the code and the tests.
- **Context evaporates between sessions.** Handoff files help, but there's no persistent project memory across many sessions.
- **"Done" doesn't mean correct.** Claude declares victory after tests pass, but nobody verified the actual database values.
- **Parallel sessions step on each other.** Two sessions modifying the same tables with no awareness of each other's intent.

flintflow fixes these by adding ground-truth verification, persistent project state, and a structured execution pipeline.

## What's Inside

### Skills (7)

| Skill | Description |
|-------|-------------|
| `/project-init` | Interactive scaffold — interviews you about your project, generates `PROJECT_STATE.md`, `VERIFICATION.md`, and verification queries. Works on new and existing projects. |
| `/data-verify` | Runs ground-truth verification against your database. Compares actual values to human-authored expected values in `VERIFICATION.md`. Refuses to generate its own expected values. |
| `/handoff` | Enhanced context transfer with data state section. Gathers from conversation, git, and database state. |
| `/catchup` | Resume from a handoff. Reads `PROJECT_STATE.md` + `VERIFICATION.md`, flags data failures, suggests fixes before proceeding. |
| `/wrap-up` | End-of-session checklist: verify data → commit (never push) → update project state → capture learnings → review. |
| `/codex` | Codex CLI (GPT-5.4) integration. Subcommands: exec, review, adversarial-review, research, compare, status, cancel, result. Structured adversarial review with JSON output, background job management, and cross-model verification at phase boundaries. |
| `/subagent-driven-development` | Full execution pipeline: Pre-flight → Implement → Spec Review → Code Quality → Data Verify → Codex Auto-Review. All subagent prompts embedded. |

### Agents (3)

| Agent | Description |
|-------|-------------|
| `pre-flight` | Checks scope conflicts, missing context, data safety, and dependencies before implementation starts. |
| `data-verifier` | Verifies database values against `VERIFICATION.md` ground-truth. Verdicts: APPROVED, REJECTED, INCONCLUSIVE, BLOCKED. |
| `integration-reviewer` | Reviews branch merges after parallel sessions. Checks git conflicts, logic conflicts, data conflicts, and schema conflicts. |

### Hooks

| Hook | Event | Description |
|------|-------|-------------|
| `session-start.sh` | SessionStart | Git snapshot (branch, staged/unstaged counts, recent commits, stash) + handoff file detection with staleness warnings. |

### Scripts

| Script | Description |
|--------|-------------|
| `codex-delegate.sh` | Bash wrapper for Codex CLI with subcommands (exec, review, adversarial-review, research, compare, status, cancel, result), timeout handling, git worktree support, background job management, and post-write lint/format integration. |
| `adversarial-review-schema.json` | JSON schema for structured adversarial review output (verdict, findings with severity/confidence/file/line). |
| `adversarial-review-prompt.txt` | System prompt template for adversarial code review via Codex. |

## Optional Codex Verifier Layer

flintflow works without any Codex-specific local skills, but Spencer's preferred
setup is to pair Flint Flow with a small read-only Codex verifier pack:

- `claude-work-verifier` — independent task review with `BLOCK`, `FIX`, or `SHIP`
- `artifact-verifier` — evidence-first verification for UI/API/data/browser work
- `handoff-auditor` — stale-context and drift check before resuming from handoff
- `ground-truth-coverage` — audit `VERIFICATION.md` coverage without inventing values

These are invoked through the same wrapper and `just` shortcuts used by the
`/codex` skill. Codex stays read-only by default; Claude remains the executor.

## Key Concepts

### VERIFICATION.md

A human-authored file of expected values. Claude and Codex are both forbidden from generating these — only humans establish ground truth. Example:

```markdown
## Premium Rates
| Carrier | Product | Age | Gender | Tobacco | Expected |
|---------|---------|-----|--------|---------|----------|
| PL | IUL | 45 | M | NS | $247.50 |
| ANICO | FE | 55 | - | NS | $32.50 |
```

### PROJECT_STATE.md

Persistent project memory that survives across sessions. Tracks architecture decisions, data accuracy scores, active work streams, parallel session boundaries, and known issues.

### The Pipeline

```
Pre-flight → Implement → Spec Review → Code Quality → Data Verify → Codex Review
```

Every stage has a clear verdict. Any REJECTED verdict blocks progression. Data verification uses `VERIFICATION.md` — not AI-generated expectations.

## Installation

```bash
# Copy to plugins directory
cp -r flintflow ~/.claude/plugins/flintflow

# Delete skills that flintflow replaces (if you have them)
rm -rf ~/.claude/skills/{catchup,handoff,wrap-up,codex,subagent-driven-development}

# Copy agents to global agents folder
cp ~/.claude/plugins/flintflow/agents/*.md ~/.claude/agents/

# Copy codex-delegate.sh to hooks directory
cp ~/.claude/plugins/flintflow/scripts/codex-delegate.sh ~/.claude/hooks/codex-delegate.sh
chmod +x ~/.claude/hooks/codex-delegate.sh

# Add alias so flintflow loads every session
echo 'alias cc="claude --plugin-dir ~/.claude/plugins/flintflow"' >> ~/.zshrc
source ~/.zshrc
```

### Requirements

- Claude Code CLI
- Codex CLI (optional — for cross-model verification)
- A database connection (for data verification skills)

## Quick Start

```bash
# Start Claude Code with flintflow
cc

# Initialize a new or existing project
/project-init

# After implementation work, verify data
/data-verify

# End of session
/wrap-up

# Transfer context to next session
/handoff

# Next session: pick up where you left off
/catchup
```

## Hard Rules

- **Never push.** Wrap-up commits only. You push when you're ready.
- **Never generate expected values.** Only humans author `VERIFICATION.md`.
- **Never approve failing tests.** Any REJECTED verdict blocks the pipeline.
- **Database disagrees with VERIFICATION.md?** The database is wrong.

## License

MIT

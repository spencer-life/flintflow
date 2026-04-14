---
name: codex
description: This skill invokes Codex CLI (GPT-5.4) for web research, second opinions,
  code review, or autonomous terminal tasks. It should be used when the user says
  "use codex", "ask codex", "codex review", "codex research", "search the web for",
  or invokes /codex. Also auto-invoked by subagent-driven-development at phase boundaries.
---

# Codex CLI Integration

Invoke OpenAI Codex CLI (GPT-5.4) as a specialist tool. Claude stays the orchestrator;
Codex is a power tool for specific strengths.

For Spencer's workflow, default to **read-only verification** first. Use Codex
as an independent auditor before using it as an implementer.

## Subcommands

| Subcommand | When to use | Example |
|------------|-------------|---------|
| `exec` | General task delegation | `/codex fix the nginx 502 error` |
| `review` | Code review (second opinion) | `/codex review` |
| `research` | Web search / current events | `/codex research latest Node LTS` |
| `compare` | Get Codex's independent take, then synthesize | `/codex compare is this schema normalized?` |

## Steps

1. **Parse the user's intent** — determine which subcommand fits:
   - Web/current events → `research`
   - Code review → `review`
   - Second opinion → `compare`
   - Everything else → `exec`

2. **Invoke the wrapper script** via Bash tool:
   ```bash
   bash ~/.claude/hooks/codex-delegate.sh <subcommand> "<prompt>" [flags]
   ```

   Available flags:
   - `--timeout N` — seconds (default 120)
   - `--sandbox MODE` — `read-only` (default) or `workspace-write`
   - `--cwd DIR` — working directory
   - `--output FILE` — custom output path
   - `--worktree` — run in isolated git worktree
   - `--search` — enable live web search (for review, compare, exec)

   > Note: `research` always enables web search automatically. Use `--search` on
   > other subcommands when Codex needs web access.

3. **Present the result** with clear attribution:
   - Label output: **Codex (GPT-5.4) says:**
   - For `compare`: present Codex's view, then Claude's view, then a **Synthesis** combining both

4. **Handle errors gracefully:**
   - Exit 2 (timeout): "Codex timed out — here's my take instead: ..."
   - Exit 3 (not installed): "Codex CLI isn't available. I'll handle this directly."
   - Exit 1 (other error): "Codex hit an error. Here's what I think: ..."

5. **Compare disagreement handling:**
   - If Claude and Codex agree: present consensus with both perspectives as support
   - If they disagree: present both side-by-side with reasoning, recommend the stronger argument, let the user decide

## Preferred Verifier Flows

These are the default Codex roles in Flint Flow. Favor them over open-ended
delegation when the goal is confidence rather than implementation:

| Goal | Prompt shape | Shortcut |
|------|--------------|----------|
| Independent review of Claude's work | `Use the claude-work-verifier skill...` | `just codex_verify "task summary"` |
| Evidence-first artifact check | `Use the artifact-verifier skill...` | `just codex_verify_artifacts "artifact summary"` |
| Audit a stale handoff before resume | `Use the handoff-auditor skill...` | `just codex_audit_handoff .claude/handoff.md` |
| Check ground-truth verification coverage | `Use the ground-truth-coverage skill...` | `just codex_ground_truth_audit "scope"` |

When a verifier flow finds issues, Claude must triage every finding as:
- fixed now
- dismissed with reasoning
- needs user input

## Auto-Invocation (by subagent-driven-development)

When subagent-driven-development completes all review stages for a task
(spec → code quality → data verification), it auto-invokes Codex as a final
cross-model check before moving to the next task.

**Auto-invocation uses `compare` mode with `--search`** (web search enabled)
and a prompt constructed from:
- The task description
- The git diff of changes made
- Verification results (if data task)

**Also auto-invoked by `/wrap-up` Phase 2** — runs `review --uncommitted --search`
on all session changes before committing. Claude triages findings: real issues
get fixed, false positives get dismissed with reasoning.

The prompt template for auto-invocation:
```
Review the changes for this task:

TASK: {task description}
DIFF: {git diff output}
{If data task:} VERIFICATION: {pass/fail results from data-verify}

Focus on:
1. Does the implementation achieve the stated goal?
2. Are there edge cases or bugs the reviews might have missed?
3. For database changes: do the queries and data look correct?
4. What could break in production?

Give your independent assessment. Don't just say "looks good."
```

## Cost Awareness

GPT-5.4 is pay-per-use. Don't invoke Codex for tasks Claude handles well:
- Large codebase refactoring (Claude's context window wins)
- Multi-file changes (Claude's subagents win)
- MCP-connected services (only Claude has access)
- Architecture decisions needing full codebase context

## Examples

**User:** "search for the latest React 19 features"
```bash
bash ~/.claude/hooks/codex-delegate.sh research "latest React 19 features" --timeout 60
```

**User:** "codex review my changes"
```bash
bash ~/.claude/hooks/codex-delegate.sh review "" --search --cwd "$(pwd)"
```

**User:** "get codex's opinion on this architecture"
```bash
bash ~/.claude/hooks/codex-delegate.sh compare "Review the architecture — is the service layer properly separated?" --search --cwd "$(pwd)"
```

**User:** "codex fix the flaky test in auth.test.ts"
```bash
bash ~/.claude/hooks/codex-delegate.sh exec "Fix the flaky test in auth.test.ts" --sandbox workspace-write --cwd "$(pwd)"
```

## Justfile Shortcuts

Users can also invoke via justfile:
- `just codex "prompt"` — quick exec
- `just codex_write "prompt"` — exec with write access
- `just codex_review` — review uncommitted changes
- `just codex_review_branch main` — review against branch
- `just codex_research "topic"` — web research
- `just codex_compare "question"` — second opinion
- `just codex_verify "task summary"` — run the `claude-work-verifier` flow
- `just codex_verify_artifacts "artifact summary"` — run the `artifact-verifier` flow
- `just codex_audit_handoff .claude/handoff.md` — run the `handoff-auditor` flow
- `just codex_ground_truth_audit "scope"` — run the `ground-truth-coverage` flow
- `just codex_status` — check install and config

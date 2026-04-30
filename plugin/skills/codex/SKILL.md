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

For this workflow, default to **read-only verification** first. Use Codex
as an independent auditor before using it as an implementer.

## Subcommands

| Subcommand | When to use | Example |
|------------|-------------|---------|
| `exec` | General task delegation | `/codex fix the nginx 502 error` |
| `review` | Code review (second opinion) | `/codex review` |
| `adversarial-review` | Structured adversarial review (JSON with severity/confidence) | `/codex adversarial-review` |
| `research` | Web search / current events | `/codex research latest Node LTS` |
| `compare` | Get Codex's independent take, then synthesize | `/codex compare is this schema normalized?` |
| `status` | Check background Codex job status | `/codex status` |
| `cancel` | Cancel a running background job | `/codex cancel <id>` |
| `result` | Get output from a completed background job | `/codex result <id>` |

## Steps

1. **Parse the user's intent** — determine which subcommand fits:
   - Web/current events → `research`
   - Code review (free text) → `review`
   - Code review (structured/automated triage) → `adversarial-review`
   - Second opinion → `compare`
   - Background job management → `status` / `cancel` / `result`
   - Everything else → `exec`

2. **Invoke the wrapper script** via Bash tool:

   ```bash
   bash ~/.claude/hooks/codex-delegate.sh <subcommand> "<prompt>" [flags]
   ```

   Available flags:
   - `--timeout N` — seconds (default 300)
   - `--sandbox MODE` — `read-only` (default) or `workspace-write`
   - `--cwd DIR` — working directory
   - `--output FILE` — custom output path
   - `--worktree` — run in isolated git worktree
   - `--search` — enable live web search (for review, compare, exec)
   - `--background` — fork to background, return job ID (use `status`/`result` to check)

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

## Adversarial Review

The `adversarial-review` subcommand produces structured JSON output using Codex's
`--output-schema` flag. The output schema:

```json
{
  "verdict": "approve" | "needs-attention",
  "summary": "terse ship/no-ship assessment",
  "findings": [{
    "severity": "critical|high|medium|low",
    "title": "short title",
    "body": "what can go wrong and why",
    "file": "path/to/file",
    "line_start": 42,
    "line_end": 50,
    "confidence": 0.0-1.0,
    "recommendation": "concrete fix"
  }]
}
```

**When to use adversarial-review vs review:**

- Use `review` for quick, human-readable feedback
- Use `adversarial-review` for automated workflows (wrap-up, SDD) where
  findings need programmatic triage by severity and confidence

**Triage rules for adversarial-review findings:**

- `critical` or `high` with confidence >= 0.7 → fix now
- `medium` with confidence >= 0.8 → fix if quick
- `low` or confidence < 0.5 → dismiss with reasoning
- Always present the full JSON to the user alongside the triage

## Background Jobs

Any subcommand can run in background with `--background`:

```bash
bash ~/.claude/hooks/codex-delegate.sh exec "fix the test" --background
# Returns: job ID

bash ~/.claude/hooks/codex-delegate.sh status
# Lists all jobs with status

bash ~/.claude/hooks/codex-delegate.sh result <job-id>
# Returns output from completed job

bash ~/.claude/hooks/codex-delegate.sh cancel <job-id>
# Kills a running job
```

Job metadata stored at `~/.codex/jobs/<id>.json`.

## Auto-Invocation (by subagent-driven-development)

When subagent-driven-development completes all review stages for a task
(spec → code quality → data verification), it auto-invokes Codex as a final
cross-model check before moving to the next task.

**Auto-invocation uses `adversarial-review` with `--search`** for structured
triage at phase boundaries. Falls back to `compare` mode for user-triggered
second opinions.

**Also auto-invoked by `/wrap-up` Phase 2** — runs `adversarial-review --search`
on all session changes before committing. Claude triages findings using the
structured JSON: critical/high → fix, medium → fix if quick, low → dismiss.

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
- `just codex_adversarial_review` — structured adversarial review (JSON)
- `just codex_adversarial_review_branch main` — adversarial review against branch
- `just codex_research "topic"` — web research
- `just codex_compare "question"` — second opinion
- `just codex_bg "prompt"` — run task in background
- `just codex_jobs` — list background jobs
- `just codex_result <id>` — get background job output
- `just codex_cancel <id>` — cancel a background job
- `just codex_verify "task summary"` — run the `claude-work-verifier` flow
- `just codex_verify_artifacts "artifact summary"` — run the `artifact-verifier` flow
- `just codex_audit_handoff .claude/handoff.md` — run the `handoff-auditor` flow
- `just codex_ground_truth_audit "scope"` — run the `ground-truth-coverage` flow
- `just codex_status` — check install and config

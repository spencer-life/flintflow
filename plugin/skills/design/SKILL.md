---
name: design
description: Idea-to-implementation pipeline. Interviews the user about their idea,
  researches libraries/APIs/patterns, designs architecture, generates a structured
  plan, then auto-transitions to /project-init (if new project) and /subagent-driven-development.
  Use when user says "I want to build", "let's build", "let's create", "I have an idea",
  "new project", "design this", "plan this out", "what if we built", or invokes /design.
  Do NOT trigger for bug fixes, quick tweaks, or questions about existing code.
---

# Design — Idea to Implementation

Take a raw idea and produce a researched, architected, user-approved plan — then
seamlessly transition into building it. This is the front door to the entire
flintflow workflow.

**NEVER write code during /design.** This skill produces a plan, not an implementation.

---

## Phase 1: Discovery Interview

Structured conversation to understand the idea before researching anything.
Adapt questions based on answers — skip what's already clear, dig deeper on
ambiguity. Don't dump all questions at once; conversational flow across 2-3 rounds.

### Round 1 — The What
- What's the idea? (one sentence)
- What problem does it solve? Who uses it?
- Does this build on existing code or start fresh?

### Round 2 — The Constraints
- Tech stack preferences? (or "whatever works best")
- Existing services to integrate with? (DB, APIs, auth)
- Timeline/scope: MVP or full feature?
- Any hard requirements? (must use X, can't use Y)

### Round 3 — The Shape
- What does "done" look like? (success criteria)
- Must-haves vs nice-to-haves?
- Any prior art or inspiration? (links, screenshots, similar tools)

**When to stop interviewing:** You have enough to research when you know the
what, who, stack, and success criteria. Don't over-interview — move to research.

---

## Phase 2: Research

Full research using all available tools. **PARALLEL DISPATCH IS MANDATORY.**
This phase is critical — never skip it, even for "simple" ideas.

### Parallel Research Dispatch

Dispatch these as parallel Agent calls in a SINGLE message:

**Agent 1 — Context7 Docs:**
Pull fresh documentation for every library, framework, and API mentioned in the
interview. Even ones you "know" — always pull current docs via Context7.

Version check (if building on existing code):
- Check installed versions first: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`
- Pull docs for the INSTALLED version, not just "latest"
- If the installed version is significantly behind current, note it
- If breaking changes exist between installed and current, flag explicitly

**Agent 2 — Web Search:**
- How do people typically build this?
- Best libraries/tools for the job in the chosen stack
- Known pitfalls and gotchas
- Existing open-source implementations to learn from

**Agent 3 — Codebase Exploration (if building on existing code):**
- Dispatch Explore agent to understand current architecture
- Find reusable patterns, utilities, abstractions
- Identify integration points and potential conflicts

Wait for all three to return, then synthesize results before moving to Phase 3.

### Optional Follow-Up (dispatch separately if needed)

**NotebookLM Deep Research** (if complex domain):
For unfamiliar domains, regulations, or complex integrations:
- Create notebook with relevant sources
- Run deep research query via `nlm research start`
- Skip for straightforward technical tasks

**Codex Second Opinion** (if architecture is non-obvious):
- Ask Codex: "Given {requirements}, what's the best architecture for X?"
- Compare Claude's instinct vs Codex's recommendation
- Flag disagreements for user decision

### Present Research Summary

Before moving to architecture, present findings to the user:

```
## Research Summary

### Libraries/Tools Evaluated
| Option | Pros | Cons | Docs Reviewed |
|--------|------|------|---------------|
| {lib}  | ...  | ...  | Context7 ✓    |

### Existing Code to Reuse
- {file}: {pattern/utility} — reusable for {purpose}

### Key Findings
- {insight from research}

### Risks/Gotchas Discovered
- {pitfall to avoid}
```

Pause for user feedback. They may redirect the research or confirm the direction.

---

## Phase 3: Architecture Design

Present 1-2 architecture options. Not 5 — decision fatigue is real.
Lead with the recommended approach.

```
## Recommended Architecture

### Overview
{One-paragraph summary of the approach}

### Stack
- Frontend: {choice + why}
- Backend: {choice + why}
- Database: {choice + why}
- Deployment: {choice + why}

### Data Flow
{How data moves through the system — brief description or simple diagram}

### Key Decisions
| Decision | Choice | Why | Alternatives Considered |
|----------|--------|-----|------------------------|

### File Structure
{Proposed directory layout}
```

If there's a meaningful alternative approach, present it briefly with tradeoffs.
Let the user choose. Record decisions (these feed into PROJECT_STATE.md later).

---

## Phase 4: Plan Generation

Generate a structured task plan that `/subagent-driven-development` can consume
directly. This is the output of `/design`.

```
## Implementation Plan

### Tasks (ordered by dependency)
1. **{Task name}** — {description}
   - Files: {files to create/modify}
   - Dependencies: {what must exist first, or "none"}
   - Touches DB: {yes/no}
   - Verification: {how to prove this works}

2. **{Task name}** — {description}
   - Files: ...
   - Dependencies: Task 1
   - Touches DB: ...
   - Verification: ...

### Smoke Test Strategy
{What checks should smoke_test.sh include for this project}

### Verification Strategy
{What ground-truth values to add to VERIFICATION.md, if data-backed}

### Estimated Scope
{task count, rough complexity: small/medium/large}
```

---

## Phase 5: Approve & Transition

Present the complete plan to the user for approval.

**After user approves:**

### If PROJECT_STATE.md does NOT exist (new project):
1. Auto-invoke `/project-init` — pass along the design context (stack, DB,
   external services, data sources) so project-init can scaffold accurate docs
   without re-asking questions the user already answered
2. After project-init completes, scaffold `smoke_test.sh` from the plan's
   smoke test strategy (if project-init didn't already create one)
3. Auto-transition to `/subagent-driven-development` with the generated plan

### If PROJECT_STATE.md exists (existing project):
1. Update PROJECT_STATE.md with the new work stream from this design
2. If `smoke_test.sh` doesn't exist, scaffold it from the plan
3. Auto-transition to `/subagent-driven-development` with the generated plan

**No manual copy-paste needed** — the plan is already in the format SDD expects.

---

## Rules

- **NEVER write code** during /design. Plan only.
- **NEVER skip research.** Even "obvious" ideas benefit from doc pulls and web search.
- **Present research before designing.** User should see what you found before
  you propose architecture.
- **1-2 architecture options max.** Lead with the recommendation.
- **Conversational interview.** Don't dump 15 questions. Adapt and flow.
- **Record decisions.** Architecture decisions feed into PROJECT_STATE.md.
- **Auto-transition is seamless.** User approves plan → project-init (if needed)
  → SDD starts. No manual skill invocation between steps.

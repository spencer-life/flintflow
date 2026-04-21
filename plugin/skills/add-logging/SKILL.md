---
name: add-logging
description: Audit a deployed service for error-logging gaps and add missing handlers. Covers Node/Discord/Express/Next.js/Supabase Edge/Python workers. Use when user says "add logging", "audit logging", "check error handling", "add error handlers", or invokes /add-logging. Also useful proactively when editing a file in a deployed service that lacks comprehensive error logging.
---

# Add Logging

Audit and add comprehensive error logging to a deployed service so failures
surface instead of dying silently. Applies the checklist from
`~/.claude/rules/quality-standards.md`.

## When to use

- User asks to add/check/audit logging
- Editing a deployed service (Discord bot, Railway API, Edge Function, webhook,
  underwriting bot, etc.) and noticing missing error handling
- Post-incident: errors happened in production that weren't logged usefully

## When NOT to use

- Local-only scripts / tools (no production blast radius)
- UI components (error boundaries are a frontend concern; use error.tsx directly)
- Pure data-processing scripts with no live endpoints

## Audit checklist per stack

### Node.js (any service)
- `process.on('unhandledRejection', ...)` — catches orphaned promise rejections
- `process.on('uncaughtException', ...)` — catches synchronous throws outside try/catch
- try/catch around every async handler (route, listener, scheduler)
- Error objects logged with context: WHAT failed, WHERE (function/file), WHY (message + stack)
- Never `console.error(e)` alone — always include context

### Discord bots
- `client.on('error', ...)` — gateway errors
- `client.on('warn', ...)` — non-fatal issues worth seeing
- Shard `error` / `disconnect` / `reconnecting` listeners (for multi-shard bots)
- `client.login(token).catch(err => ...)` — auth failure visibility
- Command handlers wrapped in try/catch; user-facing error reply + log

### Express / API routes
- Global error middleware (`app.use((err, req, res, next) => ...)`)
- Every route handler wrapped in try/catch, or async wrapper pattern
- Log route + method + params + user (if auth'd) + error
- Return proper status codes (500 for unexpected, 4xx for client errors)
- Body size limits configured (`express.json({ limit: '...' })`) — prevents DoS

### Next.js
- `error.tsx` boundary in every app/ segment
- API route handlers wrapped in try/catch
- Server-side logs include request ID / route for traceability

### Supabase Edge Functions
- Wrap entire handler body in try/catch
- Log includes function name + request context (method, URL, headers summary)
- Return proper HTTP status codes in the error branch

### Python (FastAPI/Flask workers)
- Global exception handler registered
- Every route/task wrapped in try/except
- Logging via `logging` module with appropriate levels (ERROR for failures, WARNING for recoverable, INFO for lifecycle)
- Structured context in log messages (dict extra= for JSON logs)

## Process

1. **Identify the stack** — read package.json, requirements.txt, or deno.json
   to determine what's running
2. **Read the main entry file(s)** — bot.ts, index.ts, app.py, main.py, or
   the Supabase function handler
3. **Check against the stack-specific checklist above**
4. **List gaps** — say what's missing before editing. Short list, not prose.
5. **Add the missing handlers** — each in minimal idiomatic form. Don't
   over-engineer; match the existing code style.
6. **Verify** — if tests exist, run them. If not, at least lint/typecheck.

## Integration with other flintflow tools

- `logging-nudge.sh` hook: injects the same checklist when keywords are
  detected in user prompts — this skill is the proactive audit counterpart.
- `/design` and `/project-init`: should scaffold logging handlers into new
  services from the start (future enhancement).
- `/data-verify`: pairs well — after adding logging, verify data still flows
  correctly and errors are being captured on failure paths.

## Output to user

After audit, give:
1. One-line summary: "Found N gaps. Fixed X, left Y for your review (listed below)."
2. Diff of what was added (let format-and-lint hook clean up formatting)
3. Callout for anything that needs human judgment (custom error reporting,
   alerting destinations, etc.)

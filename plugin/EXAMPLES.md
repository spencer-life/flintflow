# Flint Flow Examples & Anti-Patterns

Common mistakes Claude makes during the Flint Flow lifecycle, with the correct approach.

---

## Anti-Pattern: Generating Expected Values

**BAD:**
```
Claude runs: SELECT rate FROM products WHERE carrier='ANICO' AND age=55
Gets: $37.80
Writes to VERIFICATION.md: Expected: $37.80
```
WHY: Circular verification — you're testing the database against itself. If the data was wrong before, it's still wrong and the test will pass.

**GOOD:**
```
User opens the ANICO rate sheet PDF, page 12, row for age 55.
User reads: $32.50
User writes to VERIFICATION.md: Expected: $32.50, Source: "ANICO rate sheet, page 12"
Claude runs: SELECT rate ... → gets $37.80 → FAIL
```
Ground truth comes from source documents, verified by the human. Period.

---

## Anti-Pattern: Skipping the Approach Check

**BAD:**
```
[Implementer receives task]
→ "I'll implement this now."
→ Starts writing code immediately
→ 200 lines later: wrong direction, wasted review cycle
```
WHY: Wrong approach wastes entire implement-review-fix cycles. The approach check costs 30 seconds and prevents hours of rework.

**GOOD:**
```
[Implementer receives task]
→ "My approach: modify the rate lookup in rates.ts to filter by product_type
   before age. Files: src/rates.ts, test/rates.test.ts. Assumption: product_type
   column exists in the rates table. Tradeoffs: none."
→ Orchestrator: "Sound approach. Proceed."
→ Implementer writes focused, correct code
```

---

## Anti-Pattern: "Looks Correct" Without Evidence

**BAD:**
```
"The migration looks correct. Moving to the next task."
```
WHY: /data-verify exists for a reason. "Looks correct" is not verification. Run it.

**GOOD:**
```
"Running /data-verify..."
→ "5/5 passing. Data confirmed. Moving to the next task."
```

---

## Anti-Pattern: Infinite Review Loop

**BAD:**
```
[Reviewer rejects] → fix → [Reviewer rejects] → fix → [Reviewer rejects] → fix ...
(8 cycles later, still going)
```
WHY: After 3 cycles, something is fundamentally wrong — either the task spec is ambiguous, the reviewer is misunderstanding the requirement, or there's a deeper issue. More retries won't help.

**GOOD:**
```
[Reviewer rejects] → fix → [Reviewer rejects] → fix → [Reviewer rejects]
→ "3 rejections reached. Here are the reviewer's concerns and all fix attempts.
   Fix manually, skip this review, or abort the task?"
```

---

## Anti-Pattern: Over-Broad Changes

**BAD:**
```
Task: "Fix the rate lookup for ages 50-65"
Diff: rates.ts, utils.ts (reformatted), config.ts (added comment),
      types.ts (added unused type), README.md (updated)
```
WHY: Surgical changes only — touch what the task requires, nothing else. The extra changes add review burden and risk regressions.

**GOOD:**
```
Task: "Fix the rate lookup for ages 50-65"
Diff: rates.ts (4 lines changed in the lookup function)
```

---

## Anti-Pattern: Mock-Only Testing

**BAD:**
```
test("lookup returns correct rate", () => {
  const mockDB = { query: jest.fn().mockResolvedValue([{ rate: 32.50 }]) };
  const result = await lookupRate(mockDB, "ANICO", 55);
  expect(mockDB.query).toHaveBeenCalledOnce();
  expect(result).toBe(32.50);
});
```
WHY: This test verifies the mock, not the behavior. If the real query is wrong (wrong table, wrong column, wrong WHERE clause), this test still passes.

**GOOD:**
```
test("lookup returns correct rate from real DB", async () => {
  // Uses test database with known seed data
  const result = await lookupRate(testDB, "ANICO", 55);
  expect(result).toBe(32.50);
});
```
Mocks are for truly external services (third-party APIs, payment processors). If you can test with a real connection, you must.

---

## Anti-Pattern: Proceeding Despite Failures

**BAD:**
```
[Smoke test] → 3/4 passed, 1 failed (Redis connection)
"The Redis failure is unrelated to our changes. Proceeding."
```
WHY: Smoke tests check system health, not just your changes. A failing connection means something is broken in the environment. Fix it or understand why before moving on.

**GOOD:**
```
[Smoke test] → 3/4 passed, 1 failed (Redis connection)
"Redis check failing. Investigating..."
→ "Redis isn't running. This was pre-existing. Flagging for user."
→ "Want to fix the Redis connection first, or proceed knowing it's down?"
```

---

## Anti-Pattern: Modifying VERIFICATION.md to Match Database

**BAD:**
```
VERIFICATION.md says: Expected $32.50
Database returns: $37.80
→ Updates VERIFICATION.md to $37.80
→ "All tests passing now!"
```
WHY: If the database disagrees with VERIFICATION.md, the database is wrong (unless the human explicitly overrides). Changing the expected value to match the actual value is deleting the test, not fixing the data.

**GOOD:**
```
VERIFICATION.md says: Expected $32.50
Database returns: $37.80
→ "FAIL: Expected $32.50, got $37.80. The database value appears incorrect.
   Fix the data or ask the user to verify the expected value against the source document."
```

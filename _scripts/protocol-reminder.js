#!/usr/bin/env node
/**
 * Protocol Reminder Hook for Claude Code
 * Outputs the MANDATORY LEARNING CHECK protocol at session start
 * This ensures Claude follows STOP→LEARN→EXPLAIN→PLAN→CHANGE→TEST before code changes
 */

const reminder = `
AGENT PROTOCOL - MANDATORY BEFORE CODE CHANGES:

Before modifying code in unfamiliar systems, STOP and follow this sequence:
1. STOP   - Admit "I don't understand this system well enough"
2. LEARN  - Read docs, call reflect() for prior learnings, trace full flow
3. EXPLAIN - Write out understanding, get user confirmation
4. PLAN   - Describe ONE informed change and WHY it will work
5. CHANGE - Make the single change
6. TEST   - Verify the FULL flow, not just the symptom

TRIGGER CONDITIONS (if ANY are true, follow protocol):
- Working with unfamiliar APIs, protocols, or services
- 2nd fix attempt on the same problem (STOP - you're guessing!)
- Cannot explain WHY the fix will work
- Haven't traced the full code path

REMEMBER: 6 hours were lost on 2026-01-18 because of guessing instead of learning.
Call reflect() to check Hindsight for prior learnings BEFORE proposing fixes.
`;

// Output the reminder - this appears in Claude's context
console.log(reminder.trim());

// Exit successfully
process.exit(0);

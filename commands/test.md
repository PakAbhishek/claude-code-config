---
description: Comprehensive testing - unit, integration, system, and UAT
argument-hint: [optional: specific file or feature to test]
allowed-tools:
  - Task
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - TodoWrite
---

# Comprehensive Test Suite

Run a full testing pyramid for this codebase:

## Testing Levels

1. **Unit Tests** - Test individual functions/methods in isolation
2. **Integration Tests** - Test component interactions and API contracts
3. **System Tests** - Test end-to-end workflows
4. **User Acceptance Tests** - Validate requirements are met from user perspective

## Instructions

1. First, enter **Plan Mode** to design the test strategy
2. Identify existing test infrastructure (test frameworks, config, existing tests)
3. Determine what needs testing based on: $ARGUMENTS
4. Use the **qa-test-engineer** agent for comprehensive test execution
5. Use the **requirements-guardian** agent for UAT validation
6. Create a test report summarizing:
   - Tests run at each level
   - Pass/fail results
   - Coverage gaps identified
   - Recommendations

## Focus Area
$ARGUMENTS

If no specific focus provided, analyze recent changes and test accordingly.

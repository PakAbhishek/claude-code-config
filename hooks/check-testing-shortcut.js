#!/usr/bin/env node
/**
 * PreToolUse Hook for Bash - Testing Shortcut Blocker
 *
 * This hook fires BEFORE Bash commands and blocks direct test execution
 * when needsTesting flag is set, forcing use of qa-test-engineer agent instead.
 *
 * Prevents circumvention of SDLC by running tests manually instead of through agents.
 */

const enforcementState = require('./enforcement-state.js');

// Test command patterns - catches various test execution methods
// IMPORTANT: Includes both Unix AND Windows/PowerShell patterns
const TEST_COMMAND_PATTERNS = [
    // === UNIX/BASH TEST PATTERNS ===
    /\bbash\s+.*tests?\//i,              // bash tests/... or bash test/...
    /\bsh\s+.*tests?\//i,                // sh tests/...
    /\b\.\/run[_-]?tests?\.sh/i,         // ./run_test.sh or ./run_tests.sh
    /\b\.\/test/i,                       // ./test or ./test.sh

    // === WINDOWS/POWERSHELL TEST PATTERNS ===
    /\bpowershell\b.*\btest/i,           // powershell ... test (any test-related ps1)
    /\bpowershell\b.*\bvalidate/i,       // powershell ... validate (validation scripts)
    /\bpwsh\b.*\btest/i,                 // pwsh ... test (PowerShell Core)
    /\bpwsh\b.*\bvalidate/i,             // pwsh ... validate
    /\bInvoke-Pester\b/i,                // Pester test framework
    /\btest-.*\.ps1/i,                   // test-*.ps1 scripts
    /\bvalidate-.*\.ps1/i,               // validate-*.ps1 scripts
    /\b.*-test\.ps1/i,                   // *-test.ps1 scripts
    /\b.*-tests\.ps1/i,                  // *-tests.ps1 scripts
    /\b.*\.tests\.ps1/i,                 // *.tests.ps1 (Pester convention)
    /\brun[_-]?tests?\.ps1/i,            // run_tests.ps1, run-tests.ps1
    /\brun[_-]?tests?\.bat/i,            // run_tests.bat
    /\brun[_-]?tests?\.cmd/i,            // run_tests.cmd

    // === CROSS-PLATFORM PACKAGE MANAGERS ===
    /\bnpm\s+(run\s+)?test/i,            // npm test or npm run test
    /\byarn\s+test/i,                    // yarn test
    /\bpnpm\s+test/i,                    // pnpm test

    // === PYTHON ===
    /\bpytest\b/i,                       // pytest
    /\bpython\s+-m\s+pytest/i,           // python -m pytest
    /\bpython\s+-m\s+unittest/i,         // python -m unittest
    /\bpy\s+-m\s+pytest/i,               // py -m pytest (Windows py launcher)
    /\bpy\s+-m\s+unittest/i,             // py -m unittest

    // === OTHER LANGUAGES ===
    /\bgo\s+test/i,                      // go test
    /\bcargo\s+test/i,                   // cargo test
    /\bmvn\s+test/i,                     // mvn test
    /\bgradle\s+test/i,                  // gradle test
    /\bdotnet\s+test/i,                  // dotnet test (.NET)
    /\bvstest\.console/i,                // Visual Studio Test Console
    /\bmstest/i,                         // MSTest
    /\bnunit/i,                          // NUnit
    /\bxunit/i,                          // xUnit

    // === JAVASCRIPT TEST RUNNERS ===
    /\bjest\b/i,                         // jest
    /\bmocha\b/i,                        // mocha
    /\bvitest\b/i,                       // vitest
    /\bava\b/i,                          // ava
    /\btap\b/i,                          // tap
];

// Exempt patterns - reading/viewing test files is OK, not execution
// IMPORTANT: Includes both Unix AND Windows patterns
const EXEMPT_PATTERNS = [
    // === UNIX/BASH READ PATTERNS ===
    /\bcat\s+.*tests?\//i,               // Reading test files
    /\bless\s+.*tests?\//i,              // Viewing test files
    /\bmore\s+.*tests?\//i,              // Viewing test files
    /\bhead\s+.*tests?\//i,              // Viewing test files
    /\btail\s+.*tests?\//i,              // Viewing test files
    /\bgrep\s+.*tests?\//i,              // Searching test files
    /\bfind\s+.*tests?\//i,              // Finding test files
    /\bls\s+.*tests?\//i,                // Listing test directory
    /\bfile\s+.*tests?\//i,              // File type check
    /\bstat\s+.*tests?\//i,              // File stats

    // === WINDOWS/POWERSHELL READ PATTERNS ===
    /\btype\s+.*test/i,                  // Windows type command (like cat)
    /\bGet-Content\b.*test/i,            // PowerShell Get-Content
    /\bgc\s+.*test/i,                    // PowerShell gc alias
    /\bSelect-String\b.*test/i,          // PowerShell grep equivalent
    /\bdir\s+.*test/i,                   // Windows dir command
    /\bGet-ChildItem\b.*test/i,          // PowerShell ls equivalent
    /\bgci\s+.*test/i,                   // PowerShell gci alias
    /\bGet-Item\b.*test/i,               // PowerShell file info
    /\bTest-Path\b.*test/i,              // PowerShell path check (reading, not running)
];

// Read stdin for tool input
async function readStdin() {
    return new Promise((resolve) => {
        let data = '';
        process.stdin.setEncoding('utf8');

        process.stdin.on('readable', () => {
            let chunk;
            while ((chunk = process.stdin.read()) !== null) {
                data += chunk;
            }
        });

        process.stdin.on('end', () => {
            resolve(data);
        });

        // Timeout fallback
        setTimeout(() => {
            if (!data) resolve('{}');
        }, 100);
    });
}

// Check if command is a test execution command
function isTestCommand(command) {
    if (!command) return false;

    // Don't block if just reading/viewing
    if (EXEMPT_PATTERNS.some(p => p.test(command))) {
        return false;
    }

    // Check if it's a test execution command
    return TEST_COMMAND_PATTERNS.some(p => p.test(command));
}

async function main() {
    try {
        const input = await readStdin();
        let toolInput = {};

        try {
            toolInput = JSON.parse(input);
        } catch {
            // Not valid JSON, allow
            process.exit(0);
        }

        // Claude Code sends tool_input nested inside the hook input
        const command = toolInput.tool_input?.command || toolInput.command || '';

        // Check if this is a test command
        if (!isTestCommand(command)) {
            process.exit(0); // Allow non-test commands
        }

        // Load enforcement state
        const state = enforcementState.loadState();

        // Block if testing is needed
        if (state.needsTesting && state.editsSinceTest > 0) {
            console.log('');
            console.log('╔══════════════════════════════════════════════════════════════╗');
            console.log('║      🚫 TESTING BLOCKED - MUST USE QA AGENT 🚫              ║');
            console.log('╚══════════════════════════════════════════════════════════════╝');
            console.log('');
            console.log(`❌ Test command blocked: ${command.substring(0, 60)}`);
            console.log('');
            console.log('┌─────────────────────────────────────────────────────────────┐');
            console.log('│              SDLC ENFORCEMENT: QA AGENT REQUIRED            │');
            console.log('├─────────────────────────────────────────────────────────────┤');
            console.log('│                                                             │');
            console.log(`│  You have ${state.editsSinceTest} edits since last test run.              │`);
            console.log('│  Direct test execution is blocked.                          │');
            console.log('│                                                             │');
            console.log('│  Why this restriction exists:                              │');
            console.log('│  • qa-test-engineer ensures comprehensive test coverage    │');
            console.log('│  • Agent validates tests across all pyramid levels         │');
            console.log('│  • Agent provides proper test reporting and analysis       │');
            console.log('│  • Prevents shortcuts and incomplete testing               │');
            console.log('│                                                             │');
            console.log('│  To run tests, invoke:                                     │');
            console.log('│                                                             │');
            console.log('│    Task(subagent_type="qa-test-engineer")                  │');
            console.log('│                                                             │');
            console.log('│  The agent will:                                           │');
            console.log('│  1. Analyze what testing is needed                         │');
            console.log('│  2. Run appropriate tests at all levels                    │');
            console.log('│  3. Verify results and report findings                     │');
            console.log('│  4. Clear the needsTesting flag on success                 │');
            console.log('│                                                             │');
            console.log('└─────────────────────────────────────────────────────────────┘');
            console.log('');

            process.exit(1); // Block the operation
        }

        // Allow if no testing needed
        process.exit(0);

    } catch (err) {
        // On error, don't block - fail open
        process.exit(0);
    }
}

main();

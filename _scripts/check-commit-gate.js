#!/usr/bin/env node
/**
 * PreToolUse Hook for Bash - Git Commit Gate
 *
 * This hook fires BEFORE Bash commands and checks if:
 * 1. The command is a git commit
 * 2. devops-guardian agent has been run (clears needsDevopsReview)
 * 3. Tests have been run if there are pending edits
 *
 * Part of the SDLC enforcement chain - ensures code review before commits.
 */

const fs = require('fs');
const path = require('path');

// File location
const STATE_FILE = path.join(process.env.USERPROFILE || process.env.HOME, '.claude', 'hooks', '.enforcement_state.json');

// Git commit patterns to detect
const GIT_COMMIT_PATTERNS = [
    /\bgit\s+commit\b/i,
    /\bgit\s+.*\s+commit\b/i,
];

// Git push patterns (also require review)
const GIT_PUSH_PATTERNS = [
    /\bgit\s+push\b/i,
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

        setTimeout(() => {
            if (!data) resolve('{}');
        }, 100);
    });
}

// Load enforcement state
function loadEnforcementState() {
    try {
        if (fs.existsSync(STATE_FILE)) {
            return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
        }
    } catch (err) {}
    return {
        editsSinceTest: 0,
        editsSinceDevopsReview: 0,
        needsTesting: false,
        needsDevopsReview: false,
        needsSecurityReview: false,
        securitySensitiveEdits: []
    };
}

// Check if command is a git commit
function isGitCommit(command) {
    return GIT_COMMIT_PATTERNS.some(pattern => pattern.test(command));
}

// Check if command is a git push
function isGitPush(command) {
    return GIT_PUSH_PATTERNS.some(pattern => pattern.test(command));
}

async function main() {
    try {
        const input = await readStdin();
        let toolInput = {};

        try {
            toolInput = JSON.parse(input);
        } catch {
            process.exit(0);
        }

        const command = toolInput.command || '';

        // Only check git commit and push commands
        const isCommit = isGitCommit(command);
        const isPush = isGitPush(command);

        if (!isCommit && !isPush) {
            // Not a commit/push command, allow
            process.exit(0);
        }

        const state = loadEnforcementState();
        const issues = [];

        // Check if devops review is needed
        if (state.needsDevopsReview && state.editsSinceDevopsReview > 0) {
            issues.push({
                type: 'devops',
                message: `${state.editsSinceDevopsReview} edits made without code review`,
                agent: 'devops-guardian'
            });
        }

        // Check if testing is needed (warning for commit, block for push)
        if (state.needsTesting && state.editsSinceTest > 0) {
            issues.push({
                type: 'testing',
                message: `${state.editsSinceTest} edits made without testing`,
                agent: 'qa-test-engineer'
            });
        }

        // Check if security review is needed
        if (state.needsSecurityReview && state.securitySensitiveEdits?.length > 0) {
            issues.push({
                type: 'security',
                message: `Security-sensitive files edited: ${state.securitySensitiveEdits.map(f => path.basename(f)).join(', ')}`,
                agent: 'elite-security-auditor'
            });
        }

        // If no issues, allow
        if (issues.length === 0) {
            console.log('');
            console.log('✅ Commit gate passed - all validations complete');
            console.log('');
            process.exit(0);
        }

        // Block commit/push with issues
        console.log('');
        console.log('╔══════════════════════════════════════════════════════════════╗');
        if (isCommit) {
            console.log('║        🚫 GIT COMMIT BLOCKED - REVIEW REQUIRED 🚫            ║');
        } else {
            console.log('║         🚫 GIT PUSH BLOCKED - REVIEW REQUIRED 🚫             ║');
        }
        console.log('╚══════════════════════════════════════════════════════════════╝');
        console.log('');
        console.log('Issues to resolve before committing:');
        console.log('');

        issues.forEach((issue, i) => {
            console.log(`  ${i + 1}. ${issue.message}`);
            console.log(`     → Run: ${issue.agent} agent`);
            console.log('');
        });

        console.log('┌─────────────────────────────────────────────────────────────┐');
        console.log('│                    COMMIT GATE ACTIVE                        │');
        console.log('├─────────────────────────────────────────────────────────────┤');
        console.log('│                                                             │');
        console.log('│  Before committing, run the required agents:               │');
        console.log('│                                                             │');
        console.log('│  • devops-guardian    - Code review & git hygiene          │');
        console.log('│  • qa-test-engineer   - Test your changes                  │');
        console.log('│  • elite-security-auditor - If security files changed      │');
        console.log('│                                                             │');
        console.log('│  This ensures quality code reaches the repository.         │');
        console.log('│                                                             │');
        console.log('└─────────────────────────────────────────────────────────────┘');
        console.log('');

        process.exit(1);

    } catch (err) {
        // On error, don't block
        process.exit(0);
    }
}

main();

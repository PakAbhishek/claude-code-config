#!/usr/bin/env node
/**
 * PreToolUse Hook for Bash - Git Operations Gate
 *
 * This hook fires BEFORE Bash commands and checks if:
 * 1. The command is a git operation (commit, push, merge, rebase, etc.)
 * 2. Required validation agents have been run
 * 3. Tests have been completed if code was edited
 *
 * ENHANCEMENT over check-commit-gate.js:
 * - Blocks ALL git operations (not just commit)
 * - Categorizes operations by risk level
 * - Shows specific requirements for each operation type
 */

const enforcementState = require('./enforcement-state.js');
const fs = require('fs');
const DEBUG_FILE = require('path').join(process.env.USERPROFILE || process.env.HOME, '.claude', 'hooks-state', 'git-ops-debug.json');

// All git operations that require review
const GIT_OPERATIONS = {
    commit: {
        patterns: [/\bgit\s+commit/i],
        blockedBy: ['needsDevopsReview'],
        message: 'Git commits require devops-guardian review'
    },
    push: {
        patterns: [/\bgit\s+push/i],
        blockedBy: ['needsDevopsReview', 'needsTesting'],
        message: 'Git push requires both testing and devops review'
    },
    merge: {
        patterns: [/\bgit\s+merge/i],
        blockedBy: ['needsDevopsReview', 'needsTesting'],
        message: 'Git merge requires testing and devops review'
    },
    rebase: {
        patterns: [/\bgit\s+rebase(?!\s+-i)/i, /\bgit\s+pull\s+--rebase/i],
        blockedBy: ['needsDevopsReview'],
        message: 'Git rebase operations require devops-guardian review'
    },
    cherryPick: {
        patterns: [/\bgit\s+cherry-pick/i],
        blockedBy: ['needsDevopsReview'],
        message: 'Cherry-pick operations require devops-guardian review'
    },
    tag: {
        patterns: [/\bgit\s+tag(?!\s+-l)/i],  // Creating tags, not listing
        blockedBy: ['needsDevopsReview'],
        message: 'Creating git tags requires devops-guardian review'
    }
};

// Safe git operations (read-only or informational)
const SAFE_GIT_PATTERNS = [
    /\bgit\s+status/i,
    /\bgit\s+log/i,
    /\bgit\s+diff/i,
    /\bgit\s+show/i,
    /\bgit\s+branch$/i,          // List branches only (no -D or -d)
    /\bgit\s+branch\s+-[lavr]/i, // Safe branch listing options
    /\bgit\s+remote\s+-v/i,      // List remotes
    /\bgit\s+remote$/i,          // List remotes
    /\bgit\s+fetch/i,            // Fetch is safe, doesn't modify working tree
    /\bgit\s+tag\s+-l/i,         // List tags
    /\bgit\s+ls-/i,              // ls-files, ls-remote, etc.
    /\bgit\s+config\s+--get/i,   // Read config only
    /\bgit\s+rev-parse/i,        // Parse revision
    /\bgit\s+describe/i,         // Describe commit
];

// Destructive operations that should always warn (even if checks pass)
const DESTRUCTIVE_GIT_PATTERNS = [
    /\bgit\s+push\s+.*--force/i,
    /\bgit\s+push\s+.*-f\b/i,
    /\bgit\s+reset\s+--hard/i,
    /\bgit\s+clean\s+-[dfx]/i,
    /\bgit\s+branch\s+-D/i,
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

// Analyze git command to determine safety and requirements
function analyzeGitCommand(command) {
    if (!command.toLowerCase().includes('git')) {
        return { isGit: false };
    }

    // Check if it's destructive (always warn)
    const isDestructive = DESTRUCTIVE_GIT_PATTERNS.some(p => p.test(command));

    // IMPORTANT: Check for DANGEROUS operations FIRST before safe ones
    // A command like "git status && git commit" contains BOTH safe and dangerous ops
    // We must block if ANY dangerous operation is present
    for (const [opName, opConfig] of Object.entries(GIT_OPERATIONS)) {
        if (opConfig.patterns.some(p => p.test(command))) {
            return {
                isGit: true,
                safe: false,
                operation: opName,
                blockedBy: opConfig.blockedBy,
                message: opConfig.message,
                destructive: isDestructive
            };
        }
    }

    // Only AFTER checking for dangerous ops, check if it's a safe-only operation
    if (SAFE_GIT_PATTERNS.some(p => p.test(command))) {
        return { isGit: true, safe: true };
    }

    // Unknown git command - be conservative, allow but warn
    return {
        isGit: true,
        safe: true,  // Allow unknown commands
        unknown: true
    };
}

// Get agent name from condition
function getRequiredAgent(condition) {
    const mapping = {
        needsTesting: 'qa-test-engineer',
        needsSecurityReview: 'elite-security-auditor',
        needsDevopsReview: 'devops-guardian'
    };
    return mapping[condition] || 'unknown';
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

        // Claude Code sends tool_input nested inside the hook input
        const command = toolInput.tool_input?.command || toolInput.command || '';

        // DEBUG: Log what we receive
        try {
            const state = enforcementState.loadState();
            fs.writeFileSync(DEBUG_FILE, JSON.stringify({
                timestamp: new Date().toISOString(),
                command: command,
                tool_input: toolInput.tool_input,
                needsDevopsReview: state.needsDevopsReview,
                needsTesting: state.needsTesting,
                editsSinceDevopsReview: state.editsSinceDevopsReview
            }, null, 2));
        } catch (e) {}

        // Analyze the command
        const analysis = analyzeGitCommand(command);

        if (!analysis.isGit || analysis.safe) {
            process.exit(0); // Allow non-git or safe git commands
        }

        // Unknown git command - allow with warning
        if (analysis.unknown) {
            console.log('⚠️  Warning: Unknown git command - proceeding without validation');
            process.exit(0);
        }

        // Load enforcement state
        const state = enforcementState.loadState();
        const blockingIssues = [];

        // Check each blocking condition
        for (const condition of analysis.blockedBy) {
            if (state[condition]) {
                const editCounter = condition.replace('needs', 'editsSince')
                    .replace('Review', '')
                    .replace('Testing', 'Test');

                blockingIssues.push({
                    condition,
                    edits: state[editCounter] || 0,
                    agent: getRequiredAgent(condition)
                });
            }
        }

        // Special warning for destructive operations (even if checks pass)
        if (analysis.destructive && blockingIssues.length === 0) {
            console.log('');
            console.log('╔══════════════════════════════════════════════════════════════╗');
            console.log('║        ⚠️  DESTRUCTIVE GIT OPERATION DETECTED ⚠️            ║');
            console.log('╚══════════════════════════════════════════════════════════════╝');
            console.log('');
            console.log(`❌ Command: ${command}`);
            console.log('');
            console.log('This is a destructive operation that may cause data loss.');
            console.log('Proceeding, but please ensure this is intentional.');
            console.log('');
            // Allow but warn
            process.exit(0);
        }

        if (blockingIssues.length === 0) {
            console.log('');
            console.log(`✅ ${analysis.operation} operation approved - all reviews complete`);
            console.log('');
            process.exit(0);
        }

        // Block with detailed error
        console.log('');
        console.log('╔══════════════════════════════════════════════════════════════╗');
        console.log(`║   🚫 GIT ${analysis.operation.toUpperCase()} BLOCKED - REVIEWS REQUIRED 🚫       ║`);
        console.log('╚══════════════════════════════════════════════════════════════╝');
        console.log('');
        console.log(`❌ Operation: ${analysis.message}`);
        console.log(`❌ Command: ${command.substring(0, 60)}`);
        console.log('');
        console.log('┌─────────────────────────────────────────────────────────────┐');
        console.log('│                GIT OPERATION GATE ACTIVE                    │');
        console.log('├─────────────────────────────────────────────────────────────┤');
        console.log('│                                                             │');
        console.log('│  Required actions before this git operation:               │');
        console.log('│                                                             │');

        blockingIssues.forEach((issue, i) => {
            const editsMsg = `${issue.edits} edits need review`.padEnd(37);
            console.log(`│  ${i + 1}. ${issue.condition.padEnd(25)}: ${editsMsg}│`);
            console.log(`│     → Invoke: Task(subagent_type="${issue.agent}")${' '.repeat(21 - issue.agent.length)}│`);
        });

        console.log('│                                                             │');
        console.log('│  This ensures quality code reaches the repository.         │');
        console.log('│                                                             │');
        console.log('└─────────────────────────────────────────────────────────────┘');
        console.log('');

        process.exit(1);

    } catch (err) {
        // On error, don't block - fail open
        process.exit(0);
    }
}

main();

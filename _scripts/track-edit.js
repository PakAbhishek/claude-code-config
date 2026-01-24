#!/usr/bin/env node
/**
 * PostToolUse Hook for Edit/Write - Edit Tracker
 *
 * This hook fires AFTER every Edit/Write operation to:
 * 1. Record the edit in enforcement state
 * 2. Set needsTesting flag
 * 3. Detect security-sensitive file edits
 * 4. Track edit count since last test
 *
 * Part of the SDLC enforcement chain.
 */

const fs = require('fs');
const path = require('path');

// Import enforcement state manager
const STATE_FILE = path.join(process.env.USERPROFILE || process.env.HOME, '.claude', 'hooks', '.enforcement_state.json');
const enforcementPath = path.join(process.env.USERPROFILE || process.env.HOME, '.claude', 'hooks', 'enforcement-state.js');

let enforcement;
try {
    enforcement = require(enforcementPath);
} catch (err) {
    // Fallback if module not found
    enforcement = null;
}

// Security-sensitive file patterns (fallback)
const SECURITY_SENSITIVE_PATTERNS = [
    /auth/i, /login/i, /password/i, /credential/i, /token/i,
    /secret/i, /crypto/i, /session/i, /permission/i, /oauth/i,
    /jwt/i, /api.?key/i, /payment/i, /\.env/i
];

function isSecuritySensitive(filePath) {
    if (!filePath) return false;
    return SECURITY_SENSITIVE_PATTERNS.some(pattern => pattern.test(filePath));
}

// Read stdin for tool output
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

// Load state directly (fallback)
function loadState() {
    try {
        if (fs.existsSync(STATE_FILE)) {
            return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
        }
    } catch (err) {}
    return {
        editsSinceTest: 0,
        editsSinceSecurityReview: 0,
        editsSinceDevopsReview: 0,
        needsTesting: false,
        needsSecurityReview: false,
        needsDevopsReview: false,
        securitySensitiveEdits: [],
        agentHistory: []
    };
}

// Save state directly (fallback)
function saveState(state) {
    try {
        fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
    } catch (err) {}
}

async function main() {
    try {
        const input = await readStdin();
        let toolData = {};

        try {
            toolData = JSON.parse(input);
        } catch {
            process.exit(0);
        }

        // Get the file path that was edited
        const filePath = toolData.file_path || toolData.filePath ||
                        toolData.tool_input?.file_path || toolData.tool_input?.filePath || '';

        if (!filePath) {
            process.exit(0);
        }

        // Skip tracking for hook files and exempt paths
        const exemptPatterns = [
            /\.claude[\\/]hooks[\\/]/,
            /\.edit_token\.json$/,
            /\.enforcement_state\.json$/,
            /[\\/]node_modules[\\/]/
        ];

        if (exemptPatterns.some(p => p.test(filePath))) {
            process.exit(0);
        }

        // Record the edit
        let state;
        if (enforcement) {
            state = enforcement.recordEdit(filePath);
        } else {
            // Fallback implementation
            state = loadState();
            state.editsSinceTest++;
            state.editsSinceDevopsReview++;
            state.lastEditTimestamp = new Date().toISOString();
            state.lastEditFile = filePath;
            state.needsTesting = true;
            state.needsDevopsReview = true;

            if (isSecuritySensitive(filePath)) {
                state.editsSinceSecurityReview++;
                state.needsSecurityReview = true;
                if (!state.securitySensitiveEdits) state.securitySensitiveEdits = [];
                if (!state.securitySensitiveEdits.includes(filePath)) {
                    state.securitySensitiveEdits.push(filePath);
                }
            }
            saveState(state);
        }

        // Output status
        console.log('');
        console.log(`📝 Edit tracked: ${path.basename(filePath)}`);
        console.log(`   Edits since last test: ${state.editsSinceTest}`);

        if (state.needsSecurityReview && isSecuritySensitive(filePath)) {
            console.log(`   ⚠️  Security-sensitive file detected!`);
        }

        // Warn if many edits without testing
        if (state.editsSinceTest >= 3) {
            console.log('');
            console.log('┌─────────────────────────────────────────────────────────┐');
            console.log('│  ⚠️  TESTING REMINDER: Multiple edits without testing   │');
            console.log('├─────────────────────────────────────────────────────────┤');
            console.log(`│  Edits since last test: ${state.editsSinceTest.toString().padEnd(29)}│`);
            console.log('│  Consider running qa-test-engineer agent soon.         │');
            console.log('└─────────────────────────────────────────────────────────┘');
        }

        if (state.needsSecurityReview && state.securitySensitiveEdits?.length > 0) {
            console.log('');
            console.log('┌─────────────────────────────────────────────────────────┐');
            console.log('│  🔒 SECURITY REVIEW NEEDED                              │');
            console.log('├─────────────────────────────────────────────────────────┤');
            console.log('│  Security-sensitive files edited:                       │');
            state.securitySensitiveEdits.slice(0, 3).forEach(f => {
                console.log(`│  • ${path.basename(f).substring(0, 49).padEnd(50)}│`);
            });
            console.log('│  Run elite-security-auditor before commit.             │');
            console.log('└─────────────────────────────────────────────────────────┘');
        }

        process.exit(0);

    } catch (err) {
        // Don't block on errors
        process.exit(0);
    }
}

main();

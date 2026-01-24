#!/usr/bin/env node
/**
 * PostToolUse Hook for Task Tool - Agent Completion Handler
 *
 * This hook fires AFTER every Task tool completion to:
 * 1. Generate edit tokens for Explore/Plan agents
 * 2. Clear testing flags for qa-test-engineer
 * 3. Clear security flags for elite-security-auditor
 * 4. Clear devops flags for devops-guardian
 * 5. Track all agent usage for audit
 *
 * SDLC Enforcement Chain:
 *   Explore/Plan → Edit → qa-test-engineer → devops-guardian → requirements-guardian
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// State files go in hooks-state (local), not hooks (synced via OneDrive)
const STATE_DIR = path.join(process.env.USERPROFILE || process.env.HOME, '.claude', 'hooks-state');
const TOKEN_FILE = path.join(STATE_DIR, 'edit_token.json');
const USAGE_LOG = path.join(STATE_DIR, 'agent_usage_log.json');
const STATE_FILE = path.join(STATE_DIR, 'enforcement_state.json');

// Ensure state directory exists
if (!fs.existsSync(STATE_DIR)) {
    fs.mkdirSync(STATE_DIR, { recursive: true });
}

// Agents that grant edit permission (pre-edit phase)
const EDIT_GRANTING_AGENTS = [
    'Explore',
    'Plan',
    'general-purpose'
];

// Agents that clear validation flags (post-edit phase)
const VALIDATION_AGENTS = {
    'qa-test-engineer': { clears: 'testing', message: '✅ Testing completed - edit gate reopened' },
    'elite-security-auditor': { clears: 'security', message: '✅ Security review completed' },
    'devops-guardian': { clears: 'devops', message: '✅ DevOps review completed - ready for commit' },
    'requirements-guardian': { clears: 'requirements', message: '✅ Requirements validated' }
};

// Token validity duration (minutes)
const TOKEN_VALIDITY_MINUTES = 30;

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

        // Handle case where stdin is empty
        setTimeout(() => {
            if (!data) resolve('{}');
        }, 100);
    });
}

// Generate edit token
function generateToken(agentType, taskDescription) {
    const tokenId = crypto.randomBytes(16).toString('hex');
    const now = new Date();

    return {
        id: tokenId,
        grantedBy: agentType,
        taskDescription: taskDescription || 'Agent task completed',
        createdAt: now.toISOString(),
        expiresAt: new Date(now.getTime() + TOKEN_VALIDITY_MINUTES * 60 * 1000).toISOString(),
        used: false,
        source: 'agent-completion'  // Marks this as agent-generated, not manual
    };
}

// Log agent usage for audit trail
function logAgentUsage(agentType, taskDescription, tokenId) {
    let log = [];

    try {
        if (fs.existsSync(USAGE_LOG)) {
            log = JSON.parse(fs.readFileSync(USAGE_LOG, 'utf8'));
        }
    } catch (err) {
        log = [];
    }

    log.push({
        timestamp: new Date().toISOString(),
        agentType,
        taskDescription,
        tokenGenerated: tokenId,
        grantedEditPermission: EDIT_GRANTING_AGENTS.includes(agentType)
    });

    // Keep last 100 entries
    if (log.length > 100) {
        log = log.slice(-100);
    }

    try {
        fs.writeFileSync(USAGE_LOG, JSON.stringify(log, null, 2));
    } catch (err) {
        // Non-critical, continue
    }
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
        editsSinceSecurityReview: 0,
        editsSinceDevopsReview: 0,
        needsTesting: false,
        needsSecurityReview: false,
        needsDevopsReview: false,
        securitySensitiveEdits: [],
        agentHistory: []
    };
}

// Save enforcement state
function saveEnforcementState(state) {
    try {
        fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
    } catch (err) {}
}

// Update enforcement state based on agent type
function updateEnforcementState(agentType, taskDescription) {
    const state = loadEnforcementState();

    // Add to agent history
    if (!state.agentHistory) state.agentHistory = [];
    state.agentHistory.push({
        agent: agentType,
        task: taskDescription,
        timestamp: new Date().toISOString()
    });
    if (state.agentHistory.length > 20) {
        state.agentHistory = state.agentHistory.slice(-20);
    }

    // Update flags based on agent type
    let statusMessage = null;

    if (agentType === 'qa-test-engineer') {
        state.editsSinceTest = 0;
        state.needsTesting = false;
        statusMessage = VALIDATION_AGENTS[agentType].message;
    } else if (agentType === 'elite-security-auditor') {
        state.editsSinceSecurityReview = 0;
        state.needsSecurityReview = false;
        state.securitySensitiveEdits = [];
        statusMessage = VALIDATION_AGENTS[agentType].message;
    } else if (agentType === 'devops-guardian') {
        state.editsSinceDevopsReview = 0;
        state.needsDevopsReview = false;
        statusMessage = VALIDATION_AGENTS[agentType].message;
    } else if (agentType === 'requirements-guardian') {
        state.requirementsValidated = true;
        state.requirementsValidatedAt = new Date().toISOString();
        statusMessage = VALIDATION_AGENTS[agentType].message;
    }

    saveEnforcementState(state);
    return { state, statusMessage };
}

// Main execution
async function main() {
    try {
        // Read tool output from stdin
        const input = await readStdin();
        let toolData = {};

        try {
            toolData = JSON.parse(input);
        } catch {
            // If we can't parse, exit silently (don't block)
            process.exit(0);
        }

        // Extract agent type from the tool call
        const agentType = toolData.subagent_type || toolData.tool_input?.subagent_type || '';
        const taskDescription = toolData.description || toolData.tool_input?.description || '';

        if (!agentType) {
            process.exit(0);
        }

        // Log all agent usage for audit
        const tempTokenId = crypto.randomBytes(8).toString('hex');
        logAgentUsage(agentType, taskDescription,
            EDIT_GRANTING_AGENTS.includes(agentType) ? tempTokenId : 'none');

        // Update enforcement state for ALL agents
        const { state, statusMessage } = updateEnforcementState(agentType, taskDescription);

        // Handle validation agents (post-edit phase)
        if (VALIDATION_AGENTS[agentType]) {
            console.log('');
            console.log('╔══════════════════════════════════════════════════════════════╗');
            console.log('║            📋 VALIDATION AGENT COMPLETED                     ║');
            console.log('╚══════════════════════════════════════════════════════════════╝');
            console.log('');
            console.log(`🤖 Agent: ${agentType}`);
            console.log(`📝 Task: ${taskDescription}`);
            console.log(`${statusMessage}`);
            console.log('');

            // Show current state summary
            if (state.needsTesting || state.needsSecurityReview || state.needsDevopsReview) {
                console.log('Remaining validations needed:');
                if (state.needsTesting) console.log('  • qa-test-engineer (testing)');
                if (state.needsSecurityReview) console.log('  • elite-security-auditor (security)');
                if (state.needsDevopsReview) console.log('  • devops-guardian (before commit)');
                console.log('');
            } else {
                console.log('✨ All validations complete! Ready for commit.');
                console.log('');
            }

            process.exit(0);
        }

        // Handle edit-granting agents (pre-edit phase)
        if (EDIT_GRANTING_AGENTS.includes(agentType)) {
            // Generate and save token
            const token = generateToken(agentType, taskDescription);
            token.id = tempTokenId;

            try {
                fs.writeFileSync(TOKEN_FILE, JSON.stringify(token, null, 2));

                console.log('');
                console.log('╔══════════════════════════════════════════════════════════════╗');
                console.log('║         ✅ EDIT PERMISSION GRANTED BY AGENT ✅               ║');
                console.log('╚══════════════════════════════════════════════════════════════╝');
                console.log('');
                console.log(`🤖 Agent: ${agentType}`);
                console.log(`📝 Task: ${taskDescription}`);
                console.log(`🔑 Token: ${token.id}`);
                console.log(`⏰ Valid until: ${token.expiresAt}`);
                console.log('');
                console.log('You may now use Edit or Write tools.');
                console.log('Token will be consumed on first use.');
                console.log('');

            } catch (err) {
                console.error(`⚠️  Warning: Could not write token file: ${err.message}`);
            }

            process.exit(0);
        }

        // Other agents (documentation, etc.)
        console.log(`ℹ️  Agent '${agentType}' completed`);
        process.exit(0);

    } catch (err) {
        // On error, don't block - just log
        console.error(`Hook error: ${err.message}`);
        process.exit(0);
    }
}

main();

#!/usr/bin/env node
/**
 * Enforcement State Manager
 *
 * Shared module for tracking SDLC enforcement state across hooks.
 * Manages the state file that tracks:
 * - Edits since last test
 * - Which validation agents have run
 * - Security-sensitive file detection
 * - Commit readiness
 */

const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(process.env.USERPROFILE || process.env.HOME, '.claude', 'hooks', '.enforcement_state.json');

// Security-sensitive file patterns
const SECURITY_SENSITIVE_PATTERNS = [
    /auth/i,
    /login/i,
    /password/i,
    /credential/i,
    /token/i,
    /secret/i,
    /crypto/i,
    /encrypt/i,
    /decrypt/i,
    /session/i,
    /permission/i,
    /access.?control/i,
    /oauth/i,
    /jwt/i,
    /api.?key/i,
    /payment/i,
    /billing/i,
    /credit.?card/i,
    /\.env/i,
    /config.*secret/i,
];

// Default state
const DEFAULT_STATE = {
    editsSinceTest: 0,
    editsSinceSecurityReview: 0,
    editsSinceDevopsReview: 0,
    lastEditTimestamp: null,
    lastEditFile: null,
    securitySensitiveEdits: [],
    needsTesting: false,
    needsSecurityReview: false,
    needsDevopsReview: false,
    agentHistory: [],  // Recent agent runs
    sessionId: null,
};

// Load state
function loadState() {
    try {
        if (fs.existsSync(STATE_FILE)) {
            const content = fs.readFileSync(STATE_FILE, 'utf8');
            return { ...DEFAULT_STATE, ...JSON.parse(content) };
        }
    } catch (err) {
        // Return default on error
    }
    return { ...DEFAULT_STATE };
}

// Save state
function saveState(state) {
    try {
        fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
        return true;
    } catch (err) {
        console.error(`Failed to save enforcement state: ${err.message}`);
        return false;
    }
}

// Check if file is security-sensitive
function isSecuritySensitive(filePath) {
    if (!filePath) return false;
    return SECURITY_SENSITIVE_PATTERNS.some(pattern => pattern.test(filePath));
}

// Record an edit
function recordEdit(filePath) {
    const state = loadState();

    state.editsSinceTest++;
    state.editsSinceDevopsReview++;
    state.lastEditTimestamp = new Date().toISOString();
    state.lastEditFile = filePath;
    state.needsTesting = true;
    state.needsDevopsReview = true;

    // Check for security-sensitive files
    if (isSecuritySensitive(filePath)) {
        state.editsSinceSecurityReview++;
        state.needsSecurityReview = true;
        if (!state.securitySensitiveEdits.includes(filePath)) {
            state.securitySensitiveEdits.push(filePath);
        }
    }

    saveState(state);
    return state;
}

// Record agent completion
function recordAgentCompletion(agentType, taskDescription) {
    const state = loadState();

    // Add to history
    state.agentHistory.push({
        agent: agentType,
        task: taskDescription,
        timestamp: new Date().toISOString()
    });

    // Keep last 20 entries
    if (state.agentHistory.length > 20) {
        state.agentHistory = state.agentHistory.slice(-20);
    }

    // Update flags based on agent type
    switch (agentType) {
        case 'qa-test-engineer':
            state.editsSinceTest = 0;
            state.needsTesting = false;
            break;

        case 'elite-security-auditor':
            state.editsSinceSecurityReview = 0;
            state.needsSecurityReview = false;
            state.securitySensitiveEdits = [];
            break;

        case 'devops-guardian':
            state.editsSinceDevopsReview = 0;
            state.needsDevopsReview = false;
            break;

        case 'requirements-guardian':
            // Mark requirements as validated
            state.requirementsValidated = true;
            state.requirementsValidatedAt = new Date().toISOString();
            break;
    }

    saveState(state);
    return state;
}

// Reset state (for new session)
function resetState() {
    saveState({ ...DEFAULT_STATE, sessionId: Date.now().toString() });
}

// Get current state
function getState() {
    return loadState();
}

// Export for use by hooks
module.exports = {
    loadState,
    saveState,
    recordEdit,
    recordAgentCompletion,
    resetState,
    getState,
    isSecuritySensitive,
    STATE_FILE,
    SECURITY_SENSITIVE_PATTERNS
};

// If run directly, show current state
if (require.main === module) {
    const state = loadState();
    console.log('Current Enforcement State:');
    console.log(JSON.stringify(state, null, 2));
}

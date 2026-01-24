#!/usr/bin/env node
/**
 * PostToolUse Hook for Edit/Write - Intelligent File Type Tracker
 *
 * This hook fires AFTER Edit/Write operations to track edits by file type
 * and automatically set appropriate review flags based on what was edited.
 *
 * ENHANCEMENT over track-edit.js:
 * - Categorizes files by type (code, test, config, security, infrastructure, docs)
 * - Auto-escalates review requirements for security-sensitive files
 * - Provides detailed edit breakdown and priority warnings
 */

const enforcementState = require('./enforcement-state.js');
const path = require('path');

// File type categories with patterns and required reviews
// IMPORTANT: Includes both Unix AND Windows/PowerShell file types
const FILE_CATEGORIES = {
    code: {
        patterns: [
            // JavaScript/TypeScript
            /\.(js|ts|jsx|tsx|mjs|cjs)$/i,
            // Python
            /\.(py|pyw|pyx)$/i,
            // JVM languages
            /\.(java|kt|kts|scala)$/i,
            // Systems languages
            /\.(go|rs|c|cpp|cc|h|hpp)$/i,
            // .NET languages
            /\.(cs|vb|fs)$/i,
            // Other languages
            /\.(rb|php|swift|m|mm)$/i,
            // === WINDOWS/POWERSHELL SCRIPTS ===
            /\.(ps1|psm1|psd1)$/i,           // PowerShell scripts and modules
            /\.(bat|cmd)$/i,                  // Windows batch files
            /\.(vbs|wsf)$/i,                  // Windows Script Host
        ],
        setFlags: ['needsTesting', 'needsDevopsReview'],
        priority: 'high',
        description: 'Code file'
    },
    test: {
        patterns: [
            // JavaScript/TypeScript tests
            /\.(test|spec)\.(js|ts|jsx|tsx|py)$/i,
            // Test directories
            /[\\/]tests?[\\/]/,
            /[\\/]__tests__[\\/]/,
            // Python tests
            /test_.*\.py$/i,
            // Go tests
            /_test\.go$/i,
            // Java tests
            /Test\.java$/i,
            // === WINDOWS/POWERSHELL TESTS ===
            /\.tests\.ps1$/i,                 // Pester convention: *.tests.ps1
            /test-.*\.ps1$/i,                 // test-*.ps1
            /validate-.*\.ps1$/i,             // validate-*.ps1
            /-test\.ps1$/i,                   // *-test.ps1
            /-tests\.ps1$/i,                  // *-tests.ps1
        ],
        setFlags: ['needsDevopsReview'],  // Tests themselves don't always need more tests
        priority: 'medium',
        description: 'Test file'
    },
    config: {
        patterns: [
            // Common config formats
            /\.(json|yaml|yml|toml|ini|xml)$/i,
            /\.(conf|config|cfg)$/i,
            // JavaScript/Node
            /package\.json$/i,
            /tsconfig\.json$/i,
            /\.eslintrc/i,
            /\.prettierrc/i,
            // Python
            /requirements\.txt$/i,
            /pyproject\.toml$/i,
            // Other languages
            /Cargo\.toml$/i,
            /pom\.xml$/i,
            /build\.gradle/i,
            // === WINDOWS/POWERSHELL CONFIG ===
            /\.psd1$/i,                       // PowerShell data files (module manifests)
            /\bsettings\.json$/i,             // Claude Code settings
            /\.csproj$/i,                     // .NET project files
            /\.sln$/i,                        // Visual Studio solution files
            /\.props$/i,                      // MSBuild properties
            /\.targets$/i,                    // MSBuild targets
            /nuget\.config$/i,                // NuGet configuration
            /web\.config$/i,                  // ASP.NET config
            /app\.config$/i,                  // .NET app config
        ],
        setFlags: ['needsDevopsReview'],
        priority: 'medium',
        description: 'Configuration file'
    },
    security: {
        patterns: [
            /auth/i, /login/i, /password/i, /credential/i,
            /token/i, /secret/i, /crypto/i, /permission/i,
            /\.env/i, /security/i, /oauth/i, /jwt/i,
            /session/i, /cookie/i, /cors/i,
        ],
        setFlags: ['needsTesting', 'needsSecurityReview', 'needsDevopsReview'],
        priority: 'critical',
        description: 'Security-sensitive file'
    },
    infrastructure: {
        patterns: [
            // Docker
            /Dockerfile/i,
            /docker-compose/i,
            /\.dockerignore$/i,
            // CI/CD - Unix
            /\.gitlab-ci\.yml$/i,
            /\.github[\\/]workflows[\\/]/i,
            /\.circleci[\\/]/i,
            // Infrastructure as Code
            /terraform/i,
            /\.tf$/i,
            /kubernetes/i,
            /k8s[\\/]/i,
            /helm[\\/]/i,
            /\.hcl$/i,
            // === WINDOWS/AZURE INFRASTRUCTURE ===
            /azure-pipelines\.yml$/i,         // Azure DevOps pipelines
            /\.azure[\\/]/i,                  // Azure config directory
            /azuredeploy\.json$/i,            // ARM templates
            /\.bicep$/i,                      // Azure Bicep
            /Install-.*\.ps1$/i,              // Installer scripts (infrastructure)
            /Deploy-.*\.ps1$/i,               // Deployment scripts
            /Setup-.*\.ps1$/i,                // Setup scripts
            /\.msi$/i,                        // Windows installers
            /\.msix$/i,                       // Modern Windows apps
        ],
        setFlags: ['needsSecurityReview', 'needsDevopsReview'],
        priority: 'high',
        description: 'Infrastructure file'
    },
    hook: {
        patterns: [
            /[\\/]\.claude[\\/]hooks[\\/]/i,
            /hook.*\.js$/i,
            /\.git[\\/]hooks[\\/]/i,
        ],
        setFlags: ['needsSecurityReview', 'needsDevopsReview'],
        priority: 'critical',
        description: 'Hook file (enforcement system)'
    },
    documentation: {
        patterns: [
            /\.(md|txt|rst|adoc|org)$/i,
            /README/i,
            /CHANGELOG/i,
            /LICENSE/i,
            /CONTRIBUTING/i,
            /\.github[\\/].*\.md$/i,
        ],
        setFlags: [],  // Docs rarely need testing
        priority: 'low',
        description: 'Documentation file'
    }
};

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

// Categorize file based on path and patterns
function categorizeFile(filePath) {
    if (!filePath) return [{ category: 'unknown', setFlags: ['needsTesting', 'needsDevopsReview'], priority: 'high' }];

    const categories = [];

    for (const [category, config] of Object.entries(FILE_CATEGORIES)) {
        if (config.patterns.some(p => p.test(filePath))) {
            categories.push({
                category,
                setFlags: config.setFlags,
                priority: config.priority,
                description: config.description
            });
        }
    }

    // If no match, treat as code (conservative approach)
    if (categories.length === 0) {
        categories.push({
            category: 'unknown',
            setFlags: ['needsTesting', 'needsDevopsReview'],
            priority: 'high',
            description: 'Unknown file type (treating as code)'
        });
    }

    return categories;
}

// Get numeric priority value
function getPriorityValue(priority) {
    const values = { critical: 4, high: 3, medium: 2, low: 1 };
    return values[priority] || 0;
}

// Record edit with enhanced tracking
function recordEnhancedEdit(filePath) {
    const state = enforcementState.loadState();
    const categories = categorizeFile(filePath);

    // Update edit counts
    state.editsSinceTest++;
    state.editsSinceDevopsReview++;
    state.lastEditTimestamp = new Date().toISOString();
    state.lastEditFile = filePath;

    // Initialize file type tracking if needed
    if (!state.editsByFileType) {
        state.editsByFileType = {
            code: 0,
            test: 0,
            config: 0,
            security: 0,
            infrastructure: 0,
            hook: 0,
            documentation: 0,
            unknown: 0
        };
    }

    // Track edits by category
    categories.forEach(cat => {
        state.editsByFileType[cat.category]++;

        // Set flags based on category
        cat.setFlags.forEach(flag => {
            state[flag] = true;
        });

        // Special handling for security-sensitive files
        if (cat.category === 'security' || cat.category === 'hook') {
            state.editsSinceSecurityReview = (state.editsSinceSecurityReview || 0) + 1;
            if (!state.securitySensitiveEdits) {
                state.securitySensitiveEdits = [];
            }
            if (!state.securitySensitiveEdits.includes(filePath)) {
                state.securitySensitiveEdits.push(filePath);
            }
        }
    });

    // Record file metadata
    if (!state.recentEdits) state.recentEdits = [];
    state.recentEdits.push({
        file: filePath,
        timestamp: new Date().toISOString(),
        categories: categories.map(c => c.category),
        priority: Math.max(...categories.map(c => getPriorityValue(c.priority))),
        descriptions: categories.map(c => c.description)
    });

    // Keep last 50 edits
    if (state.recentEdits.length > 50) {
        state.recentEdits = state.recentEdits.slice(-50);
    }

    enforcementState.saveState(state);
    return { state, categories };
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

        // Claude Code sends tool_input nested inside the hook input
        const nestedInput = toolData.tool_input || toolData;
        const filePath = nestedInput.file_path || nestedInput.path || '';
        if (!filePath) {
            process.exit(0);
        }

        // Record the edit with enhanced tracking
        const { state, categories } = recordEnhancedEdit(filePath);

        console.log('');
        console.log(`📝 Edit tracked: ${path.basename(filePath)}`);
        console.log(`   Categories: ${categories.map(c => c.category).join(', ')}`);
        console.log(`   Edits since last test: ${state.editsSinceTest}`);

        // Show required reviews
        const requiredReviews = [];
        if (state.needsTesting) requiredReviews.push('qa-test-engineer');
        if (state.needsSecurityReview) requiredReviews.push('elite-security-auditor');
        if (state.needsDevopsReview) requiredReviews.push('devops-guardian');

        if (requiredReviews.length > 0) {
            console.log(`   Required reviews: ${requiredReviews.join(', ')}`);
        }

        // Priority warning for critical files
        const hasCritical = categories.some(c => c.priority === 'critical');
        if (hasCritical) {
            console.log('');
            console.log('┌─────────────────────────────────────────────────────────────┐');
            console.log('│  ⚠️  CRITICAL FILE EDITED - IMMEDIATE REVIEW REQUIRED       │');
            console.log('├─────────────────────────────────────────────────────────────┤');
            console.log('│  This file has been flagged as:                            │');
            categories.filter(c => c.priority === 'critical').forEach(cat => {
                console.log(`│  • ${cat.description.padEnd(56)}│`);
            });
            console.log('│                                                             │');
            if (state.needsSecurityReview) {
                console.log('│  Run elite-security-auditor before proceeding.             │');
            }
            console.log('└─────────────────────────────────────────────────────────────┘');
        }

        // Show edit distribution every 5 edits
        if (state.editsSinceTest >= 5 && state.editsSinceTest % 5 === 0) {
            console.log('');
            console.log(`Edit breakdown (${state.editsSinceTest} total edits since last test):`);
            for (const [type, count] of Object.entries(state.editsByFileType)) {
                if (count > 0) {
                    console.log(`  • ${type}: ${count}`);
                }
            }
            console.log('');
            console.log('Consider running qa-test-engineer soon.');
        }

        console.log('');

        process.exit(0);

    } catch (err) {
        // On error, don't block - fail open
        console.error(`Track file types hook error: ${err.message}`);
        process.exit(0);
    }
}

main();

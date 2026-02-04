#!/usr/bin/env node
/**
 * Auto-sync CLAUDE.md from OneDrive to local .claude directory
 * Runs on Claude Code SessionStart as fallback if symbolic link isn't available
 * v3.0.31 - Auto-detect OneDrive path for personal vs work machines
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Auto-detect OneDrive path (works on both personal and work machines)
 * Checks: "OneDrive - PakEnergy" (work) first, then "OneDrive" (personal)
 */
function getOneDrivePath() {
    const homeDir = os.homedir();
    const candidates = [
        'OneDrive - PakEnergy',  // Work machine (more specific, check first)
        'OneDrive'               // Personal machine
    ];

    for (const candidate of candidates) {
        const fullPath = path.join(homeDir, candidate);
        if (fs.existsSync(fullPath)) {
            return fullPath;
        }
    }

    return null;
}

function syncClaudeMd() {
    try {
        const homeDir = os.homedir();

        // Auto-detect OneDrive path
        const oneDrivePath = getOneDrivePath();
        if (!oneDrivePath) {
            // OneDrive not found, silently exit
            return;
        }

        const oneDriveSource = path.join(oneDrivePath, 'Claude Backup', 'claude-config', 'CLAUDE.md');
        const localTarget = path.join(homeDir, '.claude', 'CLAUDE.md');

        // Check if target is a symlink - if so, no sync needed
        try {
            const stats = fs.lstatSync(localTarget);
            if (stats.isSymbolicLink()) {
                // Symlink exists, no sync needed
                return;
            }
        } catch (err) {
            // File doesn't exist, will copy below
        }

        // Check if source exists
        if (!fs.existsSync(oneDriveSource)) {
            // OneDrive not synced yet, silently exit
            return;
        }

        // Ensure .claude directory exists
        const claudeDir = path.join(homeDir, '.claude');
        if (!fs.existsSync(claudeDir)) {
            fs.mkdirSync(claudeDir, { recursive: true });
        }

        // Copy from OneDrive to local
        fs.copyFileSync(oneDriveSource, localTarget);

        // Silent success - no output needed for hook
    } catch (err) {
        // Silent failure - hooks should not interrupt session start
        // Error is logged but not thrown
    }
}

// Run sync
syncClaudeMd();

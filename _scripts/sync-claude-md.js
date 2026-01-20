#!/usr/bin/env node
/**
 * Auto-sync CLAUDE.md from OneDrive to local .claude directory
 * Runs on Claude Code SessionStart as fallback if symbolic link isn't available
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

function syncClaudeMd() {
    try {
        const homeDir = os.homedir();
        const oneDriveSource = path.join(homeDir, 'OneDrive - PakEnergy', 'Claude Backup', 'claude-config', 'CLAUDE.md');
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

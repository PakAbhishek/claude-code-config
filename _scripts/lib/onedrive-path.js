/**
 * onedrive-path.js
 * Utility function to auto-detect OneDrive path
 * Works on both personal (OneDrive) and work (OneDrive - PakEnergy) machines
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Get the OneDrive path for this machine.
 * Checks in order:
 * 1. "OneDrive - PakEnergy" (work machine - more specific)
 * 2. "OneDrive" (personal machine)
 *
 * @returns {string|null} The OneDrive path, or null if not found
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

/**
 * Get the OneDrive path, throwing an error if not found.
 *
 * @returns {string} The OneDrive path
 * @throws {Error} If no OneDrive folder is found
 */
function getOneDrivePathOrThrow() {
    const result = getOneDrivePath();
    if (!result) {
        throw new Error('OneDrive folder not found. Checked: OneDrive - PakEnergy, OneDrive');
    }
    return result;
}

/**
 * Get the Claude config directory path.
 *
 * @returns {string|null} The config directory path, or null if OneDrive not found
 */
function getConfigPath() {
    const oneDrive = getOneDrivePath();
    if (!oneDrive) return null;
    return path.join(oneDrive, 'Claude Backup', 'claude-config');
}

module.exports = {
    getOneDrivePath,
    getOneDrivePathOrThrow,
    getConfigPath
};

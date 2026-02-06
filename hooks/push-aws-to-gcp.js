#!/usr/bin/env node
/**
 * Push AWS Credentials to GCP Hindsight
 * Runs on SessionStart AFTER check-aws-sso.js ensures local creds are valid
 * Pushes credentials to GCP so Hindsight's reflect() feature works
 * v3.0.31 - Auto-detect OneDrive path for personal vs work machines
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Find the Auto-Push script across OneDrive paths.
 * Checks PakEnergy (work) first, then personal OneDrive.
 * Both may have the script; we use the first one found.
 */
function findPushScript() {
    const homeDir = process.env.USERPROFILE || process.env.HOME;
    const candidates = [
        'OneDrive - PakEnergy',  // Work machine (more specific, check first)
        'OneDrive'               // Personal machine
    ];
    const relativePath = path.join('Claude Backup', 'claude-config', 'hindsight-setup', 'Auto-Push-AWS-Credentials.ps1');

    for (const candidate of candidates) {
        const fullPath = path.join(homeDir, candidate, relativePath);
        if (fs.existsSync(fullPath)) {
            return fullPath;
        }
    }

    return null;
}

// Path to the PowerShell push script (in git repo, synced via OneDrive)
const PUSH_SCRIPT = findPushScript();

function main() {
  try {
    // Check if OneDrive path was found
    if (!PUSH_SCRIPT) {
      console.log('Skipping GCP push - OneDrive folder not found');
      process.exit(0);
    }

    // Check if push script exists
    if (!fs.existsSync(PUSH_SCRIPT)) {
      console.log('Skipping GCP push - push script not found at:', PUSH_SCRIPT);
      process.exit(0);
    }

    // Check if we have valid AWS credentials locally first
    try {
      execSync('aws sts get-caller-identity', {
        encoding: 'utf8',
        timeout: 10000,
        stdio: ['pipe', 'pipe', 'pipe']
      });
    } catch (e) {
      // No valid local creds - check-aws-sso.js should have handled this
      // Don't try to push invalid creds to GCP
      console.log('Skipping GCP push - no valid local AWS credentials');
      process.exit(0);
    }

    // Run the PowerShell script to push credentials to GCP
    console.log('Pushing AWS credentials to GCP Hindsight...');

    const result = execSync(
      `powershell -ExecutionPolicy Bypass -File "${PUSH_SCRIPT}"`,
      {
        encoding: 'utf8',
        timeout: 120000, // 2 minute timeout
        stdio: ['pipe', 'pipe', 'pipe']
      }
    );

    console.log('Success');
    process.exit(0);

  } catch (error) {
    // Don't block Claude Code startup on GCP push failure
    console.log('GCP credential push failed (non-blocking):', error.message);
    process.exit(0);
  }
}

main();

#!/usr/bin/env node
/**
 * Push AWS Credentials to GCP Hindsight
 * Runs on SessionStart AFTER check-aws-sso.js ensures local creds are valid
 * Pushes credentials to GCP so Hindsight's reflect() feature works
 */

const { execSync } = require('child_process');
const path = require('path');

// Path to the PowerShell push script (synced via OneDrive)
const PUSH_SCRIPT = path.join(
  process.env.USERPROFILE || process.env.HOME,
  'OneDrive', 'Claude Backup', 'hindsight-setup', 'Auto-Push-AWS-Credentials.ps1'
);

function main() {
  try {
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

#!/usr/bin/env node
/**
 * AWS SSO Credential Checker for Claude Code
 * Runs on SessionStart to ensure AWS credentials are valid
 * If expired, triggers aws sso login
 */

const { execSync, spawn } = require('child_process');

const AWS_PROFILE = process.env.AWS_PROFILE;

function checkAwsCredentials() {
  try {
    // Try to get caller identity - this will fail if credentials are expired
    const awsCmd = AWS_PROFILE
      ? `aws sts get-caller-identity --profile ${AWS_PROFILE}`
      : 'aws sts get-caller-identity';

    const result = execSync(awsCmd, {
      encoding: 'utf8',
      timeout: 10000,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    const identity = JSON.parse(result);
    // Credentials are valid
    return { valid: true, identity };
  } catch (error) {
    // Credentials are expired or invalid
    return { valid: false, error: error.message };
  }
}

async function refreshSsoCredentials() {
  return new Promise((resolve) => {
    console.log('AWS SSO credentials expired. Opening browser for login...');

    const ssoArgs = AWS_PROFILE
      ? ['sso', 'login', '--profile', AWS_PROFILE]
      : ['sso', 'login'];

    if (AWS_PROFILE) {
      console.log(`Using AWS profile: ${AWS_PROFILE}`);
    }

    // Spawn aws sso login - this will open browser
    const ssoLogin = spawn('aws', ssoArgs, {
      stdio: 'inherit',
      shell: true
    });

    ssoLogin.on('close', (code) => {
      if (code === 0) {
        console.log('AWS SSO login completed successfully.');
        resolve(true);
      } else {
        console.log('AWS SSO login may have failed. Run "aws sso login" manually if needed.');
        resolve(false);
      }
    });

    ssoLogin.on('error', (err) => {
      console.log('Failed to start SSO login:', err.message);
      resolve(false);
    });

    // Set a timeout - if login takes too long, continue anyway
    setTimeout(() => {
      console.log('SSO login timeout - continuing. Run "aws sso login" if authentication issues occur.');
      resolve(false);
    }, 60000); // 60 second timeout
  });
}

async function main() {
  const status = checkAwsCredentials();

  if (status.valid) {
    // Credentials are good, output success quietly
    console.log('Success');
    process.exit(0);
  } else {
    // Credentials expired - try to refresh
    await refreshSsoCredentials();

    // Check again after refresh attempt
    const newStatus = checkAwsCredentials();
    if (newStatus.valid) {
      console.log('Success');
    } else {
      console.log('AWS credentials may still be invalid. Run "aws sso login" if you encounter errors.');
    }
    process.exit(0);
  }
}

main().catch(err => {
  console.error('Error checking AWS credentials:', err.message);
  process.exit(0); // Don't block Claude Code startup
});

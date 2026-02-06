#!/usr/bin/env node
/**
 * Suggest Worktree Hook
 *
 * Fires on session start to remind Claude about worktree capability
 * for parallel autonomous tasks.
 *
 * Hook type: SessionStart (Notification)
 */

const fs = require('fs');
const path = require('path');

// Check if we're in a git repo
function isGitRepo() {
  try {
    const { execSync } = require('child_process');
    execSync('git rev-parse --is-inside-work-tree', { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

// Get current worktree count
function getWorktreeCount() {
  try {
    const { execSync } = require('child_process');
    const output = execSync('git worktree list', { stdio: 'pipe', encoding: 'utf8' });
    return output.trim().split('\n').length;
  } catch {
    return 0;
  }
}

// Main
function main() {
  if (!isGitRepo()) {
    return; // Not a git repo, no suggestion needed
  }

  const worktreeCount = getWorktreeCount();

  // Output reminder for Claude (appears in session context)
  console.log(`WORKTREE_AVAILABLE: This project supports git worktrees for parallel Claude sessions.`);
  console.log(`CURRENT_WORKTREES: ${worktreeCount}`);
  console.log(`SUGGEST_WORKTREE_WHEN: User mentions "parallel", "autonomous", "background", "simultaneously", or requests a long-running task while wanting to continue other work.`);
  console.log(`HOW_TO_SUGGEST: Offer to run "/worktree create <descriptive-branch-name>" before starting isolated work.`);
}

main();

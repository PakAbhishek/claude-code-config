---
description: Git worktree management for parallel Claude sessions
argument-hint: <create|list|remove|status> [branch-name]
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Git Worktree Manager

Manage git worktrees for running parallel Claude Code sessions with complete code isolation.

## What Are Git Worktrees?

Git worktrees allow you to have multiple working directories from the same repository, each on a different branch. This enables:
- **Parallel Claude sessions** - Run multiple autonomous tasks simultaneously
- **Code isolation** - Changes in one worktree don't affect others
- **Shared history** - All worktrees share the same Git repo and remotes

## Commands

Based on the argument provided: **$ARGUMENTS**

### If `create <branch-name>`:
1. Verify we're in a git repository
2. Run the worktree helper script to create a new worktree:
   - On Windows: `powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE/OneDrive/Claude Backup/claude-config/_scripts/worktree-helper.ps1" create <branch-name>`
   - On Mac/Linux: `"$HOME/OneDrive/Claude Backup/claude-config/_scripts/worktree-helper.sh" create <branch-name>`
3. Display the path to the new worktree and instructions for starting a parallel session

### If `list`:
1. Run: `git worktree list`
2. Show all active worktrees with their branches and paths
3. Indicate which worktrees might have Claude sessions running

### If `remove <branch-name>`:
1. Run the worktree helper script to remove:
   - On Windows: `powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE/OneDrive/Claude Backup/claude-config/_scripts/worktree-helper.ps1" remove <branch-name>`
   - On Mac/Linux: `"$HOME/OneDrive/Claude Backup/claude-config/_scripts/worktree-helper.sh" remove <branch-name>`
2. Confirm the worktree was removed
3. Note: Branch is kept (merge to main first if needed)

### If `status` or no argument:
1. Run: `git worktree list`
2. For each worktree, show:
   - Path
   - Branch name
   - Whether it's the main worktree or secondary
3. Provide guidance on next steps

## Usage Examples

```bash
# Create a worktree for a new feature
/worktree create feature-oauth

# List all worktrees
/worktree list

# Remove a worktree after merging
/worktree remove feature-oauth

# Check status of all worktrees
/worktree status
```

## Workflow for Parallel Sessions

After creating a worktree:
1. Open a new terminal
2. `cd` to the worktree path shown
3. Run `claude` to start a new session
4. Both sessions work independently with full code isolation

## Important Notes

- Worktrees are created as sibling directories (e.g., `project-feature-auth` next to `project`)
- Each worktree can have its own Claude session
- Changes must be committed and pushed from within each worktree
- Always merge/delete branches after removing worktrees to keep repo clean

<#
.SYNOPSIS
    Git Worktree Helper Script (PowerShell)
.DESCRIPTION
    Windows helper for managing git worktrees
    Used by /worktree slash command
#>

param(
    [Parameter(Position=0)]
    [string]$Command = "status",

    [Parameter(Position=1)]
    [string]$BranchName
)

$ErrorActionPreference = "Stop"

function Write-Success($Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Err($Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info($Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn($Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Get-RepoInfo {
    $isGitRepo = git rev-parse --is-inside-work-tree 2>$null
    if (-not $isGitRepo) {
        Write-Err "Not inside a git repository"
        exit 1
    }

    $script:RepoRoot = git rev-parse --show-toplevel
    $script:RepoName = Split-Path -Leaf $script:RepoRoot
    $script:RepoParent = Split-Path -Parent $script:RepoRoot
}

function New-Worktree {
    param([string]$Branch)

    if ([string]::IsNullOrEmpty($Branch)) {
        Write-Err "Branch name required"
        Write-Host "Usage: worktree-helper.ps1 create BRANCH_NAME"
        exit 1
    }

    Get-RepoInfo

    $worktreePath = Join-Path $script:RepoParent "$($script:RepoName)-$Branch"

    if (Test-Path $worktreePath) {
        Write-Err "Worktree already exists at: $worktreePath"
        exit 1
    }

    $branchExists = git show-ref --verify --quiet "refs/heads/$Branch" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Branch '$Branch' exists, creating worktree from it"
        git worktree add $worktreePath $Branch
    } else {
        Write-Info "Creating new branch '$Branch' and worktree"
        git worktree add -b $Branch $worktreePath
    }

    Write-Host ""
    Write-Success "Created worktree at: $worktreePath"
    Write-Success "Branch: $Branch"
    Write-Host ""
    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host "To start a parallel Claude session:" -ForegroundColor White
    Write-Host ""
    Write-Host "  cd $worktreePath" -ForegroundColor Yellow
    Write-Host "  claude" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or for autonomous mode:" -ForegroundColor White
    Write-Host ""
    Write-Host "  claude -p ""Your task here"" --allowedTools ""Read,Edit,Write,Bash"" --max-turns 50" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor DarkGray
}

function Get-Worktrees {
    Get-RepoInfo

    Write-Host "Git Worktrees for: $($script:RepoName)" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host ""

    $worktrees = git worktree list
    $count = 0

    foreach ($line in $worktrees) {
        $count++
        $parts = $line -split '\s+'
        $path = $parts[0]
        $commit = $parts[1]
        $branch = $parts[2] -replace '[\[\]]', ''

        Write-Host "Path: $path" -ForegroundColor Cyan
        Write-Host "   Commit: $commit"
        Write-Host "   Branch: $branch" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "Total worktrees: $count"
}

function Remove-Worktree {
    param([string]$Branch)

    if ([string]::IsNullOrEmpty($Branch)) {
        Write-Err "Branch name required"
        Write-Host "Usage: worktree-helper.ps1 remove BRANCH_NAME"
        exit 1
    }

    Get-RepoInfo

    $worktreePath = Join-Path $script:RepoParent "$($script:RepoName)-$Branch"

    if (-not (Test-Path $worktreePath)) {
        Write-Err "Worktree not found at: $worktreePath"
        Write-Host ""
        Write-Host "Available worktrees:"
        git worktree list
        exit 1
    }

    Write-Info "Removing worktree at: $worktreePath"
    git worktree remove $worktreePath

    Write-Host ""
    Write-Success "Removed worktree: $worktreePath"
    Write-Warn "Branch '$Branch' was kept"
    Write-Host ""
    Write-Host "To delete the branch (if merged):"
    Write-Host "  git branch -d $Branch" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To force delete (if not merged):"
    Write-Host "  git branch -D $Branch" -ForegroundColor Yellow
}

function Get-WorktreeStatus {
    Get-RepoInfo

    Write-Host "Git Worktree Status for: $($script:RepoName)" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host ""

    $worktrees = git worktree list
    $count = 0

    foreach ($line in $worktrees) {
        $count++
        $parts = $line -split '\s+'
        $path = $parts[0]
        $commit = $parts[1]
        $branch = $parts[2] -replace '[\[\]]', ''

        if ($count -eq 1) {
            Write-Host "* Main Worktree" -ForegroundColor Green
        } else {
            Write-Host "* Secondary Worktree" -ForegroundColor Cyan
        }

        Write-Host "  Path:   $path"
        Write-Host "  Branch: $branch"
        Write-Host "  Commit: $commit"

        if (Test-Path $path) {
            Push-Location $path
            $hasChanges = $false
            git diff --quiet 2>$null
            if ($LASTEXITCODE -ne 0) { $hasChanges = $true }
            git diff --cached --quiet 2>$null
            if ($LASTEXITCODE -ne 0) { $hasChanges = $true }

            if ($hasChanges) {
                Write-Host "  Status: Has uncommitted changes" -ForegroundColor Yellow
            } else {
                Write-Host "  Status: Clean" -ForegroundColor Green
            }
            Pop-Location
        }
        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor DarkGray
    Write-Host "Total: $count worktree(s)"
}

function Show-Help {
    Write-Host "Git Worktree Helper" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: worktree-helper.ps1 COMMAND [ARGUMENTS]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  create BRANCH   Create a new worktree with branch"
    Write-Host "  list            List all worktrees"
    Write-Host "  remove BRANCH   Remove a worktree (keeps branch)"
    Write-Host "  status          Show detailed worktree status"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  worktree-helper.ps1 create feature-auth" -ForegroundColor Yellow
    Write-Host "  worktree-helper.ps1 list" -ForegroundColor Yellow
    Write-Host "  worktree-helper.ps1 remove feature-auth" -ForegroundColor Yellow
}

switch ($Command.ToLower()) {
    "create" { New-Worktree -Branch $BranchName }
    "list" { Get-Worktrees }
    "remove" { Remove-Worktree -Branch $BranchName }
    "delete" { Remove-Worktree -Branch $BranchName }
    "status" { Get-WorktreeStatus }
    "help" { Show-Help }
    default { Get-WorktreeStatus }
}

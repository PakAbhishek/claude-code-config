#!/bin/bash
# Git Worktree Helper Script
# Cross-platform helper for managing git worktrees
# Used by /worktree slash command

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Get the repository root and name
get_repo_info() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        print_error "Not inside a git repository"
        exit 1
    fi

    REPO_ROOT=$(git rev-parse --show-toplevel)
    REPO_NAME=$(basename "$REPO_ROOT")
    REPO_PARENT=$(dirname "$REPO_ROOT")
}

# Create a new worktree
cmd_create() {
    local branch_name="$1"

    if [ -z "$branch_name" ]; then
        print_error "Branch name required"
        echo "Usage: worktree-helper.sh create <branch-name>"
        exit 1
    fi

    get_repo_info

    # Worktree path is sibling directory with branch suffix
    local worktree_path="${REPO_PARENT}/${REPO_NAME}-${branch_name}"

    # Check if worktree already exists
    if [ -d "$worktree_path" ]; then
        print_error "Worktree already exists at: $worktree_path"
        exit 1
    fi

    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        print_info "Branch '${branch_name}' exists, creating worktree from it"
        git worktree add "$worktree_path" "$branch_name"
    else
        print_info "Creating new branch '${branch_name}' and worktree"
        git worktree add -b "$branch_name" "$worktree_path"
    fi

    echo ""
    print_success "Created worktree at: $worktree_path"
    print_success "Branch: $branch_name"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "To start a parallel Claude session:"
    echo ""
    echo "  cd \"$worktree_path\" && claude"
    echo ""
    echo "Or for autonomous mode:"
    echo ""
    echo "  cd \"$worktree_path\" && claude -p \"Your task here\" --allowedTools \"Read,Edit,Write,Bash\" --max-turns 50"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# List all worktrees
cmd_list() {
    get_repo_info

    echo "Git Worktrees for: $REPO_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    git worktree list --porcelain | while read -r line; do
        if [[ "$line" == worktree* ]]; then
            path="${line#worktree }"
            echo -e "${BLUE}📁 $path${NC}"
        elif [[ "$line" == HEAD* ]]; then
            head="${line#HEAD }"
            echo "   Commit: ${head:0:8}"
        elif [[ "$line" == branch* ]]; then
            branch="${line#branch refs/heads/}"
            echo -e "   Branch: ${GREEN}$branch${NC}"
        elif [[ "$line" == "bare" ]]; then
            echo "   (bare repository)"
        elif [[ -z "$line" ]]; then
            echo ""
        fi
    done

    echo ""
    echo "Total worktrees: $(git worktree list | wc -l | tr -d ' ')"
}

# Remove a worktree
cmd_remove() {
    local branch_name="$1"

    if [ -z "$branch_name" ]; then
        print_error "Branch name required"
        echo "Usage: worktree-helper.sh remove <branch-name>"
        exit 1
    fi

    get_repo_info

    local worktree_path="${REPO_PARENT}/${REPO_NAME}-${branch_name}"

    # Check if worktree exists
    if [ ! -d "$worktree_path" ]; then
        print_error "Worktree not found at: $worktree_path"
        echo ""
        echo "Available worktrees:"
        git worktree list
        exit 1
    fi

    # Remove the worktree
    print_info "Removing worktree at: $worktree_path"
    git worktree remove "$worktree_path"

    echo ""
    print_success "Removed worktree: $worktree_path"
    print_warning "Branch '${branch_name}' was kept"
    echo ""
    echo "To delete the branch (if merged):"
    echo "  git branch -d $branch_name"
    echo ""
    echo "To force delete (if not merged):"
    echo "  git branch -D $branch_name"
}

# Show status of worktrees
cmd_status() {
    get_repo_info

    echo "Git Worktree Status for: $REPO_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local count=0
    while IFS= read -r line; do
        ((count++))
        local path=$(echo "$line" | awk '{print $1}')
        local commit=$(echo "$line" | awk '{print $2}')
        local branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')

        if [ "$count" -eq 1 ]; then
            echo -e "${GREEN}★ Main Worktree${NC}"
        else
            echo -e "${BLUE}◆ Secondary Worktree${NC}"
        fi
        echo "  Path:   $path"
        echo "  Branch: $branch"
        echo "  Commit: $commit"

        # Check for uncommitted changes
        if [ -d "$path" ]; then
            cd "$path"
            if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
                echo -e "  Status: ${YELLOW}Has uncommitted changes${NC}"
            else
                echo -e "  Status: ${GREEN}Clean${NC}"
            fi
        fi
        echo ""
    done < <(git worktree list)

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: $count worktree(s)"
}

# Main command dispatcher
case "${1:-status}" in
    create)
        cmd_create "$2"
        ;;
    list)
        cmd_list
        ;;
    remove|delete)
        cmd_remove "$2"
        ;;
    status)
        cmd_status
        ;;
    *)
        echo "Git Worktree Helper"
        echo ""
        echo "Usage: worktree-helper.sh <command> [arguments]"
        echo ""
        echo "Commands:"
        echo "  create <branch>  Create a new worktree with branch"
        echo "  list             List all worktrees"
        echo "  remove <branch>  Remove a worktree (keeps branch)"
        echo "  status           Show detailed worktree status"
        echo ""
        echo "Examples:"
        echo "  worktree-helper.sh create feature-auth"
        echo "  worktree-helper.sh list"
        echo "  worktree-helper.sh remove feature-auth"
        ;;
esac

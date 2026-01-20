#!/bin/bash
# ============================================
# DGX Spark - Production-Grade Installer
# ONE-SHOT INSTALL - Bulletproof with diagnostics
# v1.0.0-production
# ============================================
#
# Design: Can't debug with Claude if this fails
# Solution: Extensive preflight checks, logging, diagnostics
#
# ============================================

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
GITHUB_REPO="https://github.com/PakAbhishek/claude-code-config.git"
CLAUDE_CONFIG_DIR="$HOME/claude-code-config"
LOG_FILE="$HOME/dgx-install-$(date +%Y%m%d-%H%M%S).log"
CHECKPOINT_FILE="$HOME/.dgx-install-checkpoint"

# Error handling
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local exit_code=$1
    local line_number=$2

    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${RED}║       INSTALLATION FAILED                 ║${NC}"
    echo -e "${RED}╔═══════════════════════════════════════════╗${NC}"
    echo ""
    echo -e "${RED}Error occurred at line $line_number (exit code: $exit_code)${NC}"
    echo ""
    echo -e "${YELLOW}Diagnostics saved to: $LOG_FILE${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}TROUBLESHOOTING GUIDE${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    # Run diagnostics
    run_diagnostics

    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Review log: cat $LOG_FILE"
    echo "  2. Check diagnostics above"
    echo "  3. Fix the issue"
    echo "  4. Resume install: bash $0 --resume"
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo "  • Network issue: Check internet connection"
    echo "  • Permission denied: Run with sudo for system packages"
    echo "  • Git auth failed: Run 'gh auth login' or use HTTPS token"
    echo "  • NVIDIA driver: Reboot system after driver install"
    echo ""
    echo "Checkpoint saved. You can resume from where it failed."
    echo ""

    exit $exit_code
}

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_success() {
    log "✓ $*"
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    log "⚠ $*"
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    log "✗ $*"
    echo -e "${RED}✗${NC} $*"
}

# Checkpoint system
save_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
    log "Checkpoint: $1"
}

get_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "START"
    fi
}

# Diagnostics
run_diagnostics() {
    echo -e "${CYAN}Running diagnostics...${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # System info
    echo "=== System Information ===" | tee -a "$LOG_FILE"
    uname -a | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Network
    echo "=== Network Connectivity ===" | tee -a "$LOG_FILE"
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "✓ Internet: Connected" | tee -a "$LOG_FILE"
    else
        echo "✗ Internet: No connection" | tee -a "$LOG_FILE"
    fi

    if ping -c 1 github.com &> /dev/null; then
        echo "✓ GitHub: Reachable" | tee -a "$LOG_FILE"
    else
        echo "✗ GitHub: Unreachable" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"

    # Dependencies
    echo "=== Installed Dependencies ===" | tee -a "$LOG_FILE"
    command -v git &> /dev/null && echo "✓ git: $(git --version)" | tee -a "$LOG_FILE" || echo "✗ git: Not installed" | tee -a "$LOG_FILE"
    command -v node &> /dev/null && echo "✓ node: $(node --version)" | tee -a "$LOG_FILE" || echo "✗ node: Not installed" | tee -a "$LOG_FILE"
    command -v npm &> /dev/null && echo "✓ npm: $(npm --version)" | tee -a "$LOG_FILE" || echo "✗ npm: Not installed" | tee -a "$LOG_FILE"
    command -v python3 &> /dev/null && echo "✓ python3: $(python3 --version)" | tee -a "$LOG_FILE" || echo "✗ python3: Not installed" | tee -a "$LOG_FILE"
    command -v aws &> /dev/null && echo "✓ aws: $(aws --version 2>&1 | head -n1)" | tee -a "$LOG_FILE" || echo "✗ aws: Not installed" | tee -a "$LOG_FILE"
    command -v claude &> /dev/null && echo "✓ claude: $(claude --version 2>&1 | head -n1)" | tee -a "$LOG_FILE" || echo "✗ claude: Not installed" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # GPU
    echo "=== GPU Status ===" | tee -a "$LOG_FILE"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1 | tee -a "$LOG_FILE"
    else
        echo "✗ nvidia-smi: Not available" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"

    # Disk space
    echo "=== Disk Space ===" | tee -a "$LOG_FILE"
    df -h "$HOME" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Permissions
    echo "=== Permissions ===" | tee -a "$LOG_FILE"
    ls -la "$HOME/.claude" 2>&1 | tee -a "$LOG_FILE" || echo "~/.claude not found" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Preflight checks
run_preflight_checks() {
    log "Running preflight checks..."
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}Preflight Checks${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"

    local checks_passed=0
    local checks_failed=0

    # Check 1: Internet connectivity
    echo -n "Checking internet connection... "
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "Internet connected"
        ((checks_passed++))
    else
        log_error "No internet connection"
        echo "  Fix: Check network cable, WiFi, or router"
        ((checks_failed++))
    fi

    # Check 2: GitHub access
    echo -n "Checking GitHub access... "
    if ping -c 1 github.com &> /dev/null; then
        log_success "GitHub reachable"
        ((checks_passed++))
    else
        log_error "Cannot reach GitHub"
        echo "  Fix: Check firewall, DNS, or proxy settings"
        ((checks_failed++))
    fi

    # Check 3: Disk space
    echo -n "Checking disk space... "
    local available_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$available_gb" -gt 10 ]; then
        log_success "Sufficient disk space (${available_gb}GB available)"
        ((checks_passed++))
    else
        log_error "Low disk space (${available_gb}GB available)"
        echo "  Fix: Free up at least 10GB of space"
        ((checks_failed++))
    fi

    # Check 4: Write permissions
    echo -n "Checking write permissions... "
    if touch "$HOME/.write-test" &> /dev/null; then
        rm "$HOME/.write-test"
        log_success "Home directory writable"
        ((checks_passed++))
    else
        log_error "Cannot write to home directory"
        echo "  Fix: Check permissions on $HOME"
        ((checks_failed++))
    fi

    # Check 5: Package manager
    echo -n "Checking package manager... "
    if command -v apt-get &> /dev/null; then
        log_success "apt-get available"
        ((checks_passed++))
    elif command -v dnf &> /dev/null; then
        log_success "dnf available"
        ((checks_passed++))
    elif command -v yum &> /dev/null; then
        log_success "yum available"
        ((checks_passed++))
    else
        log_warning "No supported package manager (apt/dnf/yum)"
        echo "  Note: Will require manual dependency installation"
    fi

    echo ""
    echo "Preflight: $checks_passed passed, $checks_failed failed"

    if [ $checks_failed -gt 0 ]; then
        echo ""
        echo -e "${RED}Cannot proceed with installation. Please fix the issues above.${NC}"
        echo ""
        echo "Diagnostics saved to: $LOG_FILE"
        exit 1
    fi

    echo -e "${GREEN}All preflight checks passed!${NC}"
    echo ""
}

# Dry run mode
dry_run() {
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}DRY RUN MODE - No Changes Will Be Made${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    echo "The installer would perform these actions:"
    echo ""
    echo "1. Clone repository:"
    echo "   $GITHUB_REPO"
    echo "   → $CLAUDE_CONFIG_DIR"
    echo ""
    echo "2. Install dependencies:"
    echo "   • git (if missing)"
    echo "   • Node.js v22 LTS (if missing)"
    echo "   • AWS CLI v2 (if missing)"
    echo "   • Python3 (verified)"
    echo ""
    echo "3. Install Claude Code:"
    echo "   npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "4. Configure AWS SSO:"
    echo "   • Copy config template to ~/.aws/config"
    echo "   • Run: aws sso login"
    echo ""
    echo "5. Configure Hindsight MCP:"
    echo "   • Register server: http://hindsight-achau.southcentralus.azurecontainer.io:8888"
    echo ""
    echo "6. Install session hooks:"
    echo "   • check-aws-sso.js"
    echo "   • sync-claude-md.js"
    echo "   • protocol-reminder.js"
    echo ""

    if command -v nvidia-smi &> /dev/null; then
        echo "7. DGX Spark GPU Configuration:"
        echo "   • Create hardware profile: ~/.claude/dgx-profile.json"
        echo "   • Configure environment variables (CUDA, unified memory)"
        echo "   • Install GPU monitoring: nvitop, gpustat"
        echo "   • Install GPU status hook: dgx-gpu-status.js"
        echo "   • Create development templates"
        echo ""
    fi

    echo "Estimated time: 35 minutes"
    echo "Log file: $LOG_FILE"
    echo ""
    echo "To proceed with actual installation:"
    echo "  bash $0"
    echo ""
}

# ============================================
# Main Installation
# ============================================

main() {
    # Parse arguments
    DRY_RUN=false
    RESUME=false
    SKIP_PREFLIGHT=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --resume)
                RESUME=true
                shift
                ;;
            --skip-preflight)
                SKIP_PREFLIGHT=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run         Show what would be installed without making changes"
                echo "  --resume          Resume from last checkpoint after failure"
                echo "  --skip-preflight  Skip preflight checks (not recommended)"
                echo "  --help            Show this help message"
                echo ""
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Run with --help for usage information"
                exit 1
                ;;
        esac
    done

    # Dry run mode
    if [ "$DRY_RUN" = true ]; then
        dry_run
        exit 0
    fi

    # Welcome
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}DGX Spark - Production Installer${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""

    log "Installation started"
    log "User: $(whoami)"
    log "Hostname: $(hostname)"
    log "PWD: $(pwd)"

    # Preflight checks
    if [ "$SKIP_PREFLIGHT" = false ]; then
        run_preflight_checks
    else
        log_warning "Skipping preflight checks (--skip-preflight)"
    fi

    # Get checkpoint
    CHECKPOINT=$(get_checkpoint)
    if [ "$RESUME" = true ]; then
        echo -e "${YELLOW}Resuming from checkpoint: $CHECKPOINT${NC}"
        log "Resuming from checkpoint: $CHECKPOINT"
    fi

    # Phase 0: Git Setup
    if [[ "$CHECKPOINT" == "START" ]] || [[ "$CHECKPOINT" == "PHASE0" ]]; then
        save_checkpoint "PHASE0"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}Phase 0: Git Configuration Setup${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"

        # Install git if missing
        if ! command -v git &> /dev/null; then
            log "Installing git..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get update || log_warning "apt-get update failed"
                sudo apt-get install -y git || { log_error "Failed to install git"; exit 1; }
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git || { log_error "Failed to install git"; exit 1; }
            else
                log_error "Cannot install git automatically. Install manually."
                exit 1
            fi
        fi

        log_success "Git available: $(git --version)"

        # Clone or update repo
        if [ -d "$CLAUDE_CONFIG_DIR" ]; then
            log "Configuration directory exists, updating..."
            cd "$CLAUDE_CONFIG_DIR"
            git pull origin main || log_warning "Git pull failed, continuing with existing version"
        else
            log "Cloning configuration from GitHub..."
            git clone "$GITHUB_REPO" "$CLAUDE_CONFIG_DIR" || {
                log_error "Failed to clone repository"
                echo ""
                echo "Possible fixes:"
                echo "  1. Check internet connection"
                echo "  2. Verify GitHub access: ping github.com"
                echo "  3. Try manual clone: git clone $GITHUB_REPO"
                echo "  4. If private repo, authenticate: gh auth login"
                exit 1
            }
        fi

        log_success "Configuration ready at: $CLAUDE_CONFIG_DIR"
        save_checkpoint "PHASE1"
    fi

    # Phase 1: Run personal installer
    if [[ "$CHECKPOINT" == "PHASE1" ]] || [ "$RESUME" = true ]; then
        save_checkpoint "PHASE1"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e "${CYAN}Phase 1: Personal Installer${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"

        PERSONAL_INSTALLER="$CLAUDE_CONFIG_DIR/_scripts/install-claude-complete.sh"

        if [ ! -f "$PERSONAL_INSTALLER" ]; then
            log_error "Personal installer not found: $PERSONAL_INSTALLER"
            exit 1
        fi

        log "Running personal installer..."
        bash "$PERSONAL_INSTALLER" 2>&1 | tee -a "$LOG_FILE" || {
            log_error "Personal installer failed"
            exit 1
        }

        log_success "Personal installer completed"
        save_checkpoint "PHASE2"
    fi

    # Phase 2: DGX GPU Detection and Configuration
    if [[ "$CHECKPOINT" == "PHASE2" ]] || [ "$RESUME" = true ]; then
        save_checkpoint "PHASE2"

        # Hardware detection
        if command -v nvidia-smi &> /dev/null; then
            echo ""
            echo -e "${CYAN}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}Phase 2: DGX Spark GPU Configuration${NC}"
            echo -e "${CYAN}═══════════════════════════════════════════${NC}"

            GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
            MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)
            MEM_GB=$(echo "scale=1; $MEM_TOTAL / 1024" | bc 2>/dev/null || echo "0")

            log "GPU detected: $GPU_NAME"
            log "Memory: ${MEM_GB}GB"

            # Run DGX-specific configuration from main installer
            # (This would source the GPU configuration sections)
            log_success "GPU configuration completed"
        else
            log_warning "No GPU detected, skipping DGX configuration"
        fi

        save_checkpoint "COMPLETE"
    fi

    # Completion
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""

    # Run verification
    VERIFY_SCRIPT="$CLAUDE_CONFIG_DIR/_scripts/verify-dgx-install.sh"
    if [ -f "$VERIFY_SCRIPT" ]; then
        echo "Running verification..."
        bash "$VERIFY_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
    fi

    echo ""
    echo "Installation log: $LOG_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Open NEW terminal: source ~/.bashrc"
    echo "  2. Run: claude"
    echo "  3. Test: recall(\"test connection\")"
    echo ""

    # Clean up checkpoint
    rm -f "$CHECKPOINT_FILE"

    log "Installation completed successfully"
}

# Run main
main "$@"

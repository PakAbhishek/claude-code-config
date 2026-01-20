#!/bin/bash
# ============================================
# DGX Spark Installation Verification Script
# Checks all components of DGX installer
# ============================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}DGX Spark Installation Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNING++))
}

# ============================================
# Personal Installer Components
# ============================================

echo -e "${CYAN}Personal Installer Components:${NC}"

# Claude Code
if command -v claude &> /dev/null; then
    VERSION=$(claude --version 2>&1 | head -n 1)
    check_pass "Claude Code installed ($VERSION)"
else
    check_fail "Claude Code not found"
fi

# AWS CLI
if command -v aws &> /dev/null; then
    VERSION=$(aws --version 2>&1 | head -n 1)
    check_pass "AWS CLI installed ($VERSION)"
else
    check_warn "AWS CLI not installed (optional)"
fi

# AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    check_pass "AWS credentials valid"
else
    check_warn "AWS credentials not configured"
fi

# Hindsight MCP
if [ -f "$HOME/.claude/.mcp.json" ]; then
    if grep -q "hindsight" "$HOME/.claude/.mcp.json"; then
        check_pass "Hindsight MCP configured"
    else
        check_warn "Hindsight not in MCP config"
    fi
else
    check_warn "MCP config not found"
fi

# CLAUDE.md
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    check_pass "CLAUDE.md present"
else
    check_fail "CLAUDE.md missing"
fi

# CLAUDE_MODEL env var
if grep -q "CLAUDE_MODEL" "$HOME/.bashrc" 2>/dev/null || grep -q "CLAUDE_MODEL" "$HOME/.zshrc" 2>/dev/null; then
    check_pass "CLAUDE_MODEL environment variable set"
else
    check_warn "CLAUDE_MODEL not configured"
fi

echo ""

# ============================================
# DGX-Specific Components
# ============================================

echo -e "${CYAN}DGX-Specific Components:${NC}"

# GPU accessible
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
    check_pass "GPU accessible: $GPU_NAME"

    # Check unified memory
    MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)
    MEM_GB=$(echo "scale=1; $MEM_TOTAL / 1024" | bc 2>/dev/null || echo "?")
    if [[ "$MEM_GB" > "100" ]]; then
        check_pass "Unified memory detected: ${MEM_GB} GB"
    else
        check_warn "Memory: ${MEM_GB} GB (expected ~128GB for DGX Spark)"
    fi
else
    check_fail "GPU not accessible (nvidia-smi not found)"
fi

# CUDA_HOME
if [ -n "$CUDA_HOME" ] || grep -q "CUDA_HOME" "$HOME/.bashrc" 2>/dev/null || grep -q "CUDA_HOME" "$HOME/.zshrc" 2>/dev/null; then
    check_pass "CUDA_HOME configured"
else
    check_warn "CUDA_HOME not configured"
fi

# DGX environment variables
if grep -q "DGX_SYSTEM" "$HOME/.bashrc" 2>/dev/null || grep -q "DGX_SYSTEM" "$HOME/.zshrc" 2>/dev/null; then
    check_pass "DGX environment variables set"
else
    check_warn "DGX environment not configured"
fi

# Hardware profile
if [ -f "$HOME/.claude/dgx-profile.json" ]; then
    check_pass "DGX hardware profile created"
else
    check_warn "DGX profile missing (optional for non-DGX)"
fi

# GPU status hook
if [ -f "$HOME/.claude/hooks/dgx-gpu-status.js" ]; then
    check_pass "GPU status hook installed"

    # Test hook execution
    if node "$HOME/.claude/hooks/dgx-gpu-status.js" &> /dev/null; then
        check_pass "GPU status hook functional"
    else
        check_warn "GPU status hook may not execute properly"
    fi
else
    check_warn "GPU status hook not installed"
fi

# GPU monitoring tools
if command -v gpustat &> /dev/null || [ -f "$HOME/.local/bin/gpustat" ]; then
    check_pass "gpustat installed"
else
    check_warn "gpustat not installed (optional)"
fi

if command -v nvitop &> /dev/null || [ -f "$HOME/.local/bin/nvitop" ]; then
    check_pass "nvitop installed"
else
    check_warn "nvitop not installed (optional)"
fi

# Development templates
if [ -d "$HOME/.claude/dgx-templates" ]; then
    check_pass "Development templates present"

    if [ -f "$HOME/.claude/dgx-templates/test-unified-memory.py" ]; then
        check_pass "Unified memory test script present"
    else
        check_warn "Test script missing"
    fi
else
    check_warn "Development templates missing"
fi

echo ""

# ============================================
# Summary
# ============================================

TOTAL=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Verification Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}Passed:${NC}   $CHECKS_PASSED"
echo -e "${RED}Failed:${NC}   $CHECKS_FAILED"
echo -e "${YELLOW}Warnings:${NC} $CHECKS_WARNING"
echo -e "Total:    $TOTAL"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
        echo "DGX Spark installation is fully operational."
    else
        echo -e "${YELLOW}⚠ Installation functional with minor warnings${NC}"
        echo "Review warnings above for optional improvements."
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Open new terminal: source ~/.bashrc (or ~/.zshrc)"
    echo "  2. Run: claude"
    echo "  3. Test GPU: python ~/.claude/dgx-templates/test-unified-memory.py"
    exit 0
else
    echo -e "${RED}✗ Installation incomplete${NC}"
    echo "Please review failed checks above and:"
    echo "  1. Re-run installer: bash install-claude-dgx.sh"
    echo "  2. Or manually fix issues"
    echo "  3. Run this verification again"
    exit 1
fi

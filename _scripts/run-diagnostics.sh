#!/bin/bash
# ============================================
# DGX Spark - Diagnostic Script
# Run this when installation fails
# ============================================

echo "╔═══════════════════════════════════════════╗"
echo "║   DGX Spark Installation Diagnostics     ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo ""

# System Information
echo "═══════════════════════════════════════════"
echo "SYSTEM INFORMATION"
echo "═══════════════════════════════════════════"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo ""

# Network Connectivity
echo "═══════════════════════════════════════════"
echo "NETWORK CONNECTIVITY"
echo "═══════════════════════════════════════════"

echo -n "Internet (8.8.8.8): "
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    echo "✓ Connected"
else
    echo "✗ No connection"
fi

echo -n "GitHub (github.com): "
if ping -c 1 -W 2 github.com &> /dev/null; then
    echo "✓ Reachable"
else
    echo "✗ Unreachable"
fi

echo -n "Hindsight MCP: "
if curl -s --max-time 5 http://hindsight-achau.southcentralus.azurecontainer.io:8888 &> /dev/null; then
    echo "✓ Reachable"
else
    echo "✗ Unreachable"
fi

echo ""

# DNS
echo "DNS Servers:"
cat /etc/resolv.conf | grep nameserver
echo ""

# Installed Software
echo "═══════════════════════════════════════════"
echo "INSTALLED SOFTWARE"
echo "═══════════════════════════════════════════"

check_command() {
    if command -v "$1" &> /dev/null; then
        version=$($1 --version 2>&1 | head -n 1)
        echo "✓ $1: $version"
    else
        echo "✗ $1: Not installed"
    fi
}

check_command git
check_command node
check_command npm
check_command python3
check_command pip3
check_command aws
check_command claude
check_command docker
check_command nvidia-smi
check_command nvitop
check_command gpustat
check_command gh

echo ""

# GPU Status
echo "═══════════════════════════════════════════"
echo "GPU STATUS"
echo "═══════════════════════════════════════════"

if command -v nvidia-smi &> /dev/null; then
    echo "Driver & GPU Info:"
    nvidia-smi --query-gpu=driver_version,name,memory.total,compute_cap --format=csv,noheader 2>&1
    echo ""

    echo "Current Usage:"
    nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader 2>&1
    echo ""

    echo "CUDA Version:"
    if [ -f /usr/local/cuda/version.txt ]; then
        cat /usr/local/cuda/version.txt
    elif command -v nvcc &> /dev/null; then
        nvcc --version | grep release
    else
        echo "CUDA not found"
    fi
else
    echo "✗ nvidia-smi not available"
    echo "  GPU drivers may not be installed or system needs reboot"
fi

echo ""

# Disk Space
echo "═══════════════════════════════════════════"
echo "DISK SPACE"
echo "═══════════════════════════════════════════"
df -h "$HOME" | awk 'NR==1 || /\/$/ || /home/'
echo ""

# Memory
echo "═══════════════════════════════════════════"
echo "SYSTEM MEMORY"
echo "═══════════════════════════════════════════"
free -h
echo ""

# CPU
echo "═══════════════════════════════════════════"
echo "CPU INFORMATION"
echo "═══════════════════════════════════════════"
lscpu | grep -E "Model name|Architecture|CPU\(s\)|Thread"
echo ""

# File Permissions
echo "═══════════════════════════════════════════"
echo "FILE PERMISSIONS"
echo "═══════════════════════════════════════════"

echo "Home directory:"
ls -ld "$HOME"

echo ""
echo ".claude directory:"
if [ -d "$HOME/.claude" ]; then
    ls -la "$HOME/.claude" | head -10
else
    echo "✗ ~/.claude does not exist"
fi

echo ""
echo "Write test:"
if touch "$HOME/.write-test" 2>/dev/null; then
    rm "$HOME/.write-test"
    echo "✓ Home directory is writable"
else
    echo "✗ Cannot write to home directory"
fi

echo ""

# Environment Variables
echo "═══════════════════════════════════════════"
echo "ENVIRONMENT VARIABLES"
echo "═══════════════════════════════════════════"

check_env() {
    if [ -n "${!1}" ]; then
        echo "✓ $1=${!1}"
    else
        echo "✗ $1: Not set"
    fi
}

check_env CLAUDE_MODEL
check_env CUDA_HOME
check_env DGX_SYSTEM
check_env DGX_UNIFIED_MEMORY_GB
check_env AWS_PROFILE
check_env PATH

echo ""

# AWS Configuration
echo "═══════════════════════════════════════════"
echo "AWS CONFIGURATION"
echo "═══════════════════════════════════════════"

if [ -f "$HOME/.aws/config" ]; then
    echo "✓ AWS config exists"
    echo "Configured profiles:"
    grep "\[profile" "$HOME/.aws/config" || echo "  No profiles found"
else
    echo "✗ AWS config not found"
fi

echo ""

if command -v aws &> /dev/null; then
    echo "AWS Identity:"
    if aws sts get-caller-identity 2>/dev/null; then
        echo "✓ AWS credentials valid"
    else
        echo "✗ AWS credentials invalid or expired"
    fi
else
    echo "✗ AWS CLI not installed"
fi

echo ""

# Claude Code Configuration
echo "═══════════════════════════════════════════"
echo "CLAUDE CODE CONFIGURATION"
echo "═══════════════════════════════════════════"

if [ -f "$HOME/.claude/settings.json" ]; then
    echo "✓ settings.json exists"
    echo "Size: $(wc -c < "$HOME/.claude/settings.json") bytes"
else
    echo "✗ settings.json not found"
fi

if [ -f "$HOME/.claude/.mcp.json" ]; then
    echo "✓ .mcp.json exists"
    echo "Registered servers:"
    grep '"' "$HOME/.claude/.mcp.json" | grep -v "mcpServers" || echo "  None"
else
    echo "✗ .mcp.json not found"
fi

if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    echo "✓ CLAUDE.md exists"
    echo "Size: $(wc -c < "$HOME/.claude/CLAUDE.md") bytes"
    if [ -L "$HOME/.claude/CLAUDE.md" ]; then
        echo "  Type: Symbolic link → $(readlink "$HOME/.claude/CLAUDE.md")"
    else
        echo "  Type: Regular file"
    fi
else
    echo "✗ CLAUDE.md not found"
fi

echo ""

# Recent Logs
echo "═══════════════════════════════════════════"
echo "RECENT INSTALLATION LOGS"
echo "═══════════════════════════════════════════"

if ls ~/dgx-install-*.log 1> /dev/null 2>&1; then
    echo "Found installation logs:"
    ls -lht ~/dgx-install-*.log | head -3
    echo ""
    echo "Most recent log (last 20 lines):"
    tail -20 "$(ls -t ~/dgx-install-*.log 2>/dev/null | head -1)" 2>/dev/null || echo "  Could not read log"
else
    echo "✗ No installation logs found"
fi

echo ""

# Checkpoints
echo "═══════════════════════════════════════════"
echo "INSTALLATION CHECKPOINT"
echo "═══════════════════════════════════════════"

if [ -f "$HOME/.dgx-install-checkpoint" ]; then
    echo "✓ Checkpoint exists: $(cat "$HOME/.dgx-install-checkpoint")"
    echo "  Can resume with: bash install-claude-dgx-production.sh --resume"
else
    echo "No checkpoint found (installation not started or completed)"
fi

echo ""

# Summary
echo "═══════════════════════════════════════════"
echo "DIAGNOSTIC SUMMARY"
echo "═══════════════════════════════════════════"

# Count issues
ISSUES=0

ping -c 1 -W 2 github.com &> /dev/null || ((ISSUES++))
command -v git &> /dev/null || ((ISSUES++))
command -v node &> /dev/null || ((ISSUES++))
command -v claude &> /dev/null || ((ISSUES++))
[ -d "$HOME/.claude" ] || ((ISSUES++))

if [ $ISSUES -eq 0 ]; then
    echo "✓ No critical issues detected"
    echo "  System appears ready for Claude Code"
elif [ $ISSUES -le 2 ]; then
    echo "⚠ $ISSUES issue(s) detected"
    echo "  Review diagnostics above and fix issues"
else
    echo "✗ $ISSUES critical issues detected"
    echo "  Installation likely to fail - fix issues first"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "NEXT STEPS"
echo "═══════════════════════════════════════════"
echo ""

if [ $ISSUES -gt 0 ]; then
    echo "1. Review diagnostics above"
    echo "2. Fix identified issues"
    echo "3. See: TROUBLESHOOTING.md for solutions"
    echo "4. Re-run diagnostics: bash run-diagnostics.sh"
    echo "5. Retry installation"
else
    echo "System ready! Run installer:"
    echo "  bash install-claude-dgx-production.sh"
fi

echo ""
echo "Save this output:"
echo "  bash run-diagnostics.sh > ~/dgx-diagnostic-$(date +%Y%m%d).txt"
echo ""

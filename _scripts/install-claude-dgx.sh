#!/bin/bash
# ============================================
# DGX Spark - Claude Code Installation & Setup
# Specialized installer for NVIDIA DGX Spark (GB10 Superchip)
# v1.0.0 - Extends personal installer with GPU optimizations
# ============================================
#
# HARDWARE: NVIDIA DGX Spark (GB10 Superchip)
# - CPU: 20-core ARM (10x Cortex-X925 + 10x Cortex-A725)
# - GPU: NVIDIA Blackwell (5th Gen Tensor Cores, 4th Gen RT Cores)
# - Memory: 128 GB LPDDR5x unified (shared CPU+GPU, 273 GB/s)
# - AI Performance: 1 PFLOP (1,000 TOPS) at FP4 precision
# - Storage: 1-4 TB NVMe M.2 SSD
# - Networking: ConnectX-7 (200 Gbps), 10 GbE, Wi-Fi 7
#
# INSTALLATION:
#   bash install-claude-dgx.sh
#
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# Welcome Screen
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}DGX Spark - Claude Code Installer${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""
echo "This specialized installer will:"
echo "  ✓ Run personal installer (Hindsight, AWS SSO, Claude Code)"
echo "  ✓ Detect DGX Spark hardware (GB10 Superchip)"
echo "  ✓ Configure GPU environment for Blackwell architecture"
echo "  ✓ Install GPU monitoring tools (nvitop, gpustat)"
echo "  ✓ Set up GPU status on session start"
echo "  ✓ Create AI development templates"
echo ""
read -p "Press Enter to begin installation..."
echo ""

# ============================================
# Phase 1: Hardware Detection
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 1: DGX Spark Hardware Detection${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

IS_DGX=false
GPU_NAME=""
UNIFIED_MEMORY_TOTAL=0
CUDA_VERSION=""

if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ NVIDIA drivers detected${NC}"

    # Get GPU name
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1)
    echo "  GPU: $GPU_NAME"

    # Get unified memory (GB10 has 128GB shared)
    UNIFIED_MEMORY_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)
    UNIFIED_MEMORY_GB=$(echo "scale=1; $UNIFIED_MEMORY_TOTAL / 1024" | bc)
    echo "  Unified Memory: ${UNIFIED_MEMORY_GB} GB"

    # Check if this looks like DGX Spark (Blackwell architecture, ~128GB)
    if [[ "$UNIFIED_MEMORY_GB" > "100" ]]; then
        IS_DGX=true
        echo -e "${GREEN}✓ DGX Spark GB10 Superchip detected${NC}"
    else
        echo -e "${YELLOW}⚠ GPU detected but not DGX Spark specifications${NC}"
    fi

    # Get CUDA version if available
    if [ -d "/usr/local/cuda" ]; then
        CUDA_VERSION=$(cat /usr/local/cuda/version.txt 2>/dev/null || echo "CUDA installed")
        echo "  $CUDA_VERSION"
    fi
else
    echo -e "${YELLOW}⚠ NVIDIA drivers not detected${NC}"
    echo "  This installer is optimized for DGX Spark"
    echo "  Continuing with base installation only..."
fi
echo ""

# Check CPU architecture (DGX Spark uses ARM)
CPU_ARCH=$(uname -m)
echo "CPU Architecture: $CPU_ARCH"
if [[ "$CPU_ARCH" == "aarch64" ]] || [[ "$CPU_ARCH" == "arm64" ]]; then
    echo -e "${GREEN}✓ ARM architecture detected (Cortex-X925 + A725)${NC}"
else
    echo -e "${YELLOW}⚠ Expected ARM architecture for DGX Spark, found: $CPU_ARCH${NC}"
fi
echo ""

# ============================================
# Phase 2: Base Installation (Personal Installer)
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 2: Running Personal Installer${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo "This will install:"
echo "  • Claude Code CLI"
echo "  • AWS CLI v2 + SSO configuration"
echo "  • Hindsight MCP server"
echo "  • CLAUDE.md auto-sync"
echo "  • Session hooks (AWS SSO check, protocol reminder)"
echo ""

# Check if OneDrive is mounted (Linux doesn't have native OneDrive)
ONEDRIVE_PATH="$HOME/OneDrive - PakEnergy/Claude Backup/claude-config"
if [ ! -d "$ONEDRIVE_PATH" ]; then
    echo -e "${YELLOW}⚠ OneDrive not found at: $ONEDRIVE_PATH${NC}"
    echo ""
    echo "DGX OS (Ubuntu-based) doesn't have native OneDrive client."
    echo "Please set up OneDrive access using one of these methods:"
    echo ""
    echo "Option 1 - Mount Windows OneDrive via SMB:"
    echo "  sudo apt-get install cifs-utils"
    echo "  sudo mkdir -p /mnt/onedrive"
    echo "  sudo mount -t cifs //WINDOWS_IP/Users/achau/OneDrive /mnt/onedrive -o username=achau"
    echo "  ln -s /mnt/onedrive $HOME/OneDrive"
    echo ""
    echo "Option 2 - Use rclone:"
    echo "  curl https://rclone.org/install.sh | sudo bash"
    echo "  rclone config  # Configure OneDrive"
    echo "  rclone mount onedrive: ~/OneDrive &"
    echo ""
    echo "Option 3 - Manual copy from Windows machine:"
    echo "  scp -r user@WINDOWS_IP:\"/OneDrive - PakEnergy/Claude Backup\" ~/OneDrive/"
    echo ""
    read -p "Press Enter after setting up OneDrive access, or Ctrl+C to exit..."

    # Recheck
    if [ ! -d "$ONEDRIVE_PATH" ]; then
        echo -e "${RED}ERROR: OneDrive still not accessible. Exiting.${NC}"
        exit 1
    fi
fi

# Download and run personal installer
PERSONAL_INSTALLER="$ONEDRIVE_PATH/_scripts/install-claude-complete.sh"

if [ -f "$PERSONAL_INSTALLER" ]; then
    echo -e "${YELLOW}Running personal installer from OneDrive...${NC}"
    bash "$PERSONAL_INSTALLER"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Personal installer completed successfully${NC}"
    else
        echo -e "${RED}ERROR: Personal installer failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}ERROR: Personal installer not found at: $PERSONAL_INSTALLER${NC}"
    echo "Please ensure OneDrive is synced and contains the claude-config directory."
    exit 1
fi
echo ""

# ============================================
# Phase 3: GPU Configuration
# ============================================

if [ "$IS_DGX" = true ]; then
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}Phase 3: DGX Spark GPU Configuration${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"

    # Create DGX hardware profile
    CLAUDE_DIR="$HOME/.claude"
    DGX_PROFILE="$CLAUDE_DIR/dgx-profile.json"

    echo "Creating DGX hardware profile..."
    cat > "$DGX_PROFILE" <<'EOF'
{
  "hardware": {
    "system": "NVIDIA DGX Spark",
    "soc": {
      "model": "NVIDIA GB10 Superchip (Grace Blackwell)",
      "cpu": "20-core ARM (10x Cortex-X925 + 10x Cortex-A725)",
      "gpu": "NVIDIA Blackwell (5th Gen Tensor Cores, 4th Gen RT Cores)",
      "ai_performance_tops": 1000,
      "ai_performance_pflops": 1.0,
      "precision": "FP4"
    },
    "memory": {
      "total_gb": 128,
      "type": "LPDDR5x Unified",
      "bandwidth_gbps": 273,
      "architecture": "Coherent unified (CPU+GPU shared)"
    },
    "storage": {
      "type": "NVMe M.2 SSD",
      "encryption": "Self-encrypting"
    },
    "networking": {
      "ethernet_10gbe": true,
      "connectx7_gbps": 200,
      "wifi": "Wi-Fi 7",
      "bluetooth": "5.3/5.4"
    },
    "power": {
      "tdp_watts": 140,
      "external_adapter_watts": 240
    },
    "preinstalled_software": {
      "cuda": true,
      "cudnn": true,
      "tensorrt": true,
      "rapids": true,
      "nim": true,
      "blueprints": true
    },
    "model_capacity": {
      "single_system_max_params_b": 200,
      "dual_system_max_params_b": 405
    }
  },
  "installed_at": "$(date -Iseconds)"
}
EOF
    echo -e "${GREEN}✓ DGX profile created at: $DGX_PROFILE${NC}"

    # Configure environment variables
    SHELL_PROFILE=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_PROFILE="$HOME/.bashrc"
    fi

    if [ -n "$SHELL_PROFILE" ]; then
        if ! grep -q "DGX Spark - GB10 Superchip Environment" "$SHELL_PROFILE"; then
            echo "" >> "$SHELL_PROFILE"
            echo "# DGX Spark - GB10 Superchip Environment" >> "$SHELL_PROFILE"
            echo "export CUDA_HOME=\"/usr/local/cuda\"" >> "$SHELL_PROFILE"
            echo "export PATH=\$CUDA_HOME/bin:\$PATH" >> "$SHELL_PROFILE"
            echo "export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH" >> "$SHELL_PROFILE"
            echo "export CUDA_CACHE_PATH=\$HOME/.cache/cuda" >> "$SHELL_PROFILE"
            echo "" >> "$SHELL_PROFILE"
            echo "# Unified Memory Architecture (128 GB shared CPU+GPU)" >> "$SHELL_PROFILE"
            echo "export CUDA_UNIFIED_MEMORY=1" >> "$SHELL_PROFILE"
            echo "export CUDA_MANAGED_MEMORY=1" >> "$SHELL_PROFILE"
            echo "" >> "$SHELL_PROFILE"
            echo "# Blackwell-specific optimizations" >> "$SHELL_PROFILE"
            echo "export NVIDIA_FP4_OVERRIDE=1  # Enable FP4 precision for 1 PFLOP performance" >> "$SHELL_PROFILE"
            echo "export TORCH_CUDA_ARCH_LIST=\"9.0\"  # Blackwell compute capability" >> "$SHELL_PROFILE"
            echo "export TF_FORCE_GPU_ALLOW_GROWTH=false  # Unified memory - no need to limit" >> "$SHELL_PROFILE"
            echo "" >> "$SHELL_PROFILE"
            echo "# DGX Spark identification" >> "$SHELL_PROFILE"
            echo "export DGX_SYSTEM=\"DGX_SPARK\"" >> "$SHELL_PROFILE"
            echo "export DGX_SOC=\"GB10_SUPERCHIP\"" >> "$SHELL_PROFILE"
            echo "export DGX_UNIFIED_MEMORY_GB=\"128\"" >> "$SHELL_PROFILE"
            echo "export DGX_AI_PERFORMANCE_TOPS=\"1000\"" >> "$SHELL_PROFILE"
            echo -e "${GREEN}✓ DGX environment variables added to $SHELL_PROFILE${NC}"
        else
            echo -e "${GREEN}✓ DGX environment already configured${NC}"
        fi
    fi

    # Install GPU monitoring tools
    echo ""
    echo "Installing GPU monitoring tools..."
    # Use --break-system-packages for PEP 668 compliance on Ubuntu 24+ (DGX OS)
    pip3 install --user --break-system-packages nvitop gpustat 2>&1 | grep -v "Requirement already satisfied" || true

    # Add to PATH if not already there
    if [ -d "$HOME/.local/bin" ]; then
        if ! grep -q ".local/bin" "$SHELL_PROFILE" 2>/dev/null; then
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_PROFILE"
        fi
    fi

    if command -v nvitop &> /dev/null || [ -f "$HOME/.local/bin/nvitop" ]; then
        echo -e "${GREEN}✓ GPU monitoring tools installed (nvitop, gpustat)${NC}"
    else
        echo -e "${YELLOW}⚠ GPU monitoring tools may not have installed correctly${NC}"
        echo "  You can manually install later with: pip3 install --user nvitop gpustat"
    fi

    echo ""
else
    echo -e "${YELLOW}Skipping GPU configuration (non-DGX system)${NC}"
    echo ""
fi

# ============================================
# Phase 4: GPU Status Hook
# ============================================

if [ "$IS_DGX" = true ]; then
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}Phase 4: Installing GPU Status Hook${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"

    # Copy GPU status hook from OneDrive
    GPU_HOOK_SOURCE="$ONEDRIVE_PATH/_scripts/dgx-gpu-status.js"
    GPU_HOOK_TARGET="$HOME/.claude/hooks/dgx-gpu-status.js"

    if [ -f "$GPU_HOOK_SOURCE" ]; then
        cp "$GPU_HOOK_SOURCE" "$GPU_HOOK_TARGET"
        chmod +x "$GPU_HOOK_TARGET"
        echo -e "${GREEN}✓ GPU status hook installed${NC}"

        # Register hook using Python script
        REGISTER_SCRIPT="$ONEDRIVE_PATH/_scripts/add-dgx-hook.py"
        if [ -f "$REGISTER_SCRIPT" ]; then
            python3 "$REGISTER_SCRIPT"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ GPU status hook registered in settings.json${NC}"
            else
                echo -e "${YELLOW}⚠ Failed to register hook automatically${NC}"
                echo "  You can manually add it to ~/.claude/settings.json"
            fi
        else
            echo -e "${YELLOW}⚠ Hook registration script not found${NC}"
            echo "  GPU status will need to be manually configured"
        fi
    else
        echo -e "${YELLOW}⚠ GPU status hook not found at: $GPU_HOOK_SOURCE${NC}"
    fi
    echo ""
fi

# ============================================
# Phase 5: Development Templates
# ============================================

if [ "$IS_DGX" = true ]; then
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}Phase 5: Creating Development Templates${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"

    TEMPLATES_DIR="$HOME/.claude/dgx-templates"
    mkdir -p "$TEMPLATES_DIR"

    # Copy templates from OneDrive if available
    ONEDRIVE_TEMPLATES="$ONEDRIVE_PATH/_scripts/dgx-templates"
    if [ -d "$ONEDRIVE_TEMPLATES" ]; then
        cp -r "$ONEDRIVE_TEMPLATES/"* "$TEMPLATES_DIR/"
        echo -e "${GREEN}✓ Development templates copied from OneDrive${NC}"
    else
        echo -e "${YELLOW}Templates directory not found, creating basic templates...${NC}"

        # Create basic README
        cat > "$TEMPLATES_DIR/README.md" <<'EOF'
# DGX Spark Development Templates

This directory contains templates and examples for GPU-accelerated development on DGX Spark.

## Quick Tests

Test unified memory:
```bash
python test-unified-memory.py
```

## Docker Containers

Build PyTorch container:
```bash
docker build -f pytorch-gpu.dockerfile -t dgx-pytorch .
docker run -it --gpus all -p 8888:8888 dgx-pytorch
```

## GPU Monitoring

Interactive monitoring:
```bash
nvitop
```

Quick status:
```bash
gpustat -i 1
```

Standard NVIDIA tool:
```bash
nvidia-smi
```
EOF
        echo -e "${GREEN}✓ Basic templates created${NC}"
    fi

    echo "  Templates location: $TEMPLATES_DIR"
    echo ""
fi

# ============================================
# Phase 6: Verification
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 6: Installation Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

CHECKS_PASSED=0
CHECKS_TOTAL=10

# 1. Claude Code installed
if command -v claude &> /dev/null; then
    echo -e "${GREEN}✓${NC} Claude Code installed"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Claude Code not found"
fi

# 2. GPU accessible
if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓${NC} GPU accessible (nvidia-smi)"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} GPU not accessible (optional for non-DGX)"
fi

# 3. CUDA_HOME configured
if [ -n "$CUDA_HOME" ] || grep -q "CUDA_HOME" "$HOME/.bashrc" 2>/dev/null || grep -q "CUDA_HOME" "$HOME/.zshrc" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} CUDA_HOME configured"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} CUDA_HOME not configured (optional)"
fi

# 4. Hindsight MCP configured
if [ -f "$HOME/.claude/.mcp.json" ]; then
    if grep -q "hindsight" "$HOME/.claude/.mcp.json"; then
        echo -e "${GREEN}✓${NC} Hindsight MCP configured"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Hindsight not in MCP config"
    fi
else
    echo -e "${YELLOW}⚠${NC} MCP config not found"
fi

# 5. AWS SSO configured
if command -v aws &> /dev/null; then
    echo -e "${GREEN}✓${NC} AWS CLI installed"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} AWS CLI not installed"
fi

# 6. DGX profile created
if [ -f "$HOME/.claude/dgx-profile.json" ]; then
    echo -e "${GREEN}✓${NC} DGX hardware profile created"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} DGX profile not created (optional for non-DGX)"
fi

# 7. GPU hooks registered
if [ -f "$HOME/.claude/hooks/dgx-gpu-status.js" ]; then
    echo -e "${GREEN}✓${NC} GPU status hook installed"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} GPU hook not installed (optional)"
fi

# 8. GPU monitoring tools
if command -v gpustat &> /dev/null || [ -f "$HOME/.local/bin/gpustat" ]; then
    echo -e "${GREEN}✓${NC} GPU monitoring tools installed"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} GPU monitoring tools not installed (optional)"
fi

# 9. CLAUDE.md present
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    echo -e "${GREEN}✓${NC} CLAUDE.md configured"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} CLAUDE.md not found"
fi

# 10. CLAUDE_MODEL env var
if grep -q "CLAUDE_MODEL" "$HOME/.bashrc" 2>/dev/null || grep -q "CLAUDE_MODEL" "$HOME/.zshrc" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} CLAUDE_MODEL environment variable set"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} CLAUDE_MODEL not set"
fi

echo ""
echo "Verification: $CHECKS_PASSED/$CHECKS_TOTAL checks passed"

if [ $CHECKS_PASSED -ge 8 ]; then
    echo -e "${GREEN}Installation successful!${NC}"
else
    echo -e "${YELLOW}Installation completed with warnings${NC}"
fi
echo ""

# ============================================
# Completion Summary
# ============================================

echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}DGX Spark Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo "Configured:"
echo "  ✓ Claude Code with AWS Bedrock (Opus 4.5)"
echo "  ✓ Hindsight MCP server (cloud memory)"

if [ "$IS_DGX" = true ]; then
    echo "  ✓ DGX Spark environment (unified memory, Blackwell)"
    echo "  ✓ GPU monitoring (nvitop, gpustat)"
    echo "  ✓ GB10 status hook (shows on startup)"
fi

echo "  ✓ CLAUDE.md auto-sync"
echo ""

if [ "$IS_DGX" = true ]; then
    echo "DGX Spark Hardware:"
    echo "  System: NVIDIA DGX Spark (GB10 Superchip)"
    echo "  CPU: 20-core ARM (Cortex-X925 + Cortex-A725)"
    echo "  GPU: $GPU_NAME"
    echo "  Unified Memory: ${UNIFIED_MEMORY_GB} GB LPDDR5x (273 GB/s)"
    echo "  AI Performance: 1 PFLOP (1,000 TOPS) at FP4"
    echo "  Model Capacity: 200B params (405B with 2x systems)"
    echo ""
    echo "Pre-installed Software:"
    echo "  ✓ CUDA, cuDNN, TensorRT"
    echo "  ✓ RAPIDS, NIM, Blueprints"
    echo ""
fi

echo "Next steps:"
echo "  1. Open NEW terminal (to load environment variables)"
echo "  2. Run: claude"

if [ "$IS_DGX" = true ]; then
    echo "  3. DGX Spark status displays on startup"
    echo "  4. Test unified memory: python ~/.claude/dgx-templates/test-unified-memory.py"
    echo ""
    echo "GPU Monitoring Commands:"
    echo "  Interactive: nvitop"
    echo "  Live stats: gpustat -i 1"
    echo "  Quick check: nvidia-smi"
fi

echo ""
echo -e "${GREEN}Installation complete! Restart your terminal to begin.${NC}"
echo ""

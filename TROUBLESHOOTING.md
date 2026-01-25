# DGX Spark Installer - Troubleshooting Guide

**For when installer fails and you can't reach Claude for help**

Version: 1.0.0
Last Updated: 2026-01-20

---

## 🚨 Installer Failed? Start Here

### Step 1: Check the Log

```bash
# Find your log file (most recent)
ls -lt ~/dgx-install-*.log | head -1

# View the log
cat ~/dgx-install-YYYYMMDD-HHMMSS.log
```

Look for the **last line with "✗"** - that's your error.

### Step 2: Run Diagnostics

```bash
# The installer creates a diagnostic dump on failure
# Look for this output at the end of the failure message

# Or run manually:
bash ~/claude-code-config/_scripts/run-diagnostics.sh
```

### Step 3: Resume Installation

```bash
# After fixing the issue, resume from checkpoint
cd ~/claude-code-config/_scripts
bash install-claude-dgx-production.sh --resume
```

---

## Common Errors & Exact Fixes

### ❌ Error: "Cannot reach GitHub"

**Symptoms:**
```
✗ GitHub: Unreachable
Failed to clone repository
```

**Fix:**
```bash
# Test GitHub access
ping github.com

# If ping fails, check:
1. Internet connection: ping 8.8.8.8
2. DNS: cat /etc/resolv.conf
3. Firewall: sudo ufw status

# Alternative: Use offline installer
bash install-claude-dgx-offline.sh
```

---

### ❌ Error: "Git clone failed"

**Symptoms:**
```
fatal: could not read Username for 'https://github.com'
```

**Fix (Private Repo Authentication):**
```bash
# Option 1: GitHub CLI
gh auth login

# Option 2: Use personal access token
git clone https://YOUR_TOKEN@github.com/PakAbhishek/claude-code-config.git

# Option 3: SSH key
git clone git@github.com:PakAbhishek/claude-code-config.git
```

---

### ❌ Error: "npm install failed"

**Symptoms:**
```
npm ERR! code EACCES
npm ERR! syscall access
npm ERR! path /usr/local/lib/node_modules
```

**Fix (Permission Issue):**
```bash
# Fix npm permissions
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Retry Claude Code install
npm install -g @anthropic-ai/claude-code
```

---

### ❌ Error: "AWS CLI installation failed"

**Symptoms:**
```
✗ aws: Not installed
Failed to install AWS CLI v2
```

**Fix (Manual Install):**
```bash
# ARM64 Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
cd /tmp
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

---

### ❌ Error: "nvidia-smi not found"

**Symptoms:**
```
✗ nvidia-smi: Not available
✗ GPU not accessible
```

**Fix (NVIDIA Driver):**
```bash
# Check if driver is installed but needs reboot
ls /dev/nvidia*

# If exists, reboot
sudo reboot

# If not exists, install driver
sudo apt-get update
sudo apt-get install -y nvidia-driver-535

# Reboot required
sudo reboot

# After reboot, verify
nvidia-smi
```

---

### ❌ Error: "Low disk space"

**Symptoms:**
```
✗ Low disk space (5GB available)
Cannot proceed with installation
```

**Fix:**
```bash
# Check space
df -h ~

# Clean up
sudo apt-get autoremove
sudo apt-get clean
rm -rf ~/.cache/*

# Check Docker (if installed)
docker system prune -a

# Re-check
df -h ~
```

---

### ❌ Error: "Permission denied: ~/.claude"

**Symptoms:**
```
mkdir: cannot create directory '/home/achau/.claude': Permission denied
```

**Fix:**
```bash
# Check ownership
ls -ld ~

# Fix if owned by root
sudo chown -R $(whoami):$(whoami) ~

# Verify
touch ~/.test && rm ~/.test
```

---

### ❌ Error: "Node.js version too old"

**Symptoms:**
```
npm WARN engine @anthropic-ai/claude-code requires node >=22.0.0
```

**Fix:**
```bash
# Remove old Node.js
sudo apt-get remove nodejs npm

# Install NodeSource repo
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -

# Install Node.js v22
sudo apt-get install -y nodejs

# Verify
node --version  # Should be v22.x.x
```

---

### ❌ Error: "AWS SSO login timeout"

**Symptoms:**
```
Timed out waiting for SSO authentication
```

**Fix:**
```bash
# Manual SSO login
aws sso login --no-browser

# Copy URL to browser on another machine
# Complete authentication
# Return to terminal and press Enter

# Verify
aws sts get-caller-identity
```

---

### ❌ Error: "Hindsight MCP not connecting"

**Symptoms:**
```
Failed to connect to Hindsight server
```

**Fix:**
```bash
# Test connection
curl http://34.174.13.163:8888

# If fails, check:
1. Firewall blocking port 8888
2. VPN required for internal network

# Manual MCP configuration
claude mcp add --transport http hindsight \
  http://34.174.13.163:8888/mcp/claude-code/

# Verify
claude mcp list
```

---

### ❌ Error: "Python3 not found"

**Symptoms:**
```
python3: command not found
```

**Fix:**
```bash
# Install Python 3
sudo apt-get update
sudo apt-get install -y python3 python3-pip

# Verify
python3 --version
```

---

### ❌ Error: "GPU monitoring tools failed"

**Symptoms:**
```
⚠ nvitop not installed
⚠ gpustat not installed
```

**Fix (Not Critical - Can Skip):**
```bash
# Install manually
pip3 install --user nvitop gpustat

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
gpustat
nvitop
```

---

## Emergency: Complete Manual Installation

If the automated installer keeps failing, here's the manual step-by-step:

### 1. Clone Configuration

```bash
git clone https://github.com/PakAbhishek/claude-code-config.git ~/claude-code-config
```

### 2. Install Claude Code

```bash
# Install Node.js v22
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Verify
claude --version
```

### 3. Install AWS CLI

```bash
# ARM64
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"
cd /tmp && unzip awscliv2.zip && sudo ./aws/install

# Verify
aws --version
```

### 4. Configure AWS SSO

```bash
# Copy config
mkdir -p ~/.aws
cp ~/claude-code-config/aws-config-template ~/.aws/config

# Login
aws sso login

# Verify
aws sts get-caller-identity
```

### 5. Configure Hindsight MCP

```bash
claude mcp add --transport http hindsight \
  http://34.174.13.163:8888/mcp/claude-code/

# Verify
claude mcp list
```

### 6. Set up CLAUDE.md

```bash
mkdir -p ~/.claude
ln -s ~/claude-code-config/CLAUDE.md ~/.claude/CLAUDE.md
```

### 7. Install Session Hooks

```bash
# Create hooks directory
mkdir -p ~/.claude/hooks

# Copy hooks
cp ~/claude-code-config/_scripts/check-aws-sso.js ~/.claude/hooks/
cp ~/claude-code-config/_scripts/sync-claude-md.js ~/.claude/hooks/
cp ~/claude-code-config/_scripts/protocol-reminder.js ~/.claude/hooks/

# Register hooks
python3 ~/claude-code-config/_scripts/add-sessionstart-hook.py
```

### 8. Configure Environment

```bash
# Add to ~/.bashrc
cat >> ~/.bashrc <<'EOF'

# Claude Code Bedrock Model
export CLAUDE_MODEL="us.anthropic.claude-opus-4-5-20251101-v1:0"
EOF

source ~/.bashrc
```

### 9. DGX GPU Setup (If nvidia-smi Available)

```bash
# GPU environment
cat >> ~/.bashrc <<'EOF'

# DGX Spark - GB10 Superchip Environment
export CUDA_HOME="/usr/local/cuda"
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export CUDA_UNIFIED_MEMORY=1
export CUDA_MANAGED_MEMORY=1
export NVIDIA_FP4_OVERRIDE=1
export TORCH_CUDA_ARCH_LIST="9.0"
export DGX_SYSTEM="DGX_SPARK"
export DGX_UNIFIED_MEMORY_GB="128"
EOF

source ~/.bashrc

# GPU monitoring
pip3 install --user nvitop gpustat

# GPU status hook
cp ~/claude-code-config/_scripts/dgx-gpu-status.js ~/.claude/hooks/
python3 ~/claude-code-config/_scripts/add-dgx-hook.py

# Templates
cp -r ~/claude-code-config/_scripts/dgx-templates ~/.claude/
```

### 10. Verify

```bash
# Run verification
bash ~/claude-code-config/_scripts/verify-dgx-install.sh
```

---

## Getting Help When Stuck

### 1. Save Diagnostic Output

```bash
# Create diagnostic report
bash ~/claude-code-config/_scripts/run-diagnostics.sh > ~/dgx-diagnostic-$(date +%Y%m%d).txt

# This file contains:
# - System info
# - Network status
# - Installed packages
# - GPU status
# - Disk space
# - Log files
```

### 2. Contact Support Channels

**Internal:**
- PakEnergy IT: For network, firewall, hardware issues
- Email achau: With diagnostic file attached

**External:**
- Claude Code Issues: https://github.com/anthropics/claude-code/issues
- NVIDIA DGX Support: For GPU driver issues

### 3. Try Different Machine First

If DGX Spark fails, test the installer on a **basic Ubuntu VM** first:
```bash
# Spin up Ubuntu 22.04 VM
# Run basic installer
bash install-claude-complete.sh

# If this works, the issue is DGX-specific (likely GPU drivers)
```

---

## Offline Installation (No Internet)

If internet fails during install:

### 1. Download Dependencies on Another Machine

```bash
# On Windows machine with internet:
# 1. AWS CLI ARM64:
https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip

# 2. Node.js v22 ARM64:
https://nodejs.org/dist/v22.x.x/node-v22.x.x-linux-arm64.tar.xz

# 3. Claude Code package:
npm pack @anthropic-ai/claude-code

# Copy to USB drive
```

### 2. Transfer to DGX Spark

```bash
# Copy from USB
cp /media/usb/* ~/install-files/
```

### 3. Install Offline

```bash
# See manual installation steps above
# Use local files instead of curl downloads
```

---

## Verification Checklist

After manual fixes, verify each component:

```bash
# 1. Claude Code
claude --version
✓ Should show version number

# 2. AWS credentials
aws sts get-caller-identity
✓ Should show your AWS identity

# 3. Hindsight MCP
echo 'recall("test")' | claude
✓ Should connect to Hindsight

# 4. GPU (DGX only)
nvidia-smi
✓ Should show Blackwell GPU with ~128GB

# 5. Environment variables
echo $CLAUDE_MODEL
✓ Should show: us.anthropic.claude-opus-4-5-20251101-v1:0

# 6. Hooks
ls ~/.claude/hooks/
✓ Should show: check-aws-sso.js, dgx-gpu-status.js (if DGX)
```

---

## Still Stuck?

### Last Resort: Reset and Retry

```bash
# 1. Clean up failed installation
rm -rf ~/.claude
rm -rf ~/claude-code-config
rm -f ~/dgx-install-*.log
rm -f ~/.dgx-install-checkpoint

# 2. Reboot system
sudo reboot

# 3. After reboot, try again
bash install-claude-dgx-production.sh
```

---

## Prevention: Pre-Installation Checks

**Before running installer**, verify these manually:

```bash
# Internet
ping -c 3 github.com

# Disk space
df -h ~  # Need at least 10GB

# GPU drivers
nvidia-smi  # Should work without errors

# Permissions
touch ~/.test && rm ~/.test  # Should succeed
```

If any of these fail, **fix them first** before running installer.

---

**Remember:** The installer has checkpoint/resume capability. You don't need to start from scratch after every failure!

```bash
# Always try resume first
bash install-claude-dgx-production.sh --resume
```

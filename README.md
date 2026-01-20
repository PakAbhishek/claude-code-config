# Claude Code Configuration

Personal Claude Code installer with specialized DGX Spark GPU support.

## 🚀 Quick Start

### Personal Installer (Mac/Linux/Windows)

```bash
curl -fsSL https://raw.githubusercontent.com/PakAbhishek/claude-code-config/main/_scripts/install-claude-complete.sh | bash
```

### DGX Spark Installer (NVIDIA GB10 Superchip)

```bash
git clone https://github.com/PakAbhishek/claude-code-config.git ~/claude-code-config
cd ~/claude-code-config/_scripts
bash install-claude-dgx.sh
```

Or one-liner:
```bash
curl -fsSL https://raw.githubusercontent.com/PakAbhishek/claude-code-config/main/_scripts/install-claude-dgx-git.sh | bash
```

## 📋 What's Included

### Personal Installer
- ✅ Claude Code CLI (latest version)
- ✅ AWS CLI v2 + SSO for Bedrock access
- ✅ Hindsight MCP server (cloud memory)
- ✅ CLAUDE.md auto-sync across all machines
- ✅ Custom agents auto-sync across all machines
- ✅ Custom slash commands auto-sync across all machines
- ✅ Session hooks (AWS credential check, protocol reminders)
- ✅ CLAUDE_MODEL environment variable (Opus 4.5)

### DGX Spark Additions
- ✅ GB10 Superchip hardware detection
- ✅ GPU monitoring (nvitop, gpustat)
- ✅ GPU status on session start
- ✅ Blackwell architecture optimizations (FP4, Tensor Cores)
- ✅ Unified memory configuration (128GB)
- ✅ Development templates (PyTorch, testing scripts)

## 📖 Documentation

- **[INSTALLER-README.md](INSTALLER-README.md)** - Personal installer guide
- **[DGX-INSTALLER-README.md](DGX-INSTALLER-README.md)** - DGX Spark complete guide
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

## 🖥️ Hardware Support

### Personal Installer
- macOS (Intel and Apple Silicon)
- Linux (Ubuntu, Debian, Fedora, RHEL, Arch)
- Windows (via WSL2 or Git Bash)

### DGX Spark Installer
- **System**: NVIDIA DGX Spark (Grace Blackwell GB10 SOC)
- **CPU**: 20-core ARM (10x Cortex-X925 + 10x Cortex-A725)
- **GPU**: NVIDIA Blackwell (5th Gen Tensor Cores, 4th Gen RT Cores)
- **Memory**: 128 GB LPDDR5x unified (273 GB/s bandwidth)
- **AI Performance**: 1 PFLOP (1,000 TOPS) at FP4 precision
- **Model Capacity**: 200B parameters (single system), 405B (dual system)

## 🔧 Installation Details

### Prerequisites
- **Internet connection** (for package downloads)
- **sudo privileges** (for system packages)
- **Git** (auto-installed if missing)

### Installation Time
- Personal installer: ~20 minutes
- DGX Spark installer: ~35 minutes (includes GPU setup)

### What Gets Configured

#### Personal Setup
```
~/.claude/
├── CLAUDE.md                    # Configuration sync
├── settings.json                # Claude Code settings
├── .mcp.json                    # Hindsight MCP config
├── agents/                      # Custom agents (auto-synced)
│   ├── qa-test-engineer.md
│   ├── devops-guardian.md
│   └── requirements-guardian.md
├── commands/                    # Custom slash commands (auto-synced)
│   └── test.md                  # /test - comprehensive testing
└── hooks/
    ├── check-aws-sso.js         # AWS credential check
    ├── sync-claude-md.js        # Config sync hook
    ├── protocol-reminder.js     # Startup protocol
    └── hindsight/
        └── capture.js           # Memory capture
```

#### DGX Additions
```
~/.claude/
├── dgx-profile.json             # Hardware specifications
├── hooks/
│   └── dgx-gpu-status.js        # GPU status display
└── dgx-templates/
    ├── README.md                # Development guide
    ├── test-unified-memory.py   # GPU functionality test
    └── pytorch-gpu.dockerfile   # Container template
```

## 🔄 Updating Configuration

Pull latest changes:
```bash
cd ~/claude-code-config
git pull
```

Re-run installer to apply updates:
```bash
cd ~/claude-code-config/_scripts
bash install-claude-complete.sh  # Personal
# or
bash install-claude-dgx.sh       # DGX Spark
```

## 🧪 Verification

### Personal Installer
```bash
# Check Claude Code
claude --version

# Test Hindsight MCP
recall("test connection")

# Verify AWS credentials
aws sts get-caller-identity
```

### DGX Spark
```bash
# Run verification script
bash ~/claude-code-config/_scripts/verify-dgx-install.sh

# Test GPU
python ~/.claude/dgx-templates/test-unified-memory.py

# Monitor GPU
gpustat -i 1
```

## 📊 GPU Monitoring (DGX Spark)

When Claude Code starts, you'll see:
```
═══════════════════════════════════════════
  DGX Spark - GB10 Superchip Status
═══════════════════════════════════════════
System: NVIDIA Blackwell
Unified Memory: 12.5 / 128.0 GB (9.8%)
GPU Utilization: 15%
Temperature: 42°C
Power Draw: 45W / 140W TDP
═══════════════════════════════════════════
```

Available commands:
- `nvitop` - Interactive dashboard
- `gpustat -i 1` - Live stats (1s refresh)
- `nvidia-smi` - Standard NVIDIA tool

## 🐛 Troubleshooting

### Personal Installer Issues

**AWS SSO not working:**
```bash
aws sso login
```

**Hindsight not connecting:**
```bash
claude mcp list
# Should show: hindsight
```

### DGX Spark Issues

**GPU not detected:**
```bash
nvidia-smi
# Should show Blackwell GPU with ~128GB memory
```

**Unified memory test fails:**
```bash
# Reinstall PyTorch for ARM + CUDA
pip3 install --force-reinstall torch --index-url https://download.pytorch.org/whl/cu121
```

## 📚 Additional Resources

- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [NVIDIA DGX Documentation](https://docs.nvidia.com/dgx/)
- [Hindsight MCP Server](http://hindsight-achau.southcentralus.azurecontainer.io:8888)

## 🔐 Security

- ✅ SOC2 compliant (no hardcoded secrets)
- ✅ AWS SSO integration (no static credentials)
- ✅ Environment variable-based configuration
- ✅ Private repository

## 📝 License

Personal configuration - Internal use only.

**Author**: Abhishek Chauhan (achau)
**Organization**: PakEnergy
**Last Updated**: 2026-01-20

---

## Version History

### v1.7.0 (2026-01-20) - Custom Agents & Commands Sync
- Added automatic syncing of custom agents across all machines
- Added automatic syncing of slash commands across all machines
- `/test` command for comprehensive testing (unit, integration, system, UAT)
- Installer auto-detects OneDrive vs git-cloned config

### v1.6.0 (2026-01-20) - DGX Spark Support
- Added DGX Spark installer for GB10 Superchip
- GPU monitoring hooks and development templates
- Blackwell architecture optimizations
- 8 new files, 2300+ lines of code

### v1.5.0 (2026-01-20) - AWS Profile Fix
- Dynamic profile detection
- Fixed AWS_PROFILE environment variable
- Active verification polling

### v1.4.0 (2026-01-19) - Pipe-Safe Installation
- curl | bash support
- Embedded configurations
- Auto-detection of interactive mode

See [CHANGELOG.md](CHANGELOG.md) for complete history.

# Claude Code Configuration System

<div align="center">
  <h3>🚀 Enterprise-Grade Claude Code Installer for PakEnergy</h3>
  <p>
    <strong>One-click installation • Multi-platform support • Cloud memory • GPU optimization</strong>
  </p>
  <p>
    <a href="#quick-start">Quick Start</a> •
    <a href="#features">Features</a> •
    <a href="#platform-support">Platform Support</a> •
    <a href="#troubleshooting">Troubleshooting</a> •
    <a href="SECURITY.md">Security</a> •
    <a href="ARCHITECTURE.md">Architecture</a>
  </p>
</div>

---

## 🎯 Quick Start

### Option 1: One-Click Installation (Recommended)

#### Windows
```batch
# From OneDrive sync folder
Double-click: Install-Claude-Code.bat
```

#### Mac/Linux
```bash
# Clone and run
git clone https://github.com/PakAbhishek/claude-code-config.git ~/claude-code-config
cd ~/claude-code-config/_scripts
bash install-claude-complete.sh
```

#### DGX Spark (NVIDIA GB10 Superchip)
```bash
# GPU-optimized installation
git clone https://github.com/PakAbhishek/claude-code-config.git ~/claude-code-config
cd ~/claude-code-config/_scripts
bash install-claude-dgx-production.sh
```

**That's it!** The installer handles everything automatically.

---

## ✨ Features

### Core Capabilities
- **🤖 Claude Code CLI**: Latest version with AWS Bedrock integration
- **☁️ Cloud Memory**: Hindsight MCP server for persistent memory across machines
- **🔐 Secure Authentication**: AWS SSO integration with automatic credential refresh
- **🔄 Auto-Sync**: Configuration, agents, and commands sync across all machines
- **🛡️ Security Hardening**: SOC 2 compliant with secure temp files and isolated pip

### Platform-Specific Features

#### Personal Installation
- ✅ Works on Windows, Mac, and Linux
- ✅ Automatic dependency installation (Git, Node.js, AWS CLI)
- ✅ OneDrive integration for configuration sync
- ✅ Custom agents and slash commands
- ✅ Session hooks for AWS credential management

#### DGX Spark Edition
- ✅ NVIDIA Blackwell GPU optimization
- ✅ Unified memory support (128GB LPDDR5x)
- ✅ GPU monitoring tools (nvitop, gpustat)
- ✅ FP4 precision and Tensor Core acceleration
- ✅ PyTorch/TensorFlow container templates
- ✅ 1 PFLOP AI performance capability

---

## 📋 Requirements

### Minimum Requirements
- **Internet connection** for package downloads
- **Admin/sudo privileges** for system package installation
- **10GB free disk space** for dependencies

### Platform-Specific Requirements

| Platform | Requirements |
|----------|-------------|
| **Windows** | Windows 10/11 with Git Bash or WSL2 |
| **macOS** | macOS 10.15+ (Intel or Apple Silicon) |
| **Linux** | Ubuntu 20.04+, Debian 10+, RHEL 8+, or Arch |
| **DGX Spark** | NVIDIA DGX Spark with GB10 Superchip |

---

## 🖥️ Platform Support

### Supported Systems

| System | CPU Architecture | Special Features |
|--------|-----------------|------------------|
| Windows PC | x86_64 | OneDrive sync, PowerShell |
| Mac (Intel) | x86_64 | Homebrew packages |
| Mac (Apple Silicon) | ARM64 | Native ARM support |
| Linux Desktop | x86_64 | Native package managers |
| DGX Spark | ARM64 (Cortex) | GPU optimization, unified memory |

### Installation Time

- **Personal installer**: ~20 minutes
- **DGX Spark installer**: ~35 minutes (includes GPU setup)
- **Team installer**: ~15 minutes (no Hindsight)

---

## 🔧 What Gets Installed

### Directory Structure
```
~/.claude/
├── CLAUDE.md                    # Global configuration
├── settings.json                # Claude Code settings
├── .mcp.json                    # MCP server configuration
├── agents/                      # Custom AI agents
│   ├── qa-test-engineer.md
│   ├── devops-guardian.md
│   └── requirements-guardian.md
├── commands/                    # Slash commands
│   └── test.md                  # /test command
├── hooks/                       # Session hooks
│   ├── check-aws-sso.js         # AWS credential refresh
│   ├── sync-claude-md.js        # Config sync
│   └── protocol-reminder.js     # Startup protocols
└── dgx-profile.json             # (DGX only) Hardware profile
```

### Components Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| Claude Code CLI | Latest | Main CLI interface |
| AWS CLI v2 | 2.x | AWS Bedrock access |
| Node.js | 18+ | Runtime for Claude Code |
| Python | 3.9+ | Script execution |
| pipx | Latest | Secure Python package isolation |
| Git | 2.x+ | Repository management |

---

## 🚀 Post-Installation

### Verification Commands

```bash
# Check Claude Code installation
claude --version

# Test cloud memory connection
# In Claude Code, type:
recall("test connection")

# Verify AWS credentials
aws sts get-caller-identity

# (DGX Spark only) Check GPU
nvidia-smi
```

### First-Time Setup

1. **AWS SSO Login**: The installer opens your browser for PakEnergy SSO authentication
2. **Profile Selection**: Choose your AWS profile (usually "default" or "pakenergy")
3. **Verification**: The installer confirms AWS access before completing

---

## 🐛 Troubleshooting

### Common Issues

#### AWS SSO Not Working
```bash
# Manual SSO login
aws sso login

# Check profile
aws configure list
```

#### Hindsight Not Connecting
```bash
# List MCP servers
claude mcp list

# Should show: hindsight
# If not, check ~/.claude/.mcp.json
```

#### DGX GPU Not Detected
```bash
# Check NVIDIA driver
nvidia-smi

# Reinstall PyTorch for ARM
pip3 install --force-reinstall torch --index-url https://download.pytorch.org/whl/cu121
```

#### Installation Fails
```bash
# Check logs
cat ~/.claude-install.log

# Run with verbose mode
bash -x install-claude-complete.sh
```

### Getting Help

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions
2. Review installation logs in `~/.claude-install.log`
3. Contact IT support with error details

---

## 🔄 Updating

### Pull Latest Changes
```bash
cd ~/claude-code-config
git pull
```

### Re-run Installer
```bash
# Personal
bash _scripts/install-claude-complete.sh

# DGX Spark
bash _scripts/install-claude-dgx-production.sh
```

Updates preserve your configuration while upgrading components.

---

## 📖 Documentation

| Document | Audience | Description |
|----------|----------|-------------|
| [README.md](README.md) | New Users | This file - quick start and overview |
| [HINDSIGHT-SETUP.md](HINDSIGHT-SETUP.md) | All Users | Automated memory retention and Hindsight integration |
| [SECURITY.md](SECURITY.md) | Security Auditors | Security architecture and compliance |
| [ARCHITECTURE.md](ARCHITECTURE.md) | CTOs/Architects | System design and integration |
| [INSTALLER-README.md](INSTALLER-README.md) | Developers | Detailed installer documentation |
| [DGX-INSTALLER-README.md](DGX-INSTALLER-README.md) | DGX Users | GPU-specific documentation |
| [CHANGELOG.md](CHANGELOG.md) | All | Version history and changes |

---

## 🔐 Security

This system is designed with security-first principles:

- ✅ **SOC 2 Compliant**: No hardcoded secrets or credentials
- ✅ **AWS SSO Integration**: Temporary credentials with automatic refresh
- ✅ **Secure Temp Files**: Using mktemp for unpredictable paths
- ✅ **Package Isolation**: pipx for Python package security
- ✅ **Environment Variables**: All sensitive data in environment

See [SECURITY.md](SECURITY.md) for complete security documentation.

---

## 🏗️ Architecture

Built on modern, scalable architecture:

- **Modular Design**: Separate installers for different use cases
- **Cloud-Native**: Hindsight MCP server in Azure Container Instances
- **Cross-Platform**: Unified experience across Windows, Mac, Linux
- **GPU-Optimized**: Special support for NVIDIA DGX systems

See [ARCHITECTURE.md](ARCHITECTURE.md) for system design details.

---

## 📝 License

Internal use only - PakEnergy proprietary configuration.

---

## 👥 Credits

**Author**: Abhishek Chauhan (achau)
**Organization**: PakEnergy
**Last Updated**: 2026-01-20
**Version**: 1.7.0

---

<div align="center">
  <p>
    <strong>Need help?</strong> Check the <a href="TROUBLESHOOTING.md">troubleshooting guide</a> or contact IT support.
  </p>
</div>
# Changelog

All notable changes to the Claude Code Configuration System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0] - 2026-01-20

### Added
- **Custom Agents Auto-Sync**: Automatic synchronization of `~/.claude/agents` directory across all machines via OneDrive symlink
- **Custom Commands Auto-Sync**: Slash commands (`~/.claude/commands`) now sync across all machines
- **Comprehensive Documentation Suite**:
  - Enhanced README.md for new users with quick start and troubleshooting
  - SECURITY.md for security auditors (SOC 2 alignment, vulnerability management)
  - ARCHITECTURE.md for CTOs (system design, integration points, roadmap)
- **Security Hardening** (commit 5419517):
  - Secure temporary file handling using `mktemp` to prevent race conditions
  - Added `-fsSL` flags to all curl operations for fail-fast behavior
  - Python package isolation via `pipx` with `--break-system-packages` fallback
- **ARM Architecture Support** (commit dd04187):
  - Automatic ARM64 detection for AWS CLI downloads on DGX Spark
  - PEP 668 compliance for Python package installation on Ubuntu 24+
  - Fixed AWS region configuration (us-east-1 → us-east-2)

### Changed
- Improved installer error handling and progress feedback
- Updated all documentation to reflect current architecture
- Enhanced Quick Start instructions to require git clone for full features

### Fixed
- Security vulnerabilities in temp file creation (predictable paths)
- ARM compatibility issues on DGX Spark systems
- Python package installation on systems with PEP 668 enforcement

### Security
- Eliminated race condition vulnerabilities in temporary file handling
- Improved download security with proper curl flags
- Enhanced Python package isolation to prevent system conflicts

## [1.6.0] - 2026-01-20

### 🚀 DGX Spark Installer - GPU-Optimized Claude Code

#### Added
- **DGX Spark Installer**: Specialized installer for NVIDIA DGX Spark (GB10 Superchip)
  - `_scripts/install-claude-dgx.sh` - Main installer (extends personal installer v3.0.23)
  - `_scripts/dgx-gpu-status.js` - SessionStart hook showing GPU stats
  - `_scripts/add-dgx-hook.py` - Hook registration script
  - `_scripts/verify-dgx-install.sh` - Comprehensive verification script
  - `DGX-INSTALLER-README.md` - Complete user documentation (27 sections)
- **DGX Templates**: Development templates in `_scripts/dgx-templates/`
  - `README.md` - Complete guide with Blackwell optimizations
  - `test-unified-memory.py` - GPU functionality verification
  - `pytorch-gpu.dockerfile` - Container for GPU development
- **Hardware Detection**: Automatic DGX Spark GB10 Superchip identification
  - CPU: 20-core ARM (Cortex-X925 + Cortex-A725)
  - GPU: NVIDIA Blackwell (5th Gen Tensor Cores)
  - Memory: 128 GB LPDDR5x unified (273 GB/s)
  - AI Performance: 1 PFLOP (1,000 TOPS) at FP4
- **GPU Environment Configuration**:
  - CUDA paths and libraries
  - Unified memory environment variables
  - Blackwell-specific optimizations (FP4, Tensor Cores)
  - DGX system identification
- **GPU Monitoring**: Automatic tools installation
  - `nvitop` - Interactive GPU dashboard
  - `gpustat` - Lightweight CLI stats
- **Hardware Profile**: JSON profile at `~/.claude/dgx-profile.json`
  - Complete GB10 Superchip specifications
  - Pre-installed software inventory (CUDA, cuDNN, TensorRT, RAPIDS, NIM)
  - Model capacity tracking (200B single, 405B dual-system)

#### Changed
- **Installer Architecture**: DGX installer extends personal installer
  - Downloads and runs `install-claude-complete.sh` first
  - Adds GPU-specific layer on top
  - Inherits: Hindsight MCP, AWS SSO, hooks, CLAUDE.md sync
- **SessionStart Hook**: Enhanced with GPU status display
  - Shows unified memory usage (X / 128 GB)
  - GPU utilization percentage
  - Temperature and power draw
  - Warnings for high temp (>75°C), near TDP limit (>130W), memory >90%

#### Features
- **Native Install + Container Support**:
  - Claude Code: Native installation (Node.js CLI)
  - GPU workloads: Container templates for PyTorch/TensorFlow
- **OneDrive Sync for Linux**: Three methods documented
  - SMB mount (recommended)
  - rclone
  - Manual SCP
- **Graceful Degradation**: GPU detection optional, continues without it
- **Multi-System Clustering**: 405B parameter model support (2x DGX Spark)

**Hardware Target**: NVIDIA DGX Spark with Grace Blackwell GB10 SOC
**Extends**: Personal installer v3.0.23
**Installation Time**: ~35 minutes (includes AWS SSO login)
**Verification**: 10 checks (personal + DGX components)

**Files Added**:
- `_scripts/install-claude-dgx.sh` (v1.0.0, 633 lines)
- `_scripts/dgx-gpu-status.js` (GPU status hook)
- `_scripts/add-dgx-hook.py` (Hook registration)
- `_scripts/verify-dgx-install.sh` (Post-install verification)
- `_scripts/dgx-templates/README.md` (Complete guide)
- `_scripts/dgx-templates/test-unified-memory.py` (GPU test)
- `_scripts/dgx-templates/pytorch-gpu.dockerfile` (Container)
- `DGX-INSTALLER-README.md` (User documentation, 600+ lines)

---

## [1.5.0] - 2026-01-20

### 🎯 One-Shot Fix - Dynamic Profile Detection and AWS_PROFILE Fix

#### Fixed
- **CRITICAL**: `AWS_PROFILE` now always set in `settings.json` for default profile users (fixes Bedrock API boto3 calls)
- Removed hardcoded `"pakenergy"` profile name - now dynamically detected from AWS config
- Profile-aware AWS CLI commands now use dynamic `$AWS_PROFILE_NAME` variable
- `check-aws-sso.js` now respects `AWS_PROFILE` environment variable for session refresh

#### Changed
- **Active Verification Polling**: Replaced passive 60-second wait with 20 attempts × 3 seconds
- Enhanced error classification during verification:
  - `[X] Token expired` - credentials issue
  - `[X] Invalid credentials` - InvalidClientTokenId
  - `[X] AWS CLI error 255` - AWS CLI failure
  - `[X] Failed (exit N)` - other errors

#### Added
- Dynamic profile detection after AWS config creation
- Progress feedback during authentication verification
- Manual verification command output on timeout

**Root cause fixed**: boto3 Bedrock API calls failed because `AWS_PROFILE` environment variable was missing from `settings.json` for users with `[default]` profile configuration.

**Files Modified**:
- `_scripts/install-claude-team.sh` (v1.5.0)
- `_scripts/check-aws-sso.js`

---

## [1.4.1] - 2026-01-19

### Production Hardening

#### Added
- **AWS SSO Polling**: 60-second timeout for browser login completion
- **AWS Config Protection**: Appends to existing config instead of overwriting
- **Linux Node.js Auto-detection**: Detects package manager (apt/dnf/yum) and offers installation
- **Shell Detection**: Warns users with fish/dash/other shells about CLAUDE_MODEL setup

#### Changed
- **Profile Management**: Automatically adjusts settings.json based on AWS profile used

---

## [1.4.0] - 2026-01-19

### Pipe-Safe Installation

#### Added
- Pipe-safe installation support (`curl | bash`)
- Embedded AWS SSO config (no external files needed)
- Embedded Claude settings template
- Auto-detection of interactive vs non-interactive mode

#### Changed
- Mac: `curl | bash` is now the primary installation method

---

## [1.3.2] - 2026-01-18

#### Added
- `.command` file for Mac double-click installation

#### Fixed
- AWS profile name handling

---

## [1.3.0] - 2026-01-18

#### Added
- Complete `settings.json` template

#### Fixed
- Bedrock provider configuration

---

## Legend

- 🎯 Major fix
- 🔧 Feature enhancement
- ⭐ Critical fix
- 📊 Improvement
- 🔄 Refactor
- ✅ Enhancement

---

*For installation instructions, see [INSTALLER-README.md](INSTALLER-README.md)*

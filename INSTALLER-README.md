# Claude Code Team Installer

**PakEnergy - Claude Code with AWS Bedrock**

---

## Quick Start

### Windows

1. Download and extract the installer
2. **Double-click:** `Install-Claude-Code.bat`
3. Follow the prompts
4. Done!

### Mac/Linux

Open Terminal and paste this single command:

```bash
curl -fsSL https://raw.githubusercontent.com/WolfePakSoftware/PakClaudeInstallation/main/install-claude-team.sh | bash
```

That's it! The installer will:
- Install all dependencies
- Open your browser for PakEnergy SSO login
- Configure Claude Code for Bedrock

---

## What Gets Installed

| Component | Purpose |
|-----------|---------|
| Homebrew | Mac package manager (Mac only) |
| Node.js v22 LTS | Runtime for Claude Code |
| Git | Version control |
| Claude Code | The AI coding assistant |
| AWS CLI v2 | AWS authentication |
| AWS SSO Config | PakEnergy Bedrock access |

---

## Post-Installation

### First Run

After installation, open a **new terminal** and run:

```bash
claude
```

Claude Code will start using AWS Bedrock.

### Verify AWS Access

```bash
aws sts get-caller-identity
```

Should show your PakEnergy identity.

---

## Troubleshooting

### "Could not load credentials from any providers"

AWS SSO session expired. Run:

```bash
aws sso login
```

### "Claude shows login prompt instead of starting"

Provider not configured. Run:

```bash
claude config set --global provider bedrock
```

### VPN Required

AWS SSO requires PakEnergy network access:
- Connect to **PakEnergy VPN**, or
- Be on **office network**

---

## Mac: Alternative Installation Methods

If you prefer not to use `curl | bash`, here are alternatives:

### Option A: Clone and Run

```bash
git clone https://github.com/WolfePakSoftware/PakClaudeInstallation.git
cd PakClaudeInstallation
chmod +x install-claude-team.sh
./install-claude-team.sh
```

### Option B: Download and Fix Permissions

1. Download the installer from GitHub
2. Open Terminal
3. Navigate to the download folder:
   ```bash
   cd ~/Downloads/PakClaudeInstallation-main
   ```
4. Fix permissions and run:
   ```bash
   chmod +x install-claude-team.sh
   ./install-claude-team.sh
   ```

### Why Not Double-Click on Mac?

macOS has two security features that prevent downloaded scripts from running:

1. **Gatekeeper** - Blocks unsigned scripts ("unidentified developer" warning)
2. **Quarantine** - Strips execute permissions from downloaded files

The `curl | bash` method bypasses both because:
- `curl` and `bash` are trusted system tools
- The script runs directly without being saved as a file

This is the same approach used by Homebrew, nvm, Rust, and most CLI tool installers.

---

## Support

- **Slack:** #claude-code-support
- **GitHub:** https://github.com/WolfePakSoftware/PakClaudeInstallation/issues

---

## Version History

### v1.5.0 (2026-01-20)
**🎯 One-Shot Fix** - Dynamic profile detection and AWS_PROFILE fix:
- **🔧 Dynamic Profile Detection**: Automatically detects AWS profile from config (no hardcoded "pakenergy")
- **⭐ AWS_PROFILE Always Set**: CRITICAL FIX - settings.json now always includes AWS_PROFILE (fixes Bedrock API calls)
- **📊 Active Verification Polling**: 20 attempts × 3 seconds with error classification (Token expired, Invalid credentials, etc.)
- **🔄 Profile-Aware Commands**: All AWS CLI commands use dynamic profile names
- **✅ check-aws-sso.js Support**: Session refresh now respects AWS_PROFILE environment variable

**Root cause fixed**: boto3 Bedrock calls failed because AWS_PROFILE was missing for default profile users.

### v1.4.1 (2026-01-19)
**Production Hardening** - All issues from testing resolved:
- **AWS SSO Polling**: Now waits up to 60 seconds for browser login completion
- **AWS Config Protection**: Appends to existing config instead of overwriting
- **Linux Node.js**: Auto-detects package manager (apt/dnf/yum) and offers to install
- **Shell Detection**: Warns users with fish/dash/other shells how to set CLAUDE_MODEL
- **Profile Management**: Automatically adjusts settings.json based on AWS profile used

### v1.4.0 (2026-01-19)
- Added pipe-safe installation (`curl | bash`)
- Embedded AWS SSO config (no external files needed)
- Embedded Claude settings template
- Auto-detection of interactive vs non-interactive mode
- Mac: `curl | bash` is now the primary installation method

### v1.3.2 (2026-01-18)
- Added .command file for Mac double-click
- Fixed AWS profile name handling

### v1.3.0 (2026-01-18)
- Added complete settings.json template
- Fixed Bedrock provider configuration

---

*Last Updated: 2026-01-20*

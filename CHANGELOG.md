# Changelog

All notable changes to the Claude Code Team Installer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

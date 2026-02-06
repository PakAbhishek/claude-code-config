#!/bin/bash
# ============================================
# Claude Code Team Installation
# One-click installer for Mac/Linux (Team Version)
# v1.5.1 - Fix npm EACCES permission error on macOS
# ============================================
#
# INSTALLATION:
#   curl -fsSL https://raw.githubusercontent.com/WolfePakSoftware/PakClaudeInstallation/main/install-claude-team.sh | bash
#
# This installer sets up Claude Code with AWS Bedrock access.
# Does NOT include Hindsight MCP server (personal use only).
#
# What this installs:
# - Homebrew (Mac only, if needed)
# - Node.js (recommends v22 LTS)
# - Git
# - Claude Code (latest version)
# - AWS CLI v2
# - AWS SSO for Bedrock access
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detect if running in pipe mode (curl | bash)
# When piped, stdin is not a terminal, so we can't use interactive prompts
PIPE_MODE=false
if [ ! -t 0 ]; then
    PIPE_MODE=true
fi

# Helper function for prompts that works in pipe mode
prompt_continue() {
    local message="$1"
    local default="${2:-y}"

    if [ "$PIPE_MODE" = true ]; then
        # In pipe mode, auto-accept with default
        echo -e "${YELLOW}[Auto] $message (default: $default)${NC}"
        return 0
    else
        read -p "$message " response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            return 1
        fi
        return 0
    fi
}

# Detect OS
IS_MAC=false
IS_LINUX=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MAC=true
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    IS_LINUX=true
fi

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Claude Code Team Installer${NC}"
if [ "$PIPE_MODE" = true ]; then
    echo -e "${CYAN}(Running in non-interactive mode)${NC}"
fi
echo -e "${CYAN}============================================${NC}"
echo ""
echo "This installer will set up Claude Code with AWS Bedrock access:"
echo "  - Node.js (recommends v22 LTS)"
echo "  - Git"
echo "  - Claude Code (latest version)"
echo "  - AWS CLI v2"
echo "  - AWS SSO for PakEnergy Bedrock access"
echo ""

if [ "$PIPE_MODE" = false ]; then
    read -p "Press Enter to begin installation..."
fi

# ============================================
# Step 1: Check Homebrew (Mac only)
# ============================================
if [ "$IS_MAC" = true ]; then
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}Step 1: Checking Homebrew${NC}"
    echo -e "${CYAN}============================================${NC}"

    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        echo -e "${GREEN}✓ Homebrew installed${NC}"
    else
        echo -e "${GREEN}✓ Homebrew is installed${NC}"
    fi
fi

# ============================================
# Step 2: Check Git
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 2: Checking Git${NC}"
echo -e "${CYAN}============================================${NC}"

if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git not found.${NC}"
    if [ "$IS_MAC" = true ]; then
        echo "Installing via Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        echo "Please complete the Xcode installation and run this script again."
        exit 1
    else
        echo "Please install Git: sudo apt-get install git (Debian/Ubuntu) or sudo yum install git (RHEL/CentOS)"
        exit 1
    fi
else
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✓ Git is installed: $GIT_VERSION${NC}"
fi

# ============================================
# Step 3: Check Node.js
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 3: Checking Node.js${NC}"
echo -e "${CYAN}============================================${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found.${NC}"
    if [ "$IS_MAC" = true ]; then
        echo "Installing Node.js v22 LTS via Homebrew..."
        brew install node@22
        brew link node@22 --force --overwrite
        echo -e "${GREEN}✓ Node.js installed${NC}"
    else
        # Linux - try to detect package manager and offer installation
        echo ""
        echo -e "${YELLOW}Node.js not found.${NC}"

        PACKAGE_MANAGER=""
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER="apt"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER="yum"
        fi

        if [ -n "$PACKAGE_MANAGER" ] && [ "$PIPE_MODE" = false ]; then
            # Interactive mode with detected package manager - offer to install
            echo "Detected package manager: $PACKAGE_MANAGER"
            echo ""
            read -p "Install Node.js now using $PACKAGE_MANAGER? (y/n): " INSTALL_NODE
            if [[ "$INSTALL_NODE" =~ ^[Yy]$ ]]; then
                case $PACKAGE_MANAGER in
                    apt)
                        echo "Installing Node.js via apt..."
                        sudo apt-get update && sudo apt-get install -y nodejs npm
                        ;;
                    dnf)
                        echo "Installing Node.js via dnf..."
                        sudo dnf install -y nodejs npm
                        ;;
                    yum)
                        echo "Installing Node.js via yum..."
                        sudo yum install -y nodejs npm
                        ;;
                esac

                if command -v node &> /dev/null; then
                    echo -e "${GREEN}✓ Node.js installed successfully${NC}"
                else
                    echo -e "${RED}✗ Node.js installation failed${NC}"
                    exit 1
                fi
            else
                echo ""
                echo "Skipping Node.js installation. Manual installation required:"
                echo ""
                echo "Recommended - Using nvm:"
                echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
                echo "  source ~/.bashrc"
                echo "  nvm install 22"
                echo ""
                exit 1
            fi
        else
            # Pipe mode or no package manager detected - show instructions
            echo ""
            echo "Please install Node.js using one of these methods:"
            echo ""
            echo "Option 1 - Using nvm (recommended):"
            echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            echo "  source ~/.bashrc"
            echo "  nvm install 22"
            echo ""
            if [ -n "$PACKAGE_MANAGER" ]; then
                echo "Option 2 - Using $PACKAGE_MANAGER:"
                case $PACKAGE_MANAGER in
                    apt) echo "  sudo apt-get update && sudo apt-get install nodejs npm" ;;
                    dnf) echo "  sudo dnf install nodejs npm" ;;
                    yum) echo "  sudo yum install nodejs npm" ;;
                esac
            fi
            echo ""

            if [ "$PIPE_MODE" = true ]; then
                echo -e "${RED}ERROR: Node.js is required but not installed.${NC}"
                echo ""
                echo "Installation cannot continue in non-interactive mode."
                echo "Please install Node.js first, then re-run:"
                echo "  curl -fsSL https://raw.githubusercontent.com/WolfePakSoftware/PakClaudeInstallation/main/install-claude-team.sh | bash"
                echo ""
                exit 1
            fi

            read -p "Press Enter after installing Node.js..."

            if ! command -v node &> /dev/null; then
                echo -e "${RED}Node.js installation not detected. Exiting.${NC}"
                exit 1
            fi
            echo -e "${GREEN}✓ Node.js detected${NC}"
        fi
    fi
else
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js is installed: $NODE_VERSION${NC}"

    # Check for v24 warning
    NODE_MAJOR=$(echo $NODE_VERSION | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge 24 ]; then
        echo -e "${YELLOW}⚠ Note: Node.js v24+ may show assertion errors on some systems.${NC}"
        echo -e "${YELLOW}  Recommended: Node.js v22 LTS for best stability.${NC}"
    fi
fi

# ============================================
# Step 4: Install/Update Claude Code
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 4: Installing/Updating Claude Code${NC}"
echo -e "${CYAN}============================================${NC}"

# Helper function to check if npm global install needs sudo
# Returns 0 (true) if sudo is needed, 1 (false) if not
npm_needs_sudo() {
    # Get npm's global prefix
    NPM_PREFIX=$(npm config get prefix 2>/dev/null)
    if [ -z "$NPM_PREFIX" ]; then
        NPM_PREFIX="/usr/local"
    fi

    # Check if the node_modules directory under prefix is writable
    NPM_GLOBAL_DIR="$NPM_PREFIX/lib/node_modules"

    # If directory exists, check if writable
    if [ -d "$NPM_GLOBAL_DIR" ]; then
        if [ -w "$NPM_GLOBAL_DIR" ]; then
            return 1  # No sudo needed
        else
            return 0  # Needs sudo
        fi
    else
        # Directory doesn't exist, check if parent is writable
        NPM_LIB_DIR="$NPM_PREFIX/lib"
        if [ -d "$NPM_LIB_DIR" ]; then
            if [ -w "$NPM_LIB_DIR" ]; then
                return 1  # No sudo needed
            else
                return 0  # Needs sudo
            fi
        else
            # Check prefix itself
            if [ -w "$NPM_PREFIX" ]; then
                return 1  # No sudo needed
            else
                return 0  # Needs sudo
            fi
        fi
    fi
}

# Check if sudo is needed for npm global installs
USE_SUDO=""
if npm_needs_sudo; then
    echo -e "${YELLOW}Note: npm global directory requires elevated permissions${NC}"
    NPM_PREFIX=$(npm config get prefix 2>/dev/null)
    echo "  npm prefix: $NPM_PREFIX"
    USE_SUDO="sudo"
fi

if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Claude Code is installed: $CLAUDE_VERSION${NC}"

    UPDATE_CLAUDE="n"
    if [ "$PIPE_MODE" = true ]; then
        echo -e "${YELLOW}[Auto] Skipping update check in non-interactive mode${NC}"
    else
        read -p "Update to latest version? (y/n): " UPDATE_CLAUDE
    fi

    if [[ "$UPDATE_CLAUDE" =~ ^[Yy]$ ]]; then
        echo "Updating Claude Code..."
        if [ -n "$USE_SUDO" ]; then
            echo -e "${YELLOW}Using sudo for npm global update...${NC}"
        fi
        $USE_SUDO npm update -g @anthropic-ai/claude-code
        echo -e "${GREEN}✓ Claude Code updated${NC}"
    fi
else
    echo "Installing Claude Code..."
    if [ -n "$USE_SUDO" ]; then
        echo -e "${YELLOW}Using sudo for npm global install...${NC}"
    fi
    $USE_SUDO npm install -g @anthropic-ai/claude-code
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Claude Code installed${NC}"
    else
        echo -e "${RED}✗ Failed to install Claude Code${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Try running: sudo npm install -g @anthropic-ai/claude-code"
        echo "  2. Or fix npm permissions: https://docs.npmjs.com/resolving-eacces-permissions-errors"
        echo "  3. Or use nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
        exit 1
    fi
fi

# ============================================
# Step 5: Install AWS CLI v2
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 5: Checking AWS CLI${NC}"
echo -e "${CYAN}============================================${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}AWS CLI not found. Installing...${NC}"
    if [ "$IS_MAC" = true ]; then
        echo "Downloading AWS CLI v2 for Mac..."
        # Use secure temp file to prevent race conditions
        AWS_TMP_PKG=$(mktemp /tmp/awscli.XXXXXXXXXX.pkg)
        curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "$AWS_TMP_PKG"
        echo "Installing AWS CLI (requires sudo)..."
        sudo installer -pkg "$AWS_TMP_PKG" -target /
        rm -f "$AWS_TMP_PKG"
        echo -e "${GREEN}✓ AWS CLI v2 installed${NC}"
    else
        # Linux installation - detect architecture for ARM support
        ARCH=$(uname -m)
        if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
            echo "Downloading AWS CLI v2 for Linux (ARM64)..."
            AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
        else
            echo "Downloading AWS CLI v2 for Linux (x86_64)..."
            AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
        fi
        # Use secure temp directory to prevent race conditions
        AWS_TMP_DIR=$(mktemp -d /tmp/awscli.XXXXXXXXXX)
        curl -fsSL "$AWS_CLI_URL" -o "$AWS_TMP_DIR/awscliv2.zip"
        unzip -q "$AWS_TMP_DIR/awscliv2.zip" -d "$AWS_TMP_DIR"
        echo "Installing AWS CLI (requires sudo)..."
        sudo "$AWS_TMP_DIR/aws/install"
        rm -rf "$AWS_TMP_DIR"
        echo -e "${GREEN}✓ AWS CLI v2 installed${NC}"
    fi
else
    AWS_VERSION=$(aws --version)
    echo -e "${GREEN}✓ AWS CLI is installed: $AWS_VERSION${NC}"
fi

# ============================================
# Step 6: Configure AWS SSO
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 6: Configuring AWS SSO for Bedrock${NC}"
echo -e "${CYAN}============================================${NC}"

AWS_CONFIG_DIR="$HOME/.aws"
mkdir -p "$AWS_CONFIG_DIR"

# Track which AWS profile we use (will be detected after config is created)
AWS_PROFILE_NAME=""

# Check if already logged in with valid SSO session
echo "Checking AWS SSO login status..."
if aws sts get-caller-identity &> /dev/null; then
    AWS_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    echo -e "${GREEN}✓ Already authenticated: $AWS_IDENTITY${NC}"
else
    echo ""
    echo -e "${YELLOW}AWS SSO authentication required for Bedrock access.${NC}"
    echo ""

    # In pipe mode, we can't use BASH_SOURCE for script directory
    # Try to copy AWS config template if running from file, otherwise create it inline
    CONFIG_DEST="$HOME/.aws/config"

    if [ "$PIPE_MODE" = false ]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        CONFIG_TEMPLATE="$SCRIPT_DIR/../aws-config-template"
        if [ -f "$CONFIG_TEMPLATE" ]; then
            echo "Copying AWS config template..."
            cp "$CONFIG_TEMPLATE" "$CONFIG_DEST"
            echo -e "${GREEN}✓ AWS config template copied${NC}"
        fi
    fi

    # Check if SSO config already exists
    if [ -f "$CONFIG_DEST" ] && grep -q "sso_start_url" "$CONFIG_DEST" 2>/dev/null; then
        echo -e "${GREEN}✓ AWS SSO config already exists${NC}"
    elif [ -f "$CONFIG_DEST" ]; then
        # Config exists but no SSO - append instead of overwrite
        echo -e "${YELLOW}Existing AWS config found. Appending SSO configuration...${NC}"
        echo "" >> "$CONFIG_DEST"
        echo "# PakEnergy SSO Configuration (added by Claude Code installer)" >> "$CONFIG_DEST"
        cat >> "$CONFIG_DEST" << 'AWS_CONFIG_EOF'
[profile pakenergy]
sso_session = pakenergy
sso_account_id = 590183895017
sso_role_name = Bedrock
region = us-east-1
output = json

[sso-session pakenergy]
sso_start_url = https://d-9a6774682a.awsapps.com/start
sso_region = us-east-2
sso_registration_scopes = sso:account:access
AWS_CONFIG_EOF
        echo -e "${GREEN}✓ AWS SSO config appended${NC}"
    else
        # No config exists - create fresh
        echo "Creating AWS SSO config..."
        cat > "$CONFIG_DEST" << 'AWS_CONFIG_EOF'
[default]
sso_session = pakenergy
sso_account_id = 590183895017
sso_role_name = Bedrock
region = us-east-1
output = json

[sso-session pakenergy]
sso_start_url = https://d-9a6774682a.awsapps.com/start
sso_region = us-east-2
sso_registration_scopes = sso:account:access
AWS_CONFIG_EOF
        echo -e "${GREEN}✓ AWS SSO config created${NC}"
    fi

    # Detect AWS profile from config file AFTER it's been created
    echo "Detecting AWS profile from configuration..."
    if [ -f "$CONFIG_DEST" ]; then
        # Check for [default] profile first
        if grep -q '^\[default\]' "$CONFIG_DEST" 2>/dev/null; then
            AWS_PROFILE_NAME=""  # Empty = use default
            echo -e "${GREEN}✓ Using default AWS profile${NC}"
        # Check for named profile [profile NAME]
        elif grep -q '^\[profile ' "$CONFIG_DEST" 2>/dev/null; then
            # Extract profile name
            AWS_PROFILE_NAME=$(grep '^\[profile ' "$CONFIG_DEST" | head -1 | sed 's/\[profile \(.*\)\]/\1/')
            echo -e "${GREEN}✓ Detected AWS profile: $AWS_PROFILE_NAME${NC}"
        else
            AWS_PROFILE_NAME=""
            echo -e "${YELLOW}⚠ No profile detected, using default${NC}"
        fi
    fi

    echo ""
    echo "PakEnergy SSO URL: https://d-9a6774682a.awsapps.com/start"
    echo ""

    # In pipe mode, we already created the config inline, so just run aws sso login
    # (aws sso login opens browser and waits - works fine in pipe mode)
    if [ "$PIPE_MODE" = true ]; then
        echo -e "${CYAN}Opening browser for AWS SSO authentication...${NC}"
        echo ""
        echo "A browser window will open. Complete the PakEnergy SSO login."
        echo ""

        # Start aws sso login (opens browser)
        if [ -n "$AWS_PROFILE_NAME" ]; then
            echo "Logging in with AWS profile: $AWS_PROFILE_NAME"
            aws sso login --profile "$AWS_PROFILE_NAME"
        else
            echo "Logging in with default AWS profile"
            aws sso login
        fi
        SSO_EXIT_CODE=$?

        # Active verification polling with error classification
        echo ""
        echo "Verifying AWS authentication..."
        echo "(This may take up to 60 seconds for credentials to propagate)"
        echo ""

        MAX_ATTEMPTS=20
        ATTEMPT_DELAY=3
        VERIFIED=false

        for attempt in $(seq 1 $MAX_ATTEMPTS); do
            echo -n "  Attempt $attempt of $MAX_ATTEMPTS..."
            sleep $ATTEMPT_DELAY

            # Build AWS command with profile
            if [ -n "$AWS_PROFILE_NAME" ]; then
                AWS_VERIFY_CMD="aws sts get-caller-identity --profile $AWS_PROFILE_NAME"
            else
                AWS_VERIFY_CMD="aws sts get-caller-identity"
            fi

            # Capture output and exit code
            OUTPUT=$($AWS_VERIFY_CMD 2>&1)
            EXIT_CODE=$?

            if [ $EXIT_CODE -eq 0 ]; then
                # Parse account from JSON
                ACCOUNT=$(echo "$OUTPUT" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
                if [ -n "$ACCOUNT" ]; then
                    echo " [OK] Authenticated"
                    echo -e "${GREEN}✓ AWS SSO verification successful${NC}"
                    echo "  Account: $ACCOUNT"
                    VERIFIED=true
                    break
                fi
            else
                # Classify error
                if echo "$OUTPUT" | grep -qi "ExpiredToken\|credentials expired"; then
                    echo " [X] Token expired"
                elif echo "$OUTPUT" | grep -qi "InvalidClientTokenId"; then
                    echo " [X] Invalid credentials"
                elif [ $EXIT_CODE -eq 255 ]; then
                    echo " [X] AWS CLI error 255"
                else
                    echo " [X] Failed (exit $EXIT_CODE)"
                fi
            fi
        done

        if [ "$VERIFIED" = false ]; then
            echo ""
            echo -e "${YELLOW}⚠ Verification timed out${NC}"
            if [ -n "$AWS_PROFILE_NAME" ]; then
                echo "  Run manually: aws sts get-caller-identity --profile $AWS_PROFILE_NAME"
            else
                echo "  Run manually: aws sts get-caller-identity"
            fi
        fi
        SETUP_SSO="n"  # Skip the interactive configure sso flow below
    else
        echo "This will:"
        echo "  1. Open your browser"
        echo "  2. Prompt you to login with PakEnergy SSO credentials"
        echo "  3. Authenticate your AWS access"
        echo ""
        read -p "Continue with SSO authentication? (y/n): " SETUP_SSO
    fi

    if [[ ! "$SETUP_SSO" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipping SSO authentication.${NC}"
        echo "You can authenticate later by running: aws sso login"
    else
        echo ""
        echo -e "${CYAN}============================================${NC}"
        echo -e "${CYAN}AWS SSO Setup${NC}"
        echo -e "${CYAN}============================================${NC}"
        echo ""
        echo "You will be prompted for several values."
        echo "Enter these EXACTLY as shown:"
        echo ""
        echo "  SSO session name:  pakenergy"
        echo "  SSO start URL:     https://d-9a6774682a.awsapps.com/start"
        echo "  SSO region:        us-east-2"
        echo ""
        echo "Then browser opens - complete PakEnergy login."
        echo "After login, select your AWS account and role."
        echo "Finally:"
        echo "  CLI default client Region: us-east-1"
        echo "  CLI default output format: json"
        echo "  CLI profile name:          default"
        echo ""

        SSO_SUCCESS=false
        SSO_RETRY=true

        while [ "$SSO_RETRY" = true ] && [ "$SSO_SUCCESS" = false ]; do
            # Run aws configure sso for first-time setup
            SSO_OUTPUT=$(aws configure sso 2>&1)
            SSO_EXIT_CODE=$?

            # Check for specific errors
            if echo "$SSO_OUTPUT" | grep -q "InvalidRequestException"; then
                echo ""
                echo -e "${RED}✗ AWS SSO registration failed with InvalidRequestException${NC}"
                echo ""
                echo "This usually means:"
                echo "  - Network connectivity issues"
                echo "  - VPN disconnected during setup"
                echo "  - AWS service temporarily unavailable"
                echo ""
                read -p "Would you like to retry? (y/n): " RETRY_CHOICE
                if [[ ! "$RETRY_CHOICE" =~ ^[Yy]$ ]]; then
                    SSO_RETRY=false
                fi
            elif echo "$SSO_OUTPUT" | grep -qi "error"; then
                echo ""
                echo -e "${YELLOW}⚠ AWS SSO configuration encountered an error${NC}"
                read -p "Would you like to retry? (y/n): " RETRY_CHOICE
                if [[ ! "$RETRY_CHOICE" =~ ^[Yy]$ ]]; then
                    SSO_RETRY=false
                fi
            else
                # Verify
                sleep 2
                if aws sts get-caller-identity &> /dev/null; then
                    echo -e "${GREEN}✓ AWS SSO configuration successful${NC}"
                    SSO_SUCCESS=true
                else
                    echo ""
                    echo -e "${YELLOW}⚠ AWS SSO setup completed but verification failed${NC}"
                    echo "This might mean the login didn't complete."
                    read -p "Would you like to retry? (y/n): " RETRY_CHOICE
                    if [[ ! "$RETRY_CHOICE" =~ ^[Yy]$ ]]; then
                        SSO_RETRY=false
                    fi
                fi
            fi
        done

        if [ "$SSO_SUCCESS" = false ]; then
            echo ""
            echo -e "${YELLOW}AWS SSO setup was not completed successfully.${NC}"
            echo ""
            echo "You can configure it manually later by running:"
            echo "  aws configure sso"
        fi
    fi
fi

# ============================================
# Step 7: Set CLAUDE_MODEL environment variable
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 7: Setting CLAUDE_MODEL environment variable${NC}"
echo -e "${CYAN}============================================${NC}"

BEDROCK_MODEL="us.anthropic.claude-sonnet-4-20250514-v1:0"
SHELL_RC=""

# Determine shell config file
if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
    if grep -q "CLAUDE_MODEL" "$SHELL_RC"; then
        echo -e "${GREEN}✓ CLAUDE_MODEL already set in $SHELL_RC${NC}"
    else
        echo "" >> "$SHELL_RC"
        echo "# Claude Code - AWS Bedrock model" >> "$SHELL_RC"
        echo "export CLAUDE_MODEL=\"$BEDROCK_MODEL\"" >> "$SHELL_RC"
        echo -e "${GREEN}✓ CLAUDE_MODEL added to $SHELL_RC${NC}"
    fi
elif [ -n "$SHELL_RC" ]; then
    # Shell RC file doesn't exist yet - create it
    echo "# Claude Code - AWS Bedrock model" > "$SHELL_RC"
    echo "export CLAUDE_MODEL=\"$BEDROCK_MODEL\"" >> "$SHELL_RC"
    echo -e "${GREEN}✓ CLAUDE_MODEL added to $SHELL_RC${NC}"
else
    # Unrecognized shell
    echo -e "${YELLOW}⚠ Could not detect shell type (bash/zsh)${NC}"
    echo -e "${YELLOW}  Current shell: $SHELL${NC}"
    echo ""
    echo "Please manually add this to your shell config file:"
    echo "  export CLAUDE_MODEL=\"$BEDROCK_MODEL\""
    echo ""
    case "$SHELL" in
        */fish)
            echo "For Fish shell, add to ~/.config/fish/config.fish:"
            echo "  set -x CLAUDE_MODEL \"$BEDROCK_MODEL\""
            ;;
        */dash)
            echo "For Dash shell, add to ~/.profile:"
            echo "  export CLAUDE_MODEL=\"$BEDROCK_MODEL\""
            ;;
        *)
            echo "Add to your shell's config file (check your shell's documentation)"
            ;;
    esac
    echo ""
fi

# Set for current session
export CLAUDE_MODEL="$BEDROCK_MODEL"
echo "CLAUDE_MODEL=$BEDROCK_MODEL"

# ============================================
# Step 8: Configure Claude Code settings for Bedrock
# ============================================
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 8: Configuring Claude Code settings for Bedrock${NC}"
echo -e "${CYAN}============================================${NC}"

# Ensure .claude directory exists
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Try to copy template if running from file (not pipe mode)
TEMPLATE_COPIED=false
if [ "$PIPE_MODE" = false ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SETTINGS_TEMPLATE="$SCRIPT_DIR/team-settings.json"
    if [ -f "$SETTINGS_TEMPLATE" ]; then
        echo "Copying team settings template..."
        cp "$SETTINGS_TEMPLATE" "$SETTINGS_FILE"
        echo -e "${GREEN}✓ Team settings installed to $SETTINGS_FILE${NC}"
        TEMPLATE_COPIED=true
    fi
fi

# If template wasn't copied (pipe mode or file not found), create inline
if [ "$TEMPLATE_COPIED" = false ]; then
    echo "Creating Claude Code settings..."

    # Build settings based on AWS profile being used
    if [ -n "$AWS_PROFILE_NAME" ]; then
        # Using named profile - need to specify it in commands and env
        cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
{
  "provider": "bedrock",
  "awsAuthRefresh": "aws sso login --profile PROFILE_PLACEHOLDER",
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
    "AWS_PROFILE": "PROFILE_PLACEHOLDER"
  },
  "permissions": {
    "deny": [
      "mcp__ado__wit_create_work_item",
      "mcp__ado__wit_update_work_item",
      "mcp__ado__wit_update_work_items_batch",
      "mcp__ado__wit_add_work_item_comment"
    ]
  }
}
SETTINGS_EOF
        sed -i.bak "s/PROFILE_PLACEHOLDER/$AWS_PROFILE_NAME/g" "$SETTINGS_FILE"
        rm -f "$SETTINGS_FILE.bak"
    else
        # Using default profile - explicitly set for clarity
        cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
{
  "provider": "bedrock",
  "awsAuthRefresh": "aws sso login",
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
    "AWS_PROFILE": "default"
  },
  "permissions": {
    "deny": [
      "mcp__ado__wit_create_work_item",
      "mcp__ado__wit_update_work_item",
      "mcp__ado__wit_update_work_items_batch",
      "mcp__ado__wit_add_work_item_comment"
    ]
  }
}
SETTINGS_EOF
    fi
    echo -e "${GREEN}✓ Team settings created at $SETTINGS_FILE${NC}"
fi

# Verify the settings file
if command -v jq &> /dev/null; then
    PROVIDER=$(jq -r '.provider' "$SETTINGS_FILE" 2>/dev/null)
    DENY_COUNT=$(jq -r '.permissions.deny | length' "$SETTINGS_FILE" 2>/dev/null)
    echo "  Settings configured:"
    echo "    - Provider: $PROVIDER"
    echo "    - Auto SSO refresh: enabled"
    echo "    - ADO write protection: $DENY_COUNT rules"
else
    echo "  Settings configured (install jq for detailed verification)"
fi

# ============================================
# Complete
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Configured:"
echo "  ✓ Claude Code installed"
echo "  ✓ AWS Bedrock provider configured"
echo "  ✓ Auto SSO refresh configured"
echo "  ✓ CLAUDE_MODEL set to Claude Sonnet 4"
echo "  ✓ ADO work item write protection enabled"
echo ""

echo "Next steps:"
echo "  1. Open a NEW terminal window"
echo "  2. Run: claude"
echo "  3. Start using Claude Code!"
echo ""
echo "SSO will auto-refresh when sessions start."
echo ""

#!/bin/bash
# ============================================
# Claude Code Complete Installation & Setup
# One-click installer for Mac/Linux
# v3.0.7 - Pipe-safe for curl | bash installation
# ============================================
#
# INSTALLATION:
#   curl -fsSL https://raw.githubusercontent.com/WolfePakSoftware/PakClaudeInstallation/main/install-claude-complete.sh | bash
#
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detect if running in pipe mode (curl | bash)
PIPE_MODE=false
if [ ! -t 0 ]; then
    PIPE_MODE=true
fi

# Detect OS
IS_MAC=false
IS_LINUX=false
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MAC=true
elif [[ "$OSTYPE" == "linux"* ]]; then
    IS_LINUX=true
fi

# ============================================
# Helper Functions
# ============================================

show_message() {
    local title="$1"
    local message="$2"
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}$title${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo -e "$message"
    echo ""
    if [ "$PIPE_MODE" = false ]; then
        read -p "Press Enter to continue..."
    fi
}

ask_yes_no() {
    local message="$1"
    local default="${2:-y}"

    if [ "$PIPE_MODE" = true ]; then
        # In pipe mode, use default value
        echo -e "${YELLOW}[Auto] $message (default: $default)${NC}"
        if [[ "$default" =~ ^[Yy] ]]; then
            return 0
        else
            return 1
        fi
    fi

    while true; do
        read -p "$message (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# ============================================
# Welcome Screen
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Claude Code Complete Installer${NC}"
if [ "$PIPE_MODE" = true ]; then
    echo -e "${CYAN}(Running in non-interactive mode)${NC}"
fi
echo -e "${CYAN}============================================${NC}"
echo ""
echo "This installer will:"
echo "  ✓ Check and install Homebrew (Mac only, if needed)"
echo "  ✓ Check and install Git (if needed)"
echo "  ✓ Check and install Node.js (if needed)"
echo "  ✓ Verify Python 3 is available"
echo "  ✓ Install/Update Claude Code to latest version"
echo "  ✓ Install AWS CLI v2 (if needed)"
echo "  ✓ Configure AWS SSO for Bedrock access"
echo "  ✓ Configure Hindsight MCP server"
echo "  ✓ Set up auto-sync for CLAUDE.md"
echo ""
if [ "$PIPE_MODE" = false ]; then
    read -p "Press Enter to begin installation..."
fi
echo ""

# ============================================
# Step 1: Check Homebrew (Mac only)
# ============================================

if [ "$IS_MAC" = true ]; then
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}Step 1: Checking Homebrew Installation (Mac)${NC}"
    echo -e "${CYAN}============================================${NC}"

    if command -v brew &> /dev/null; then
        BREW_VERSION=$(brew --version | head -n 1)
        echo -e "${GREEN}✓ Homebrew is installed: $BREW_VERSION${NC}"
    else
        echo -e "${YELLOW}✗ Homebrew not found${NC}"
        echo ""
        echo "Homebrew is required to install dependencies on Mac."
        echo ""

        if ask_yes_no "Would you like to install Homebrew now?"; then
            echo -e "${YELLOW}Installing Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Add Homebrew to PATH for this session
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi

            if command -v brew &> /dev/null; then
                echo -e "${GREEN}✓ Homebrew installed successfully${NC}"
            else
                echo -e "${RED}Failed to install Homebrew. Please install manually from https://brew.sh${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Homebrew is required on Mac. Installation cancelled.${NC}"
            exit 1
        fi
    fi
    echo ""
else
    echo -e "${CYAN}Step 1: Skipped (Homebrew is Mac-only)${NC}"
    echo ""
fi

# ============================================
# Step 2: Check Git
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 2: Checking Git Installation${NC}"
echo -e "${CYAN}============================================${NC}"

if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo -e "${GREEN}✓ Git is installed: $GIT_VERSION${NC}"
else
    echo -e "${YELLOW}✗ Git not found${NC}"
    echo ""

    if [ "$IS_MAC" = true ]; then
        echo "Git can be installed via Xcode Command Line Tools."
        if ask_yes_no "Would you like to install Xcode Command Line Tools now?"; then
            echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
            xcode-select --install
            echo ""
            echo "Please complete the installation in the popup window."
            echo "After installation completes, run this installer again."
            exit 0
        else
            echo -e "${YELLOW}⚠ Git is recommended but not required. Continuing...${NC}"
        fi
    else
        # Linux
        echo "Please install Git using your package manager:"
        echo "  Ubuntu/Debian: sudo apt-get install git"
        echo "  Fedora: sudo dnf install git"
        echo "  Arch: sudo pacman -S git"
        echo ""
        if ask_yes_no "Have you installed Git?"; then
            if ! command -v git &> /dev/null; then
                echo -e "${YELLOW}⚠ Git still not detected. Continuing anyway...${NC}"
            fi
        fi
    fi
fi
echo ""

# ============================================
# Step 3: Check Python 3
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 3: Checking Python 3 Installation${NC}"
echo -e "${CYAN}============================================${NC}"

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python 3 is installed: $PYTHON_VERSION${NC}"
else
    echo -e "${YELLOW}✗ Python 3 not found${NC}"
    echo ""

    if [ "$IS_MAC" = true ]; then
        echo "Python 3 is usually installed with Xcode Command Line Tools."
        if ask_yes_no "Would you like to install Python 3 via Homebrew?"; then
            brew install python3
            if command -v python3 &> /dev/null; then
                echo -e "${GREEN}✓ Python 3 installed successfully${NC}"
            else
                echo -e "${RED}Failed to install Python 3${NC}"
            fi
        fi
    else
        echo "Please install Python 3 using your package manager:"
        echo "  Ubuntu/Debian: sudo apt-get install python3"
        echo "  Fedora: sudo dnf install python3"
        echo ""
    fi
fi
echo ""

# ============================================
# Step 4: Check Node.js
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 4: Checking Node.js Installation${NC}"
echo -e "${CYAN}============================================${NC}"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js is installed: $NODE_VERSION${NC}"
else
    echo -e "${YELLOW}✗ Node.js not found${NC}"

    if ask_yes_no "Node.js is required. Would you like to install it now?"; then
        echo -e "${YELLOW}Installing Node.js...${NC}"

        if [ "$IS_MAC" = true ]; then
            brew install node
        else
            # Linux - suggest nvm or package manager
            echo "Please install Node.js using one of these methods:"
            echo ""
            echo "Option 1 - Using nvm (recommended):"
            echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            echo "  source ~/.bashrc"
            echo "  nvm install --lts"
            echo ""
            echo "Option 2 - Using package manager:"
            echo "  Ubuntu/Debian: sudo apt-get install nodejs npm"
            echo "  Fedora: sudo dnf install nodejs npm"
            echo ""
            read -p "Press Enter after installing Node.js..."

            if ! command -v node &> /dev/null; then
                echo -e "${RED}Node.js installation not detected. Exiting.${NC}"
                exit 1
            fi
        fi

        if command -v node &> /dev/null; then
            echo -e "${GREEN}✓ Node.js installed successfully${NC}"
        else
            echo -e "${RED}Failed to install Node.js. Please install manually from https://nodejs.org${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Claude Code requires Node.js. Installation cancelled.${NC}"
        exit 1
    fi
fi
echo ""

# ============================================
# Step 5: Install/Update Claude Code
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 5: Installing/Updating Claude Code${NC}"
echo -e "${CYAN}============================================${NC}"

if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Claude Code is installed: $CLAUDE_VERSION${NC}"

    if ask_yes_no "Update to latest version?"; then
        echo -e "${YELLOW}Updating Claude Code...${NC}"
        npm update -g @anthropic-ai/claude-code
        echo -e "${GREEN}✓ Claude Code updated${NC}"
    fi
else
    echo -e "${YELLOW}Installing Claude Code...${NC}"
    npm install -g @anthropic-ai/claude-code

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Claude Code installed successfully${NC}"
    else
        echo -e "${RED}Failed to install Claude Code. Please check your internet connection.${NC}"
        exit 1
    fi
fi
echo ""

# ============================================
# Step 6: Install AWS CLI v2
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 6: Checking AWS CLI v2 Installation${NC}"
echo -e "${CYAN}============================================${NC}"

if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | head -n 1)
    echo -e "${GREEN}✓ AWS CLI is installed: $AWS_VERSION${NC}"
else
    echo -e "${YELLOW}✗ AWS CLI not found${NC}"
    echo ""
    echo "AWS CLI v2 is required for Bedrock authentication."
    echo ""

    if ask_yes_no "Would you like to install AWS CLI v2 now?"; then
        echo -e "${YELLOW}Installing AWS CLI v2...${NC}"

        if [ "$IS_MAC" = true ]; then
            # Mac installation
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
            sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
            rm /tmp/AWSCLIV2.pkg
        else
            # Linux installation
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
            cd /tmp
            unzip -q awscliv2.zip
            sudo ./aws/install
            rm -rf /tmp/aws /tmp/awscliv2.zip
            cd -
        fi

        if command -v aws &> /dev/null; then
            echo -e "${GREEN}✓ AWS CLI v2 installed successfully${NC}"
        else
            echo -e "${RED}Failed to install AWS CLI. Please install manually from https://aws.amazon.com/cli/${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ AWS CLI not installed. Bedrock features will not be available.${NC}"
    fi
fi
echo ""

# ============================================
# Step 7: Configure AWS SSO for Bedrock
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 7: Configuring AWS SSO for Bedrock${NC}"
echo -e "${CYAN}============================================${NC}"

CONFIG_DIR="$HOME/OneDrive - PakEnergy/Claude Backup/claude-config"
AWS_CONFIG_TEMPLATE="$CONFIG_DIR/aws-config-template"
AWS_DIR="$HOME/.aws"
AWS_CONFIG="$AWS_DIR/config"

if command -v aws &> /dev/null; then
    # Create .aws directory if needed
    mkdir -p "$AWS_DIR"

    # Copy SSO config template
    if [ -f "$AWS_CONFIG_TEMPLATE" ]; then
        cp "$AWS_CONFIG_TEMPLATE" "$AWS_CONFIG"
        chmod 600 "$AWS_CONFIG"
        echo -e "${GREEN}✓ AWS SSO configuration copied${NC}"

        # Check if already logged in
        if aws sts get-caller-identity &> /dev/null; then
            IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
            echo -e "${GREEN}✓ Already authenticated to AWS: $IDENTITY${NC}"
        else
            echo ""
            echo "AWS SSO login is required."
            echo "A browser window will open for PakEnergy SSO authentication."
            echo ""
            read -p "Press Enter to open browser for SSO login..."

            aws sso login

            if aws sts get-caller-identity &> /dev/null; then
                echo -e "${GREEN}✓ AWS SSO login successful${NC}"
            else
                echo -e "${YELLOW}⚠ AWS SSO login may have failed. Run 'aws sso login' manually if needed.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ AWS SSO config template not found. Please ensure OneDrive is synced.${NC}"
    fi

    # Set CLAUDE_MODEL environment variable
    BEDROCK_MODEL="us.anthropic.claude-opus-4-5-20251101-v1:0"

    # Add to shell profile
    SHELL_PROFILE=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    fi

    if [ -n "$SHELL_PROFILE" ]; then
        if ! grep -q "CLAUDE_MODEL" "$SHELL_PROFILE"; then
            echo "" >> "$SHELL_PROFILE"
            echo "# Claude Code Bedrock Model" >> "$SHELL_PROFILE"
            echo "export CLAUDE_MODEL=\"$BEDROCK_MODEL\"" >> "$SHELL_PROFILE"
            echo -e "${GREEN}✓ CLAUDE_MODEL added to $SHELL_PROFILE${NC}"
        else
            echo -e "${GREEN}✓ CLAUDE_MODEL already configured${NC}"
        fi
        export CLAUDE_MODEL="$BEDROCK_MODEL"
    fi
else
    echo -e "${YELLOW}⚠ AWS CLI not installed. Skipping SSO configuration.${NC}"
fi
echo ""

# ============================================
# Step 8: Configure Hindsight & Auto-Sync
# ============================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}Step 8: Configuring Hindsight & Auto-Sync${NC}"
echo -e "${CYAN}============================================${NC}"

SETUP_SCRIPT="$CONFIG_DIR/_scripts/setup-new-machine.sh"

if [ -f "$SETUP_SCRIPT" ]; then
    echo -e "${YELLOW}Running configuration script...${NC}"
    bash "$SETUP_SCRIPT"
    echo -e "${GREEN}✓ Configuration complete${NC}"
else
    echo -e "${YELLOW}⚠ Configuration script not found at: $SETUP_SCRIPT${NC}"
    echo "Please ensure OneDrive is synced."
fi
echo ""

# ============================================
# Completion
# ============================================

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Configured:"
echo "  ✓ Claude Code installed"
echo "  ✓ Hindsight MCP server configured"
echo "  ✓ CLAUDE.md auto-sync enabled"
echo "  ✓ AWS Bedrock (via SSO) configured"
echo "  ✓ CLAUDE_MODEL environment variable set"
echo ""
echo "Next steps:"
echo "  1. Open a NEW terminal (to load environment variables)"
echo "  2. Run: claude"
echo "  3. Test with: reflect(\"What is my startup protocol?\")"
echo ""
echo -e "${GREEN}Press Enter to exit...${NC}"
read

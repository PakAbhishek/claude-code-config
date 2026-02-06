#!/bin/bash
# ============================================
# Claude Code Linux Installer
# v1.0.0 - Complete setup for Linux (Pop!_OS, Ubuntu, Debian, etc.)
#
# Usage:
#   git clone <repo-url> ~/claude-code-config
#   cd ~/claude-code-config
#   ./install-linux.sh
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header "Claude Code Linux Installer"
echo

# Determine script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Config source: $SCRIPT_DIR"
echo

# ============================================
# Step 1: Check/Install Node.js
# ============================================
print_header "Step 1: Checking Node.js"

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_success "Node.js is installed: $NODE_VERSION"
else
    echo "Node.js not found. Installing via NodeSource..."

    # Detect package manager
    if command -v apt &> /dev/null; then
        # Debian/Ubuntu/Pop!_OS
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
    elif command -v dnf &> /dev/null; then
        # Fedora
        sudo dnf install -y nodejs
    elif command -v pacman &> /dev/null; then
        # Arch
        sudo pacman -S --noconfirm nodejs npm
    else
        print_error "Could not detect package manager. Please install Node.js manually."
        exit 1
    fi

    print_success "Node.js installed: $(node --version)"
fi
echo

# ============================================
# Step 2: Check/Install Claude Code
# ============================================
print_header "Step 2: Checking Claude Code"

if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
    print_success "Claude Code is installed: $CLAUDE_VERSION"

    # Check for updates
    echo "Checking for updates..."
    npm update -g @anthropic-ai/claude-code 2>/dev/null || true
else
    echo "Claude Code not found. Installing..."
    npm install -g @anthropic-ai/claude-code
    print_success "Claude Code installed"
fi
echo

# ============================================
# Step 3: Create .claude directory structure
# ============================================
print_header "Step 3: Setting up .claude directory"

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/hooks"
mkdir -p "$HOME/.claude/hooks/hindsight"
print_success "Directory structure created"
echo

# ============================================
# Step 4: Set up CLAUDE.md with symlink
# ============================================
print_header "Step 4: Setting up CLAUDE.md"

SOURCE_CLAUDE="$SCRIPT_DIR/CLAUDE.md"
TARGET_CLAUDE="$HOME/.claude/CLAUDE.md"

if [ ! -f "$SOURCE_CLAUDE" ]; then
    print_error "Source CLAUDE.md not found at: $SOURCE_CLAUDE"
    exit 1
fi

# Remove existing target
rm -f "$TARGET_CLAUDE" 2>/dev/null || true

# Create symbolic link
if ln -s "$SOURCE_CLAUDE" "$TARGET_CLAUDE" 2>/dev/null; then
    print_success "CLAUDE.md linked (real-time auto-sync)"
else
    cp "$SOURCE_CLAUDE" "$TARGET_CLAUDE"
    print_warning "Created copy (symlink failed, manual sync needed)"
fi
echo

# ============================================
# Step 5: Set up agents directory
# ============================================
print_header "Step 5: Setting up custom agents"

SOURCE_AGENTS="$SCRIPT_DIR/agents"
TARGET_AGENTS="$HOME/.claude/agents"

if [ -d "$SOURCE_AGENTS" ]; then
    rm -rf "$TARGET_AGENTS" 2>/dev/null || true

    if ln -s "$SOURCE_AGENTS" "$TARGET_AGENTS" 2>/dev/null; then
        print_success "Agents linked (real-time auto-sync)"
    else
        cp -r "$SOURCE_AGENTS" "$TARGET_AGENTS"
        print_warning "Agents copied (manual sync needed)"
    fi
else
    print_warning "No agents directory found, skipping"
fi
echo

# ============================================
# Step 6: Set up commands directory
# ============================================
print_header "Step 6: Setting up custom commands"

SOURCE_COMMANDS="$SCRIPT_DIR/commands"
TARGET_COMMANDS="$HOME/.claude/commands"

if [ -d "$SOURCE_COMMANDS" ]; then
    rm -rf "$TARGET_COMMANDS" 2>/dev/null || true

    if ln -s "$SOURCE_COMMANDS" "$TARGET_COMMANDS" 2>/dev/null; then
        print_success "Commands linked (real-time auto-sync)"
    else
        cp -r "$SOURCE_COMMANDS" "$TARGET_COMMANDS"
        print_warning "Commands copied (manual sync needed)"
    fi
else
    print_warning "No commands directory found, skipping"
fi
echo

# ============================================
# Step 7: Install hook scripts
# ============================================
print_header "Step 7: Installing hook scripts"

HOOKS_SOURCE="$SCRIPT_DIR/hooks"
HOOKS_TARGET="$HOME/.claude/hooks"

if [ -d "$HOOKS_SOURCE" ]; then
    # Copy all JavaScript hooks
    for hook in "$HOOKS_SOURCE"/*.js; do
        if [ -f "$hook" ]; then
            cp "$hook" "$HOOKS_TARGET/"
            print_success "Installed: $(basename "$hook")"
        fi
    done

    # Copy hindsight subdirectory
    if [ -d "$HOOKS_SOURCE/hindsight" ]; then
        mkdir -p "$HOOKS_TARGET/hindsight"
        for hook in "$HOOKS_SOURCE/hindsight"/*.js; do
            if [ -f "$hook" ]; then
                cp "$hook" "$HOOKS_TARGET/hindsight/"
                print_success "Installed: hindsight/$(basename "$hook")"
            fi
        done
    fi
else
    print_warning "No hooks directory found, skipping"
fi
echo

# ============================================
# Step 8: Configure settings.json
# ============================================
print_header "Step 8: Configuring settings.json"

SETTINGS_FILE="$HOME/.claude/settings.json"

# Create Linux-compatible settings.json
cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/sync-claude-md.js\"",
            "timeout": 10
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/protocol-reminder.js\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/check-edit-token.js\"",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/check-edit-token.js\"",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/check-testing-shortcut.js\"",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/check-git-operations.js\"",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/hindsight/capture.js\"",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/clear-review-flags.js\"",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/track-file-types.js\"",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$HOME/.claude/hooks/track-file-types.js\"",
            "timeout": 5
          }
        ]
      }
    ]
  },
  "mcpServers": {
    "hindsight": {
      "transport": "sse",
      "url": "http://34.174.13.163:8888/mcp/claude-code/"
    }
  }
}
EOF

# Replace $HOME with actual path
sed -i "s|\$HOME|$HOME|g" "$SETTINGS_FILE"

print_success "settings.json configured with Linux paths"
echo

# ============================================
# Step 9: Configure Hindsight MCP server
# ============================================
print_header "Step 9: Configuring Hindsight MCP server"

if command -v claude &> /dev/null; then
    # Check if already configured
    MCP_LIST=$(claude mcp list 2>&1 || true)

    if echo "$MCP_LIST" | grep -q "hindsight"; then
        print_success "Hindsight already configured"
    else
        echo "Adding Hindsight MCP server..."
        claude mcp add --transport http hindsight "http://34.174.13.163:8888/mcp/claude-code/" 2>&1 || true
        print_success "Hindsight MCP server added"
    fi
else
    print_warning "Claude CLI not available, MCP server configured in settings.json only"
fi
echo

# ============================================
# Step 10: Add shell alias (optional)
# ============================================
print_header "Step 10: Setting up shell alias"

# Detect shell config file
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC=""
fi

if [ -n "$SHELL_RC" ]; then
    # Check if alias already exists
    if ! grep -q "alias cc=" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Claude Code alias" >> "$SHELL_RC"
        echo "alias cc='claude'" >> "$SHELL_RC"
        print_success "Added 'cc' alias to $SHELL_RC"
        echo "  Run 'source $SHELL_RC' or restart terminal to use it"
    else
        print_success "Alias 'cc' already exists"
    fi
else
    print_warning "Could not detect shell config file"
fi
echo

# ============================================
# Complete
# ============================================
print_header "Installation Complete!"
echo
echo -e "${GREEN}Configured:${NC}"
echo "  ✓ Node.js"
echo "  ✓ Claude Code CLI"
echo "  ✓ CLAUDE.md (auto-sync via symlink)"
echo "  ✓ Custom agents"
echo "  ✓ Custom commands (slash commands)"
echo "  ✓ Hook scripts for SDLC enforcement"
echo "  ✓ Hindsight MCP server (cloud memory)"
echo "  ✓ settings.json with Linux paths"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run: source ~/.bashrc (or ~/.zshrc)"
echo "  2. Start Claude Code: claude (or cc)"
echo "  3. Test Hindsight: reflect(\"What is my startup protocol?\")"
echo
echo -e "${BLUE}Config location: $SCRIPT_DIR${NC}"
echo -e "${BLUE}Claude config: $HOME/.claude${NC}"
echo

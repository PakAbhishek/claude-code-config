#!/bin/bash
# ============================================
# Claude Code Multi-Machine Setup Script
# v3.0.31 - Auto-detect OneDrive path for personal vs work machines
# Run this on each new Mac/Linux machine to configure Claude Code
# ============================================

echo "===================================="
echo "Claude Code Multi-Machine Setup"
echo "===================================="
echo

# ============================================
# Auto-detect OneDrive path
# ============================================
echo "Detecting OneDrive path..."

# Source the OneDrive path utility if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONEDRIVE_PATH=""

if [ -f "$SCRIPT_DIR/lib/get-onedrive-path.sh" ]; then
    source "$SCRIPT_DIR/lib/get-onedrive-path.sh"
    ONEDRIVE_PATH=$(get_onedrive_path)
    if [ $? -ne 0 ]; then
        ONEDRIVE_PATH=""
    fi
fi

# Fallback to manual detection if utility failed
if [ -z "$ONEDRIVE_PATH" ]; then
    # Check work machine path first (more specific)
    if [ -d "$HOME/OneDrive - PakEnergy" ]; then
        ONEDRIVE_PATH="$HOME/OneDrive - PakEnergy"
        echo "✓ Found OneDrive - PakEnergy (work machine)"
    # Check personal machine path
    elif [ -d "$HOME/OneDrive" ]; then
        ONEDRIVE_PATH="$HOME/OneDrive"
        echo "✓ Found OneDrive (personal machine)"
    fi
else
    echo "✓ OneDrive detected: $ONEDRIVE_PATH"
fi

# Check for config directory (OneDrive or git-cloned)
GIT_CONFIG="$HOME/claude-code-config"

if [ -n "$ONEDRIVE_PATH" ] && [ -d "$ONEDRIVE_PATH/Claude Backup/claude-config" ]; then
    CONFIG_DIR="$ONEDRIVE_PATH/Claude Backup/claude-config"
    echo "Using OneDrive config: $CONFIG_DIR"
elif [ -d "$GIT_CONFIG" ]; then
    CONFIG_DIR="$GIT_CONFIG"
    echo "Using git-cloned config: $CONFIG_DIR"
else
    echo "ERROR: No config directory found!"
    echo "Checked locations:"
    if [ -n "$ONEDRIVE_PATH" ]; then
        echo "  - $ONEDRIVE_PATH/Claude Backup/claude-config"
    else
        echo "  - $HOME/OneDrive - PakEnergy/Claude Backup/claude-config"
        echo "  - $HOME/OneDrive/Claude Backup/claude-config"
    fi
    echo "  - $GIT_CONFIG"
    exit 1
fi
SCRIPTS_DIR="$CONFIG_DIR/_scripts"
echo

# ============================================
# Step 1: Set up CLAUDE.md with auto-sync
# ============================================
echo "Step 1: Setting up CLAUDE.md with auto-sync..."
SOURCE_CLAUDE="$CONFIG_DIR/CLAUDE.md"
TARGET_CLAUDE="$HOME/.claude/CLAUDE.md"
NEEDS_HOOK=0

if [ ! -f "$SOURCE_CLAUDE" ]; then
    echo "ERROR: Source CLAUDE.md not found at: $SOURCE_CLAUDE"
    echo "Please ensure OneDrive is synced first."
    exit 1
fi

# Ensure .claude directory exists
mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/hooks"
mkdir -p "$HOME/.claude/hooks/hindsight"

# Remove existing target if it exists (for clean symlink creation)
rm -f "$TARGET_CLAUDE" 2>/dev/null

# Try to create symbolic link (best option - real-time sync)
if ln -s "$SOURCE_CLAUDE" "$TARGET_CLAUDE" 2>/dev/null; then
    echo "✓ CLAUDE.md linked with real-time auto-sync (symbolic link)"
    NEEDS_HOOK=0
else
    echo "  Symbolic link not available, using copy with SessionStart hook..."
    cp "$SOURCE_CLAUDE" "$TARGET_CLAUDE"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to setup CLAUDE.md"
        exit 1
    fi
    echo "✓ CLAUDE.md copied (will auto-sync on session start)"
    NEEDS_HOOK=1
fi
echo

# ============================================
# Step 1b: Set up custom agents with auto-sync
# ============================================
echo "Step 1b: Setting up custom agents with auto-sync..."
SOURCE_AGENTS="$CONFIG_DIR/agents"
TARGET_AGENTS="$HOME/.claude/agents"

if [ -d "$SOURCE_AGENTS" ]; then
    # Remove existing target if it exists
    rm -rf "$TARGET_AGENTS" 2>/dev/null

    # Try to create symbolic link
    if ln -s "$SOURCE_AGENTS" "$TARGET_AGENTS" 2>/dev/null; then
        echo "✓ Agents linked with real-time auto-sync (symbolic link)"
    else
        # Fallback: copy directory
        echo "  Symbolic link not available, copying instead..."
        cp -r "$SOURCE_AGENTS" "$TARGET_AGENTS"
        if [ $? -eq 0 ]; then
            echo "✓ Agents copied (manual sync needed for updates)"
        else
            echo "WARNING: Failed to copy agents directory"
        fi
    fi
else
    echo "⚠ Source agents directory not found: $SOURCE_AGENTS"
    echo "  Skipping agents setup"
fi
echo

# ============================================
# Step 1c: Set up custom commands with auto-sync
# ============================================
echo "Step 1c: Setting up custom commands with auto-sync..."
SOURCE_COMMANDS="$CONFIG_DIR/commands"
TARGET_COMMANDS="$HOME/.claude/commands"

if [ -d "$SOURCE_COMMANDS" ]; then
    # Remove existing target if it exists
    rm -rf "$TARGET_COMMANDS" 2>/dev/null

    # Try to create symbolic link
    if ln -s "$SOURCE_COMMANDS" "$TARGET_COMMANDS" 2>/dev/null; then
        echo "✓ Commands linked with real-time auto-sync (symbolic link)"
    else
        # Fallback: copy directory
        echo "  Symbolic link not available, copying instead..."
        cp -r "$SOURCE_COMMANDS" "$TARGET_COMMANDS"
        if [ $? -eq 0 ]; then
            echo "✓ Commands copied (manual sync needed for updates)"
        else
            echo "WARNING: Failed to copy commands directory"
        fi
    fi
else
    echo "⚠ Source commands directory not found: $SOURCE_COMMANDS"
    echo "  Skipping commands setup"
fi
echo

# ============================================
# Step 2: Configure Hindsight MCP server
# ============================================
echo "Step 2: Configuring Hindsight MCP server..."

# Use CLI method (add-hindsight.sh) if Claude is available
if command -v claude &> /dev/null; then
    if [ -f "$SCRIPTS_DIR/add-hindsight.sh" ]; then
        bash "$SCRIPTS_DIR/add-hindsight.sh"
        if [ $? -eq 0 ]; then
            echo "✓ Hindsight MCP server configured via CLI"
        else
            echo "WARNING: Failed to configure Hindsight MCP server"
        fi
    else
        echo "WARNING: add-hindsight.sh not found"
    fi
else
    echo "WARNING: Claude Code not found. Hindsight MCP server not configured."
    echo "  Run 'claude mcp add --transport http hindsight http://34.174.13.163:8888/mcp/claude-code/' after installing Claude Code."
fi
echo

# ============================================
# Step 3: Copy hook scripts
# ============================================
echo "Step 3: Installing hook scripts..."

# Copy AWS SSO hook
if [ -f "$SCRIPTS_DIR/check-aws-sso.js" ]; then
    cp "$SCRIPTS_DIR/check-aws-sso.js" "$HOME/.claude/hooks/check-aws-sso.js"
    echo "✓ AWS SSO credential check hook installed"
else
    echo "WARNING: check-aws-sso.js not found"
fi

# Copy Hindsight capture hook
if [ -f "$SCRIPTS_DIR/hindsight/capture.js" ]; then
    cp "$SCRIPTS_DIR/hindsight/capture.js" "$HOME/.claude/hooks/hindsight/capture.js"
    echo "✓ Hindsight capture hook installed"
else
    echo "WARNING: hindsight/capture.js not found"
fi

# Copy sync hook (always, as backup for symlink)
if [ -f "$SCRIPTS_DIR/sync-claude-md.js" ]; then
    cp "$SCRIPTS_DIR/sync-claude-md.js" "$HOME/.claude/hooks/sync-claude-md.js"
    if [ $NEEDS_HOOK -eq 1 ]; then
        echo "✓ CLAUDE.md sync hook installed (required for sync)"
    else
        echo "✓ Sync hook installed (backup for symlink)"
    fi
else
    echo "WARNING: sync-claude-md.js not found"
fi
echo

# ============================================
# Step 4: Configure settings.json with auto-sync
# ============================================
echo "Step 4: Configuring settings.json with auto-sync..."

SETTINGS_TEMPLATE="$CONFIG_DIR/settings.json"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_DIR="$HOME/.claude/hooks"

if [ -f "$SETTINGS_TEMPLATE" ]; then
    echo "  Settings template found in OneDrive"

    # Read template and replace {{HOOKS_DIR}} placeholder
    sed "s|{{HOOKS_DIR}}|$HOOKS_DIR|g" "$SETTINGS_TEMPLATE" > "$SETTINGS_FILE"

    if [ $? -eq 0 ]; then
        echo "✓ Settings.json configured with NEW hook format"
    else
        echo "WARNING: Failed to configure settings.json"
    fi
else
    echo "WARNING: Settings template not found at: $SETTINGS_TEMPLATE"
    echo "  Will use manual hook registration method instead"

    # Fallback to old method if template doesn't exist
    if [ -f "$SCRIPTS_DIR/add-sessionstart-hook.py" ]; then
        python3 "$SCRIPTS_DIR/add-sessionstart-hook.py"
        if [ $? -eq 0 ]; then
            echo "✓ SessionStart hooks registered (fallback method)"
        else
            echo "WARNING: Failed to register SessionStart hooks"
        fi
    else
        echo "WARNING: add-sessionstart-hook.py not found"
    fi
fi
echo

# ============================================
# Complete
# ============================================
echo "===================================="
echo "Setup Complete!"
echo "===================================="
echo
echo "Configured:"
echo "  ✓ .claude directory ready"
echo "  ✓ CLAUDE.md auto-sync across all machines"
echo "  ✓ Custom agents auto-sync across all machines"
echo "  ✓ Custom commands (slash commands) auto-sync across all machines"
echo "  ✓ Settings.json with NEW hook format (auto-synced)"
echo "  ✓ SDLC enforcement hooks configured"
echo "  ✓ Hindsight MCP server"
echo "  ✓ Hindsight memory capture hook"
echo "  ✓ AWS SSO credential auto-refresh on session start"
echo
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Test with: reflect(\"What is my startup protocol?\")"
echo "  3. Should connect to Hindsight cloud server"
echo

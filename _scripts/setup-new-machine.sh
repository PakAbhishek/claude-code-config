#!/bin/bash
# ============================================
# Claude Code Multi-Machine Setup Script
# v3.0.6 - Uses CLI method for Hindsight config
# Run this on each new Mac/Linux machine to configure Claude Code
# ============================================

echo "===================================="
echo "Claude Code Multi-Machine Setup"
echo "===================================="
echo

CONFIG_DIR="$HOME/OneDrive - PakEnergy/Claude Backup/claude-config"
SCRIPTS_DIR="$CONFIG_DIR/_scripts"

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
    echo "  Run 'claude mcp add --transport http hindsight http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/' after installing Claude Code."
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
# Step 4: Register hooks in settings.json
# ============================================
echo "Step 4: Registering hooks in settings.json..."

if [ -f "$SCRIPTS_DIR/add-sessionstart-hook.py" ]; then
    python3 "$SCRIPTS_DIR/add-sessionstart-hook.py"
    if [ $? -eq 0 ]; then
        echo "✓ SessionStart hooks registered"
    else
        echo "WARNING: Failed to register SessionStart hooks"
    fi
else
    echo "WARNING: add-sessionstart-hook.py not found"
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
echo "  ✓ Hindsight MCP server"
echo "  ✓ Hindsight memory capture hook"
echo "  ✓ AWS SSO credential auto-refresh on session start"
echo
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Test with: reflect(\"What is my startup protocol?\")"
echo "  3. Should connect to Hindsight cloud server"
echo

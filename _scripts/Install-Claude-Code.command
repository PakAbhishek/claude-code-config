#!/bin/bash
# ============================================
# Claude Code Team Installer - Mac/Linux Launcher
# Double-click this file to start installation
# ============================================

# Change to the directory where this script is located
cd "$(dirname "$0")"

# Make the installer executable (in case it isn't)
chmod +x install-claude.sh 2>/dev/null || chmod +x install-claude-team.sh 2>/dev/null

# Run the installer
if [ -f "install-claude.sh" ]; then
    ./install-claude.sh
elif [ -f "install-claude-team.sh" ]; then
    ./install-claude-team.sh
else
    echo "ERROR: Could not find install-claude.sh or install-claude-team.sh"
    echo "Make sure this file is in the same directory as the installer script."
    read -p "Press Enter to exit..."
    exit 1
fi

# Keep terminal open to see results
echo ""
echo "============================================"
echo "Installation complete. You can close this window."
echo "============================================"
read -p "Press Enter to close..."

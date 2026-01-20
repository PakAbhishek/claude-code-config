#!/bin/bash
# ============================================
# Add Hindsight MCP server using Claude CLI
# Used by setup-new-machine.sh for Mac/Linux
# v3.0.6 - Uses CLI method instead of deprecated settings.json
# ============================================

HINDSIGHT_URL="http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/"

echo "Configuring Hindsight MCP server..."

# Check if claude command is available
if ! command -v claude &> /dev/null; then
    echo "ERROR: Claude Code CLI not found. Please ensure Claude Code is installed and in PATH."
    exit 1
fi

# Check if hindsight is already configured
echo "Checking existing MCP configuration..."
MCP_LIST=$(claude mcp list 2>&1)

if echo "$MCP_LIST" | grep -q "hindsight.*Connected\|hindsight:"; then
    echo "Hindsight MCP server is already configured"
    exit 0
fi

# Add Hindsight MCP server using CLI
echo "Adding Hindsight MCP server via CLI..."
RESULT=$(claude mcp add --transport http hindsight "$HINDSIGHT_URL" 2>&1)

if [ $? -eq 0 ]; then
    echo "Hindsight MCP server added successfully"
    echo ""
    echo "Verifying connection..."
    claude mcp list 2>&1
    exit 0
else
    echo "ERROR: Failed to add Hindsight MCP server: $RESULT"
    exit 1
fi

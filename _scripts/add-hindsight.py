#!/usr/bin/env python3
"""
Python script to add Hindsight MCP server to settings.json
Used by setup-new-machine.sh for Mac/Linux systems
"""

import json
import os
import sys
from pathlib import Path

def main():
    # Get settings path
    home = os.path.expanduser("~")
    settings_path = os.path.join(home, ".claude", "settings.json")

    try:
        if os.path.exists(settings_path):
            # Modify existing settings.json
            with open(settings_path, "r", encoding="utf-8") as f:
                settings = json.load(f)

            # Check if Hindsight is already configured
            if (settings.get("mcpServers") and
                settings["mcpServers"].get("hindsight") and
                settings["mcpServers"]["hindsight"].get("url") == "http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/"):
                print("Hindsight MCP server already configured correctly")
                return 0

            # Add mcpServers if missing
            if "mcpServers" not in settings:
                settings["mcpServers"] = {}

            # Add Hindsight config
            settings["mcpServers"]["hindsight"] = {
                "type": "http",
                "url": "http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/"
            }

            # Write back to file
            with open(settings_path, "w", encoding="utf-8") as f:
                json.dump(settings, f, indent=2)

            print("Hindsight MCP server added successfully")
        else:
            # Create new settings.json
            settings = {
                "mcpServers": {
                    "hindsight": {
                        "type": "http",
                        "url": "http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/"
                    }
                }
            }

            # Ensure directory exists
            os.makedirs(os.path.dirname(settings_path), exist_ok=True)

            # Write new file
            with open(settings_path, "w", encoding="utf-8") as f:
                json.dump(settings, f, indent=2)

            print("Settings.json created with Hindsight MCP server")

        return 0

    except Exception as e:
        print(f"Error: Failed to modify settings.json: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())

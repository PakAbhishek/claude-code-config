#!/usr/bin/env python3
"""
Python script to add DGX GPU status SessionStart hook
Registers the dgx-gpu-status.js hook in Claude Code settings
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
        if not os.path.exists(settings_path):
            print(f"Error: settings.json not found at {settings_path}", file=sys.stderr)
            return 1

        # Read settings.json
        with open(settings_path, "r", encoding="utf-8") as f:
            settings = json.load(f)

        # Initialize hooks if missing
        if "hooks" not in settings:
            settings["hooks"] = {}

        # Check if SessionStart hook already exists with our GPU script
        hook_exists = False
        if "SessionStart" in settings["hooks"]:
            for hook_entry in settings["hooks"]["SessionStart"]:
                if "hooks" in hook_entry:
                    for hook in hook_entry["hooks"]:
                        if "command" in hook and "dgx-gpu-status.js" in hook["command"]:
                            hook_exists = True
                            break
                if hook_exists:
                    break

        if hook_exists:
            print("SessionStart hook for DGX GPU status already configured")
            return 0

        # Create SessionStart hook array if missing
        if "SessionStart" not in settings["hooks"]:
            settings["hooks"]["SessionStart"] = []

        # Create our hook configuration
        gpu_hook = {
            "hooks": [
                {
                    "type": "command",
                    "command": f'node "{home}/.claude/hooks/dgx-gpu-status.js"',
                    "timeout": 10
                }
            ]
        }

        # Add to SessionStart hooks
        settings["hooks"]["SessionStart"].append(gpu_hook)

        # Write back to file
        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=2)

        print("DGX GPU status hook added successfully")
        return 0

    except Exception as e:
        print(f"Error: Failed to add DGX GPU hook: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())

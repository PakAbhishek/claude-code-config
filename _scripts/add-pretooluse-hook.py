#!/usr/bin/env python3
"""
Python script to add PreToolUse hook for SOC 2 compliance validation
Used by setup-new-machine.sh (Mac/Linux) to register the soc2-validator.py hook
"""

import json
import os
import sys
from pathlib import Path

def main():
    try:
        # Get settings path
        home = Path.home()
        settings_path = home / '.claude' / 'settings.json'

        # Ensure .claude directory exists
        settings_path.parent.mkdir(parents=True, exist_ok=True)

        # Create or read settings.json
        if settings_path.exists():
            with open(settings_path, 'r') as f:
                settings = json.load(f)
            if not settings:
                settings = {}
        else:
            print("Creating new settings.json...")
            settings = {}

        # Initialize hooks if missing
        if "hooks" not in settings:
            settings["hooks"] = {}

        # Check if SOC2 PreToolUse hook already exists
        soc2_hook_exists = False

        if "PreToolUse" in settings["hooks"]:
            for hook_entry in settings["hooks"]["PreToolUse"]:
                if "matcher" in hook_entry and "Write" in hook_entry["matcher"] and "Edit" in hook_entry["matcher"]:
                    if "hooks" in hook_entry:
                        for hook in hook_entry["hooks"]:
                            if "command" in hook and "soc2-validator.py" in hook["command"]:
                                soc2_hook_exists = True
                                break

        if soc2_hook_exists:
            print("SOC 2 PreToolUse hook already configured")
            sys.exit(0)

        # Create PreToolUse hook array if missing
        if "PreToolUse" not in settings["hooks"]:
            settings["hooks"]["PreToolUse"] = []

        # Create the SOC 2 validation hook
        soc2_hook = {
            "type": "command",
            "command": f'python "{home}/.claude/hooks/soc2-validator.py"',
            "timeout": 5000
        }

        # Create PreToolUse hook configuration
        pre_tool_use_entry = {
            "matcher": "Write|Edit|NotebookEdit",
            "hooks": [soc2_hook]
        }

        # Add to PreToolUse hooks
        settings["hooks"]["PreToolUse"].append(pre_tool_use_entry)

        # Write back to file
        with open(settings_path, 'w') as f:
            json.dump(settings, f, indent=2)

        print("SOC 2 PreToolUse hook added successfully")
        sys.exit(0)

    except Exception as e:
        print(f"Failed to add PreToolUse hook: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

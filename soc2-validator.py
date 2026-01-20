#!/usr/bin/env python3
"""
SOC 2 Security Validator for Claude Code PreToolUse Hook
Scans content for security violations before Write/Edit operations.

Version: 1.0.0

Returns:
  - Exit 0 with JSON {"decision": "allow"} if clean
  - Exit 0 with JSON {"decision": "deny", "reason": "..."} if violation found

Graceful Failure:
  - If anything goes wrong, ALLOW (don't block developer work)
  - Log errors for debugging
"""

import json
import re
import sys
import base64
import os

VERSION = "1.1.0"

# Check for --version flag (for installer validation)
if len(sys.argv) > 1 and sys.argv[1] == "--version":
    print(f"soc2-validator version {VERSION}")
    sys.exit(0)

# Override patterns - allow violations when explicitly documented
OVERRIDE_PATTERNS = [
    r'#\s*SOC2_OVERRIDE:\s*Security testing',
    r'#\s*SOC2_OVERRIDE:\s*Educational example',
    r'#\s*SOC2_OVERRIDE:\s*Testing hook itself',
    r'#\s*SOC2_OVERRIDE:\s*Penetration testing',
    r'#\s*SOC2_OVERRIDE:\s*Security research',
    r'#\s*SOC2_OVERRIDE:\s*Vulnerability disclosure',
    r'#\s*SOC2_OVERRIDE:\s*Training material',
    r'#\s*SOC2_OVERRIDE:\s*Honeypot credentials',
    r'//\s*SOC2_OVERRIDE:',  # JavaScript/C/Java style
    r'/\*\s*SOC2_OVERRIDE:',  # Multi-line comment style
]

# Patterns to detect
PATTERNS = {
    "hardcoded_password": [
        r'password\s*[=:]\s*["\'][^"\']+["\']',
        r'passwd\s*[=:]\s*["\'][^"\']+["\']',
        r'pwd\s*[=:]\s*["\'][^"\']+["\']',
        r'pass\s*[=:]\s*["\'][^"\']+["\']',
    ],
    "hardcoded_secret": [
        r'secret\s*[=:]\s*["\'][^"\']+["\']',
        r'api_key\s*[=:]\s*["\'][^"\']+["\']',
        r'apikey\s*[=:]\s*["\'][^"\']+["\']',
        r'api-key\s*[=:]\s*["\'][^"\']+["\']',
        r'token\s*[=:]\s*["\'][^"\']+["\']',
        r'bearer\s*[=:]\s*["\'][^"\']+["\']',
        r'auth\s*[=:]\s*["\'][^"\']+["\']',
        r'credential\s*[=:]\s*["\'][^"\']+["\']',
    ],
    "aws_key": [
        r'AKIA[0-9A-Z]{16}',
        r'ASIA[0-9A-Z]{16}',
        r'aws_access_key_id\s*[=:]\s*["\'][^"\']+["\']',
        r'aws_secret_access_key\s*[=:]\s*["\'][^"\']+["\']',
    ],
    "private_ip": [
        r'\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
        r'\b192\.168\.\d{1,3}\.\d{1,3}\b',
        r'\b172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}\b',
    ],
    "internal_url": [
        r'[a-zA-Z0-9-]+\.internal\b',
        r'[a-zA-Z0-9-]+\.local\b',
        r'[a-zA-Z0-9-]+\.corp\b',
        r'[a-zA-Z0-9-]+\.lan\b',
        r'[a-zA-Z0-9-]+\.private\b',
    ],
    "connection_string": [
        r'(postgres|mysql|mongodb|redis|amqp)://[^:]+:[^@]+@',
    ],
    "pii_ssn": [
        r'\b\d{3}-\d{2}-\d{4}\b',
    ],
    "github_token": [
        r'ghp_[a-zA-Z0-9]{36}',
        r'gho_[a-zA-Z0-9]{36}',
        r'ghu_[a-zA-Z0-9]{36}',
        r'ghs_[a-zA-Z0-9]{36}',
        r'ghr_[a-zA-Z0-9]{36}',
    ],
}

# Safe patterns to ignore (false positives)
SAFE_PATTERNS = [
    r'os\.environ\[',
    r'os\.environ\.get\(',
    r'os\.getenv\(',
    r'process\.env\.',
    r'\$\{.*\}',  # Environment variable substitution
    r'<[A-Z_]+>',  # Placeholder like <PASSWORD>
    r'your[_-]?(password|secret|key|token)',  # Placeholder text
    r'FAKE_',
    r'EXAMPLE_',
    r'TODO',
    r'CHANGEME',
    r'xxxxxx',
]


def check_for_override(content: str) -> tuple[bool, str]:
    """
    Check if content has an explicit SOC2_OVERRIDE comment in the first 10 lines.
    Returns (has_override, override_reason)
    """
    lines = content.split('\n')[:10]  # Check first 10 lines only
    first_lines = '\n'.join(lines)

    for pattern in OVERRIDE_PATTERNS:
        match = re.search(pattern, first_lines, re.IGNORECASE)
        if match:
            # Extract the full comment line
            for line in lines:
                if 'SOC2_OVERRIDE' in line:
                    return True, line.strip()

    return False, ""


def is_safe_pattern(content: str, match: str) -> bool:
    """Check if the match is actually a safe pattern (false positive)."""
    # Get context around the match
    match_pos = content.find(match)
    if match_pos == -1:
        return False

    context_start = max(0, match_pos - 50)
    context_end = min(len(content), match_pos + len(match) + 50)
    context = content[context_start:context_end]

    for safe in SAFE_PATTERNS:
        if re.search(safe, context, re.IGNORECASE):
            return True
    return False


def check_base64_secrets(content: str) -> list:
    """Check for base64 encoded secrets."""
    violations = []
    # Find potential base64 strings (at least 20 chars)
    b64_pattern = r'["\']([A-Za-z0-9+/]{20,}={0,2})["\']'

    for match in re.finditer(b64_pattern, content):
        try:
            decoded = base64.b64decode(match.group(1)).decode('utf-8', errors='ignore')
            # Check if decoded content contains secrets
            for category, patterns in PATTERNS.items():
                for pattern in patterns:
                    if re.search(pattern, decoded, re.IGNORECASE):
                        violations.append(f"Encoded secret ({category}): base64 decodes to sensitive content")
                        break
        except:
            pass

    return violations


def scan_content(content: str) -> list:
    """Scan content for SOC 2 violations."""
    violations = []

    for category, patterns in PATTERNS.items():
        for pattern in patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                matched_text = match.group(0)
                if not is_safe_pattern(content, matched_text):
                    # Truncate for display
                    display = matched_text[:50] + "..." if len(matched_text) > 50 else matched_text
                    violations.append(f"{category}: {display}")

    # Also check for encoded secrets
    violations.extend(check_base64_secrets(content))

    return violations


def main():
    # Read input from Claude Code (JSON on stdin)
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        # If not JSON, treat as raw content
        input_data = {"content": sys.stdin.read()}

    # Extract content to scan
    # PreToolUse provides tool input in different formats
    content = ""

    if "tool_input" in input_data:
        tool_input = input_data["tool_input"]
        if isinstance(tool_input, dict):
            # Write/Edit tool input
            content = tool_input.get("content", "")
            if not content:
                content = tool_input.get("new_string", "")
        else:
            content = str(tool_input)
    elif "content" in input_data:
        content = input_data["content"]

    if not content:
        # No content to scan, allow
        result = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow"
            }
        }
        print(json.dumps(result))
        sys.exit(0)

    # Check for explicit override
    has_override, override_reason = check_for_override(content)

    # Scan for violations
    violations = scan_content(content)

    if violations:
        if has_override:
            # Override present - ALLOW but warn
            violation_list = "\n".join(f"  - {v}" for v in violations[:5])  # Show first 5
            reason = f"⚠️ SOC 2 OVERRIDE ACTIVE\n{override_reason}\n\nViolations detected but allowed:\n{violation_list}"

            result = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "permissionDecisionReason": reason
                }
            }
            print(json.dumps(result))
            sys.exit(0)
        else:
            # Violations found - DENY
            violation_list = "\n".join(f"  - {v}" for v in violations[:5])  # Show first 5
            reason = f"SOC 2 VIOLATION DETECTED:\n{violation_list}\n\nUse environment variables instead of hardcoded values."

            result = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason
                }
            }
            print(json.dumps(result))
            sys.exit(0)
    else:
        # Clean - ALLOW
        result = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow"
            }
        }
        print(json.dumps(result))
        sys.exit(0)


if __name__ == "__main__":
    main()

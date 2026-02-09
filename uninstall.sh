#!/usr/bin/env bash
#
# Uninstall guardrails PreToolUse hook from Claude Code
#

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
HOOKS_FILE="${CLAUDE_DIR}/settings.json"
GUARDRAIL_FILE="${HOOKS_DIR}/guardrail.py"
POLICY_FILE="${HOOKS_DIR}/policy.yaml"

echo "Uninstalling guardrails PreToolUse hook..."

# Check if Claude directory exists
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "Error: Claude Code directory not found at $CLAUDE_DIR"
    exit 1
fi

# Remove hook files
if [ -f "$GUARDRAIL_FILE" ]; then
    echo "Removing ${GUARDRAIL_FILE}..."
    rm "$GUARDRAIL_FILE"
else
    echo "Hook file not found at ${GUARDRAIL_FILE}"
fi

if [ -f "$POLICY_FILE" ]; then
    echo "Removing ${POLICY_FILE}..."
    rm "$POLICY_FILE"
else
    echo "Policy file not found at ${POLICY_FILE}"
fi

# Update settings.json to remove PreToolUse hook
if [ -f "$HOOKS_FILE" ]; then
    echo "Updating settings.json..."

    python3 <<EOF
import json
import sys

try:
    with open("${HOOKS_FILE}", 'r') as f:
        settings = json.load(f)
except:
    print("Could not read settings.json")
    sys.exit(1)

# Remove PreToolUse hook
if 'hooks' in settings and 'PreToolUse' in settings['hooks']:
    del settings['hooks']['PreToolUse']
    print("Removed PreToolUse hook")

# Remove environment variables
if 'env' in settings:
    if 'GUARDRAILS_POLICY_PATH' in settings['env']:
        del settings['env']['GUARDRAILS_POLICY_PATH']
    if 'GUARDRAILS_VERBOSE' in settings['env']:
        del settings['env']['GUARDRAILS_VERBOSE']

with open("${HOOKS_FILE}", 'w') as f:
    json.dump(settings, f, indent=2)

print("Settings updated successfully")
EOF
else
    echo "Settings file not found at ${HOOKS_FILE}"
fi

echo ""
echo "✓ Guardrails uninstalled successfully!"
echo ""
echo "Restart Claude Code for changes to take effect."

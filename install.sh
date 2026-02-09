#!/usr/bin/env bash
#
# Install guardrails PreToolUse hook into Claude Code
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
HOOKS_FILE="${CLAUDE_DIR}/settings.json"
GUARDRAIL_DEST="${HOOKS_DIR}/guardrail.py"
POLICY_PATH="${SCRIPT_DIR}/policy.yaml"

echo "Installing guardrails PreToolUse hook..."

# Ensure Claude directory exists
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "Error: Claude Code directory not found at $CLAUDE_DIR"
    echo "Please install Claude Code first."
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not found in PATH"
    exit 1
fi

# Check if PyYAML is installed
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "Installing PyYAML..."
    pip3 install pyyaml
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Copy guardrail.py to ~/.claude/hooks/
echo "Copying guardrail.py to $GUARDRAIL_DEST..."
cp "${SCRIPT_DIR}/guardrail.py" "$GUARDRAIL_DEST"
chmod +x "$GUARDRAIL_DEST"

# Check if settings.json is a symlink (likely Nix/Home Manager)
IS_NIX_MANAGED=false
if [ -L "$HOOKS_FILE" ]; then
    TARGET=$(readlink "$HOOKS_FILE")
    if [[ "$TARGET" == /nix/store/* ]]; then
        IS_NIX_MANAGED=true
        echo "Detected Nix-managed settings.json"
    fi
fi

# Try to update settings.json
if [ "$IS_NIX_MANAGED" = true ]; then
    echo ""
    echo "⚠️  Your settings.json is managed by Nix/Home Manager."
    echo ""
    echo "Please add this configuration to your Home Manager config:"
    echo ""
    echo "-----------------------------------------------------------"
    cat <<'EOF'
  programs.claude-code = {
    settings = {
      hooks = {
        PreToolUse = "${config.home.homeDirectory}/.claude/hooks/guardrail.py";
      };
      env = {
        GUARDRAILS_POLICY_PATH = "${config.home.homeDirectory}/.claude/hooks/policy.yaml";
        GUARDRAILS_VERBOSE = "0";
      };
    };
  };
EOF
    echo "-----------------------------------------------------------"
    echo ""
    echo "Or add to your existing Claude settings JSON:"
    echo ""
    cat <<EOF
  "hooks": {
    "PreToolUse": "${GUARDRAIL_DEST}"
  },
  "env": {
    "GUARDRAILS_POLICY_PATH": "${POLICY_PATH}",
    "GUARDRAILS_VERBOSE": "0"
  }
EOF
    echo ""
    echo "After updating your config, rebuild with: home-manager switch"

elif [ ! -f "$HOOKS_FILE" ]; then
    # Create new settings file
    echo "Creating new settings.json..."
    cat > "$HOOKS_FILE" <<EOF
{
  "hooks": {
    "PreToolUse": "${GUARDRAIL_DEST}"
  },
  "env": {
    "GUARDRAILS_POLICY_PATH": "${POLICY_PATH}",
    "GUARDRAILS_VERBOSE": "0"
  }
}
EOF
else
    # Update existing settings file
    echo "Updating existing settings.json..."

    # Use Python to update JSON
    python3 <<EOF || {
        echo ""
        echo "⚠️  Could not automatically update settings.json"
        echo "Please manually add this to ${HOOKS_FILE}:"
        echo ""
        echo '  "hooks": {'
        echo "    \"PreToolUse\": \"${GUARDRAIL_DEST}\""
        echo '  },'
        echo '  "env": {'
        echo "    \"GUARDRAILS_POLICY_PATH\": \"${POLICY_PATH}\","
        echo '    "GUARDRAILS_VERBOSE": "0"'
        echo '  }'
        exit 0
    }
import json
import sys

try:
    with open("${HOOKS_FILE}", 'r') as f:
        settings = json.load(f)
except:
    settings = {}

# Update hooks
if 'hooks' not in settings:
    settings['hooks'] = {}
settings['hooks']['PreToolUse'] = "${GUARDRAIL_DEST}"

# Update environment variables
if 'env' not in settings:
    settings['env'] = {}
settings['env']['GUARDRAILS_POLICY_PATH'] = "${POLICY_PATH}"
if 'GUARDRAILS_VERBOSE' not in settings['env']:
    settings['env']['GUARDRAILS_VERBOSE'] = "0"

with open("${HOOKS_FILE}", 'w') as f:
    json.dump(settings, f, indent=2)

print("Settings updated successfully")
EOF
fi

echo ""
echo "✓ Guardrails installed successfully!"
echo ""
echo "Files:"
echo "  Hook: ${GUARDRAIL_DEST}"
echo "  Policy: ${POLICY_PATH}"
if [ "$IS_NIX_MANAGED" = false ]; then
    echo "  Settings: ${HOOKS_FILE}"
fi
echo ""
echo "Environment variables:"
echo "  GUARDRAILS_POLICY_PATH=${POLICY_PATH}"
echo "  GUARDRAILS_VERBOSE=0 (set to 1 to enable verbose logging)"
echo ""
echo "To customize rules, edit: ${POLICY_PATH}"
echo ""
if [ "$IS_NIX_MANAGED" = false ]; then
    echo "Next steps:"
    echo "1. Review policy.yaml and adjust rules as needed"
    echo "2. Restart Claude Code for changes to take effect"
    echo "3. Set GUARDRAILS_VERBOSE=1 in settings.json if you want to see decision logs"
else
    echo "Next steps:"
    echo "1. Add the configuration shown above to your Home Manager config"
    echo "2. Run: home-manager switch"
    echo "3. Review policy.yaml and adjust rules as needed: ${POLICY_PATH}"
    echo "4. Restart Claude Code"
fi

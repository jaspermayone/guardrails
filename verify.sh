#!/usr/bin/env bash

set -e

echo "🔍 Verifying Guardrails Installation..."
echo ""

# Check files
echo "1. Checking files..."
if [ -x ~/.claude/hooks/guardrail.py ]; then
    echo "   ✓ guardrail.py exists and is executable"
else
    echo "   ✗ guardrail.py missing or not executable"
    exit 1
fi

if [ -f ~/.claude/hooks/policy.yaml ]; then
    echo "   ✓ policy.yaml exists"
else
    echo "   ✗ policy.yaml missing"
    exit 1
fi

# Check settings
echo ""
echo "2. Checking settings.json..."
if [ -f ~/.claude/settings.json ]; then
    if grep -q "PreToolUse" ~/.claude/settings.json 2>/dev/null; then
        echo "   ✓ PreToolUse hook configured in settings.json"
        grep -A 2 "PreToolUse" ~/.claude/settings.json | sed 's/^/     /'
    else
        echo "   ⚠️  PreToolUse hook not found in settings.json"
        echo "      (This is expected if using Nix-managed config)"
    fi
else
    echo "   ✗ settings.json not found"
fi

# Test hook functionality
echo ""
echo "3. Testing hook functionality..."

# Test 1: Deny secret file
echo -n "   Testing secret file protection... "
RESULT=$(echo '{"tool": "Read", "arguments": {"file_path": ".env"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "deny"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected deny, got: $RESULT"
fi

# Test 2: Allow normal file
echo -n "   Testing normal file access... "
RESULT=$(echo '{"tool": "Read", "arguments": {"file_path": "README.md"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "allow"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected allow, got: $RESULT"
fi

# Test 3: Deny dangerous command
echo -n "   Testing dangerous command protection... "
RESULT=$(echo '{"tool": "Bash", "arguments": {"command": "rm -rf /"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "deny"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected deny, got: $RESULT"
fi

# Test 4: Allow safe command
echo -n "   Testing safe command... "
RESULT=$(echo '{"tool": "Bash", "arguments": {"command": "rm -rf node_modules"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "allow"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected allow, got: $RESULT"
fi

# Test 5: Deny git commit
echo -n "   Testing git commit protection... "
RESULT=$(echo '{"tool": "Bash", "arguments": {"command": "git commit -m \"test\""}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "deny"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected deny, got: $RESULT"
fi

# Test 6: Allow git status
echo -n "   Testing git status... "
RESULT=$(echo '{"tool": "Bash", "arguments": {"command": "git status"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "allow"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected allow, got: $RESULT"
fi

# Test 7: Allow .claude directory (even if under dotfiles)
echo -n "   Testing .claude directory access... "
RESULT=$(echo '{"tool": "Read", "arguments": {"file_path": "/Users/jsp/.claude/settings.json"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "allow"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected allow, got: $RESULT"
fi

# Test 8: Deny dotfiles (if not .claude)
echo -n "   Testing dotfiles protection... "
RESULT=$(echo '{"tool": "Read", "arguments": {"file_path": "/Users/jsp/dev/dots/secrets/secrets.nix"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "deny"'; then
    echo "✓"
else
    echo "✗"
    echo "      Expected deny, got: $RESULT"
fi

echo ""
echo "✅ Verification complete!"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. Try asking Claude to read a .env file or run git commit"
echo "  3. It should get blocked with an explanation"
echo ""
echo "To enable verbose logging, set guardrails.verbose = true in your Nix config"

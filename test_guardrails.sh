#!/usr/bin/env bash
#
# Test script to verify guardrails work correctly
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARDRAIL="${SCRIPT_DIR}/guardrail.py"

echo "Testing guardrails..."
echo ""

# Test 1: Reading a secret file (should be denied)
echo "Test 1: Reading .env file"
echo '{"tool": "Read", "arguments": {"file_path": "/some/path/.env"}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 2: Reading a normal file (should be allowed)
echo "Test 2: Reading normal file"
echo '{"tool": "Read", "arguments": {"file_path": "/some/path/file.txt"}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 3: Dangerous bash command (should be denied)
echo "Test 3: Dangerous rm -rf /"
echo '{"tool": "Bash", "arguments": {"command": "rm -rf /"}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 4: Safe bash command (should be allowed)
echo "Test 4: Safe rm -rf node_modules"
echo '{"tool": "Bash", "arguments": {"command": "rm -rf node_modules"}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 5: Git commit (should be denied)
echo "Test 5: Git commit"
echo '{"tool": "Bash", "arguments": {"command": "git commit -m \"test\""}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 6: Git status (should be allowed)
echo "Test 6: Git status"
echo '{"tool": "Bash", "arguments": {"command": "git status"}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 7: Reading dotfiles (should be denied)
echo "Test 7: Reading dotfiles"
echo '{"tool": "Read", "arguments": {"file_path": "/Users/jsp/dev/dots/some/config"}}' | python3 "$GUARDRAIL" | jq .
echo ""

# Test 8: Environment dump (should be denied)
echo "Test 8: Environment dump"
echo '{"tool": "Bash", "arguments": {"command": "printenv"}}' | python3 "$GUARDRAIL" | jq .
echo ""

echo "✓ All tests completed"

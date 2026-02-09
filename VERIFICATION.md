# Verifying Guardrails Installation

## 1. Check Files Are Installed

```bash
# Check hook script exists
ls -lh ~/.claude/hooks/guardrail.py

# Check policy exists
ls -lh ~/.claude/hooks/policy.yaml

# Verify hook is executable
test -x ~/.claude/hooks/guardrail.py && echo "✓ Hook is executable" || echo "✗ Hook is not executable"
```

## 2. Check Settings Configuration

```bash
# For Nix-managed settings (symlinked)
cat ~/.claude/settings.json | grep -A 5 "hooks\|PreToolUse"

# Should show something like:
#   "hooks": {
#     "PreToolUse": "/Users/jsp/.claude/hooks/guardrail.py"
#   }
```

## 3. Test the Hook Directly

Test the guardrail script manually with JSON input:

```bash
# Test 1: Should DENY reading .env file
echo '{"tool": "Read", "arguments": {"file_path": "/some/path/.env"}}' | ~/.claude/hooks/guardrail.py | jq .

# Expected output:
# {
#   "action": "deny",
#   "reason": "Blocked reading secret file: /some/path/.env. Override explicitly if needed."
# }

# Test 2: Should ALLOW reading normal file
echo '{"tool": "Read", "arguments": {"file_path": "/some/path/README.md"}}' | ~/.claude/hooks/guardrail.py | jq .

# Expected output:
# {
#   "action": "allow"
# }

# Test 3: Should DENY dangerous rm -rf /
echo '{"tool": "Bash", "arguments": {"command": "rm -rf /"}}' | ~/.claude/hooks/guardrail.py | jq .

# Expected output:
# {
#   "action": "deny",
#   "reason": "Blocked potentially dangerous command: rm -rf /"
# }

# Test 4: Should ALLOW safe rm -rf node_modules
echo '{"tool": "Bash", "arguments": {"command": "rm -rf node_modules"}}' | ~/.claude/hooks/guardrail.py | jq .

# Expected output:
# {
#   "action": "allow"
# }

# Test 5: Should DENY git commit
echo '{"tool": "Bash", "arguments": {"command": "git commit -m \"test\""}}' | ~/.claude/hooks/guardrail.py | jq .

# Expected output:
# {
#   "action": "deny",
#   "reason": "Blocked git command that modifies history/remotes: git commit -m \"test\". Git is read-only by default."
# }

# Test 6: Should ALLOW git status
echo '{"tool": "Bash", "arguments": {"command": "git status"}}' | ~/.claude/hooks/guardrail.py | jq .

# Expected output:
# {
#   "action": "allow"
# }
```

## 4. Test in Claude Code

After restarting Claude Code, try asking it to do something that should be blocked:

### Test Secret File Protection
```
You: "Can you read my .env file?"
```
Claude should get blocked and explain why it can't read secret files.

### Test Dotfiles Protection
```
You: "Can you show me /Users/jsp/dev/dots/secrets/secrets.nix?"
```
Claude should get blocked from reading your dotfiles (unless explicitly allowlisted).

### Test Git Protection
```
You: "Create a git commit with message 'test'"
```
Claude should get blocked from running git commit.

### Test Dangerous Commands
```
You: "Run rm -rf /"
```
Claude should get blocked from running dangerous commands.

## 5. Enable Verbose Logging (Optional)

To see what the guardrails are doing in real-time:

### For Nix users:
Edit your `~/dev/dots/home/default.nix`:
```nix
jsp.claude-code = {
  enable = true;
  guardrails = {
    enable = true;
    verbose = true;  # Change to true
  };
};
```

Then rebuild:
```bash
darwin-rebuild switch --flake .#remus
```

### For non-Nix users:
Edit `~/.claude/settings.json`:
```json
{
  "env": {
    "GUARDRAILS_VERBOSE": "1"
  }
}
```

Now when you restart Claude Code, you'll see guardrail decisions in the logs.

## 6. Check Claude Code Logs

If something seems wrong, check the logs:

```bash
# Check for any hook errors
# (Location depends on how you run Claude Code)
tail -f ~/Library/Logs/claude-code/main.log
```

## Quick Verification Script

Save this as `verify-guardrails.sh`:

```bash
#!/usr/bin/env bash

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
if grep -q "PreToolUse" ~/.claude/settings.json 2>/dev/null; then
    echo "   ✓ PreToolUse hook configured"
else
    echo "   ✗ PreToolUse hook not found in settings.json"
fi

# Test hook
echo ""
echo "3. Testing hook functionality..."

# Test deny case
RESULT=$(echo '{"tool": "Read", "arguments": {"file_path": ".env"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "deny"'; then
    echo "   ✓ Secret file protection working"
else
    echo "   ✗ Secret file protection not working"
fi

# Test allow case
RESULT=$(echo '{"tool": "Read", "arguments": {"file_path": "README.md"}}' | ~/.claude/hooks/guardrail.py 2>/dev/null)
if echo "$RESULT" | grep -q '"action": "allow"'; then
    echo "   ✓ Normal file access working"
else
    echo "   ✗ Normal file access not working"
fi

echo ""
echo "✅ Verification complete! Restart Claude Code to activate guardrails."
```

Make it executable and run:
```bash
chmod +x verify-guardrails.sh
./verify-guardrails.sh
```

## Troubleshooting

### Hook not being called?
- Make sure you restarted Claude Code after installation
- Check that settings.json has the correct path to guardrail.py
- Verify the hook is executable: `chmod +x ~/.claude/hooks/guardrail.py`

### Python errors?
- Make sure PyYAML is installed: `pip3 install pyyaml`
- For Nix users, this should be handled automatically

### Policy not loading?
- Check that GUARDRAILS_POLICY_PATH points to the right location
- Verify policy.yaml exists at that path
- Enable verbose logging to see what's happening

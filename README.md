# guardrails

Local, opinionated guardrails for Claude Code tool calls on my machines.

This is a PreToolUse hook for Claude Code that inspects every tool call (Bash, file read/write, git tools, MCP servers, etc.) and decides whether to:

- allow it as-is
- deny it with an explanation

Everything is local – no external SaaS, no remote policy engine.

## Hard rules

These rules are enforced in code, not just docs:

- **No secrets:**
  - Never read `.env`, `.env.*`, `secrets.*`, `*.age`, or other obvious secret files unless I explicitly override.
  - Never suggest commands that dump all env vars (`printenv`, `env`) unless I explicitly ask.

- **Dotfiles are infra:**
  - Never read or edit anything under `/Users/jsp/dev/dots` by default.
  - Only allow access to specific, explicit allow-listed files in that tree (for example when I am actively working on a module and say so).

- **No automatic git changes:**
  - Never run git commands that create or rewrite commits or push:
    - `git commit`, `git commit -am`, `git rebase`, `git push`, etc.
  - Git tools are read-only: status, diff, log, etc. are fine; anything that modifies history or remotes is denied.

- **Dangerous shell commands:**
  - Deny obviously destructive commands (`rm -rf /`, `rm -rf ~`, etc.) unless they match a safe, explicit pattern like `rm -rf node_modules` in a project directory.

## How it works

- Claude Code calls a PreToolUse hook before executing any tool.
- This repo provides `guardrail.py`, a Python script that:
  - Receives the tool name and arguments on stdin (Claude's hook protocol).
  - Applies a local policy (simple Python logic plus optional `policy.yaml`).
  - Prints a JSON response telling Claude to `allow` or `deny`.

There is no network call – all decisions are made locally.

## Files

- `guardrail.py` – main PreToolUse hook.
- `policy.yaml` – config for paths and patterns:
  - secret file patterns
  - dotfiles root (`/Users/jsp/dev/dots`)
  - allowed subpaths under dotfiles
  - dangerous shell patterns to block
- `install.sh` – local installer (requires cloned repo).
- `install-remote.sh` – remote installer (no clone required).
- `uninstall.sh` – removes the hook and cleans up settings.
- `test_guardrails.sh` – test suite to verify the implementation.

## Install

### Option 1: Remote Install (No Clone Required)

Run this one-liner to download and install:

```bash
curl -fsSL https://raw.githubusercontent.com/jaspermayone/guardrails/main/install-remote.sh | bash
```

Or download and inspect first:

```bash
curl -fsSL https://raw.githubusercontent.com/jaspermayone/guardrails/main/install-remote.sh -o install-remote.sh
bash install-remote.sh
```

### Option 2: Clone and Install

```bash
git clone git@github.com:jaspermayone/guardrails.git
cd guardrails
./install.sh
```

Both installers will:

- copy `guardrail.py` to `~/.claude/hooks/guardrail.py`
- add or update a PreToolUse hook entry in `~/.claude/settings.json` pointing to it
- set optional env vars like:
  - `GUARDRAILS_POLICY_PATH` – path to `policy.yaml`
  - `GUARDRAILS_VERBOSE=1` – log decisions to stderr

Then restart Claude Code.

### Nix/Home Manager Support

If your `settings.json` is managed by Nix/Home Manager, the installer will detect this and provide the appropriate configuration snippet. Add this to your Home Manager config:

```nix
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
```

After adding, rebuild with `home-manager switch` and restart Claude Code.

**Note**: The `.claude` directory is automatically excluded from dotfiles protection, even if it's under your dotfiles root.

## Behavior

On each tool call, the hook will:

1. Inspect `tool_name` and its arguments.
2. If it is a file operation:
   - Deny if the path matches secret patterns or dotfiles paths not on the allow-list.
3. If it is a Bash command:
   - Deny if it includes dangerous patterns (`rm -rf` outside the safe list, `cat .env`, etc.).
4. If it is a git tool:
   - Deny if the command contains `commit`, `push`, `rebase`, or similar.
5. Otherwise:
   - Allow the call to proceed unchanged.

Denied calls return a short explanation for why they were blocked.

## Uninstall

To remove the guardrails:

```bash
# If you cloned the repo
cd guardrails
./uninstall.sh

# Or manually
rm ~/.claude/hooks/guardrail.py ~/.claude/hooks/policy.yaml
# Then remove the PreToolUse hook from ~/.claude/settings.json
```

## Non-goals

- This project does not talk to any external API.
- It does not auto-fix or rewrite commands; it only allows or blocks.
- It does not try to be a generic policy engine; it is tuned specifically to my setup (remus, `/Users/jsp/dev/dots`, Nix, Homebrew, etc.).

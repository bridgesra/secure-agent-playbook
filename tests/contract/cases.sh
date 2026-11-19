#!/usr/bin/env bash
# Shipped Claude settings plus the Case 2 Dev Container recipe.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

settings="${TEMPLATE}/.claude/settings.json"
dc="${TEMPLATE}/.devcontainer/devcontainer.json"

# All cases (shipped template files)
assert_jq "${settings}" '.permissions.deny | length > 0' \
  "settings deny list present"
assert_jq "${settings}" '.permissions.deny | index("Read(~/.git-credentials)")' \
  "settings deny git credential store"
assert_jq "${settings}" '.permissions.deny | index("Read(~/.claude/.credentials.json)")' \
  "settings deny Claude OAuth credentials"
assert_jq "${settings}" '.statusLine.command | test("statusline\\.sh")' \
  "settings statusLine points at statusline.sh"
assert_jq "${settings}" '.env.ANTHROPIC_BASE_URL == "http://127.0.0.1:8787"' \
  "settings Headroom ANTHROPIC_BASE_URL"

# Case 2 (VS Code Dev Container) recipe
assert_jq "${dc}" '.forwardPorts | index(8787)' \
  "devcontainer forwards 8787"
assert_jq "${dc}" '.postStartCommand == "bash .devcontainer/start-headroom.sh"' \
  "devcontainer postStart starts Headroom"
assert_jq "${dc}" '.features | has("ghcr.io/anthropics/devcontainer-features/claude-code:1.0")' \
  "devcontainer has Claude Code feature"
assert_jq "${dc}" '.postCreateCommand == "bash .devcontainer/setup-agent-tools.sh"' \
  "devcontainer postCreate runs setup with no mode"
assert_jq "${dc}" '.customizations.vscode.extensions | index("anthropic.claude-code")' \
  "devcontainer installs Claude extension"
assert_jq "${dc}" '.remoteEnv | has("ANTHROPIC_API_KEY")' \
  "devcontainer forwards ANTHROPIC_API_KEY"
assert_jq "${dc}" '.remoteEnv | has("CLAUDE_CODE_OAUTH_TOKEN")' \
  "devcontainer forwards CLAUDE_CODE_OAUTH_TOKEN"
assert_jq "${dc}" '.mounts | map(test("claude-code-config")) | any' \
  "devcontainer mounts claude-code-config volume"

finish

#!/usr/bin/env bash
# Per-case config matrix: shared add-ons plus Case 2 vs Case 3 recipes.
set -u
source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"

mcp="${TEMPLATE}/.cursor/mcp.json"
settings="${TEMPLATE}/.claude/settings.json"
both="${TEMPLATE}/.devcontainer/devcontainer.json"
cursor="${TEMPLATE}/.devcontainer/devcontainer.cursor-only.json"

# All cases (shipped template files)
assert_jq "${mcp}" '.mcpServers.headroom.command == "/usr/local/bin/headroom"' \
  "mcp headroom command"
assert_jq "${mcp}" '.mcpServers.headroom.args | index("mcp")' \
  "mcp headroom args include mcp"
assert_jq "${mcp}" '.mcpServers.headroom.args | index("http://127.0.0.1:8787")' \
  "mcp proxy url"

assert_jq "${settings}" '.permissions.deny | length > 0' \
  "settings deny list present"
assert_jq "${settings}" '.statusLine.command | test("statusline\\.sh")' \
  "settings statusLine points at statusline.sh"
assert_jq "${settings}" '.env.ANTHROPIC_BASE_URL == "http://127.0.0.1:8787"' \
  "settings Headroom ANTHROPIC_BASE_URL"

for recipe in "${both}" "${cursor}"; do
  assert_jq "${recipe}" '.forwardPorts | index(8787)' \
    "$(basename "${recipe}") forwards 8787"
  assert_jq "${recipe}" '.postStartCommand == "bash .devcontainer/start-headroom.sh"' \
    "$(basename "${recipe}") postStart starts Headroom"
done

# Case 3 (both) recipe
assert_jq "${both}" '.features | has("ghcr.io/anthropics/devcontainer-features/claude-code:1.0")' \
  "both has Claude Code feature"
assert_jq "${both}" '.postCreateCommand == "bash .devcontainer/setup-agent-tools.sh both"' \
  "both postCreate mode both"
assert_jq "${both}" '.customizations.vscode.extensions | index("anthropic.claude-code")' \
  "both installs Claude extension"
assert_jq "${both}" '.remoteEnv | has("ANTHROPIC_API_KEY")' \
  "both forwards ANTHROPIC_API_KEY"
assert_jq "${both}" '.remoteEnv | has("CLAUDE_CODE_OAUTH_TOKEN")' \
  "both forwards CLAUDE_CODE_OAUTH_TOKEN"
assert_jq "${both}" '.mounts | map(test("claude-code-config")) | any' \
  "both mounts claude-code-config volume"

# Case 2 (cursor-only) recipe — this file is what new-project copies over
assert_jq "${cursor}" '.features | has("ghcr.io/anthropics/devcontainer-features/claude-code:1.0") | not' \
  "cursor-only has no Claude Code feature"
assert_jq "${cursor}" '.postCreateCommand == "bash .devcontainer/setup-agent-tools.sh cursor"' \
  "cursor-only postCreate mode cursor"
assert_jq "${cursor}" '.customizations.vscode.extensions | index("anthropic.claude-code") | not' \
  "cursor-only has no Claude extension"
assert_jq "${cursor}" 'has("remoteEnv") | not' \
  "cursor-only has no remoteEnv API keys"

finish
